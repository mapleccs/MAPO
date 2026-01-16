classdef MATLABFunctionEvaluator < Evaluator
    % MATLABFunctionEvaluator 使用MATLAB函数的评估器
    % 直接调用MATLAB函数进行评估
    %
    % 功能:
    %   - 使用函数句柄作为目标函数
    %   - 支持单目标和多目标
    %   - 可选的约束函数
    %
    % 示例:
    %   % 单目标
    %   objFunc = @(x) sum(x.^2);
    %   evaluator = MATLABFunctionEvaluator(objFunc);
    %
    %   % 多目标
    %   objFunc = @(x) [sum(x.^2), sum((x-1).^2)];
    %   evaluator = MATLABFunctionEvaluator(objFunc);
    %
    %   % 带约束
    %   objFunc = @(x) sum(x.^2);
    %   conFunc = @(x) sum(x) - 5;
    %   evaluator = MATLABFunctionEvaluator(objFunc, conFunc);


    properties (Access = private)
        objectiveFunction;   % 目标函数句柄
        constraintFunction;  % 约束函数句柄
    end

    methods
        function obj = MATLABFunctionEvaluator(objFunc, conFunc)
            % MATLABFunctionEvaluator 构造函数
            %
            % 输入:
            %   objFunc - 目标函数句柄 @(x) ...
            %   conFunc - (可选) 约束函数句柄 @(x) ...
            %
            % 示例:
            %   evaluator = MATLABFunctionEvaluator(@(x) sum(x.^2));

            % 调用父类构造函数
            obj@Evaluator();

            if nargin < 1
                error('MATLABFunctionEvaluator:NoFunction', ...
                      '必须提供目标函数');
            end

            if ~isa(objFunc, 'function_handle')
                error('MATLABFunctionEvaluator:InvalidFunction', ...
                      '目标函数必须是函数句柄');
            end

            obj.objectiveFunction = objFunc;

            if nargin >= 2 && ~isempty(conFunc)
                if ~isa(conFunc, 'function_handle')
                    error('MATLABFunctionEvaluator:InvalidFunction', ...
                          '约束函数必须是函数句柄');
                end
                obj.constraintFunction = conFunc;
            else
                obj.constraintFunction = [];
            end
        end

        function result = evaluate(obj, x)
            % evaluate 评估解（实现Evaluator接口）
            %
            % 输入:
            %   x - 决策变量向量
            %
            % 输出:
            %   result - 评估结果结构体
            %
            % 示例:
            %   result = evaluator.evaluate([1, 2, 3]);

            obj.evaluationCounter = obj.evaluationCounter + 1;

            result = struct();
            result.success = true;
            result.message = '';

            try
                % 评估目标函数
                objValues = obj.objectiveFunction(x);

                % 确保是行向量
                if iscolumn(objValues)
                    objValues = objValues';
                end

                result.objectives = objValues;

                % 评估约束（如果有）
                if ~isempty(obj.constraintFunction)
                    conValues = obj.constraintFunction(x);

                    % 确保是行向量
                    if iscolumn(conValues)
                        conValues = conValues';
                    end

                    result.constraints = conValues;
                else
                    result.constraints = [];
                end

            catch ME
                result.success = false;
                result.message = sprintf('评估失败: %s', ME.message);
                result.objectives = [];
                result.constraints = [];
            end
        end
    end
end
