classdef AnnNsga2Operators
    % AnnNsga2Operators 遗传算子工具类（ANN-NSGA-II专用）
    % 提供SBX交叉、多项式变异、二元锦标赛选择等算子。

    methods (Static)
        function selected = binaryTournament(individuals)
            % binaryTournament 二元锦标赛选择
            %
            % 比较标准：
            %   1) rank更小优先
            %   2) rank相同则crowdingDistance更大优先

            n = length(individuals);
            idx1 = randi(n);
            idx2 = randi(n);

            ind1 = individuals(idx1);
            ind2 = individuals(idx2);

            if ind1.rank < ind2.rank
                selected = ind1;
            elseif ind1.rank > ind2.rank
                selected = ind2;
            else
                if ind1.crowdingDistance > ind2.crowdingDistance
                    selected = ind1;
                else
                    selected = ind2;
                end
            end
        end

        function [child1, child2] = sbxCrossover(parent1, parent2, lowerBounds, upperBounds, eta)
            % sbxCrossover SBX交叉（模拟二进制交叉）
            %
            % 输入:
            %   parent1,parent2 - 父代变量向量
            %   lowerBounds,upperBounds - 边界向量
            %   eta - 分布指数（默认20）

            if nargin < 5
                eta = 20;
            end

            numVars = length(parent1);
            child1 = parent1;
            child2 = parent2;

            for i = 1:numVars
                if rand() > 0.5
                    continue;
                end

                if abs(parent1(i) - parent2(i)) < 1e-14
                    continue;
                end

                y1 = min(parent1(i), parent2(i));
                y2 = max(parent1(i), parent2(i));

                lb = lowerBounds(i);
                ub = upperBounds(i);

                u = rand();
                if u <= 0.5
                    beta_q = (2 * u)^(1 / (eta + 1));
                else
                    beta_q = (1 / (2 * (1 - u)))^(1 / (eta + 1));
                end

                c1 = 0.5 * ((y1 + y2) - beta_q * (y2 - y1));
                c2 = 0.5 * ((y1 + y2) + beta_q * (y2 - y1));

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
            %   lowerBounds,upperBounds - 边界向量
            %   mutationRate - 归一化变异率（会再除以维度）
            %   eta - 分布指数（默认20）

            if nargin < 5
                eta = 20;
            end

            numVars = length(vars);
            mutatedVars = vars;

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

                    y = y + delta_q * (ub - lb);
                    y = max(lb, min(ub, y));
                    mutatedVars(i) = y;
                end
            end
        end
    end
end

