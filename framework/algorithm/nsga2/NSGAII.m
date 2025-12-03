classdef NSGAII < AlgorithmBase
    % NSGAII 非支配排序遗传算法-II
    % Non-dominated Sorting Genetic Algorithm II
    %
    % 功能:
    %   - NSGA-II多目标优化算法
    %   - 快速非支配排序
    %   - 拥挤距离保持多样性
    %   - SBX交叉和多项式变异
    %   - 精英保留策略
    %
    % 参考文献:
    %   Deb, K., Pratap, A., Agarwal, S., & Meyarivan, T. (2002).
    %   A fast and elitist multiobjective genetic algorithm: NSGA-II.
    %   IEEE transactions on evolutionary computation, 6(2), 182-197.
    %
    % 示例:
    %   % 创建NSGA-II算法
    %   config = struct();
    %   config.populationSize = 100;
    %   config.maxGenerations = 250;
    %   config.crossoverRate = 0.9;
    %   config.mutationRate = 1.0;
    %
    %   nsga2 = NSGAII();
    %   results = nsga2.optimize(problem, config);
    %

    properties (Access = private)
        populationSize;      % 种群大小
        maxGenerations;      % 最大代数
        crossoverRate;       % 交叉概率
        mutationRate;        % 变异概率（归一化到每个变量）
        crossoverDistIndex;  % SBX交叉分布指数
        mutationDistIndex;   % 多项式变异分布指数
        lowerBounds;         % 变量下界
        upperBounds;         % 变量上界
        currentGeneration;   % 当前代数
        allEvaluatedIndividuals;  % 所有评估过的Individual（用于完整历史记录）
        parallelConfig;      % 并行计算配置 (ParallelConfig对象)
        enableParallel;      % 是否启用并行评估
    end

    methods
        function obj = NSGAII()
            % NSGAII 构造函数
            %
            % 示例:
            %   nsga2 = NSGAII();

            % 调用父类构造函数
            obj@AlgorithmBase();

            % 默认参数（NSGA-II论文推荐值）
            obj.populationSize = 100;
            obj.maxGenerations = 250;
            obj.crossoverRate = 0.9;      % 交叉概率
            obj.mutationRate = 1.0;       % 归一化变异率
            obj.crossoverDistIndex = 20;  % SBX分布指数
            obj.mutationDistIndex = 20;   % 多项式变异分布指数
            obj.currentGeneration = 0;
            obj.enableParallel = false;   % 默认不启用并行
            obj.parallelConfig = [];      % 并行配置（延迟初始化）
        end

        function results = optimize(obj, problem, config)
            % optimize 运行NSGA-II优化（实现IOptimizer接口）
            %
            % 输入:
            %   problem - OptimizationProblem对象
            %   config - 配置结构体
            %
            % 输出:
            %   results - 优化结果结构体
            %
            % 示例:
            %   results = nsga2.optimize(problem, config);

            % 初始化
            obj.initialize(problem, config);
            obj.loadConfig(config);
            obj.validateProblem();
            obj.getBounds();

            % 初始化历史记录数组
            obj.allEvaluatedIndividuals = Individual.empty(0, 0);

            % 初始化种群
            obj.initializePopulation();

            % 记录初始种群（所有评估过的解）
            initialInds = obj.population.getAll();
            for i = 1:length(initialInds)
                obj.allEvaluatedIndividuals(end+1) = initialInds(i).clone();
            end

            % 主循环
            obj.logMessage('INFO', '开始NSGA-II进化...');
            while ~obj.shouldStop()
                obj.currentGeneration = obj.currentGeneration + 1;

                % 生成子代
                offspring = obj.generateOffspring();

                % 评估子代（支持并行）
                if obj.enableParallel && ~isempty(obj.parallelConfig)
                    offspring.evaluate(obj.problem.evaluator, obj.parallelConfig);
                else
                    offspring.evaluate(obj.problem.evaluator);
                end
                obj.incrementEvaluationCount(offspring.size());

                % 记录子代（所有评估过的解）
                offspringInds = offspring.getAll();
                for i = 1:length(offspringInds)
                    obj.allEvaluatedIndividuals(end+1) = offspringInds(i).clone();
                end

                % 合并父代和子代
                combinedPop = obj.population.merge(offspring);

                % 快速非支配排序
                combinedPop.fastNonDominatedSort();

                % 计算拥挤距离
                combinedPop.calculateCrowdingDistance();

                % 环境选择：选择最好的N个个体
                obj.population = obj.environmentalSelection(combinedPop);

                % 记录历史
                obj.recordHistory();

                % 日志输出
                if mod(obj.currentGeneration, 10) == 0 || obj.shouldStop()
                    obj.logProgress();
                end

                % 调用迭代回调
                obj.callIterationCallback(obj.currentGeneration, struct());
            end

            % 完成优化
            obj.logMessage('INFO', 'NSGA-II进化完成');
            results = obj.finalizeResults();
        end
    end

    methods (Access = protected)
        function validateProblem(obj)
            % validateProblem 验证问题定义
            %
            % 说明:
            %   检查问题是否满足NSGA-II要求

            % 调用父类验证
            validateProblem@AlgorithmBase(obj);

            % NSGA-II特定验证
            if obj.problem.getNumberOfVariables() == 0
                error('NSGAII:InvalidProblem', '问题必须至少有一个变量');
            end

            if obj.problem.getNumberOfObjectives() == 0
                error('NSGAII:InvalidProblem', '问题必须至少有一个目标');
            end

            % NSGA-II主要用于多目标，但也支持单目标
            if obj.problem.getNumberOfObjectives() == 1
                obj.logMessage('WARNING', 'NSGA-II用于单目标优化，建议使用单目标算法（如GA、PSO）');
            end
        end

        function results = finalizeResults(obj)
            % finalizeResults 完成优化并生成结果（重写父类方法）
            %
            % 输出:
            %   results - 结果结构体
            %
            % 说明:
            %   重写父类方法，添加所有评估过的Individual记录

            % 调用父类方法获取基本结果
            results = finalizeResults@AlgorithmBase(obj);

            % 添加所有评估过的Individual
            results.allEvaluatedIndividuals = obj.allEvaluatedIndividuals;
            results.totalEvaluatedSolutions = length(obj.allEvaluatedIndividuals);

            % 日志输出
            obj.logMessage('INFO', '总评估解数（包括历史）: %d', results.totalEvaluatedSolutions);
        end
    end

    methods (Access = private)
        function loadConfig(obj, config)
            % loadConfig 加载NSGA-II配置参数
            %
            % 输入:
            %   config - 配置结构体

            if isstruct(config)
                if isfield(config, 'populationSize')
                    obj.populationSize = config.populationSize;
                end
                if isfield(config, 'maxGenerations')
                    obj.maxGenerations = config.maxGenerations;
                    obj.maxEvaluations = obj.populationSize * (obj.maxGenerations + 1);
                end
                if isfield(config, 'crossoverRate')
                    obj.crossoverRate = config.crossoverRate;
                end
                if isfield(config, 'mutationRate')
                    obj.mutationRate = config.mutationRate;
                end
                if isfield(config, 'crossoverDistIndex')
                    obj.crossoverDistIndex = config.crossoverDistIndex;
                end
                if isfield(config, 'mutationDistIndex')
                    obj.mutationDistIndex = config.mutationDistIndex;
                end

                % 加载并行配置
                if isfield(config, 'enableParallel')
                    obj.enableParallel = config.enableParallel;
                end
                if isfield(config, 'parallelConfig')
                    obj.parallelConfig = config.parallelConfig;
                elseif obj.enableParallel
                    % 如果启用并行但没有提供配置，创建默认配置
                    obj.parallelConfig = ParallelConfig('EnableParallel', true);
                    if isfield(config, 'numWorkers')
                        obj.parallelConfig.numWorkers = config.numWorkers;
                    end
                end
            end

            % 记录并行配置信息
            if obj.enableParallel
                obj.logMessage('INFO', '并行评估已启用');
                if ~isempty(obj.parallelConfig)
                    nWorkers = obj.parallelConfig.getActiveWorkers();
                    if nWorkers > 1
                        obj.logMessage('INFO', '当前Worker数量: %d', nWorkers);
                    end
                end
            end
        end

        function getBounds(obj)
            % getBounds 获取变量边界
            %
            % 说明:
            %   从问题定义中提取变量边界

            bounds = obj.problem.getBounds();

            % bounds是[n×2]矩阵，第一列是下界，第二列是上界
            obj.lowerBounds = bounds(:, 1)';
            obj.upperBounds = bounds(:, 2)';
        end

        function initializePopulation(obj)
            % initializePopulation 初始化种群
            %
            % 说明:
            %   生成初始种群并评估（支持并行）

            numVars = obj.problem.getNumberOfVariables();

            obj.logMessage('INFO', '初始化种群 (大小: %d, 维度: %d)', ...
                          obj.populationSize, numVars);

            % 创建随机初始种群
            obj.population = Population.random(obj.populationSize, numVars, ...
                                              obj.lowerBounds, obj.upperBounds);

            % 评估初始种群（支持并行）
            if obj.enableParallel && ~isempty(obj.parallelConfig)
                obj.population.evaluate(obj.problem.evaluator, obj.parallelConfig);
            else
                obj.population.evaluate(obj.problem.evaluator);
            end
            obj.incrementEvaluationCount(obj.populationSize);

            % 快速非支配排序
            obj.population.fastNonDominatedSort();

            % 计算拥挤距离
            obj.population.calculateCrowdingDistance();

            obj.logMessage('INFO', '种群初始化完成');
        end

        function offspring = generateOffspring(obj)
            % generateOffspring 生成子代种群
            %
            % 输出:
            %   offspring - 子代种群对象
            %
            % 说明:
            %   通过二元锦标赛选择、交叉和变异生成子代

            numVars = obj.problem.getNumberOfVariables();
            offspring = Population();

            % 获取种群所有个体
            individuals = obj.population.getAll();

            % 生成N个子代
            for i = 1:obj.populationSize
                % 二元锦标赛选择两个父代
                parent1 = GeneticOperators.binaryTournament(individuals);
                parent2 = GeneticOperators.binaryTournament(individuals);

                % 交叉
                if rand() < obj.crossoverRate
                    [child1Vars, child2Vars] = GeneticOperators.sbxCrossover(...
                        parent1.getVariables(), parent2.getVariables(), ...
                        obj.lowerBounds, obj.upperBounds, obj.crossoverDistIndex);
                    % 随机选择一个子代
                    if rand() < 0.5
                        childVars = child1Vars;
                    else
                        childVars = child2Vars;
                    end
                else
                    % 不交叉，直接复制父代
                    if rand() < 0.5
                        childVars = parent1.getVariables();
                    else
                        childVars = parent2.getVariables();
                    end
                end

                % 变异
                childVars = GeneticOperators.polynomialMutation(childVars, ...
                    obj.lowerBounds, obj.upperBounds, obj.mutationRate, obj.mutationDistIndex);

                % 创建子代个体
                child = Individual(childVars);
                offspring.add(child);
            end
        end

        function selectedPop = environmentalSelection(obj, combinedPop)
            % environmentalSelection 环境选择
            %
            % 输入:
            %   combinedPop - 合并后的种群（父代+子代）
            %
            % 输出:
            %   selectedPop - 选择后的种群
            %
            % 说明:
            %   根据rank和crowdingDistance选择最好的N个个体

            selectedPop = Population();
            individuals = combinedPop.getAll();

            % 按rank排序，rank相同则按crowdingDistance降序
            [~, sortIdx] = sort(arrayfun(@(ind) ind.rank * 1e6 - ind.crowdingDistance, individuals));

            % 选择前N个个体
            for i = 1:min(obj.populationSize, length(sortIdx))
                selectedPop.add(individuals(sortIdx(i)).clone());
            end
        end

        function logProgress(obj)
            % logProgress 记录优化进度
            %
            % 说明:
            %   输出当前代数、评估次数和Pareto前沿信息

            paretoFront = obj.population.getParetoFront();
            paretoSize = paretoFront.size();

            obj.logMessage('INFO', '代数: %d/%d, 评估: %d, Pareto前沿: %d个解', ...
                          obj.currentGeneration, obj.maxGenerations, ...
                          obj.evaluationCount, paretoSize);

            % 如果是单目标，输出最优值
            if obj.problem.getNumberOfObjectives() == 1
                bestInd = obj.population.getBestIndividual();
                if ~isempty(bestInd)
                    obj.logMessage('INFO', '  最优值: %.6e', bestInd.getObjectives());
                end
            end
        end

        function recordHistory(obj)
            % recordHistory 记录历史数据
            %
            % 说明:
            %   记录当前代的最优解、Pareto前沿等信息

            historyEntry = struct();
            historyEntry.iteration = obj.currentGeneration;
            historyEntry.evaluations = obj.evaluationCount;

            % 记录Pareto前沿
            paretoFront = obj.population.getParetoFront();
            if paretoFront.size() > 0
                if obj.problem.getNumberOfObjectives() == 1
                    % 单目标：记录最优个体
                    bestInd = paretoFront.get(1);
                    historyEntry.bestSolution = bestInd.getVariables();
                    historyEntry.bestObjectives = bestInd.getObjectives();
                else
                    % 多目标：记录Pareto前沿大小
                    historyEntry.paretoFrontSize = paretoFront.size();
                end
            end

            % 添加到历史记录
            if isempty(obj.history)
                obj.history = historyEntry;
            else
                obj.history(end+1) = historyEntry;
            end
        end
    end
end
