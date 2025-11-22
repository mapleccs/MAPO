classdef OptimizationProblem < handle
    % OptimizationProblem 优化问题类
    % 定义完整的优化问题，包括变量、目标和约束
    %
    % 功能:
    %   - 管理变量、目标函数和约束条件
    %   - 从配置文件加载问题定义
    %   - 提供问题信息查询接口
    %   - 序列化支持
    %
    % 示例:
    %   % 创建问题
    %   problem = OptimizationProblem('MyProblem');
    %
    %   % 添加变量
    %   problem.addVariable(Variable('x1', 'continuous', [0, 10]));
    %   problem.addVariable(Variable('x2', 'integer', [1, 20]));
    %
    %   % 添加目标
    %   problem.addObjective(Objective('cost', 'minimize'));
    %   problem.addObjective(Objective('emission', 'minimize'));
    %
    %   % 添加约束
    %   problem.addConstraint(Constraint.createLessEqual('c1', 0));
    %
    %   % 从配置加载
    %   config = Config('config.json');
    %   problem.loadFromConfig(config);
    %
    %   % 获取信息
    %   nVars = problem.getNumberOfVariables();
    %   bounds = problem.getBounds();


    properties
        name;           % 问题名称
        description;    % 问题描述
        problemType;    % 问题类型 ('single-objective' 或 'multi-objective')
        evaluator;      % 评估器对象 (Evaluator的子类)
    end

    properties (Access = private)
        variableSet;    % VariableSet对象
        objectives;     % Objective对象的cell array
        constraints;    % Constraint对象的cell array
    end

    methods
        function obj = OptimizationProblem(name, description)
            % OptimizationProblem 构造函数
            %
            % 输入:
            %   name - 问题名称
            %   description - (可选) 问题描述
            %
            % 示例:
            %   problem = OptimizationProblem('DistillationOptimization');
            %   problem = OptimizationProblem('MyProblem', '示例优化问题');

            if nargin < 1
                obj.name = 'UnnamedProblem';
            else
                obj.name = name;
            end

            if nargin < 2
                obj.description = '';
            else
                obj.description = description;
            end

            obj.variableSet = VariableSet();
            obj.objectives = {};
            obj.constraints = {};
            obj.problemType = 'single-objective';
            obj.evaluator = [];
        end

        function addVariable(obj, variable)
            % addVariable 添加变量到问题
            %
            % 输入:
            %   variable - Variable对象
            %
            % 示例:
            %   problem.addVariable(Variable('x1', 'continuous', [0, 10]));

            obj.variableSet.addVariable(variable);
        end

        function addObjective(obj, objective)
            % addObjective 添加目标函数到问题
            %
            % 输入:
            %   objective - Objective对象
            %
            % 示例:
            %   problem.addObjective(Objective('cost', 'minimize'));

            if ~isa(objective, 'Objective')
                error('OptimizationProblem:InvalidInput', '输入必须是Objective对象');
            end

            obj.objectives{end+1} = objective;

            % 更新问题类型
            if length(obj.objectives) > 1
                obj.problemType = 'multi-objective';
            else
                obj.problemType = 'single-objective';
            end
        end

        function addConstraint(obj, constraint)
            % addConstraint 添加约束条件到问题
            %
            % 输入:
            %   constraint - Constraint对象
            %
            % 示例:
            %   problem.addConstraint(Constraint.createLessEqual('c1', 0));

            if ~isa(constraint, 'Constraint')
                error('OptimizationProblem:InvalidInput', '输入必须是Constraint对象');
            end

            obj.constraints{end+1} = constraint;
        end

        function setEvaluator(obj, evaluator)
            % setEvaluator 设置问题评估器
            %
            % 输入:
            %   evaluator - Evaluator对象或其子类
            %
            % 示例:
            %   problem.setEvaluator(MATLABFunctionEvaluator(@(x) sum(x.^2)));

            obj.evaluator = evaluator;
        end

        function result = evaluate(obj, x)
            % evaluate 评估给定解
            %
            % 输入:
            %   x - 解向量
            %
            % 输出:
            %   result - 评估结果结构体，包含objectives和constraints
            %
            % 示例:
            %   result = problem.evaluate([1, 2, 3]);

            if isempty(obj.evaluator)
                error('OptimizationProblem:NoEvaluator', '未设置评估器');
            end

            result = obj.evaluator.evaluate(x);
        end

        function n = getNumberOfVariables(obj)
            % getNumberOfVariables 获取变量数量
            %
            % 输出:
            %   n - 变量数量
            %
            % 示例:
            %   nVars = problem.getNumberOfVariables();

            n = obj.variableSet.size();
        end

        function n = getNumberOfObjectives(obj)
            % getNumberOfObjectives 获取目标函数数量
            %
            % 输出:
            %   n - 目标函数数量
            %
            % 示例:
            %   nObjs = problem.getNumberOfObjectives();

            n = length(obj.objectives);
        end

        function n = getNumberOfConstraints(obj)
            % getNumberOfConstraints 获取约束条件数量
            %
            % 输出:
            %   n - 约束条件数量
            %
            % 示例:
            %   nCons = problem.getNumberOfConstraints();

            n = length(obj.constraints);
        end

        function varSet = getVariableSet(obj)
            % getVariableSet 获取变量集合
            %
            % 输出:
            %   varSet - VariableSet对象
            %
            % 示例:
            %   varSet = problem.getVariableSet();

            varSet = obj.variableSet;
        end

        function objective = getObjective(obj, index)
            % getObjective 获取指定索引的目标函数
            %
            % 输入:
            %   index - 目标函数索引 (1-based)
            %
            % 输出:
            %   objective - Objective对象
            %
            % 示例:
            %   obj = problem.getObjective(1);

            if index < 1 || index > length(obj.objectives)
                error('OptimizationProblem:IndexOutOfRange', ...
                      '目标索引 %d 超出范围 [1, %d]', index, length(obj.objectives));
            end

            objective = obj.objectives{index};
        end

        function constraint = getConstraint(obj, index)
            % getConstraint 获取指定索引的约束条件
            %
            % 输入:
            %   index - 约束索引 (1-based)
            %
            % 输出:
            %   constraint - Constraint对象
            %
            % 示例:
            %   con = problem.getConstraint(1);

            if index < 1 || index > length(obj.constraints)
                error('OptimizationProblem:IndexOutOfRange', ...
                      '约束索引 %d 超出范围 [1, %d]', index, length(obj.constraints));
            end

            constraint = obj.constraints{index};
        end

        function bounds = getBounds(obj)
            % getBounds 获取变量边界矩阵
            %
            % 输出:
            %   bounds - [n×2] 矩阵，每行为 [lower, upper]
            %
            % 示例:
            %   bounds = problem.getBounds();
            %   lb = bounds(:, 1);
            %   ub = bounds(:, 2);

            bounds = obj.variableSet.getBounds();
        end

        function indices = getIntegerIndices(obj)
            % getIntegerIndices 获取整数变量的索引
            %
            % 输出:
            %   indices - 整数变量索引向量
            %
            % 示例:
            %   intIdx = problem.getIntegerIndices();

            indices = obj.variableSet.getIntegerIndices();
        end

        function tf = isSingleObjective(obj)
            % isSingleObjective 判断是否为单目标问题
            %
            % 输出:
            %   tf - 布尔值
            %
            % 示例:
            %   if problem.isSingleObjective()

            tf = strcmp(obj.problemType, 'single-objective');
        end

        function tf = isMultiObjective(obj)
            % isMultiObjective 判断是否为多目标问题
            %
            % 输出:
            %   tf - 布尔值
            %
            % 示例:
            %   if problem.isMultiObjective()

            tf = strcmp(obj.problemType, 'multi-objective');
        end

        function loadFromConfig(obj, config)
            % loadFromConfig 从Config对象加载问题定义
            %
            % 输入:
            %   config - Config对象或配置结构体
            %
            % 示例:
            %   config = Config('config.json');
            %   problem.loadFromConfig(config);

            % 获取配置数据
            if isa(config, 'Config')
                configData = config.toStruct();
            elseif isstruct(config)
                configData = config;
            else
                error('OptimizationProblem:InvalidInput', ...
                      '输入必须是Config对象或结构体');
            end

            % 检查是否有problem字段
            if ~isfield(configData, 'problem')
                error('OptimizationProblem:MissingField', '配置中缺少problem字段');
            end

            problemConfig = configData.problem;

            % 加载基本信息
            if isfield(problemConfig, 'name')
                obj.name = problemConfig.name;
            end

            if isfield(problemConfig, 'description')
                obj.description = problemConfig.description;
            end

            if isfield(problemConfig, 'type')
                obj.problemType = problemConfig.type;
            end

            % 加载变量
            if isfield(problemConfig, 'variables')
                obj.loadVariablesFromConfig(problemConfig.variables);
            end

            % 加载目标函数
            if isfield(problemConfig, 'objectives')
                obj.loadObjectivesFromConfig(problemConfig.objectives);
            end

            % 加载约束条件
            if isfield(problemConfig, 'constraints')
                obj.loadConstraintsFromConfig(problemConfig.constraints);
            end
        end

        function s = toStruct(obj)
            % toStruct 将问题转换为结构体
            %
            % 输出:
            %   s - 包含问题信息的结构体
            %
            % 示例:
            %   structData = problem.toStruct();

            s = struct();
            s.name = obj.name;
            s.description = obj.description;
            s.problemType = obj.problemType;
            s.hasEvaluator = ~isempty(obj.evaluator);

            % 变量
            s.variableSet = obj.variableSet.toStruct();

            % 目标函数
            s.objectives = cell(1, length(obj.objectives));
            for i = 1:length(obj.objectives)
                s.objectives{i} = obj.objectives{i}.toStruct();
            end

            % 约束条件
            s.constraints = cell(1, length(obj.constraints));
            for i = 1:length(obj.constraints)
                s.constraints{i} = obj.constraints{i}.toStruct();
            end
        end

        function display(obj)
            % display 显示问题信息
            %
            % 示例:
            %   problem.display();

            fprintf('========================================\n');
            fprintf('Optimization Problem: %s\n', obj.name);
            if ~isempty(obj.description)
                fprintf('Description: %s\n', obj.description);
            end
            fprintf('Type: %s\n', obj.problemType);
            fprintf('========================================\n\n');

            % 变量信息
            fprintf('Variables (%d):\n', obj.getNumberOfVariables());
            obj.variableSet.display();
            fprintf('\n');

            % 目标函数信息
            fprintf('Objectives (%d):\n', obj.getNumberOfObjectives());
            for i = 1:length(obj.objectives)
                fprintf('  [%d] %s\n', i, obj.objectives{i}.toString());
            end
            fprintf('\n');

            % 约束条件信息
            fprintf('Constraints (%d):\n', obj.getNumberOfConstraints());
            if isempty(obj.constraints)
                fprintf('  None\n');
            else
                for i = 1:length(obj.constraints)
                    fprintf('  [%d] %s\n', i, obj.constraints{i}.toString());
                end
            end
            fprintf('========================================\n');
        end

        function clear(obj)
            % clear 清空问题定义
            %
            % 示例:
            %   problem.clear();

            obj.variableSet.clear();
            obj.objectives = {};
            obj.constraints = {};
            obj.problemType = 'single-objective';
        end
    end

    methods (Access = private)
        function loadVariablesFromConfig(obj, variablesConfig)
            % loadVariablesFromConfig 从配置加载变量
            %
            % 输入:
            %   variablesConfig - 变量配置数组

            for i = 1:length(variablesConfig)
                varConfig = variablesConfig(i);

                % 确定边界或值集合
                if strcmp(varConfig.type, 'continuous') || strcmp(varConfig.type, 'integer')
                    bounds = [varConfig.lowerBound, varConfig.upperBound];
                elseif strcmp(varConfig.type, 'discrete')
                    bounds = varConfig.values;
                elseif strcmp(varConfig.type, 'categorical')
                    bounds = varConfig.values;
                else
                    error('OptimizationProblem:InvalidVariableType', ...
                          '未知的变量类型: %s', varConfig.type);
                end

                % 创建变量
                if isfield(varConfig, 'description')
                    var = Variable(varConfig.name, varConfig.type, bounds, ...
                                  'Description', varConfig.description);
                else
                    var = Variable(varConfig.name, varConfig.type, bounds);
                end

                obj.addVariable(var);
            end
        end

        function loadObjectivesFromConfig(obj, objectivesConfig)
            % loadObjectivesFromConfig 从配置加载目标函数
            %
            % 输入:
            %   objectivesConfig - 目标函数配置数组

            for i = 1:length(objectivesConfig)
                objConfig = objectivesConfig(i);

                % 构建参数
                args = {};
                if isfield(objConfig, 'description')
                    args = [args, {'Description', objConfig.description}];
                end
                if isfield(objConfig, 'weight')
                    args = [args, {'Weight', objConfig.weight}];
                end

                % 创建目标函数
                objective = Objective(objConfig.name, objConfig.type, args{:});
                obj.addObjective(objective);
            end
        end

        function loadConstraintsFromConfig(obj, constraintsConfig)
            % loadConstraintsFromConfig 从配置加载约束条件
            %
            % 输入:
            %   constraintsConfig - 约束条件配置数组

            for i = 1:length(constraintsConfig)
                conConfig = constraintsConfig(i);

                % 构建参数
                args = {};

                if strcmp(conConfig.type, 'equality')
                    if isfield(conConfig, 'target')
                        args = [args, {'Target', conConfig.target}];
                    end
                    if isfield(conConfig, 'tolerance')
                        args = [args, {'Tolerance', conConfig.tolerance}];
                    end
                else % inequality
                    if isfield(conConfig, 'lowerBound')
                        args = [args, {'LowerBound', conConfig.lowerBound}];
                    end
                    if isfield(conConfig, 'upperBound')
                        args = [args, {'UpperBound', conConfig.upperBound}];
                    end
                end

                if isfield(conConfig, 'description')
                    args = [args, {'Description', conConfig.description}];
                end

                % 创建约束
                constraint = Constraint(conConfig.name, conConfig.type, args{:});
                obj.addConstraint(constraint);
            end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            % fromStruct 从结构体创建OptimizationProblem对象
            %
            % 输入:
            %   s - 结构体（通常来自toStruct()）
            %
            % 输出:
            %   obj - OptimizationProblem对象
            %
            % 示例:
            %   problem = OptimizationProblem.fromStruct(structData);

            if isfield(s, 'description')
                obj = OptimizationProblem(s.name, s.description);
            else
                obj = OptimizationProblem(s.name);
            end

            if isfield(s, 'problemType')
                obj.problemType = s.problemType;
            end

            % 加载变量集合
            if isfield(s, 'variableSet')
                obj.variableSet = VariableSet.fromStruct(s.variableSet);
            end

            % 加载目标函数
            if isfield(s, 'objectives')
                for i = 1:length(s.objectives)
                    objective = Objective.fromStruct(s.objectives{i});
                    obj.addObjective(objective);
                end
            end

            % 加载约束条件
            if isfield(s, 'constraints')
                for i = 1:length(s.constraints)
                    constraint = Constraint.fromStruct(s.constraints{i});
                    obj.addConstraint(constraint);
                end
            end
        end

        function obj = fromConfig(config)
            % fromConfig 从Config对象创建OptimizationProblem
            %
            % 输入:
            %   config - Config对象或配置文件路径
            %
            % 输出:
            %   obj - OptimizationProblem对象
            %
            % 示例:
            %   problem = OptimizationProblem.fromConfig('config.json');
            %   problem = OptimizationProblem.fromConfig(configObj);

            if ischar(config)
                config = Config(config);
            end

            obj = OptimizationProblem('Problem');
            obj.loadFromConfig(config);
        end
    end
end
