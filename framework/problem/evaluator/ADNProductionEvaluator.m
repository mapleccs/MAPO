classdef ADNProductionEvaluator < handle
    % ADNProductionEvaluator ADN生产工艺评估器
    % Evaluator for ADN Production Process Optimization
    %
    % 功能:
    %   - 调用Aspen Plus仿真器进行二级氢氰化工段仿真
    %   - 计算ADN质量分数（最大化）
    %   - 计算ADN质量流量（最大化）
    %   - 检查工艺收敛性约束
    %
    % 优化目标:
    %   1. 最大化ADN质量分数（转为最小化 -ADN_FRAC）
    %   2. 最大化ADN质量流量（转为最小化 -ADN_FLOW）
    %
    % 设计变量:
    %   1. T0301_BF - 塔底采出比 [0.3, 0.9]
    %   2. T0301_FEED_STAGE - 进料板位置 [10, 20]
    %   3. T0301_BASIS_RR - 回流比 [1, 3]
    %
    % 使用示例:
    %   simulator = AspenPlusSimulator();
    %   simulator.connect(config);
    %
    %   evaluator = ADNProductionEvaluator(simulator);
    %   x = [0.6, 15, 2.0];  % [BF, FEED_STAGE, BASIS_RR]
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
        function obj = ADNProductionEvaluator(simulator)
            % ADNProductionEvaluator 构造函数
            %
            % 输入:
            %   simulator - AspenPlusSimulator对象
            %
            % 示例:
            %   evaluator = ADNProductionEvaluator(simulator);

            obj.simulator = simulator;
            obj.evaluationCount = 0;

            % 惩罚系数（收敛失败时返回大的正值，因为是最小化问题）
            obj.constraintPenalty = 1e8;

            % 默认超时时间
            obj.timeout = 300;  % 5分钟

            % 创建logger
            if exist('Logger', 'class')
                obj.logger = Logger.getLogger('ADNProductionEvaluator');
            else
                obj.logger = [];
            end
        end

        function result = evaluate(obj, x)
            % evaluate 评估给定设计的目标函数值
            %
            % 输入:
            %   x - 设计变量向量 [T0301_BF, T0301_FEED_STAGE, T0301_BASIS_RR]
            %       T0301_BF - 塔底采出比 [0.3, 0.9]
            %       T0301_FEED_STAGE - 进料板位置 [10, 20]（整数）
            %       T0301_BASIS_RR - 回流比 [1, 3]
            %
            % 输出:
            %   result - 评估结果结构体
            %       result.objectives - 目标函数值 [-ADN_FRAC, -ADN_FLOW]
            %           -ADN_FRAC - 负的ADN质量分数（最大化转最小化）
            %           -ADN_FLOW - 负的ADN质量流量（最大化转最小化）
            %
            % 示例:
            %   result = evaluator.evaluate([0.6, 15, 2.0]);

            obj.evaluationCount = obj.evaluationCount + 1;

            % 提取设计变量
            T0301_BF = x(1);
            T0301_FEED_STAGE = round(x(2));  % 进料板位置必须是整数
            T0301_BASIS_RR = x(3);

            obj.logInfo(sprintf('评估 #%d: BF=%.4f, FEED_STAGE=%d, BASIS_RR=%.4f', ...
                obj.evaluationCount, T0301_BF, T0301_FEED_STAGE, T0301_BASIS_RR));

            % 初始化结果结构体
            result = struct();

            try
                % 步骤1: 运行Aspen Plus仿真
                simResults = obj.runSimulation([T0301_BF, T0301_FEED_STAGE, T0301_BASIS_RR]);

                if ~simResults.success
                    obj.logWarning('仿真失败或收敛失败，返回惩罚值');
                    result.objectives = [obj.constraintPenalty, obj.constraintPenalty];
                    return;
                end

                % 步骤2: 提取目标值
                ADN_FRAC = simResults.ADN_FRAC;  % ADN质量分数
                ADN_FLOW = simResults.ADN_FLOW;  % ADN质量流量

                % 步骤3: 转换为最小化问题（取负值）
                result.objectives = [-ADN_FRAC, -ADN_FLOW];

                obj.logInfo(sprintf('  结果: ADN质量分数=%.6f, ADN质量流量=%.6f kg/hr', ...
                    ADN_FRAC, ADN_FLOW));
                obj.logInfo(sprintf('  目标值: obj1=%.6f, obj2=%.6f', ...
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
            %   x - [T0301_BF, T0301_FEED_STAGE, T0301_BASIS_RR]
            %
            % 输出:
            %   simResults - 仿真结果结构体
            %       success - 仿真是否成功
            %       ADN_FRAC - ADN质量分数
            %       ADN_FLOW - ADN质量流量 (kg/hr)

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
                % ADN质量分数：\Data\Streams\0320\Output\MASSFRAC\MIXED\ADN
                simResults.ADN_FRAC = obj.simulator.getVariable('ADN_FRAC');

                % ADN质量流量：\Data\Streams\ADN\Output\MASSFLOW\MIXED\ADN
                simResults.ADN_FLOW = obj.simulator.getVariable('ADN_FLOW');

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
