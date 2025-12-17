classdef PSO < AlgorithmBase
    % PSO 粒子群优化算法
    % Particle Swarm Optimization
    %
    % 功能:
    %   - 标准PSO算法实现
    %   - 支持单目标和多目标优化
    %   - 速度限制和边界处理
    %   - 惯性权重策略
    %
    % 示例:
    %   % 单目标优化
    %   config = struct();
    %   config.swarmSize = 30;
    %   config.maxIterations = 100;
    %   config.w = 0.7298;
    %   config.c1 = 1.49618;
    %   config.c2 = 1.49618;
    %
    %   pso = PSO();
    %   results = pso.optimize(problem, config);

    properties (Access = private)
        swarmSize;          % 粒子群大小
        maxIterations;      % 最大迭代次数
        w;                  % 惯性权重
        c1;                 % 个体学习因子
        c2;                 % 社会学习因子
        vMax;               % 最大速度（相对于搜索空间）
        velocities;         % 速度矩阵 [swarmSize × numVars]
        pBest;              % 个体最优Individual数组
        gBest;              % 全局最优Individual
        lowerBounds;        % 变量下界
        upperBounds;        % 变量上界
        useExternalArchive; % 是否使用外部档案（多目标）
        archive;            % 外部档案（多目标Pareto解集）
        parallelConfig;     % 并行计算配置 (ParallelConfig对象)
        enableParallel;     % 是否启用并行评估
    end

    methods
        function obj = PSO()
            % PSO 构造函数
            %
            % 示例:
            %   pso = PSO();

            % 调用父类构造函数
            obj@AlgorithmBase();

            % 默认参数
            obj.swarmSize = 30;
            obj.maxIterations = 200;
            obj.w = 0.7298;           % 惯性权重
            obj.c1 = 1.49618;         % 个体学习因子
            obj.c2 = 1.49618;         % 社会学习因子
            obj.vMax = 0.2;           % 最大速度（占搜索空间的比例）
            obj.useExternalArchive = false;
            obj.archive = [];
            obj.enableParallel = false;   % 默认不启用并行
            obj.parallelConfig = [];      % 并行配置（延迟初始化）
        end

        function results = optimize(obj, problem, config)
            % optimize 运行PSO优化（实现IOptimizer接口）
            %
            % 输入:
            %   problem - OptimizationProblem对象
            %   config - 配置结构体
            %
            % 输出:
            %   results - 优化结果结构体
            %
            % 示例:
            %   results = pso.optimize(problem, config);

            % 初始化
            obj.initialize(problem, config);
            obj.loadConfig(config);
            obj.validateProblem();
            obj.validateConfig();

            % 获取变量界限
            obj.getBounds();

            % 初始化粒子群
            obj.initializeSwarm();

            % 主循环
            iteration = 0;
            while ~obj.shouldStop()
                iteration = iteration + 1;

                % 更新速度
                obj.updateVelocities();

                % 更新位置
                obj.updatePositions();

                % 评估（支持并行）
                if obj.enableParallel && ~isempty(obj.parallelConfig)
                    obj.population.evaluate(problem.evaluator, obj.parallelConfig);
                else
                    obj.population.evaluate(problem.evaluator);
                end
                obj.incrementEvaluationCount(obj.swarmSize);

                % 更新个体最优
                obj.updatePBest();

                % 更新全局最优
                obj.updateGBest();

                % 记录历史
                iterData = obj.getIterationData(iteration);
                obj.logIteration(iteration, iterData);
            end

            % 完成优化
            results = obj.finalizeResults();
        end
    end

    methods (Access = private)
        function loadConfig(obj, config)
            % loadConfig 加载PSO配置参数
            %
            % 输入:
            %   config - 配置结构体

            if isstruct(config)
                if isfield(config, 'swarmSize')
                    obj.swarmSize = config.swarmSize;
                end
                if isfield(config, 'maxIterations')
                    obj.maxIterations = config.maxIterations;
                    obj.maxEvaluations = obj.swarmSize * obj.maxIterations;
                end
                % Support both legacy and GUI/ConfigBuilder parameter names
                if isfield(config, 'inertiaWeight')
                    obj.w = config.inertiaWeight;
                elseif isfield(config, 'w')
                    obj.w = config.w;
                end
                if isfield(config, 'cognitiveCoeff')
                    obj.c1 = config.cognitiveCoeff;
                elseif isfield(config, 'c1')
                    obj.c1 = config.c1;
                end
                if isfield(config, 'socialCoeff')
                    obj.c2 = config.socialCoeff;
                elseif isfield(config, 'c2')
                    obj.c2 = config.c2;
                end
                if isfield(config, 'maxVelocityRatio')
                    obj.vMax = config.maxVelocityRatio;
                elseif isfield(config, 'vMax')
                    obj.vMax = config.vMax;
                end
                if isfield(config, 'useExternalArchive')
                    obj.useExternalArchive = config.useExternalArchive;
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

            % 多目标优化自动启用外部档案
            if obj.problem.getNumberOfObjectives() > 1
                obj.useExternalArchive = true;
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

            numVars = obj.problem.getNumberOfVariables();
            bounds = obj.problem.getBounds();

            % bounds是[n×2]矩阵，第一列是下界，第二列是上界
            obj.lowerBounds = bounds(:, 1)';
            obj.upperBounds = bounds(:, 2)';
        end

        function initializeSwarm(obj)
            % initializeSwarm 初始化粒子群
            %
            % 说明:
            %   生成初始粒子位置和速度（支持并行）

            numVars = obj.problem.getNumberOfVariables();

            obj.logMessage('INFO', '初始化粒子群 (大小: %d, 维度: %d)', ...
                          obj.swarmSize, numVars);

            % 创建初始种群
            obj.population = Population.random(obj.swarmSize, numVars, ...
                                              obj.lowerBounds, obj.upperBounds);

            % 评估初始种群（支持并行）
            if obj.enableParallel && ~isempty(obj.parallelConfig)
                obj.population.evaluate(obj.problem.evaluator, obj.parallelConfig);
            else
                obj.population.evaluate(obj.problem.evaluator);
            end
            obj.incrementEvaluationCount(obj.swarmSize);

            % 初始化速度
            range = obj.upperBounds - obj.lowerBounds;
            vRange = obj.vMax * range;
            obj.velocities = -vRange + 2 * vRange .* rand(obj.swarmSize, numVars);

            % 初始化个体最优
            obj.pBest = Individual.empty(0, 0);
            individuals = obj.population.getAll();
            for i = 1:obj.swarmSize
                obj.pBest(i) = individuals(i).clone();
            end

            % 初始化外部档案（多目标）
            if obj.useExternalArchive
                obj.archive = obj.population.getParetoFront();
                obj.logMessage('INFO', '初始化外部档案 (大小: %d)', obj.archive.size());
            end

            % 初始化全局最优
            obj.updateGBest();

            obj.logMessage('INFO', '粒子群初始化完成');
        end

        function updateVelocities(obj)
            % updateVelocities 更新粒子速度
            %
            % 说明:
            %   使用标准PSO速度更新公式
            %   v = w*v + c1*rand()*(pBest-x) + c2*rand()*(gBest-x)

            individuals = obj.population.getAll();
            numVars = obj.problem.getNumberOfVariables();

            for i = 1:obj.swarmSize
                % 当前位置
                x = individuals(i).getVariables();

                % 个体最优位置
                pBestPos = obj.pBest(i).getVariables();

                % 全局最优位置
                gBestPos = obj.gBest.getVariables();

                % 生成随机数
                r1 = rand(1, numVars);
                r2 = rand(1, numVars);

                % 更新速度
                obj.velocities(i, :) = obj.w * obj.velocities(i, :) + ...
                                       obj.c1 * r1 .* (pBestPos - x) + ...
                                       obj.c2 * r2 .* (gBestPos - x);

                % 速度限制
                range = obj.upperBounds - obj.lowerBounds;
                vMaxVec = obj.vMax * range;
                obj.velocities(i, :) = max(min(obj.velocities(i, :), vMaxVec), -vMaxVec);
            end
        end

        function updatePositions(obj)
            % updatePositions 更新粒子位置
            %
            % 说明:
            %   x = x + v
            %   并进行边界处理

            individuals = obj.population.getAll();

            for i = 1:obj.swarmSize
                % 当前位置
                x = individuals(i).getVariables();

                % 更新位置
                newX = x + obj.velocities(i, :);

                % 边界处理（反弹）
                for j = 1:length(newX)
                    if newX(j) < obj.lowerBounds(j)
                        newX(j) = obj.lowerBounds(j);
                        obj.velocities(i, j) = -obj.velocities(i, j) * 0.5;
                    elseif newX(j) > obj.upperBounds(j)
                        newX(j) = obj.upperBounds(j);
                        obj.velocities(i, j) = -obj.velocities(i, j) * 0.5;
                    end
                end

                % 设置新位置
                individuals(i).setVariables(newX);
            end
        end

        function updatePBest(obj)
            % updatePBest 更新个体最优
            %
            % 说明:
            %   如果当前位置优于个体最优，则更新

            individuals = obj.population.getAll();

            for i = 1:obj.swarmSize
                % 比较当前位置和个体最优
                if individuals(i).dominates(obj.pBest(i))
                    % 当前位置支配个体最优，更新
                    obj.pBest(i) = individuals(i).clone();
                elseif obj.problem.getNumberOfObjectives() == 1
                    % 单目标：直接比较目标值
                    if individuals(i).getObjective(1) < obj.pBest(i).getObjective(1)
                        obj.pBest(i) = individuals(i).clone();
                    end
                end
            end
        end

        function updateGBest(obj)
            % updateGBest 更新全局最优
            %
            % 说明:
            %   单目标：选择种群中最优个体
            %   多目标：从外部档案中选择

            if obj.problem.getNumberOfObjectives() == 1
                % 单目标优化
                obj.updateGBestSingleObjective();
            else
                % 多目标优化
                obj.updateGBestMultiObjective();
            end

            % 更新最优个体
            obj.updateBestIndividual(obj.gBest);
        end

        function updateGBestSingleObjective(obj)
            % updateGBestSingleObjective 更新全局最优（单目标）
            %
            % 说明:
            %   选择pBest中目标值最小的个体

            bestIdx = 1;
            bestObj = obj.pBest(1).getObjective(1);

            for i = 2:length(obj.pBest)
                objVal = obj.pBest(i).getObjective(1);
                if objVal < bestObj
                    bestObj = objVal;
                    bestIdx = i;
                end
            end

            obj.gBest = obj.pBest(bestIdx).clone();
        end

        function updateGBestMultiObjective(obj)
            % updateGBestMultiObjective 更新全局最优（多目标）
            %
            % 说明:
            %   更新外部档案
            %   从档案中选择一个解作为gBest

            % 更新外部档案
            combinedPop = obj.population.merge(obj.archive);
            combinedPop.fastNonDominatedSort();
            newArchive = combinedPop.getParetoFront();

            % 限制档案大小
            maxArchiveSize = obj.swarmSize * 2;
            if newArchive.size() > maxArchiveSize
                % 计算拥挤距离并截断
                newArchive.calculateCrowdingDistance();
                sortedArchive = newArchive.sortByCrowdingDistance();
                obj.archive = sortedArchive.truncate(maxArchiveSize);
            else
                obj.archive = newArchive;
            end

            % 从档案中随机选择一个解作为gBest
            if ~obj.archive.isEmpty()
                randIdx = randi(obj.archive.size());
                obj.gBest = obj.archive.get(randIdx).clone();
            else
                % 如果档案为空，从当前种群选择
                obj.updateGBestSingleObjective();
            end
        end

        function data = getIterationData(obj, iteration)
            % getIterationData 获取迭代数据
            %
            % 输入:
            %   iteration - 迭代次数
            %
            % 输出:
            %   data - 数据结构体

            data = struct();
            data.iteration = iteration;
            data.evaluations = obj.evaluationCount;

            if ~isempty(obj.gBest)
                data.bestObjectives = obj.gBest.getObjectives();
                data.bestFeasible = obj.gBest.isFeasible();
            end

            % 种群统计
            if ~obj.population.isEmpty()
                stats = obj.population.getStatistics();
                data.feasibleRatio = stats.feasibleRatio;
                data.objectiveMean = stats.objectiveMean;
                data.objectiveStd = stats.objectiveStd;
            end

            % 多目标：档案大小
            if obj.useExternalArchive && ~isempty(obj.archive)
                data.archiveSize = obj.archive.size();
            end
        end
    end

    methods (Access = protected)
        function validateConfig(obj)
            % validateConfig 验证配置（覆盖父类）

            % 调用父类验证
            validateConfig@AlgorithmBase(obj);

            % PSO特定验证
            if obj.swarmSize <= 0
                error('PSO:InvalidConfig', '粒子群大小必须大于0');
            end

            if obj.maxIterations <= 0
                error('PSO:InvalidConfig', '最大迭代次数必须大于0');
            end

            if obj.w < 0
                warning('PSO:InvalidConfig', '惯性权重通常为正数');
            end

            if obj.c1 <= 0 || obj.c2 <= 0
                error('PSO:InvalidConfig', '学习因子必须大于0');
            end

            if obj.vMax <= 0 || obj.vMax > 1
                warning('PSO:InvalidConfig', '最大速度通常在(0,1]范围内');
            end
        end
    end

    methods (Static)
        function type = getAlgorithmType()
            % getAlgorithmType 获取算法类型
            %
            % 输出:
            %   type - 'PSO'

            type = 'PSO';
        end

        function config = getDefaultConfig()
            % getDefaultConfig 获取默认配置
            %
            % 输出:
            %   config - 默认配置结构体
            %
            % 示例:
            %   config = PSO.getDefaultConfig();

            config = struct();
            config.swarmSize = 30;
            config.maxIterations = 200;
            config.maxEvaluations = 6000;
            % Preferred parameter names (aligned with GUI/ConfigBuilder)
            config.inertiaWeight = 0.7298;        % 惯性权重
            config.cognitiveCoeff = 1.49618;      % 个体学习因子
            config.socialCoeff = 1.49618;         % 社会学习因子
            config.maxVelocityRatio = 0.2;        % 最大速度比例

            % Legacy aliases for backward compatibility
            config.w = config.inertiaWeight;
            config.c1 = config.cognitiveCoeff;
            config.c2 = config.socialCoeff;
            config.vMax = config.maxVelocityRatio;
            config.verbose = true;
            config.useExternalArchive = false;  % 多目标时自动启用
        end
    end
end
