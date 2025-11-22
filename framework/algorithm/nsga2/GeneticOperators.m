classdef GeneticOperators
    % GeneticOperators 遗传算子工具类
    % 提供常用的遗传算法算子（交叉、变异、选择）
    %
    % 功能:
    %   - SBX交叉（模拟二进制交叉）
    %   - 多项式变异
    %   - 二元锦标赛选择
    %   - 单点交叉、多点交叉（待实现）
    %   - 均匀变异（待实现）
    %
    % 示例:
    %   % SBX交叉
    %   [child1, child2] = GeneticOperators.sbxCrossover(parent1, parent2, ...
    %                                                     lb, ub, eta);
    %
    %   % 多项式变异
    %   mutated = GeneticOperators.polynomialMutation(individual, lb, ub, ...
    %                                                  mutationRate, eta);
    %
    %   % 二元锦标赛选择
    %   selected = GeneticOperators.binaryTournament(population);

    methods (Static)
        function [child1, child2] = sbxCrossover(parent1, parent2, lowerBounds, upperBounds, eta)
            % sbxCrossover SBX交叉（模拟二进制交叉）
            %
            % 输入:
            %   parent1 - 父代1变量向量
            %   parent2 - 父代2变量向量
            %   lowerBounds - 变量下界向量
            %   upperBounds - 变量上界向量
            %   eta - 交叉分布指数（默认20）
            %
            % 输出:
            %   child1 - 子代1变量向量
            %   child2 - 子代2变量向量
            %
            % 说明:
            %   实现SBX交叉算子，保持搜索分布特性
            %   参考文献：Deb & Agrawal (1995)
            %
            % 示例:
            %   [c1, c2] = GeneticOperators.sbxCrossover(p1, p2, lb, ub, 20);

            if nargin < 5
                eta = 20;  % 默认分布指数
            end

            numVars = length(parent1);
            child1 = parent1;
            child2 = parent2;

            for i = 1:numVars
                % 每个变量以0.5的概率进行交叉
                if rand() > 0.5
                    continue;
                end

                % 确保父代不相同
                if abs(parent1(i) - parent2(i)) < 1e-14
                    continue;
                end

                % 计算beta
                y1 = min(parent1(i), parent2(i));
                y2 = max(parent1(i), parent2(i));

                lb = lowerBounds(i);
                ub = upperBounds(i);

                % 计算beta_q
                u = rand();
                if u <= 0.5
                    beta_q = (2 * u)^(1 / (eta + 1));
                else
                    beta_q = (1 / (2 * (1 - u)))^(1 / (eta + 1));
                end

                % 生成子代
                c1 = 0.5 * ((y1 + y2) - beta_q * (y2 - y1));
                c2 = 0.5 * ((y1 + y2) + beta_q * (y2 - y1));

                % 边界处理
                c1 = max(lb, min(ub, c1));
                c2 = max(lb, min(ub, c2));

                child1(i) = c1;
                child2(i) = c2;
            end
        end

        function mutatedVars = polynomialMutation(vars, lowerBounds, upperBounds, mutationRate, eta)
            % polynomialMutation 多项式变异
            %
            % 输入:
            %   vars - 变量向量
            %   lowerBounds - 变量下界向量
            %   upperBounds - 变量上界向量
            %   mutationRate - 变异率（通常为1/n，n为变量数）
            %   eta - 变异分布指数（默认20）
            %
            % 输出:
            %   mutatedVars - 变异后的变量向量
            %
            % 说明:
            %   实现多项式变异算子
            %   参考文献：Deb & Goyal (1996)
            %
            % 示例:
            %   mutated = GeneticOperators.polynomialMutation(x, lb, ub, 1/n, 20);

            if nargin < 5
                eta = 20;  % 默认分布指数
            end

            numVars = length(vars);
            mutatedVars = vars;

            % 每个变量的变异概率
            mutationProb = mutationRate / numVars;

            for i = 1:numVars
                if rand() < mutationProb
                    y = vars(i);
                    lb = lowerBounds(i);
                    ub = upperBounds(i);

                    delta1 = (y - lb) / (ub - lb);
                    delta2 = (ub - y) / (ub - lb);

                    u = rand();
                    if u <= 0.5
                        delta_q = (2 * u + (1 - 2 * u) * (1 - delta1)^(eta + 1))^(1 / (eta + 1)) - 1;
                    else
                        delta_q = 1 - (2 * (1 - u) + 2 * (u - 0.5) * (1 - delta2)^(eta + 1))^(1 / (eta + 1));
                    end

                    % 应用变异
                    y = y + delta_q * (ub - lb);

                    % 边界处理
                    y = max(lb, min(ub, y));

                    mutatedVars(i) = y;
                end
            end
        end

        function selected = binaryTournament(individuals)
            % binaryTournament 二元锦标赛选择
            %
            % 输入:
            %   individuals - Individual对象数组
            %
            % 输出:
            %   selected - 选中的Individual对象
            %
            % 说明:
            %   随机选择两个个体，返回较优的一个
            %   比较标准：rank更小优先，rank相同则crowdingDistance更大优先
            %
            % 示例:
            %   parent = GeneticOperators.binaryTournament(population);

            % 随机选择两个个体
            n = length(individuals);
            idx1 = randi(n);
            idx2 = randi(n);

            ind1 = individuals(idx1);
            ind2 = individuals(idx2);

            % 比较：rank小的优先
            if ind1.rank < ind2.rank
                selected = ind1;
            elseif ind1.rank > ind2.rank
                selected = ind2;
            else
                % rank相同，crowdingDistance大的优先
                if ind1.crowdingDistance > ind2.crowdingDistance
                    selected = ind1;
                else
                    selected = ind2;
                end
            end
        end

        function offspring = uniformCrossover(parent1, parent2, lowerBounds, upperBounds)
            % uniformCrossover 均匀交叉
            %
            % 输入:
            %   parent1 - 父代1变量向量
            %   parent2 - 父代2变量向量
            %   lowerBounds - 变量下界向量
            %   upperBounds - 变量上界向量
            %
            % 输出:
            %   offspring - 子代变量向量
            %
            % 说明:
            %   每个变量以0.5概率从父代1或父代2继承
            %
            % 示例:
            %   child = GeneticOperators.uniformCrossover(p1, p2, lb, ub);

            numVars = length(parent1);
            offspring = zeros(1, numVars);

            for i = 1:numVars
                if rand() < 0.5
                    offspring(i) = parent1(i);
                else
                    offspring(i) = parent2(i);
                end
            end
        end

        function offspring = singlePointCrossover(parent1, parent2, lowerBounds, upperBounds)
            % singlePointCrossover 单点交叉
            %
            % 输入:
            %   parent1 - 父代1变量向量
            %   parent2 - 父代2变量向量
            %   lowerBounds - 变量下界向量
            %   upperBounds - 变量上界向量
            %
            % 输出:
            %   offspring - 子代变量向量
            %
            % 说明:
            %   在随机位置切分，前半部分继承父代1，后半部分继承父代2
            %
            % 示例:
            %   child = GeneticOperators.singlePointCrossover(p1, p2, lb, ub);

            numVars = length(parent1);
            crossoverPoint = randi([1, numVars-1]);

            offspring = [parent1(1:crossoverPoint), parent2(crossoverPoint+1:end)];
        end

        function mutatedVars = uniformMutation(vars, lowerBounds, upperBounds, mutationRate)
            % uniformMutation 均匀变异
            %
            % 输入:
            %   vars - 变量向量
            %   lowerBounds - 变量下界向量
            %   upperBounds - 变量上界向量
            %   mutationRate - 变异率
            %
            % 输出:
            %   mutatedVars - 变异后的变量向量
            %
            % 说明:
            %   以给定概率对每个变量进行均匀随机变异
            %
            % 示例:
            %   mutated = GeneticOperators.uniformMutation(x, lb, ub, 0.01);

            numVars = length(vars);
            mutatedVars = vars;

            for i = 1:numVars
                if rand() < mutationRate
                    % 在边界内均匀随机生成新值
                    mutatedVars(i) = lowerBounds(i) + rand() * (upperBounds(i) - lowerBounds(i));
                end
            end
        end

        function mutatedVars = gaussianMutation(vars, lowerBounds, upperBounds, mutationRate, sigma)
            % gaussianMutation 高斯变异
            %
            % 输入:
            %   vars - 变量向量
            %   lowerBounds - 变量下界向量
            %   upperBounds - 变量上界向量
            %   mutationRate - 变异率
            %   sigma - 高斯分布标准差（相对于搜索空间，默认0.1）
            %
            % 输出:
            %   mutatedVars - 变异后的变量向量
            %
            % 说明:
            %   以高斯分布对变量进行扰动
            %
            % 示例:
            %   mutated = GeneticOperators.gaussianMutation(x, lb, ub, 0.1, 0.1);

            if nargin < 5
                sigma = 0.1;
            end

            numVars = length(vars);
            mutatedVars = vars;

            for i = 1:numVars
                if rand() < mutationRate
                    range = upperBounds(i) - lowerBounds(i);
                    delta = sigma * range * randn();  % 高斯扰动
                    y = vars(i) + delta;

                    % 边界处理
                    y = max(lowerBounds(i), min(upperBounds(i), y));
                    mutatedVars(i) = y;
                end
            end
        end

        function selected = tournamentSelection(individuals, tournamentSize)
            % tournamentSelection K元锦标赛选择
            %
            % 输入:
            %   individuals - Individual对象数组
            %   tournamentSize - 锦标赛大小（默认2）
            %
            % 输出:
            %   selected - 选中的Individual对象
            %
            % 说明:
            %   随机选择K个个体，返回最优的一个
            %
            % 示例:
            %   parent = GeneticOperators.tournamentSelection(population, 3);

            if nargin < 2
                tournamentSize = 2;
            end

            n = length(individuals);
            tournamentSize = min(tournamentSize, n);

            % 随机选择K个个体
            indices = randperm(n, tournamentSize);
            candidates = individuals(indices);

            % 找到最优个体（rank最小，如果rank相同则crowdingDistance最大）
            selected = candidates(1);
            for i = 2:tournamentSize
                if candidates(i).rank < selected.rank || ...
                   (candidates(i).rank == selected.rank && ...
                    candidates(i).crowdingDistance > selected.crowdingDistance)
                    selected = candidates(i);
                end
            end
        end

        function selected = rouletteWheelSelection(individuals, fitness)
            % rouletteWheelSelection 轮盘赌选择
            %
            % 输入:
            %   individuals - Individual对象数组
            %   fitness - 适应度值数组（越大越好）
            %
            % 输出:
            %   selected - 选中的Individual对象
            %
            % 说明:
            %   按照适应度比例进行选择
            %
            % 示例:
            %   parent = GeneticOperators.rouletteWheelSelection(pop, fitness);

            % 计算累积适应度
            totalFitness = sum(fitness);
            if totalFitness == 0
                % 如果所有适应度为0，随机选择
                selected = individuals(randi(length(individuals)));
                return;
            end

            % 归一化适应度
            probabilities = fitness / totalFitness;
            cumulativeProb = cumsum(probabilities);

            % 轮盘赌选择
            r = rand();
            idx = find(cumulativeProb >= r, 1, 'first');
            selected = individuals(idx);
        end
    end
end
