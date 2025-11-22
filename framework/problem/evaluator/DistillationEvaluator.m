classdef DistillationEvaluator < handle
    % DistillationEvaluator 精馏塔优化评估器
    % Evaluator for Distillation Column Optimization
    %
    % 功能:
    %   - 调用Aspen Plus仿真器
    %   - 计算总年化成本(TAC)
    %   - 计算CO2排放量
    %   - 检查工艺约束
    %   - 返回多目标函数值
    %
    % 使用示例:
    %   simulator = AspenPlusSimulator();
    %   simulator.connect(config);
    %
    %   evaluator = DistillationEvaluator(simulator);
    %   evaluator.setCostModule(costModule);
    %   evaluator.setEmissionModule(emissionModule);
    %
    %   x = [25, 2.5, 15];  % [板数, 回流比, 进料位置]
    %   objectives = evaluator.evaluate(x);


    properties (Access = private)
        simulator;          % AspenPlusSimulator对象
        costModule;         % SeiderCostModule对象
        emissionModule;     % EmissionModule对象
        logger;             % Logger对象
        evaluationCount;    % 评估计数
    end

    properties (Access = public)
        % 约束设置
        minPurity;          % 最小纯度要求
        maxEnergyRatio;     % 最大能耗比

        % 设备参数
        columnDiameter;     % 塔径(m)
        feedRate;           % 进料流量(kmol/hr)
        feedComposition;    % 进料组成

        % 惩罚系数
        constraintPenalty;  % 约束违反惩罚
    end

    methods
        function obj = DistillationEvaluator(simulator)
            % DistillationEvaluator 构造函数
            %
            % 输入:
            %   simulator - AspenPlusSimulator对象
            %
            % 示例:
            %   evaluator = DistillationEvaluator(simulator);

            obj.simulator = simulator;
            obj.costModule = [];
            obj.emissionModule = [];
            obj.evaluationCount = 0;

            % 默认约束
            obj.minPurity = 0.995;        % 最小纯度99.5%
            obj.maxEnergyRatio = 10.0;    % 最大能耗比

            % 默认设备参数
            obj.columnDiameter = 1.5;     % 塔径1.5m
            obj.feedRate = 100;           % 进料100 kmol/hr
            obj.feedComposition = [0.4, 0.6];  % 40% 乙醇

            % 惩罚系数
            obj.constraintPenalty = 1e8;

            % 创建logger
            if exist('Logger', 'class')
                obj.logger = Logger.getLogger('DistillationEvaluator');
            else
                obj.logger = [];
            end
        end

        function objectives = evaluate(obj, x)
            % evaluate 评估给定设计的目标函数值
            %
            % 输入:
            %   x - 设计变量向量 [numStages, refluxRatio, feedStage]
            %       numStages - 理论板数
            %       refluxRatio - 回流比
            %       feedStage - 进料位置
            %
            % 输出:
            %   objectives - 目标函数值 [TAC, CO2]
            %       TAC - 总年化成本 (USD/year)
            %       CO2 - CO2排放量 (ton/year)
            %
            % 示例:
            %   objectives = evaluator.evaluate([25, 2.5, 15]);

            obj.evaluationCount = obj.evaluationCount + 1;

            % 提取设计变量
            numStages = round(x(1));      % 板数必须是整数
            refluxRatio = x(2);
            feedStage = round(x(3));      % 进料位置必须是整数

            obj.logInfo(sprintf('评估 #%d: 板数=%d, 回流比=%.4f, 进料位置=%d', ...
                obj.evaluationCount, numStages, refluxRatio, feedStage));

            try
                % 步骤1: 运行Aspen Plus仿真
                simResults = obj.runSimulation([numStages, refluxRatio, feedStage]);

                if ~simResults.success
                    obj.logWarning('仿真失败，返回惩罚值');
                    objectives = [obj.constraintPenalty, obj.constraintPenalty];
                    return;
                end

                % 步骤2: 检查约束
                if ~obj.checkConstraints(simResults)
                    obj.logWarning('约束不满足，返回惩罚值');
                    objectives = [obj.constraintPenalty, obj.constraintPenalty];
                    return;
                end

                % 步骤3: 计算成本
                TAC = obj.calculateCost(numStages, simResults);

                % 步骤4: 计算排放
                CO2 = obj.calculateEmission(simResults);

                % 返回目标值
                objectives = [TAC, CO2];

                obj.logInfo(sprintf('  结果: TAC=%.2e USD/year, CO2=%.2f ton/year', TAC, CO2));

            catch ME
                obj.logError(sprintf('评估异常: %s', ME.message));
                objectives = [obj.constraintPenalty, obj.constraintPenalty];
            end
        end

        function setCostModule(obj, module)
            % setCostModule 设置成本计算模块
            obj.costModule = module;
        end

        function setEmissionModule(obj, module)
            % setEmissionModule 设置排放计算模块
            obj.emissionModule = module;
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
            %   x - [numStages, refluxRatio, feedStage]
            %
            % 输出:
            %   simResults - 仿真结果结构体

            simResults = struct();
            simResults.success = false;

            try
                % 设置Aspen变量
                obj.simulator.setVariables(x);

                % 运行仿真
                success = obj.simulator.run(300);  % 300秒超时

                if ~success
                    obj.logWarning('Aspen仿真运行失败');
                    return;
                end

                % 获取结果
                simResults.reboilerDuty = obj.simulator.getVariable('reboilerDuty');      % kW
                simResults.condenserDuty = obj.simulator.getVariable('condenserDuty');    % kW
                simResults.topPurity = obj.simulator.getVariable('topPurity');            % 塔顶纯度
                simResults.bottomPurity = obj.simulator.getVariable('bottomPurity');      % 塔底纯度
                simResults.topFlowRate = obj.simulator.getVariable('topFlowRate');        % kmol/hr
                simResults.bottomFlowRate = obj.simulator.getVariable('bottomFlowRate');  % kmol/hr

                simResults.success = true;

            catch ME
                obj.logError(sprintf('仿真执行异常: %s', ME.message));
                simResults.success = false;
            end
        end

        function isValid = checkConstraints(obj, simResults)
            % checkConstraints 检查工艺约束
            %
            % 输入:
            %   simResults - 仿真结果
            %
            % 输出:
            %   isValid - 约束是否满足

            isValid = true;

            % 约束1: 塔顶纯度必须 >= 最小纯度
            if simResults.topPurity < obj.minPurity
                obj.logWarning(sprintf('纯度约束: %.4f < %.4f', ...
                    simResults.topPurity, obj.minPurity));
                isValid = false;
                return;
            end

            % 约束2: 能耗比检查
            if simResults.reboilerDuty <= 0
                obj.logWarning('再沸器负荷为零或负值');
                isValid = false;
                return;
            end

            energyRatio = simResults.condenserDuty / simResults.reboilerDuty;
            if energyRatio > obj.maxEnergyRatio
                obj.logWarning(sprintf('能耗比约束: %.2f > %.2f', ...
                    energyRatio, obj.maxEnergyRatio));
                isValid = false;
                return;
            end

            % 约束3: 流量合理性检查
            if simResults.topFlowRate <= 0 || simResults.bottomFlowRate <= 0
                obj.logWarning('产品流量为零或负值');
                isValid = false;
                return;
            end
        end

        function TAC = calculateCost(obj, numStages, simResults)
            % calculateCost 计算总年化成本
            %
            % 输入:
            %   numStages - 理论板数
            %   simResults - 仿真结果
            %
            % 输出:
            %   TAC - 总年化成本 (USD/year)

            if isempty(obj.costModule)
                error('DistillationEvaluator:NoCostModule', ...
                    '未设置成本计算模块');
            end

            % 准备成本模块输入
            costInput = struct();
            costInput.equipmentType = 'column';
            costInput.diameter = obj.columnDiameter;
            costInput.numStages = numStages;
            costInput.temperature = 373.15;    % 假设塔顶温度100°C
            costInput.pressure = 101325;        % 假设常压
            costInput.materialColumn = 'SS304';
            costInput.materialTray = 'SS304';

            % 运营成本
            costInput.reboilerDuty = simResults.reboilerDuty;     % kW
            costInput.condenserDuty = simResults.condenserDuty;   % kW

            % 假设蒸汽成本 $20/GJ, 冷却水成本 $0.5/GJ
            steamCostRate = 20;     % USD/GJ
            coolingCostRate = 0.5;  % USD/GJ

            % kW * 3.6 = MJ/hr = 0.0036 GJ/hr
            costInput.steamCost = simResults.reboilerDuty * 0.0036 * steamCostRate;    % USD/hr
            costInput.coolingCost = simResults.condenserDuty * 0.0036 * coolingCostRate;  % USD/hr

            % 执行成本计算
            costResult = obj.costModule.execute(costInput);

            TAC = costResult.totalCost;
        end

        function CO2 = calculateEmission(obj, simResults)
            % calculateEmission 计算CO2排放量
            %
            % 输入:
            %   simResults - 仿真结果
            %
            % 输出:
            %   CO2 - CO2排放量 (ton/year)

            if isempty(obj.emissionModule)
                error('DistillationEvaluator:NoEmissionModule', ...
                    '未设置排放计算模块');
            end

            % 准备排放模块输入
            emissionInput = struct();

            % 蒸汽排放因子: 0.184 kg CO2/kg steam
            % 假设蒸汽焓值 2000 kJ/kg
            steamRate = simResults.reboilerDuty / 2000;  % kg/s
            emissionInput.steamCO2Rate = steamRate * 0.184 * 3600;  % kg CO2/hr

            % 冷却水排放因子很小，可忽略
            emissionInput.coolingCO2Rate = 0;

            % 产量
            emissionInput.productionRate = simResults.topFlowRate * 46;  % kg/hr (假设乙醇)

            % 执行排放计算
            emissionResult = obj.emissionModule.execute(emissionInput);

            CO2 = emissionResult.co2Emission;
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
