classdef ParallelEvaluationManager < handle
    % ParallelEvaluationManager 并行评估管理器
    % 管理优化算法中的并行评估任务
    %
    % 功能:
    %   - 批量并行评估个体
    %   - 支持多种评估器类型
    %   - 自动负载均衡
    %   - 错误处理和恢复
    %   - 评估结果缓存
    %
    % 设计说明:
    %   由于Aspen Plus COM对象不能跨进程共享，本管理器提供两种模式：
    %   1. MATLAB评估器模式：直接使用parfor并行
    %   2. Aspen评估器模式：使用批处理或单进程顺序执行
    %
    % 示例:
    %   manager = ParallelEvaluationManager(parallelConfig);
    %   results = manager.evaluatePopulation(population, evaluator);
    %
    % 作者: MAPO Framework
    % 日期: 2024

    properties (Access = private)
        parallelConfig      % ParallelConfig对象
        evaluatorType       % 评估器类型 ('matlab', 'aspen', 'python', 'auto')
        enableCache         % 是否启用缓存
        resultCache         % 结果缓存 (containers.Map)
        verbose             % 是否显示详细信息
        totalEvaluations    % 总评估次数统计
        parallelEvaluations % 并行评估次数统计
    end

    methods
        function obj = ParallelEvaluationManager(parallelConfig, varargin)
            % ParallelEvaluationManager 构造函数
            %
            % 输入:
            %   parallelConfig - ParallelConfig对象
            %   可选参数（名称-值对）:
            %     'EvaluatorType' - 评估器类型 (默认'auto')
            %     'EnableCache' - 是否启用缓存 (默认false)
            %     'Verbose' - 是否显示详情 (默认false)

            p = inputParser;
            addRequired(p, 'parallelConfig');
            addParameter(p, 'EvaluatorType', 'auto', @ischar);
            addParameter(p, 'EnableCache', false, @islogical);
            addParameter(p, 'Verbose', false, @islogical);
            parse(p, parallelConfig, varargin{:});

            if isa(parallelConfig, 'ParallelConfig')
                obj.parallelConfig = parallelConfig;
            else
                obj.parallelConfig = ParallelConfig();
            end

            obj.evaluatorType = p.Results.EvaluatorType;
            obj.enableCache = p.Results.EnableCache;
            obj.verbose = p.Results.Verbose;

            if obj.enableCache
                obj.resultCache = containers.Map('KeyType', 'char', 'ValueType', 'any');
            end

            obj.totalEvaluations = 0;
            obj.parallelEvaluations = 0;
        end

        function results = evaluatePopulation(obj, population, evaluator)
            % evaluatePopulation 并行评估种群
            %
            % 输入:
            %   population - Population对象或变量矩阵 [N×nVars]
            %   evaluator - Evaluator对象
            %
            % 输出:
            %   results - 评估结果cell数组

            % 提取变量矩阵
            if isa(population, 'Population')
                individuals = population.getAll();
                N = length(individuals);
                varMatrix = zeros(N, length(individuals(1).getVariables()));
                needsUpdate = false(N, 1);

                for i = 1:N
                    varMatrix(i, :) = individuals(i).getVariables();
                    needsUpdate(i) = ~individuals(i).isEvaluated();
                end
            else
                varMatrix = population;
                N = size(varMatrix, 1);
                needsUpdate = true(N, 1);
            end

            % 检查缓存
            if obj.enableCache
                [varMatrix, needsUpdate, cachedResults] = obj.checkCache(varMatrix, needsUpdate);
            else
                cachedResults = cell(N, 1);
            end

            % 确定评估模式
            evalType = obj.determineEvaluatorType(evaluator);

            % 执行评估
            numToEvaluate = sum(needsUpdate);
            if numToEvaluate == 0
                results = cachedResults;
                return;
            end

            if obj.verbose
                fprintf('[ParallelManager] 评估 %d 个个体 (模式: %s)\n', numToEvaluate, evalType);
            end

            % 根据评估器类型选择并行策略
            if obj.parallelConfig.enableParallel && strcmp(evalType, 'matlab')
                newResults = obj.parallelEvaluate(varMatrix, needsUpdate, evaluator);
                obj.parallelEvaluations = obj.parallelEvaluations + numToEvaluate;
            else
                newResults = obj.sequentialEvaluate(varMatrix, needsUpdate, evaluator);
            end

            obj.totalEvaluations = obj.totalEvaluations + numToEvaluate;

            % 合并结果
            results = obj.mergeResults(cachedResults, newResults, needsUpdate);

            % 更新缓存
            if obj.enableCache
                obj.updateCache(varMatrix, results);
            end

            % 如果输入是Population，更新个体
            if isa(population, 'Population')
                obj.updatePopulation(population, results);
            end
        end

        function results = evaluateIndividuals(obj, individuals, evaluator)
            % evaluateIndividuals 评估Individual数组
            %
            % 输入:
            %   individuals - Individual对象数组
            %   evaluator - Evaluator对象
            %
            % 输出:
            %   results - 评估结果cell数组

            N = length(individuals);
            varMatrix = zeros(N, length(individuals(1).getVariables()));
            needsUpdate = false(N, 1);

            for i = 1:N
                varMatrix(i, :) = individuals(i).getVariables();
                needsUpdate(i) = ~individuals(i).isEvaluated();
            end

            % 执行评估
            results = obj.evaluateVariables(varMatrix, needsUpdate, evaluator);

            % 更新Individual对象
            for i = 1:N
                if needsUpdate(i) && ~isempty(results{i})
                    if isfield(results{i}, 'objectives')
                        individuals(i).setObjectives(results{i}.objectives);
                    end
                    if isfield(results{i}, 'constraints')
                        individuals(i).setConstraints(results{i}.constraints);
                    end
                end
            end
        end

        function results = evaluateVariables(obj, varMatrix, needsUpdate, evaluator)
            % evaluateVariables 评估变量矩阵
            %
            % 输入:
            %   varMatrix - 变量矩阵 [N×nVars]
            %   needsUpdate - 需要评估的标志向量
            %   evaluator - Evaluator对象
            %
            % 输出:
            %   results - 评估结果cell数组

            N = size(varMatrix, 1);

            if nargin < 3 || isempty(needsUpdate)
                needsUpdate = true(N, 1);
            end

            % 确定评估模式
            evalType = obj.determineEvaluatorType(evaluator);

            % 根据评估器类型选择并行策略
            if obj.parallelConfig.enableParallel && strcmp(evalType, 'matlab')
                results = obj.parallelEvaluate(varMatrix, needsUpdate, evaluator);
            else
                results = obj.sequentialEvaluate(varMatrix, needsUpdate, evaluator);
            end
        end

        function stats = getStatistics(obj)
            % getStatistics 获取统计信息
            %
            % 输出:
            %   stats - 统计信息结构体

            stats = struct();
            stats.totalEvaluations = obj.totalEvaluations;
            stats.parallelEvaluations = obj.parallelEvaluations;
            stats.sequentialEvaluations = obj.totalEvaluations - obj.parallelEvaluations;

            if obj.totalEvaluations > 0
                stats.parallelRatio = obj.parallelEvaluations / obj.totalEvaluations;
            else
                stats.parallelRatio = 0;
            end

            if obj.enableCache
                stats.cacheSize = obj.resultCache.Count;
            else
                stats.cacheSize = 0;
            end
        end

        function clearCache(obj)
            % clearCache 清空缓存

            if obj.enableCache
                obj.resultCache = containers.Map('KeyType', 'char', 'ValueType', 'any');
            end
        end

        function resetStatistics(obj)
            % resetStatistics 重置统计信息

            obj.totalEvaluations = 0;
            obj.parallelEvaluations = 0;
        end
    end

    methods (Access = private)
        function evalType = determineEvaluatorType(obj, evaluator)
            % determineEvaluatorType 确定评估器类型
            %
            % 输入:
            %   evaluator - Evaluator对象
            %
            % 输出:
            %   evalType - 'matlab', 'aspen', 或 'python'

            if ~strcmp(obj.evaluatorType, 'auto')
                evalType = obj.evaluatorType;
                return;
            end

            % 自动检测评估器类型
            className = class(evaluator);

            if contains(className, 'Aspen', 'IgnoreCase', true)
                evalType = 'aspen';
            elseif contains(className, 'Python', 'IgnoreCase', true)
                evalType = 'python';
            elseif contains(className, 'MATLAB', 'IgnoreCase', true) || ...
                   contains(className, 'Function', 'IgnoreCase', true)
                evalType = 'matlab';
            else
                % 默认假设为MATLAB类型（可并行）
                evalType = 'matlab';
            end
        end

        function results = parallelEvaluate(obj, varMatrix, needsUpdate, evaluator)
            % parallelEvaluate 并行评估
            %
            % 输入:
            %   varMatrix - 变量矩阵 [N×nVars]
            %   needsUpdate - 需要评估的标志向量
            %   evaluator - Evaluator对象
            %
            % 输出:
            %   results - 评估结果cell数组

            N = size(varMatrix, 1);
            results = cell(N, 1);

            % 获取需要评估的索引
            evalIndices = find(needsUpdate);
            numToEval = length(evalIndices);

            if numToEval == 0
                return;
            end

            % 确保并行池存在
            pool = obj.parallelConfig.getOrCreatePool();

            if isempty(pool)
                % 回退到顺序执行
                if obj.parallelConfig.fallbackToSequential
                    results = obj.sequentialEvaluate(varMatrix, needsUpdate, evaluator);
                    return;
                else
                    error('ParallelEvaluationManager:NoPool', '无法创建并行池');
                end
            end

            % 提取需要评估的变量
            varsToEval = varMatrix(evalIndices, :);

            % 并行评估
            evalResults = cell(numToEval, 1);
            timeout = obj.parallelConfig.timeout;

            try
                parfor i = 1:numToEval
                    try
                        % 每个worker独立调用评估器
                        x = varsToEval(i, :);
                        evalResults{i} = evaluator.evaluate(x);
                    catch ME
                        % 创建错误结果
                        evalResults{i} = struct(...
                            'objectives', inf, ...
                            'constraints', inf, ...
                            'success', false, ...
                            'message', ME.message);
                    end
                end
            catch ME
                warning('ParallelEvaluationManager:ParforFailed', ...
                    '并行执行失败: %s\n回退到顺序执行', ME.message);

                if obj.parallelConfig.fallbackToSequential
                    results = obj.sequentialEvaluate(varMatrix, needsUpdate, evaluator);
                    return;
                else
                    rethrow(ME);
                end
            end

            % 将结果放回正确位置
            for i = 1:numToEval
                results{evalIndices(i)} = evalResults{i};
            end
        end

        function results = sequentialEvaluate(obj, varMatrix, needsUpdate, evaluator)
            % sequentialEvaluate 顺序评估
            %
            % 输入:
            %   varMatrix - 变量矩阵 [N×nVars]
            %   needsUpdate - 需要评估的标志向量
            %   evaluator - Evaluator对象
            %
            % 输出:
            %   results - 评估结果cell数组

            N = size(varMatrix, 1);
            results = cell(N, 1);

            for i = 1:N
                if needsUpdate(i)
                    try
                        results{i} = evaluator.evaluate(varMatrix(i, :));
                    catch ME
                        results{i} = struct(...
                            'objectives', inf, ...
                            'constraints', inf, ...
                            'success', false, ...
                            'message', ME.message);
                    end
                end
            end
        end

        function [varMatrix, needsUpdate, cachedResults] = checkCache(obj, varMatrix, needsUpdate)
            % checkCache 检查缓存中的结果
            %
            % 输入:
            %   varMatrix - 变量矩阵
            %   needsUpdate - 需要评估的标志向量
            %
            % 输出:
            %   varMatrix - 变量矩阵（未修改）
            %   needsUpdate - 更新后的标志向量
            %   cachedResults - 从缓存中获取的结果

            N = size(varMatrix, 1);
            cachedResults = cell(N, 1);

            for i = 1:N
                if needsUpdate(i)
                    key = obj.generateCacheKey(varMatrix(i, :));
                    if obj.resultCache.isKey(key)
                        cachedResults{i} = obj.resultCache(key);
                        needsUpdate(i) = false;
                    end
                end
            end
        end

        function updateCache(obj, varMatrix, results)
            % updateCache 更新缓存
            %
            % 输入:
            %   varMatrix - 变量矩阵
            %   results - 评估结果

            N = size(varMatrix, 1);

            for i = 1:N
                if ~isempty(results{i}) && ...
                   isfield(results{i}, 'success') && results{i}.success
                    key = obj.generateCacheKey(varMatrix(i, :));
                    obj.resultCache(key) = results{i};
                end
            end
        end

        function key = generateCacheKey(~, variables)
            % generateCacheKey 生成缓存键
            %
            % 输入:
            %   variables - 变量向量
            %
            % 输出:
            %   key - 缓存键字符串

            % 使用变量值生成唯一键
            key = sprintf('%.8g_', variables);
            key = key(1:end-1);  % 移除末尾下划线
        end

        function results = mergeResults(~, cachedResults, newResults, needsUpdate)
            % mergeResults 合并缓存结果和新结果
            %
            % 输入:
            %   cachedResults - 缓存的结果
            %   newResults - 新计算的结果
            %   needsUpdate - 评估标志向量
            %
            % 输出:
            %   results - 合并后的结果

            N = length(cachedResults);
            results = cachedResults;

            for i = 1:N
                if needsUpdate(i) && ~isempty(newResults{i})
                    results{i} = newResults{i};
                end
            end
        end

        function updatePopulation(~, population, results)
            % updatePopulation 使用结果更新种群
            %
            % 输入:
            %   population - Population对象
            %   results - 评估结果cell数组

            individuals = population.getAll();

            for i = 1:length(individuals)
                if ~isempty(results{i})
                    if isfield(results{i}, 'objectives')
                        individuals(i).setObjectives(results{i}.objectives);
                    end
                    if isfield(results{i}, 'constraints')
                        individuals(i).setConstraints(results{i}.constraints);
                    end
                end
            end
        end
    end
end
