classdef BaseSensitivityAnalyzer < ISensitivityAnalyzer
    % BaseSensitivityAnalyzer - 基础灵敏度分析器实现
    %
    % 描述:
    %   提供灵敏度分析的基础实现
    %   支持顺序和并行仿真、缓存机制、进度显示等功能
    %
    % 使用示例:
    %   context = SensitivityContext(problem);
    %   analyzer = BaseSensitivityAnalyzer(context);
    %   results = analyzer.analyzeAll();
    %   analyzer.report();
    %
    % 作者: MAPO Framework
    % 日期: 2024

    properties (Access = protected)
        context              % SensitivityContext对象
        convergenceEvaluator % 收敛性评估器
        enableParallel       % 是否启用并行
        enableCache          % 是否启用缓存
        dataCache           % 缓存对象（containers.Map）
        progressDisplay      % 进度显示选项
        parallelConfig       % 并行配置对象 (ParallelConfig)
    end

    methods
        function obj = BaseSensitivityAnalyzer(context, varargin)
            % 构造函数
            %
            % 输入:
            %   context - SensitivityContext对象
            %   可选参数（名称-值对）:
            %     'EnableParallel' - 是否启用并行计算 (默认false)
            %     'EnableCache' - 是否启用缓存 (默认true)
            %     'ProgressDisplay' - 进度显示选项 (默认true)
            %     'ParallelConfig' - 并行配置对象 (可选)
            %     'NumWorkers' - Worker数量 (可选，仅当EnableParallel为true时有效)

            % 解析输入参数
            p = inputParser;
            addRequired(p, 'context', @(x) isa(x, 'SensitivityContext'));
            addParameter(p, 'EnableParallel', false, @islogical);
            addParameter(p, 'EnableCache', true, @islogical);
            addParameter(p, 'ProgressDisplay', true, @islogical);
            addParameter(p, 'ParallelConfig', [], @(x) isempty(x) || isa(x, 'ParallelConfig'));
            addParameter(p, 'NumWorkers', 0, @isnumeric);
            parse(p, context, varargin{:});

            obj.context = p.Results.context;
            obj.enableParallel = p.Results.EnableParallel;
            obj.enableCache = p.Results.EnableCache;
            obj.progressDisplay = p.Results.ProgressDisplay;

            % 初始化并行配置
            if ~isempty(p.Results.ParallelConfig)
                obj.parallelConfig = p.Results.ParallelConfig;
            elseif obj.enableParallel
                obj.parallelConfig = ParallelConfig(...
                    'EnableParallel', true, ...
                    'NumWorkers', p.Results.NumWorkers, ...
                    'Verbose', obj.progressDisplay);
            else
                obj.parallelConfig = [];
            end

            % 初始化缓存
            if obj.enableCache
                obj.dataCache = containers.Map();
            end

            % 默认使用简单的收敛性评估
            obj.convergenceEvaluator = [];

            % 显示并行信息
            if obj.enableParallel && obj.progressDisplay
                fprintf('灵敏度分析: 并行计算已启用\n');
            end
        end

        function result = analyzeVariable(obj, variableName)
            % 分析单个变量
            %
            % 输入:
            %   variableName - 变量名称
            %
            % 输出:
            %   result - SensitivityResult对象

            if obj.progressDisplay
                fprintf('\n分析变量: %s\n', variableName);
                fprintf('----------------------------------------\n');
            end

            % 检查缓存
            if obj.enableCache && obj.dataCache.isKey(variableName)
                if obj.progressDisplay
                    fprintf('从缓存读取结果...\n');
                end
                result = obj.dataCache(variableName);
                return;
            end

            % 获取变量信息
            variable = obj.getVariable(variableName);
            if isempty(variable)
                error('BaseSensitivityAnalyzer:InvalidVariable', ...
                    '变量 %s 不存在', variableName);
            end

            % 生成测试点
            testValues = obj.generateTestPoints(variable);

            % 获取基准值
            baseline = obj.context.getBaseline();

            % 执行仿真
            if obj.enableParallel
                [convergency, outputs] = obj.parallelSimulation(...
                    variableName, testValues, baseline);
            else
                [convergency, outputs] = obj.sequentialSimulation(...
                    variableName, testValues, baseline);
            end

            % 创建结果对象
            result = SensitivityResult();
            result.variableName = variableName;
            result.variableDisplayName = variable.name;
            result.variableUnit = variable.unit;
            result.testValues = testValues;
            result.convergency = convergency;
            result.outputs = outputs;
            result.calculateMetrics();

            % 存储结果
            obj.context.addResult(variableName, result);
            if obj.enableCache
                obj.dataCache(variableName) = result;
            end

            if obj.progressDisplay
                fprintf('分析完成: 收敛率 %.2f%%\n', result.convergenceRate * 100);
                if ~isempty(result.feasibleRange)
                    fprintf('可行域: [%.4f, %.4f]\n', ...
                        result.feasibleRange(1), result.feasibleRange(2));
                end
            end
        end

        function results = analyzeAll(obj)
            % 分析所有变量
            %
            % 输出:
            %   results - SensitivityResult对象的cell数组

            variables = obj.context.problem.variables;
            numVariables = length(variables);

            if obj.progressDisplay
                fprintf('\n========================================\n');
                fprintf('开始灵敏度分析\n');
                fprintf('总变量数: %d\n', numVariables);
                fprintf('========================================\n');
            end

            results = cell(numVariables, 1);

            for i = 1:numVariables
                variableName = variables(i).name;

                if obj.progressDisplay
                    fprintf('\n进度: %d/%d\n', i, numVariables);
                end

                try
                    results{i} = obj.analyzeVariable(variableName);
                catch ME
                    warning('BaseSensitivityAnalyzer:AnalysisFailed', ...
                        '变量 %s 分析失败: %s', variableName, ME.message);
                    results{i} = [];
                end
            end

            if obj.progressDisplay
                fprintf('\n========================================\n');
                fprintf('分析完成\n');
                fprintf('========================================\n');
            end
        end

        function ranges = getFeasibleRanges(obj, convergenceThreshold)
            % 获取所有变量的可行域
            %
            % 输入:
            %   convergenceThreshold - 收敛率阈值，默认0.7
            %
            % 输出:
            %   ranges - containers.Map对象

            if nargin < 2
                convergenceThreshold = 0.7;
            end

            ranges = containers.Map();
            variables = obj.context.problem.variables;

            for i = 1:length(variables)
                varName = variables(i).name;
                result = obj.context.getResult(varName);

                if ~isempty(result)
                    [minVal, maxVal] = result.getFeasibleRange(convergenceThreshold);
                    if ~isempty(minVal) && ~isempty(maxVal)
                        ranges(varName) = [minVal, maxVal];
                    end
                end
            end
        end

        function report(obj, reporter)
            % 生成报告
            %
            % 输入:
            %   reporter - IReporter对象（可选）

            if nargin < 2
                % 使用默认的控制台报告器
                obj.generateConsoleReport();
            else
                reporter.generate(obj.context);
            end
        end
    end

    methods (Access = protected)
        function variable = getVariable(obj, variableName)
            % 获取变量对象
            variables = obj.context.problem.variables;
            variable = [];

            for i = 1:length(variables)
                if strcmp(variables(i).name, variableName)
                    variable = variables(i);
                    break;
                end
            end
        end

        function testValues = generateTestPoints(obj, variable)
            % 生成测试点
            %
            % 输入:
            %   variable - 变量对象
            %
            % 输出:
            %   testValues - 测试值数组

            % 默认策略：线性扩展30%
            expansionFactor = 1.3;
            numPoints = 21;

            range = variable.upperBound - variable.lowerBound;
            center = (variable.upperBound + variable.lowerBound) / 2;
            expansion = range * (expansionFactor - 1) / 2;

            minVal = max(0, variable.lowerBound - expansion);  % 确保非负
            maxVal = variable.upperBound + expansion;

            testValues = linspace(minVal, maxVal, numPoints);
        end

        function [convergency, outputs] = sequentialSimulation(...
                obj, variableName, testValues, baseline)
            % 顺序执行仿真
            %
            % 输入:
            %   variableName - 变量名称
            %   testValues - 测试值数组
            %   baseline - 基准值Map
            %
            % 输出:
            %   convergency - 收敛性数组
            %   outputs - 输出矩阵

            n = length(testValues);
            convergency = false(n, 1);
            outputs = [];

            problem = obj.context.problem;
            evaluator = problem.evaluator;

            % 构建基准变量向量
            variables = problem.variables;
            baselineVector = zeros(length(variables), 1);
            varIndex = 0;

            for i = 1:length(variables)
                if strcmp(variables(i).name, variableName)
                    varIndex = i;
                end
                if baseline.isKey(variables(i).name)
                    baselineVector(i) = baseline(variables(i).name);
                else
                    baselineVector(i) = (variables(i).lowerBound + variables(i).upperBound) / 2;
                end
            end

            % 初始化输出矩阵
            firstRun = true;
            numOutputs = 0;

            for i = 1:n
                % 构建变量向量
                x = baselineVector;
                x(varIndex) = testValues(i);

                % 执行评估
                try
                    result = evaluator.evaluate(x);

                    % 检查收敛性（简单判断：如果有结果就认为收敛）
                    if ~isempty(result) && isfield(result, 'objectives')
                        convergency(i) = true;

                        % 提取输出
                        if firstRun
                            numOutputs = length(result.objectives);
                            outputs = NaN(n, numOutputs);
                            firstRun = false;
                        end
                        outputs(i, :) = result.objectives;
                    else
                        convergency(i) = false;
                        if ~firstRun
                            outputs(i, :) = NaN;
                        end
                    end
                catch ME
                    convergency(i) = false;
                    if ~firstRun
                        outputs(i, :) = NaN;
                    end
                end

                % 进度显示
                if obj.progressDisplay && mod(i, 5) == 0
                    fprintf('  测试进度: %d/%d (%.1f%%)\n', i, n, i/n*100);
                end
            end

            % 如果没有任何成功的运行，创建空输出矩阵
            if firstRun
                outputs = NaN(n, 2);  % 默认假设2个输出
            end
        end

        function [convergency, outputs] = parallelSimulation(...
                obj, variableName, testValues, baseline)
            % 并行执行仿真
            %
            % 输入:
            %   variableName - 变量名称
            %   testValues - 测试值数组
            %   baseline - 基准值Map
            %
            % 输出:
            %   convergency - 收敛性数组
            %   outputs - 输出矩阵
            %
            % 说明:
            %   使用parfor并行评估多个测试点
            %   自动检测评估器类型并选择合适的并行策略

            n = length(testValues);
            convergency = false(n, 1);
            outputs = [];

            problem = obj.context.problem;
            evaluator = problem.evaluator;

            % 检测评估器类型
            evaluatorClass = class(evaluator);
            isAspenEvaluator = contains(evaluatorClass, 'Aspen', 'IgnoreCase', true);

            % 如果是Aspen评估器，警告并回退到顺序执行
            if isAspenEvaluator
                if obj.progressDisplay
                    fprintf('  注意: Aspen评估器检测到，使用顺序执行\n');
                end
                [convergency, outputs] = obj.sequentialSimulation(...
                    variableName, testValues, baseline);
                return;
            end

            % 构建基准变量向量
            variables = problem.variables;
            baselineVector = zeros(length(variables), 1);
            varIndex = 0;

            for i = 1:length(variables)
                if strcmp(variables(i).name, variableName)
                    varIndex = i;
                end
                if baseline.isKey(variables(i).name)
                    baselineVector(i) = baseline(variables(i).name);
                else
                    baselineVector(i) = (variables(i).lowerBound + variables(i).upperBound) / 2;
                end
            end

            % 获取或创建并行池
            if ~isempty(obj.parallelConfig)
                pool = obj.parallelConfig.getOrCreatePool();
            else
                pool = gcp('nocreate');
                if isempty(pool)
                    try
                        pool = parpool('local');
                    catch
                        pool = [];
                    end
                end
            end

            if isempty(pool)
                % 回退到顺序执行
                if obj.progressDisplay
                    fprintf('  无法创建并行池，回退到顺序执行\n');
                end
                [convergency, outputs] = obj.sequentialSimulation(...
                    variableName, testValues, baseline);
                return;
            end

            % 准备并行评估的数据
            % 由于parfor的限制，需要预先分配数据
            varsToEval = zeros(n, length(baselineVector));
            for i = 1:n
                varsToEval(i, :) = baselineVector;
                varsToEval(i, varIndex) = testValues(i);
            end

            % 并行评估
            evalResults = cell(n, 1);
            evalConvergency = false(n, 1);

            if obj.progressDisplay
                fprintf('  并行评估 %d 个测试点 (%d workers)...\n', n, pool.NumWorkers);
            end

            try
                parfor i = 1:n
                    try
                        x = varsToEval(i, :);
                        result = evaluator.evaluate(x);

                        % 检查收敛性
                        if ~isempty(result) && isfield(result, 'objectives')
                            evalConvergency(i) = true;
                            evalResults{i} = result;
                        else
                            evalConvergency(i) = false;
                            evalResults{i} = [];
                        end
                    catch
                        evalConvergency(i) = false;
                        evalResults{i} = [];
                    end
                end
            catch ME
                warning('BaseSensitivityAnalyzer:ParforFailed', ...
                    '并行执行失败: %s\n回退到顺序执行', ME.message);
                [convergency, outputs] = obj.sequentialSimulation(...
                    variableName, testValues, baseline);
                return;
            end

            % 处理结果
            convergency = evalConvergency;

            % 初始化输出矩阵
            firstValidIdx = find(convergency, 1);
            if ~isempty(firstValidIdx) && ~isempty(evalResults{firstValidIdx})
                numOutputs = length(evalResults{firstValidIdx}.objectives);
                outputs = NaN(n, numOutputs);

                for i = 1:n
                    if convergency(i) && ~isempty(evalResults{i})
                        outputs(i, :) = evalResults{i}.objectives;
                    end
                end
            else
                outputs = NaN(n, 2);  % 默认假设2个输出
            end

            if obj.progressDisplay
                convRate = sum(convergency) / n * 100;
                fprintf('  并行评估完成: 收敛率 %.1f%%\n', convRate);
            end
        end

        function generateConsoleReport(obj)
            % 生成控制台报告

            fprintf('\n========================================\n');
            fprintf('灵敏度分析报告\n');
            fprintf('========================================\n\n');

            summary = obj.context.getSummary();

            fprintf('问题名称: %s\n', summary.problemName);
            fprintf('分析时间: %s\n', char(summary.createdAt));
            fprintf('总变量数: %d\n', summary.totalVariables);
            fprintf('已完成: %d\n', summary.completedAnalyses);
            fprintf('待完成: %d\n\n', summary.pendingAnalyses);

            % 显示每个变量的结果
            variables = obj.context.problem.variables;
            fprintf('%-20s | %-20s | %-12s | %-20s\n', ...
                '变量', '测试范围', '收敛率', '可行域');
            fprintf('%s\n', repmat('-', 1, 80));

            for i = 1:length(variables)
                varName = variables(i).name;
                result = obj.context.getResult(varName);

                if ~isempty(result)
                    testRange = sprintf('[%.2f, %.2f]', ...
                        min(result.testValues), max(result.testValues));
                    convRate = sprintf('%.1f%%', result.convergenceRate * 100);

                    if ~isempty(result.feasibleRange)
                        feasRange = sprintf('[%.2f, %.2f]', ...
                            result.feasibleRange(1), result.feasibleRange(2));
                    else
                        feasRange = 'N/A';
                    end

                    fprintf('%-20s | %-20s | %-12s | %-20s\n', ...
                        varName, testRange, convRate, feasRange);
                else
                    fprintf('%-20s | %-20s | %-12s | %-20s\n', ...
                        varName, 'N/A', 'N/A', 'N/A');
                end
            end

            fprintf('\n');
        end
    end
end