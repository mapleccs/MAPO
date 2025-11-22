classdef SensitivityContext < handle
    % SensitivityContext - 灵敏度分析上下文
    %
    % 描述:
    %   存储灵敏度分析的配置和结果
    %   自动从OptimizationProblem提取信息，实现与多目标优化的连贯性
    %
    % 使用示例:
    %   problem = OptimizationProblem(...);
    %   context = SensitivityContext(problem);
    %   context.setBaseline('VAR1', 5.0);
    %   context.setVariationStrategy('VAR1', LinearVariationStrategy());
    %
    % 作者: MAPO Framework
    % 日期: 2024

    properties (SetAccess = private)
        problem                 % OptimizationProblem引用
        variationStrategies     % 变量变化策略映射 (containers.Map)
        baselineValues          % 基准值映射 (containers.Map)
        analysisResults         % 分析结果存储 (containers.Map)
        metadata               % 元数据结构体
    end

    methods
        function obj = SensitivityContext(problem)
            % 构造函数 - 从OptimizationProblem初始化
            %
            % 输入:
            %   problem - OptimizationProblem对象

            if nargin < 1 || isempty(problem)
                error('SensitivityContext:InvalidInput', ...
                    '必须提供OptimizationProblem对象');
            end

            obj.problem = problem;
            obj.variationStrategies = containers.Map();
            obj.baselineValues = containers.Map();
            obj.analysisResults = containers.Map();
            obj.metadata = struct();
            obj.metadata.createdAt = datetime('now');

            obj.initializeFromProblem();
        end

        function initializeFromProblem(obj)
            % 自动从problem提取变量信息并设置默认值

            variables = obj.problem.variables;

            if isempty(variables)
                warning('SensitivityContext:NoVariables', ...
                    'OptimizationProblem中没有定义变量');
                return;
            end

            for i = 1:length(variables)
                var = variables(i);

                % 自动计算基准值（取中点）
                baseline = (var.lowerBound + var.upperBound) / 2;
                obj.baselineValues(var.name) = baseline;

                % 自动选择变化策略
                if var.upperBound / var.lowerBound > 100
                    % 范围跨度大，使用对数策略
                    % 暂时先用线性策略，后续可扩展
                    strategy = 'Linear';
                else
                    % 范围适中，使用线性策略
                    strategy = 'Linear';
                end
                obj.variationStrategies(var.name) = strategy;

                % 记录元数据
                obj.metadata.(var.name) = struct(...
                    'originalRange', [var.lowerBound, var.upperBound], ...
                    'unit', var.unit, ...
                    'type', var.type, ...
                    'baseline', baseline, ...
                    'strategy', strategy);
            end
        end

        function setVariationStrategy(obj, variableName, strategy)
            % 设置特定变量的变化策略
            %
            % 输入:
            %   variableName - 变量名称
            %   strategy - 策略对象或策略名称字符串

            if ~obj.baselineValues.isKey(variableName)
                error('SensitivityContext:InvalidVariable', ...
                    '变量 %s 不存在', variableName);
            end

            obj.variationStrategies(variableName) = strategy;

            if isfield(obj.metadata, variableName)
                obj.metadata.(variableName).strategy = class(strategy);
            end
        end

        function setBaseline(obj, variableName, value)
            % 设置特定变量的基准值
            %
            % 输入:
            %   variableName - 变量名称
            %   value - 基准值

            if ~obj.baselineValues.isKey(variableName)
                warning('SensitivityContext:NewVariable', ...
                    '变量 %s 不存在，将创建新变量', variableName);
            end

            obj.baselineValues(variableName) = value;

            if isfield(obj.metadata, variableName)
                obj.metadata.(variableName).baseline = value;
            end
        end

        function addResult(obj, variableName, result)
            % 存储分析结果
            %
            % 输入:
            %   variableName - 变量名称
            %   result - SensitivityResult对象

            obj.analysisResults(variableName) = result;
            obj.metadata.(variableName).analysisCompleted = datetime('now');
        end

        function result = getResult(obj, variableName)
            % 获取分析结果
            %
            % 输入:
            %   variableName - 变量名称
            %
            % 输出:
            %   result - SensitivityResult对象，若不存在返回空

            if obj.analysisResults.isKey(variableName)
                result = obj.analysisResults(variableName);
            else
                result = [];
            end
        end

        function baseline = getBaseline(obj, variableName)
            % 获取基准值
            %
            % 输入:
            %   variableName - 变量名称（可选，若不提供则返回所有）
            %
            % 输出:
            %   baseline - 单个基准值或整个基准值Map

            if nargin < 2
                baseline = obj.baselineValues;
            else
                if obj.baselineValues.isKey(variableName)
                    baseline = obj.baselineValues(variableName);
                else
                    baseline = [];
                end
            end
        end

        function strategy = getStrategy(obj, variableName)
            % 获取变化策略
            %
            % 输入:
            %   variableName - 变量名称
            %
            % 输出:
            %   strategy - 策略对象或策略名称

            if obj.variationStrategies.isKey(variableName)
                strategy = obj.variationStrategies(variableName);
            else
                strategy = [];
            end
        end

        function summary = getSummary(obj)
            % 获取分析摘要信息
            %
            % 输出:
            %   summary - 包含分析状态的结构体

            variables = obj.problem.variables;
            numVariables = length(variables);
            numCompleted = obj.analysisResults.Count;

            summary = struct();
            summary.problemName = obj.problem.name;
            summary.totalVariables = numVariables;
            summary.completedAnalyses = numCompleted;
            summary.pendingAnalyses = numVariables - numCompleted;
            summary.createdAt = obj.metadata.createdAt;

            % 添加每个变量的状态
            summary.variableStatus = struct();
            for i = 1:numVariables
                varName = variables(i).name;
                summary.variableStatus.(varName) = struct(...
                    'analyzed', obj.analysisResults.isKey(varName), ...
                    'baseline', obj.baselineValues(varName), ...
                    'strategy', obj.variationStrategies(varName));
            end
        end
    end
end