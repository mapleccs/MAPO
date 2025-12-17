classdef MyCaseEvaluator < Evaluator
    % MyCaseEvaluator - 用户自定义评估器模板（推荐从此文件复制）
    %
    % 评估器职责:
    %   - 接收算法给出的决策变量向量 x
    %   - 将 x 写入仿真器（simulator.setVariables）
    %   - 运行仿真（simulator.run）
    %   - 从仿真器提取结果并计算目标/约束
    %   - 返回统一的结果结构体（result.objectives / result.constraints）
    %
    % 评估器接口要求（被算法调用）:
    %   result = evaluator.evaluate(x)
    %   其中 result 必须是 struct，至少包含字段:
    %     - objectives  : 1×nObj 数值向量
    %     - constraints : 1×nCon 数值向量（可为空）
    %     - success     : logical
    %     - message     : char
    %
    % 配置文件:
    %   在 case_config.json 中设置:
    %     problem.evaluator.type = "MyCaseEvaluator"
    %     problem.evaluator.timeout = 300
    %     problem.evaluator.economicParameters = { ... }  % 可选
    %
    % 说明:
    %   - 最大化目标需要在此处取负值（框架内部统一为最小化）
    %   - 仿真失败/异常应返回惩罚值（默认 1e8）

    properties
        % 通用参数（runOptimizationAsync 会在存在该属性时写入）
        timeout = 300;                 % 仿真超时时间（秒）
        constraintPenalty = 1e8;       % 惩罚值（用于失败/不收敛）

        % ===== 可选：用户自定义参数（可通过 economicParameters 注入）=====
        productPrice = 1000;           % 产品价格 ($/ton)
        energyCost = 0.1;              % 能源成本 ($/kWh)
        operatingHours = 8000;         % 年运行小时数
    end

    properties (Access = private)
        simulator;                     % SimulatorBase 实例（AspenPlusSimulator 等）
    end

    methods
        function obj = MyCaseEvaluator(simulator)
            % 构造函数
            % 输入:
            %   simulator - 仿真器实例（可选；部分测试评估器可不依赖仿真器）

            obj@Evaluator();

            if nargin >= 1
                obj.simulator = simulator;
            else
                obj.simulator = [];
            end
        end

        function result = evaluate(obj, x)
            % evaluate - 核心评估函数

            % 计数（算法默认直接调用 evaluate，不会走 evaluateWithValidation）
            obj.evaluationCounter = obj.evaluationCounter + 1;

            try
                % 无仿真器场景（例如纯函数测试）——此处给出一个示例
                if isempty(obj.simulator)
                    f = sum(x(:)'.^2);
                    result = obj.createSuccessResult(f, [], '');
                    return;
                end

                % 1) 写入变量并运行仿真
                obj.simulator.setVariables(x);
                success = obj.simulator.run(obj.timeout);

                if ~success
                    result = obj.createPenaltyResult('仿真失败或未收敛');
                    return;
                end

                % 2) 读取结果并计算目标/约束（示例逻辑：请按你的问题修改）
                %
                % 推荐做法：把 Tab3 结果映射中需要用到的 key 映射好，
                % 然后在此处通过 key 获取数值。

                productFlow = obj.tryGetResultValue('PRODUCT_FLOW', NaN);  % kg/hr
                energyUsage = obj.tryGetResultValue('ENERGY', NaN);        % kW
                efficiency = obj.tryGetResultValue('EFFICIENCY', NaN);     % 0-1 或 %

                % 目标 1：利润（最大化 -> 取负最小化）
                objective1 = 0;
                if ~isnan(productFlow) && ~isnan(energyUsage)
                    annualRevenue = productFlow * obj.operatingHours * obj.productPrice / 1000; % $/year
                    annualCost = energyUsage * obj.operatingHours * obj.energyCost;             % $/year
                    profit = annualRevenue - annualCost;
                    objective1 = -profit;
                end

                % 目标 2：效率（最大化 -> 取负最小化；若为百分比请自行统一单位）
                objective2 = 0;
                if ~isnan(efficiency)
                    if efficiency > 1
                        efficiency = efficiency / 100;
                    end
                    objective2 = -efficiency;
                end

                objectives = obj.fitObjectivesToProblem([objective1, objective2]);

                % 约束（可选）：按 g(x) <= 0 形式返回（>0 为违反）
                constraints = [];
                if ~isnan(productFlow)
                    minProductFlow = 1000;                 % 示例：最小产量
                    constraints(end+1) = minProductFlow - productFlow; %#ok<AGROW>
                end
                if ~isnan(energyUsage)
                    maxEnergy = 5000;                      % 示例：最大能耗
                    constraints(end+1) = energyUsage - maxEnergy; %#ok<AGROW>
                end
                constraints = obj.fitConstraintsToProblem(constraints);

                result = obj.createSuccessResult(objectives, constraints, '');

            catch ME
                result = obj.createPenaltyResult(ME.message);
            end
        end
    end

    methods (Access = private)
        function value = tryGetResultValue(obj, resultName, defaultValue)
            % tryGetResultValue - 尝试按“结果映射名称”获取数值
            %
            % AspenPlusSimulator 提供 getVariable(name)（基于 resultMapping）
            % 其他仿真器可通过 SimulatorConfig 的 resultMapping 获取节点路径，
            % 再调用 getResults({nodePath}) 取回单值。

            value = defaultValue;

            if isempty(obj.simulator)
                return;
            end

            % 1) AspenPlusSimulator: getVariable(name)
            if ismethod(obj.simulator, 'getVariable')
                try
                    value = obj.simulator.getVariable(resultName);
                    return;
                catch
                end
            end

            % 2) Generic: use SimulatorConfig resultMapping -> nodePath -> getResults(nodePath)
            try
                cfg = obj.simulator.getConfig();
                if isa(cfg, 'SimulatorConfig') && cfg.hasResultMapping(resultName)
                    nodePath = cfg.getResultPath(resultName);
                    s = obj.simulator.getResults({nodePath});
                    f = fieldnames(s);
                    if ~isempty(f)
                        value = s.(f{1});
                    end
                    return;
                end
            catch
            end

            % 3) Fallback: try getResults({resultName}) (e.g., MATLABSimulator)
            try
                s = obj.simulator.getResults({resultName});
                if isstruct(s) && isfield(s, resultName)
                    value = s.(resultName);
                    return;
                end
                f = fieldnames(s);
                if ~isempty(f)
                    value = s.(f{1});
                end
            catch
            end
        end

        function objectives = fitObjectivesToProblem(obj, objectives)
            % 将目标向量长度适配到 problem.objectives 数量（若已设置 problem）
            n = obj.getProblemObjectiveCount();
            if n <= 0
                return;
            end
            objectives = objectives(:)';
            if numel(objectives) >= n
                objectives = objectives(1:n);
            else
                objectives = [objectives, zeros(1, n - numel(objectives))];
            end
        end

        function constraints = fitConstraintsToProblem(obj, constraints)
            % 将约束向量长度适配到 problem.constraints 数量（若已设置 problem）
            n = obj.getProblemConstraintCount();
            if n <= 0
                return;
            end
            constraints = constraints(:)';
            if numel(constraints) >= n
                constraints = constraints(1:n);
            else
                constraints = [constraints, zeros(1, n - numel(constraints))];
            end
        end

        function n = getProblemObjectiveCount(obj)
            n = 0;
            if ~isempty(obj.problem) && isa(obj.problem, 'OptimizationProblem')
                n = obj.problem.getNumberOfObjectives();
            end
        end

        function n = getProblemConstraintCount(obj)
            n = 0;
            if ~isempty(obj.problem) && isa(obj.problem, 'OptimizationProblem')
                n = obj.problem.getNumberOfConstraints();
            end
        end

        function result = createPenaltyResult(obj, message)
            nObj = obj.getProblemObjectiveCount();
            nCon = obj.getProblemConstraintCount();
            if nObj <= 0
                nObj = 1;
            end

            result = struct();
            result.objectives = obj.constraintPenalty * ones(1, nObj);
            result.constraints = obj.constraintPenalty * ones(1, nCon);
            result.success = false;
            result.message = message;
        end
    end
end

