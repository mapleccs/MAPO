classdef (Abstract) Evaluator < handle
    % Evaluator 评估器抽象基类
    % 定义优化问题的评估接口
    %
    % 功能:
    %   - 定义统一的评估接口
    %   - 管理关联的优化问题
    %   - 输入验证
    %   - 评估次数统计
    %   - 标准化评估结果格式
    %
    % 使用方法:
    %   子类必须实现evaluate(variables)方法
    %
    % 示例:
    %   classdef MyEvaluator < Evaluator
    %       methods
    %           function result = evaluate(obj, variables)
    %               % 实现评估逻辑
    %               result.objectives = [f1, f2];
    %               result.constraints = [g1, g2];
    %               result.success = true;
    %               result.message = '';
    %           end
    %       end
    %   end
    %
    %   evaluator = MyEvaluator();
    %   evaluator.setProblem(problem);
    %   result = evaluator.evaluate([x1, x2, x3]);

    properties (Access = protected)
        problem;            % 关联的OptimizationProblem对象
        evaluationCounter;  % 评估次数计数器
    end

    methods
        function obj = Evaluator()
            % Evaluator 构造函数
            %
            % 示例:
            %   evaluator = MyEvaluator();

            obj.problem = [];
            obj.evaluationCounter = 0;
        end

        function setProblem(obj, problem)
            % setProblem 设置关联的优化问题
            %
            % 输入:
            %   problem - OptimizationProblem对象
            %
            % 示例:
            %   evaluator.setProblem(problem);

            if ~isa(problem, 'OptimizationProblem')
                error('Evaluator:InvalidInput', '输入必须是OptimizationProblem对象');
            end

            obj.problem = problem;
        end

        function problem = getProblem(obj)
            % getProblem 获取关联的优化问题
            %
            % 输出:
            %   problem - OptimizationProblem对象
            %
            % 示例:
            %   problem = evaluator.getProblem();

            problem = obj.problem;
        end

        function valid = validateInput(obj, variables)
            % validateInput 验证输入变量
            %
            % 输入:
            %   variables - 变量值向量 [1×n] 或 [n×1]
            %
            % 输出:
            %   valid - 布尔值，输入是否有效
            %
            % 说明:
            %   验证变量数量和取值范围
            %
            % 示例:
            %   if evaluator.validateInput(variables)

            valid = false;

            if isempty(obj.problem)
                warning('Evaluator:NoProblem', '未设置优化问题');
                return;
            end

            % 检查变量数量
            nVars = obj.problem.getNumberOfVariables();
            if length(variables) ~= nVars
                warning('Evaluator:SizeMismatch', ...
                        '变量数量不匹配: 期望%d，实际%d', nVars, length(variables));
                return;
            end

            % 验证每个变量的取值
            varSet = obj.problem.getVariableSet();
            valid = varSet.validate(variables);

            if ~valid
                warning('Evaluator:InvalidValues', '变量值超出有效范围');
            end
        end

        function n = getNumberOfEvaluations(obj)
            % getNumberOfEvaluations 获取评估次数
            %
            % 输出:
            %   n - 评估次数
            %
            % 示例:
            %   count = evaluator.getNumberOfEvaluations();

            n = obj.evaluationCounter;
        end

        function resetCounter(obj)
            % resetCounter 重置评估计数器
            %
            % 示例:
            %   evaluator.resetCounter();

            obj.evaluationCounter = 0;
        end

        function result = evaluateWithValidation(obj, variables)
            % evaluateWithValidation 带输入验证的评估
            %
            % 输入:
            %   variables - 变量值向量
            %
            % 输出:
            %   result - 评估结果结构体
            %
            % 说明:
            %   自动验证输入，并在验证失败时返回错误结果
            %
            % 示例:
            %   result = evaluator.evaluateWithValidation([x1, x2, x3]);

            % 验证输入
            if ~obj.validateInput(variables)
                result = obj.createErrorResult('输入验证失败');
                return;
            end

            % 执行评估
            result = obj.evaluate(variables);

            % 增加计数器
            obj.evaluationCounter = obj.evaluationCounter + 1;
        end

        function result = evaluateBatch(obj, population)
            % evaluateBatch 批量评估
            %
            % 输入:
            %   population - 变量矩阵 [N×n]，每行是一个解
            %
            % 输出:
            %   result - 结果结构体数组 [N×1]
            %
            % 示例:
            %   results = evaluator.evaluateBatch(population);

            N = size(population, 1);
            result(N) = obj.createEmptyResult();

            for i = 1:N
                result(i) = obj.evaluateWithValidation(population(i, :));
            end
        end
    end

    methods (Abstract)
        % evaluate 评估函数（子类必须实现）
        %
        % 输入:
        %   variables - 变量值向量 [1×n]
        %
        % 输出:
        %   result - 评估结果结构体
        %            result.objectives - 目标函数值向量 [1×m]
        %            result.constraints - 约束函数值向量 [1×k]
        %            result.success - 评估是否成功（布尔值）
        %            result.message - 消息字符串
        %            result.additionalData - (可选) 额外数据
        %
        % 示例实现:
        %   function result = evaluate(obj, variables)
        %       try
        %           % 计算目标函数
        %           f1 = ...;
        %           f2 = ...;
        %
        %           % 计算约束函数
        %           g1 = ...;
        %           g2 = ...;
        %
        %           % 返回结果
        %           result.objectives = [f1, f2];
        %           result.constraints = [g1, g2];
        %           result.success = true;
        %           result.message = '';
        %       catch ME
        %           result = obj.createErrorResult(ME.message);
        %       end
        %   end
        result = evaluate(obj, variables)
    end

    methods (Access = protected)
        function result = createEmptyResult(obj)
            % createEmptyResult 创建空结果结构体
            %
            % 输出:
            %   result - 空结果结构体

            if isempty(obj.problem)
                nObjectives = 0;
                nConstraints = 0;
            else
                nObjectives = obj.problem.getNumberOfObjectives();
                nConstraints = obj.problem.getNumberOfConstraints();
            end

            result = struct();
            result.objectives = zeros(1, nObjectives);
            result.constraints = zeros(1, nConstraints);
            result.success = false;
            result.message = '';
        end

        function result = createErrorResult(obj, message)
            % createErrorResult 创建错误结果
            %
            % 输入:
            %   message - 错误消息
            %
            % 输出:
            %   result - 错误结果结构体

            result = obj.createEmptyResult();
            result.objectives(:) = inf;  % 目标函数设为无穷大
            result.constraints(:) = inf; % 约束违反度设为无穷大
            result.success = false;
            result.message = message;
        end

        function result = createSuccessResult(obj, objectives, constraints, message)
            % createSuccessResult 创建成功结果
            %
            % 输入:
            %   objectives - 目标函数值向量
            %   constraints - 约束函数值向量
            %   message - (可选) 消息
            %
            % 输出:
            %   result - 成功结果结构体

            if nargin < 4
                message = '';
            end

            result = struct();
            result.objectives = objectives;
            result.constraints = constraints;
            result.success = true;
            result.message = message;
        end
    end

    methods (Static)
        function result = combineResults(results)
            % combineResults 合并多个评估结果
            %
            % 输入:
            %   results - 结果结构体数组
            %
            % 输出:
            %   result - 合并后的结果
            %            result.objectives - [N×m] 目标函数矩阵
            %            result.constraints - [N×k] 约束函数矩阵
            %            result.success - [N×1] 成功标志向量
            %
            % 示例:
            %   combined = Evaluator.combineResults(results);

            N = length(results);

            if N == 0
                result = struct('objectives', [], 'constraints', [], 'success', []);
                return;
            end

            nObjectives = length(results(1).objectives);
            nConstraints = length(results(1).constraints);

            result = struct();
            result.objectives = zeros(N, nObjectives);
            result.constraints = zeros(N, nConstraints);
            result.success = false(N, 1);

            for i = 1:N
                result.objectives(i, :) = results(i).objectives;
                result.constraints(i, :) = results(i).constraints;
                result.success(i) = results(i).success;
            end
        end

        function tf = isValidResult(result)
            % isValidResult 检查结果是否有效
            %
            % 输入:
            %   result - 评估结果结构体
            %
            % 输出:
            %   tf - 布尔值

            tf = isstruct(result) && ...
                 isfield(result, 'objectives') && ...
                 isfield(result, 'constraints') && ...
                 isfield(result, 'success') && ...
                 isfield(result, 'message');

            if tf
                tf = tf && isnumeric(result.objectives) && ...
                     isnumeric(result.constraints) && ...
                     islogical(result.success) && ...
                     ischar(result.message);
            end
        end
    end
end
