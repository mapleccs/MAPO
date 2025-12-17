classdef ASPLProductionEvaluator < handle
    % ASPLProductionEvaluator 阿司匹林生产工艺评估器
    % Evaluator for ASPL (Aspirin) Production Process Optimization
    %
    % 功能:
    %   - 调用Aspen Plus仿真器进行阿司匹林生产工段仿真
    %   - 计算水杨酸(C7H6O3)质量分率（最大化）
    %   - 计算水杨酸(C7H6O3)质量流量/产量（最大化）
    %   - 检查工艺收敛性约束
    %
    % 优化目标:
    %   1. 最大化水杨酸质量分率（转为最小化 -SA_FRAC）
    %   2. 最大化水杨酸质量流量（转为最小化 -SA_FLOW）
    %
    % 设计变量:
    %   1. R101_FEED_TEMP - 反应釜进料温度 [80, 150] ℃
    %   2. R101_FEED_PRES - 反应釜进料压力 [0.5, 3.0] MPa
    %
    % 使用示例:
    %   simulator = AspenPlusSimulator();
    %   simulator.connect(config);
    %
    %   evaluator = ASPLProductionEvaluator(simulator);
    %   x = [100, 1.5];  % [TEMP, PRES]
    %   objectives = evaluator.evaluate(x);


    properties (Access = private)
        simulator;          % AspenPlusSimulator对象
        logger;             % Logger对象
        evaluationCount;    % 评估计数
    end

    properties (Access = public)
        % 惩罚系数
        constraintPenalty;  % 约束违反惩罚（用于收敛失败）
        timeout;            % 仿真超时时间（秒）
    end

    methods
        function obj = ASPLProductionEvaluator(simulator)
            % ASPLProductionEvaluator 构造函数
            %
            % 输入:
            %   simulator - AspenPlusSimulator对象
            %
            % 示例:
            %   evaluator = ASPLProductionEvaluator(simulator);

            obj.simulator = simulator;
            obj.evaluationCount = 0;

            % 惩罚系数（收敛失败时返回大的正值，因为是最小化问题）
            obj.constraintPenalty = 1e8;

            % 默认超时时间
            obj.timeout = 300;  % 5分钟

            % 创建logger
            if exist('Logger', 'class')
                obj.logger = Logger.getLogger('ASPLProductionEvaluator');
            else
                obj.logger = [];
            end
        end

        function result = evaluate(obj, x)
            % evaluate 评估给定设计的目标函数值
            %
            % 输入:
            %   x - 设计变量向量 [R101_FEED_TEMP, R101_FEED_PRES]
            %       R101_FEED_TEMP - 反应釜进料温度 [80, 150] ℃
            %       R101_FEED_PRES - 反应釜进料压力 [0.5, 3.0] MPa
            %
            % 输出:
            %   result - 评估结果结构体
            %       result.objectives - 目标函数值 [-SA_FRAC, -SA_FLOW]
            %           -SA_FRAC - 负的水杨酸质量分率（最大化转最小化）
            %           -SA_FLOW - 负的水杨酸质量流量（最大化转最小化）
            %
            % 示例:
            %   result = evaluator.evaluate([100, 1.5]);

            obj.evaluationCount = obj.evaluationCount + 1;

            % 提取设计变量
            R101_FEED_TEMP = x(1);
            R101_FEED_PRES = x(2);

            obj.logInfo(sprintf('评估 #%d: TEMP=%.2f℃, PRES=%.2fMPa', ...
                obj.evaluationCount, R101_FEED_TEMP, R101_FEED_PRES));

            % 初始化结果结构体
            result = struct();

            try
                % 步骤1: 运行Aspen Plus仿真
                simResults = obj.runSimulation([R101_FEED_TEMP, R101_FEED_PRES]);

                if ~simResults.success
                    obj.logWarning('仿真失败或收敛失败，返回惩罚值');
                    result.objectives = [obj.constraintPenalty, obj.constraintPenalty];
                    return;
                end

                % 步骤2: 提取目标值
                SA_FRAC = simResults.SA_FRAC;  % 水杨酸质量分率
                SA_FLOW = simResults.SA_FLOW;  % 水杨酸质量流量（产量）

                % 步骤3: 转换为最小化问题（取负值）
                result.objectives = [-SA_FRAC, -SA_FLOW];

                obj.logInfo(sprintf('  结果: 水杨酸质量分率=%.6f, 水杨酸产量=%.4f kg/hr', ...
                    SA_FRAC, SA_FLOW));
                obj.logInfo(sprintf('  目标值: obj1=%.6f, obj2=%.4f', ...
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
            %   x - [R101_FEED_TEMP, R101_FEED_PRES]
            %
            % 输出:
            %   simResults - 仿真结果结构体
            %       success - 仿真是否成功
            %       SA_FRAC - 水杨酸质量分率
            %       SA_FLOW - 水杨酸质量流量/产量 (kg/hr)

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

                % 获取结果
                % 水杨酸质量分率（需要根据实际Aspen模型中的流股名称调整）
                % 假设从0106流股中获取C7H6O3的质量分率和质量流量
                simResults.SA_FRAC = obj.simulator.getVariable('SA_FRAC');

                % 水杨酸质量流量/产量
                simResults.SA_FLOW = obj.simulator.getVariable('SA_FLOW');

                simResults.success = true;

            catch ME
                obj.logError(sprintf('仿真执行异常: %s', ME.message));
                simResults.success = false;
            end
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
