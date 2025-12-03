classdef Population < handle
    % Population 种群类
    % 管理优化算法中的个体集合
    %
    % 功能:
    %   - 存储和管理Individual对象集合
    %   - 批量评估个体
    %   - Pareto前沿提取
    %   - 快速非支配排序
    %   - 拥挤距离计算
    %   - 种群统计和筛选
    %   - 种群操作（合并、分割、采样）
    %
    % 示例:
    %   % 创建种群
    %   pop = Population();
    %
    %   % 添加个体
    %   for i = 1:100
    %       ind = Individual(rand(1, 10));
    %       pop.add(ind);
    %   end
    %
    %   % 批量评估
    %   pop.evaluate(evaluator);
    %
    %   % 提取Pareto前沿
    %   front = pop.getParetoFront();


    properties (Access = private)
        individuals;    % Individual对象数组
    end

    methods
        function obj = Population(individuals)
            % Population 构造函数
            %
            % 输入:
            %   individuals - (可选) Individual对象数组
            %
            % 示例:
            %   pop = Population();
            %   pop = Population(individualArray);

            if nargin < 1
                obj.individuals = Individual.empty(0, 0);
            else
                obj.individuals = individuals;
            end
        end

        function add(obj, individual)
            % add 添加个体到种群
            %
            % 输入:
            %   individual - Individual对象
            %
            % 示例:
            %   pop.add(ind);

            obj.individuals(end+1) = individual;
        end

        function addAll(obj, individuals)
            % addAll 批量添加个体
            %
            % 输入:
            %   individuals - Individual对象数组
            %
            % 示例:
            %   pop.addAll(indArray);

            obj.individuals = [obj.individuals, individuals];
        end

        function remove(obj, index)
            % remove 移除指定索引的个体
            %
            % 输入:
            %   index - 索引
            %
            % 示例:
            %   pop.remove(5);

            if index > 0 && index <= length(obj.individuals)
                obj.individuals(index) = [];
            end
        end

        function ind = get(obj, index)
            % get 获取指定索引的个体
            %
            % 输入:
            %   index - 索引
            %
            % 输出:
            %   ind - Individual对象
            %
            % 示例:
            %   ind = pop.get(1);

            if index > 0 && index <= length(obj.individuals)
                ind = obj.individuals(index);
            else
                error('Population:InvalidIndex', '索引超出范围');
            end
        end

        function set(obj, index, individual)
            % set 设置指定索引的个体
            %
            % 输入:
            %   index - 索引
            %   individual - Individual对象
            %
            % 示例:
            %   pop.set(1, newInd);

            if index > 0 && index <= length(obj.individuals)
                obj.individuals(index) = individual;
            else
                error('Population:InvalidIndex', '索引超出范围');
            end
        end

        function inds = getAll(obj)
            % getAll 获取所有个体
            %
            % 输出:
            %   inds - Individual对象数组
            %
            % 示例:
            %   allInds = pop.getAll();

            inds = obj.individuals;
        end

        function n = size(obj)
            % size 获取种群大小
            %
            % 输出:
            %   n - 个体数量
            %
            % 示例:
            %   popSize = pop.size();

            n = length(obj.individuals);
        end

        function tf = isEmpty(obj)
            % isEmpty 检查种群是否为空
            %
            % 输出:
            %   tf - 布尔值
            %
            % 示例:
            %   if pop.isEmpty()

            tf = isempty(obj.individuals);
        end

        function clear(obj)
            % clear 清空种群
            %
            % 示例:
            %   pop.clear();

            obj.individuals = Individual.empty(0, 0);
        end

        function evaluate(obj, evaluator, parallelConfig)
            % evaluate 批量评估所有未评估的个体
            %
            % 输入:
            %   evaluator - Evaluator对象
            %   parallelConfig - (可选) ParallelConfig对象，用于并行评估
            %
            % 示例:
            %   pop.evaluate(evaluator);
            %   pop.evaluate(evaluator, parallelConfig);  % 并行评估

            % 如果提供了并行配置且启用了并行，使用并行评估
            if nargin >= 3 && ~isempty(parallelConfig) && ...
               isa(parallelConfig, 'ParallelConfig') && parallelConfig.enableParallel
                obj.evaluateParallel(evaluator, parallelConfig);
                return;
            end

            % 顺序评估
            for i = 1:length(obj.individuals)
                ind = obj.individuals(i);
                if ~ind.isEvaluated()
                    % 评估个体
                    x = ind.getVariables();
                    result = evaluator.evaluate(x);

                    % 设置目标值和约束
                    if isfield(result, 'objectives')
                        ind.setObjectives(result.objectives);
                    end

                    if isfield(result, 'constraints')
                        ind.setConstraints(result.constraints);
                    end
                end
            end
        end

        function evaluateParallel(obj, evaluator, parallelConfig)
            % evaluateParallel 并行评估所有未评估的个体
            %
            % 输入:
            %   evaluator - Evaluator对象
            %   parallelConfig - ParallelConfig对象
            %
            % 示例:
            %   pop.evaluateParallel(evaluator, parallelConfig);

            n = length(obj.individuals);
            if n == 0
                return;
            end

            % 收集需要评估的个体信息
            needsEval = false(n, 1);
            numVars = length(obj.individuals(1).getVariables());
            varMatrix = zeros(n, numVars);

            for i = 1:n
                needsEval(i) = ~obj.individuals(i).isEvaluated();
                varMatrix(i, :) = obj.individuals(i).getVariables();
            end

            evalIndices = find(needsEval);
            numToEval = length(evalIndices);

            if numToEval == 0
                return;
            end

            % 获取或创建并行池
            pool = parallelConfig.getOrCreatePool();

            if isempty(pool)
                % 回退到顺序评估
                obj.evaluate(evaluator);
                return;
            end

            % 提取需要评估的变量
            varsToEval = varMatrix(evalIndices, :);

            % 并行评估
            results = cell(numToEval, 1);

            try
                parfor i = 1:numToEval
                    try
                        x = varsToEval(i, :);
                        results{i} = evaluator.evaluate(x);
                    catch ME
                        results{i} = struct(...
                            'objectives', inf, ...
                            'constraints', inf, ...
                            'success', false, ...
                            'message', ME.message);
                    end
                end
            catch ME
                warning('Population:ParallelEvalFailed', ...
                    '并行评估失败: %s\n回退到顺序评估', ME.message);
                obj.evaluate(evaluator);
                return;
            end

            % 更新个体
            for i = 1:numToEval
                idx = evalIndices(i);
                if ~isempty(results{i})
                    if isfield(results{i}, 'objectives')
                        obj.individuals(idx).setObjectives(results{i}.objectives);
                    end
                    if isfield(results{i}, 'constraints')
                        obj.individuals(idx).setConstraints(results{i}.constraints);
                    end
                end
            end
        end

        function evaluateAll(obj, evaluator)
            % evaluateAll 强制评估所有个体（包括已评估的）
            %
            % 输入:
            %   evaluator - Evaluator对象
            %
            % 示例:
            %   pop.evaluateAll(evaluator);

            for i = 1:length(obj.individuals)
                ind = obj.individuals(i);
                x = ind.getVariables();
                result = evaluator.evaluate(x);

                if isfield(result, 'objectives')
                    ind.setObjectives(result.objectives);
                end

                if isfield(result, 'constraints')
                    ind.setConstraints(result.constraints);
                end
            end
        end

        function front = getParetoFront(obj)
            % getParetoFront 提取Pareto前沿（第一非支配层）
            %
            % 输出:
            %   front - Population对象，包含前沿个体
            %
            % 示例:
            %   paretoFront = pop.getParetoFront();

            if obj.isEmpty()
                front = Population();
                return;
            end

            % 执行快速非支配排序
            obj.fastNonDominatedSort();

            % 提取秩为1的个体
            frontInds = Individual.empty(0, 0);
            for i = 1:length(obj.individuals)
                if obj.individuals(i).getRank() == 1
                    frontInds(end+1) = obj.individuals(i); %#ok<AGROW>
                end
            end

            front = Population(frontInds);
        end

        function fronts = getAllFronts(obj)
            % getAllFronts 获取所有非支配层
            %
            % 输出:
            %   fronts - Population对象的cell array
            %
            % 示例:
            %   allFronts = pop.getAllFronts();

            if obj.isEmpty()
                fronts = {};
                return;
            end

            % 执行快速非支配排序
            obj.fastNonDominatedSort();

            % 按秩分组
            maxRank = max(arrayfun(@(ind) ind.getRank(), obj.individuals));
            fronts = cell(maxRank, 1);

            for rank = 1:maxRank
                frontInds = Individual.empty(0, 0);
                for i = 1:length(obj.individuals)
                    if obj.individuals(i).getRank() == rank
                        frontInds(end+1) = obj.individuals(i); %#ok<AGROW>
                    end
                end
                fronts{rank} = Population(frontInds);
            end
        end

        function fastNonDominatedSort(obj)
            % fastNonDominatedSort 快速非支配排序
            %
            % 说明:
            %   为所有个体分配Pareto秩
            %   使用NSGA-II的快速非支配排序算法
            %
            % 示例:
            %   pop.fastNonDominatedSort();

            n = length(obj.individuals);
            if n == 0
                return;
            end

            % 初始化
            for i = 1:n
                obj.individuals(i).resetDominationCount();
                obj.individuals(i).clearDominatedSolutions();
            end

            % 第一层（非支配解集）
            firstFront = [];

            % 计算支配关系
            for i = 1:n
                for j = i+1:n
                    if obj.individuals(i).dominates(obj.individuals(j))
                        % i支配j
                        obj.individuals(i).addDominatedSolution(j);
                        obj.individuals(j).incrementDominationCount();
                    elseif obj.individuals(j).dominates(obj.individuals(i))
                        % j支配i
                        obj.individuals(j).addDominatedSolution(i);
                        obj.individuals(i).incrementDominationCount();
                    end
                end

                % 如果i未被任何解支配，加入第一层
                if obj.individuals(i).getDominationCount() == 0
                    obj.individuals(i).setRank(1);
                    firstFront(end+1) = i; %#ok<AGROW>
                end
            end

            % 构建后续层
            currentFront = firstFront;
            rank = 1;

            while ~isempty(currentFront)
                nextFront = [];

                for i = 1:length(currentFront)
                    p = currentFront(i);
                    dominated = obj.individuals(p).getDominatedSolutions();

                    for j = 1:length(dominated)
                        q = dominated(j);
                        obj.individuals(q).decrementDominationCount();

                        if obj.individuals(q).getDominationCount() == 0
                            obj.individuals(q).setRank(rank + 1);
                            nextFront(end+1) = q; %#ok<AGROW>
                        end
                    end
                end

                rank = rank + 1;
                currentFront = nextFront;
            end
        end

        function calculateCrowdingDistance(obj)
            % calculateCrowdingDistance 计算拥挤距离
            %
            % 说明:
            %   为所有个体计算拥挤距离
            %   使用NSGA-II的拥挤距离计算方法
            %
            % 示例:
            %   pop.calculateCrowdingDistance();

            n = length(obj.individuals);
            if n == 0
                return;
            end

            % 检查是否已评估
            if ~obj.individuals(1).isEvaluated()
                error('Population:NotEvaluated', '种群未评估');
            end

            numObjectives = length(obj.individuals(1).getObjectives());

            % 初始化拥挤距离为0
            for i = 1:n
                obj.individuals(i).setCrowdingDistance(0);
            end

            % 对每个目标
            for m = 1:numObjectives
                % 按该目标排序
                sorted = Individual.sortByObjective(obj.individuals, m, true);

                % 边界个体设置为无穷大
                sorted(1).setCrowdingDistance(inf);
                sorted(end).setCrowdingDistance(inf);

                % 目标值范围
                objMin = sorted(1).getObjective(m);
                objMax = sorted(end).getObjective(m);
                objRange = objMax - objMin;

                % 避免除以零
                if objRange == 0
                    continue;
                end

                % 计算中间个体的拥挤距离
                for i = 2:n-1
                    distance = sorted(i).getCrowdingDistance();
                    objPrev = sorted(i-1).getObjective(m);
                    objNext = sorted(i+1).getObjective(m);

                    distance = distance + (objNext - objPrev) / objRange;
                    sorted(i).setCrowdingDistance(distance);
                end
            end
        end

        function sorted = sortByObjective(obj, objectiveIndex, ascending)
            % sortByObjective 按指定目标排序
            %
            % 输入:
            %   objectiveIndex - 目标索引
            %   ascending - (可选) 是否升序，默认true
            %
            % 输出:
            %   sorted - 排序后的Population对象
            %
            % 示例:
            %   sortedPop = pop.sortByObjective(1);

            if nargin < 3
                ascending = true;
            end

            sortedInds = Individual.sortByObjective(obj.individuals, objectiveIndex, ascending);
            sorted = Population(sortedInds);
        end

        function sorted = sortByRank(obj)
            % sortByRank 按Pareto秩排序
            %
            % 输出:
            %   sorted - 排序后的Population对象
            %
            % 示例:
            %   sortedPop = pop.sortByRank();

            sortedInds = Individual.sortByRank(obj.individuals);
            sorted = Population(sortedInds);
        end

        function sorted = sortByCrowdingDistance(obj, ascending)
            % sortByCrowdingDistance 按拥挤距离排序
            %
            % 输入:
            %   ascending - (可选) 是否升序，默认false
            %
            % 输出:
            %   sorted - 排序后的Population对象
            %
            % 示例:
            %   sortedPop = pop.sortByCrowdingDistance();

            if nargin < 2
                ascending = false;
            end

            sortedInds = Individual.sortByCrowdingDistance(obj.individuals, ascending);
            sorted = Population(sortedInds);
        end

        function filtered = filterByRank(obj, rank)
            % filterByRank 筛选指定秩的个体
            %
            % 输入:
            %   rank - 秩值
            %
            % 输出:
            %   filtered - 筛选后的Population对象
            %
            % 示例:
            %   firstFront = pop.filterByRank(1);

            filteredInds = Individual.empty(0, 0);
            for i = 1:length(obj.individuals)
                if obj.individuals(i).getRank() == rank
                    filteredInds(end+1) = obj.individuals(i); %#ok<AGROW>
                end
            end

            filtered = Population(filteredInds);
        end

        function filtered = filterFeasible(obj)
            % filterFeasible 筛选可行解
            %
            % 输出:
            %   filtered - 筛选后的Population对象
            %
            % 示例:
            %   feasiblePop = pop.filterFeasible();

            filteredInds = Individual.empty(0, 0);
            for i = 1:length(obj.individuals)
                if obj.individuals(i).isFeasible()
                    filteredInds(end+1) = obj.individuals(i); %#ok<AGROW>
                end
            end

            filtered = Population(filteredInds);
        end

        function merged = merge(obj, other)
            % merge 合并两个种群
            %
            % 输入:
            %   other - 另一个Population对象
            %
            % 输出:
            %   merged - 合并后的Population对象
            %
            % 示例:
            %   combined = pop1.merge(pop2);

            mergedInds = [obj.individuals, other.getAll()];
            merged = Population(mergedInds);
        end

        function [split1, split2] = split(obj, index)
            % split 分割种群
            %
            % 输入:
            %   index - 分割位置
            %
            % 输出:
            %   split1 - 第一部分Population对象
            %   split2 - 第二部分Population对象
            %
            % 示例:
            %   [part1, part2] = pop.split(50);

            n = length(obj.individuals);
            if index < 1 || index > n
                error('Population:InvalidIndex', '分割索引超出范围');
            end

            split1 = Population(obj.individuals(1:index));
            if index < n
                split2 = Population(obj.individuals(index+1:end));
            else
                split2 = Population();
            end
        end

        function sampled = sample(obj, n, withReplacement)
            % sample 随机采样
            %
            % 输入:
            %   n - 采样数量
            %   withReplacement - (可选) 是否有放回，默认false
            %
            % 输出:
            %   sampled - 采样后的Population对象
            %
            % 示例:
            %   subset = pop.sample(50);

            if nargin < 3
                withReplacement = false;
            end

            popSize = length(obj.individuals);
            if n > popSize && ~withReplacement
                error('Population:InvalidSize', '无放回采样数量超过种群大小');
            end

            if withReplacement
                indices = randi(popSize, 1, n);
            else
                indices = randperm(popSize, n);
            end

            sampledInds = obj.individuals(indices);
            sampled = Population(sampledInds);
        end

        function truncated = truncate(obj, n)
            % truncate 截取前n个个体
            %
            % 输入:
            %   n - 保留数量
            %
            % 输出:
            %   truncated - 截取后的Population对象
            %
            % 示例:
            %   subset = pop.truncate(100);

            if n >= length(obj.individuals)
                truncated = Population(obj.individuals);
            else
                truncated = Population(obj.individuals(1:n));
            end
        end

        function bestInd = getBestIndividual(obj, objectiveIndex)
            % getBestIndividual 获取最优个体（单目标或指定目标）
            %
            % 输入:
            %   objectiveIndex - (可选) 目标索引，默认为1
            %
            % 输出:
            %   bestInd - 最优Individual对象，如果种群为空返回[]
            %
            % 示例:
            %   best = pop.getBestIndividual();
            %   best = pop.getBestIndividual(2);  % 按第二个目标

            if nargin < 2
                objectiveIndex = 1;
            end

            if obj.isEmpty()
                bestInd = [];
                return;
            end

            % 检查是否已评估
            if ~obj.individuals(1).isEvaluated()
                bestInd = [];
                return;
            end

            % 找到目标值最小的个体
            bestInd = obj.individuals(1);
            bestValue = bestInd.getObjective(objectiveIndex);

            for i = 2:length(obj.individuals)
                currentValue = obj.individuals(i).getObjective(objectiveIndex);
                if currentValue < bestValue
                    bestValue = currentValue;
                    bestInd = obj.individuals(i);
                end
            end
        end

        function stats = getStatistics(obj)
            % getStatistics 获取种群统计信息
            %
            % 输出:
            %   stats - 统计信息结构体
            %
            % 示例:
            %   stats = pop.getStatistics();

            stats = struct();
            stats.size = length(obj.individuals);

            if stats.size == 0
                return;
            end

            % 检查是否已评估
            if ~obj.individuals(1).isEvaluated()
                stats.evaluated = false;
                return;
            end

            stats.evaluated = true;
            numObjectives = length(obj.individuals(1).getObjectives());

            % 提取所有目标值
            objMatrix = zeros(stats.size, numObjectives);
            for i = 1:stats.size
                objMatrix(i, :) = obj.individuals(i).getObjectives();
            end

            % 统计信息
            stats.numObjectives = numObjectives;
            stats.objectiveMean = mean(objMatrix, 1);
            stats.objectiveStd = std(objMatrix, 0, 1);
            stats.objectiveMin = min(objMatrix, [], 1);
            stats.objectiveMax = max(objMatrix, [], 1);

            % 可行解统计
            feasibleCount = 0;
            for i = 1:stats.size
                if obj.individuals(i).isFeasible()
                    feasibleCount = feasibleCount + 1;
                end
            end
            stats.feasibleCount = feasibleCount;
            stats.feasibleRatio = feasibleCount / stats.size;
        end

        function display(obj)
            % display 显示种群信息
            %
            % 示例:
            %   pop.display();

            fprintf('========================================\n');
            fprintf('Population\n');
            fprintf('========================================\n');
            fprintf('Size: %d\n', length(obj.individuals));

            if ~obj.isEmpty() && obj.individuals(1).isEvaluated()
                stats = obj.getStatistics();
                fprintf('Objectives: %d\n', stats.numObjectives);
                fprintf('Feasible: %d (%.1f%%)\n', stats.feasibleCount, stats.feasibleRatio * 100);

                fprintf('\nObjective Statistics:\n');
                for i = 1:stats.numObjectives
                    fprintf('  Obj %d: Mean=%.4g, Std=%.4g, Min=%.4g, Max=%.4g\n', ...
                            i, stats.objectiveMean(i), stats.objectiveStd(i), ...
                            stats.objectiveMin(i), stats.objectiveMax(i));
                end
            else
                fprintf('Status: Not evaluated\n');
            end

            fprintf('========================================\n');
        end
    end

    methods (Static)
        function pop = random(n, numVars, lowerBounds, upperBounds)
            % random 创建随机种群
            %
            % 输入:
            %   n - 种群大小
            %   numVars - 变量数量
            %   lowerBounds - 下界向量
            %   upperBounds - 上界向量
            %
            % 输出:
            %   pop - Population对象
            %
            % 示例:
            %   pop = Population.random(100, 10, zeros(1,10), ones(1,10));

            individuals = Individual.empty(0, 0);

            for i = 1:n
                % 生成随机变量
                vars = lowerBounds + rand(1, numVars) .* (upperBounds - lowerBounds);
                individuals(i) = Individual(vars);
            end

            pop = Population(individuals);
        end
    end
end
