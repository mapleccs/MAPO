classdef ORCEvaluator < handle
    % ORCEvaluator ORC余热回收系统评估器
    % Evaluator for ORC (Organic Rankine Cycle) Waste Heat Recovery System
    %
    % 功能:
    %   - 调用Aspen Plus仿真器进行ORC系统仿真
    %   - 计算ORC系统利润（最大化）
    %   - 计算ORC热力学效率（最大化）
    %   - 检查工艺收敛性约束
    %
    % 优化目标:
    %   1. 最大化ORC系统利润 (转为最小化 -PROFIT)
    %   2. 最大化ORC热力学效率 (转为最小化 -EFF)
    %
    % 设计变量:
    %   1. FLOW_S7 - S7流量进EV1 (kmol/hr)
    %   2. FLOW_S8 - S8流量进EV2 (kmol/hr)
    %   3. P_EVAP - 蒸发压力/泵出口压力 (bar)
    %   4. P_COND - 冷凝压力/透平出口压力 (bar)
    %
    % 使用示例:
    %   simulator = AspenPlusSimulator();
    %   simulator.connect(config);
    %
    %   evaluator = ORCEvaluator(simulator);
    %   x = [40, 50, 2.6, 1.0];  % [FLOW_S7, FLOW_S8, P_EVAP, P_COND
    %   result = evaluator.evaluate(x);


    properties (Access = private)
        simulator;          % AspenPlusSimulator对象
        logger;             % Logger对象
        evaluationCount;    % 评估计数
    end

    properties (Access = public)
        % 惩罚系数
        constraintPenalty;  % 约束违反惩罚（用于收敛失败）
        timeout;            % 仿真超时时间（秒）

        % 经济参数（可根据实际情况调整）
        electricityPrice;   % 电价 ($/kWh)
        operatingHours;     % 年运行小时数 (hr/year)
        coolingWaterCost;   % 冷却水成本 ($/GJ)
    end

    methods
        function obj = ORCEvaluator(simulator)
            % ORCEvaluator 构造函数
            %
            % 输入:
            %   simulator - AspenPlusSimulator对象
            %
            % 示例:
            %   evaluator = ORCEvaluator(simulator);

            obj.simulator = simulator;
            obj.evaluationCount = 0;

            % 惩罚系数（收敛失败时返回大的正值，因为是最小化问题）
            obj.constraintPenalty = 1e8;

            % 默认超时时间
            obj.timeout = 300;  % 5分钟

            % 默认经济参数
            obj.electricityPrice = 0.1;      % 0.1 $/kWh
            obj.operatingHours = 8000;       % 8000 hr/year
            obj.coolingWaterCost = 0.354;    % 0.354 $/GJ (参考值)

            % 创建logger
            if exist('Logger', 'class')
                obj.logger = Logger.getLogger('ORCEvaluator');
            else
                obj.logger = [];
            end
        end

        function result = evaluate(obj, x)
            % evaluate 评估给定设计的目标函数值
            %
            % 输入:
            %   x - 设计变量向量 [FLOW_S7, FLOW_S8, P_EVAP, P_COND, T_CON_OUT]
            %       FLOW_S7 - S7流量进EV1 (kmol/hr)
            %       FLOW_S8 - S8流量进EV2 (kmol/hr)
            %       P_EVAP - 蒸发压力/泵出口压力 (bar)
            %       P_COND - 冷凝压力/透平出口压力 (bar)
            %       T_CON_OUT - 冷凝器出口温度 (C)
            %
            % 输出:
            %   result - 评估结果结构体
            %       result.objectives - 目标函数值 [-PROFIT, -EFF]
            %           -PROFIT - 负的ORC系统利润 ($/year)（最大化转最小化）
            %           -EFF - 负的ORC热力学效率 (%)（最大化转最小化）
            %
            % 示例:
            %   result = evaluator.evaluate([40, 50, 2.6, 1.0, 45]);

            obj.evaluationCount = obj.evaluationCount + 1;

            % 提取设计变量（5个变量）
            FLOW_S7 = x(1);
            FLOW_S8 = x(2);
            P_EVAP = x(3);
            P_COND = x(4);

            % 计算总流量
            TOTAL_FLOW = FLOW_S7 + FLOW_S8;

            obj.logInfo(sprintf('评估 #%d: S7=%.4f, S8=%.4f, Total=%.4f, P_EVAP=%.4f, P_COND=%.4f', ...
                obj.evaluationCount, FLOW_S7, FLOW_S8, TOTAL_FLOW, P_EVAP, P_COND));

            % 初始化结果结构体
            result = struct();

            try
                % 步骤1: 运行Aspen Plus仿真
                simResults = obj.runSimulation(x);

                if ~simResults.success
                    obj.logWarning('仿真失败或收敛失败，返回惩罚值');
                    result.objectives = [obj.constraintPenalty, obj.constraintPenalty];
                    return;
                end

                % 步骤2: 计算目标函数
                [PROFIT, EFF] = obj.calculateObjectives(simResults);

                % 步骤3: 转换为最小化问题（取负值）
                result.objectives = [-PROFIT, -EFF];

                obj.logInfo(sprintf('  结果: ORC利润=%.2f $/yr, ORC效率=%.4f %%', ...
                    PROFIT, EFF));
                obj.logInfo(sprintf('  目标值: obj1=%.2f, obj2=%.6f', ...
                    result.objectives(1), result.objectives(2)));

            catch ME
                obj.logError(sprintf('评估异常: %s', ME.message));
                result.objectives = [obj.constraintPenalty, obj.constraintPenalty];
            end
        end

        function count = getEvaluationCount(obj)
            % getEvaluationCount 获取评估次数
            count = obj.evaluationCount;
        end

        function resetCount(obj)
            % resetCount 重置评估计数
            obj.evaluationCount = 0;
        end
    end

    methods (Access = private)
        function simResults = runSimulation(obj, x)
            % runSimulation 运行Aspen Plus仿真
            %
            % 输入:
            %   x - [FLOW_S7, FLOW_S8, P_EVAP, P_COND]
            %
            % 输出:
            %   simResults - 仿真结果结构体
            %       success - 仿真是否成功
            %       W_TUR - 透平做功 (kW)
            %       W_PUM - 泵耗功 (kW)
            %       Q_CON - 冷凝器冷负荷 (kW)
            %       H_1 - 透平入口焓值
            %       H_2 - 透平出口焓值
            %       H_3 - 泵入口焓值
            %       H_4 - 泵出口焓值

            simResults = struct();
            simResults.success = false;

            try
                % 设置Aspen变量
                obj.simulator.setVariables(x);

                % 运行仿真
                success = obj.simulator.run(obj.timeout);

                if ~success
                    obj.logWarning('Aspen仿真运行失败或收敛失败');
                    return;
                end

                % 获取仿真结果
                simResults.W_TUR = obj.simulator.getVariable('W_TUR');  % 透平做功 (kW)
                simResults.W_PUM = obj.simulator.getVariable('W_PUM');  % 泵耗功 (kW)
                simResults.Q_CON = obj.simulator.getVariable('Q_CON');  % CON冷负荷 (kW)

                % 获取焓值（用于计算热力学效率）
                simResults.H_1 = obj.simulator.getVariable('H_1');  % 透平入口焓值
                simResults.H_2 = obj.simulator.getVariable('H_2');  % 透平出口焓值
                simResults.H_3 = obj.simulator.getVariable('H_3');  % 泵入口焓值
                simResults.H_4 = obj.simulator.getVariable('H_4');  % 泵出口焓值

                simResults.success = true;

            catch ME
                obj.logError(sprintf('仿真执行异常: %s', ME.message));
                simResults.success = false;
            end
        end

        function [PROFIT, EFF] = calculateObjectives(obj, simResults)
            % calculateObjectives 计算目标函数
            %
            % 输入:
            %   simResults - 仿真结果结构体
            %
            % 输出:
            %   PROFIT - ORC系统年利润 ($/year)
            %   EFF - ORC热力学效率 (%)
            %
            % 计算公式:
            %   净功率 W_net = W_TUR - |W_PUM| (kW)
            %   热力学效率 EFF = ((H_1-H_2) - (H_4-H_3)) / (H_1-H_4) * 100 (%)
            %   年发电收益 = W_net * operatingHours * electricityPrice ($/year)
            %   年冷却成本 = |Q_CON| * operatingHours * coolingWaterCost / 1000 ($/year)
            %   年利润 PROFIT = 年发电收益 - 年冷却成本 ($/year)

            % 提取功率和热负荷（确保单位正确）
            W_TUR = simResults.W_TUR;  % 透平做功，通常为负值（对外做功）
            W_PUM = simResults.W_PUM;  % 泵耗功，通常为正值（消耗功）
            Q_CON = simResults.Q_CON;  % 冷凝器冷负荷

            % 提取焓值
            H_1 = simResults.H_1;  % 透平入口焓值
            H_2 = simResults.H_2;  % 透平出口焓值
            H_3 = simResults.H_3;  % 泵入口焓值
            H_4 = simResults.H_4;  % 泵出口焓值

            % 计算净功率（kW）
            % 注意：Aspen中透平做功通常为负值，泵耗功为正值
            W_net = abs(W_TUR) - abs(W_PUM);

            % 计算热力学效率 (%)
            % 公式: η = ((H_1-H_2) - (H_4-H_3)) / (H_1-H_4)
            numerator = (H_1 - H_2) - (H_4 - H_3);   % 净功（透平功 - 泵功）
            denominator = H_1 - H_4;                 % 吸热量
            if abs(denominator) > 1e-6
                EFF = (numerator / denominator) * 100;
            else
                EFF = 0;
            end

            % 计算年发电收益 ($/year)
            revenue = W_net * obj.operatingHours * obj.electricityPrice;

            % 计算年冷却成本 ($/year)
            % Q_CON单位为kW，转换为GJ: kW * hr / 1000 = MWh, MWh * 3.6 = GJ
            coolingCost = abs(Q_CON) * obj.operatingHours * 3.6 / 1000 * obj.coolingWaterCost;

            % 计算年利润 ($/year)
            PROFIT = revenue - coolingCost;

            obj.logInfo(sprintf('    W_net=%.4f kW, H_1=%.4f, H_2=%.4f, H_3=%.4f, H_4=%.4f', ...
                W_net, H_1, H_2, H_3, H_4));
            obj.logInfo(sprintf('    EFF=%.4f %%, 收益=%.2f $/yr, 冷却成本=%.2f $/yr, 利润=%.2f $/yr', ...
                EFF, revenue, coolingCost, PROFIT));
        end

        % 日志方法
        function logInfo(obj, message)
            if ~isempty(obj.logger)
                obj.logger.info(message);
            else
                fprintf('[INFO] %s\n', message);
            end
        end

        function logWarning(obj, message)
            if ~isempty(obj.logger)
                obj.logger.warning(message);
            else
                fprintf('[WARN] %s\n', message);
            end
        end

        function logError(obj, message)
            if ~isempty(obj.logger)
                obj.logger.error(message);
            else
                fprintf('[ERROR] %s\n', message);
            end
        end
    end
end
