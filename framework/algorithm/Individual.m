classdef Individual < handle
    % Individual 优化算法中的个体（解）
    % 表示一个候选解，包含决策变量、目标值、约束等信息
    %
    % 功能:
    %   - 存储决策变量和目标值
    %   - 计算约束违反度
    %   - Pareto支配关系判断
    %   - 可行性检查
    %   - 深拷贝和比较
    %
    % 示例:
    %   % 创建个体
    %   ind = Individual([1.0, 2.0, 3.0]);
    %
    %   % 设置目标值
    %   ind.setObjectives([10.5, 20.3]);
    %
    %   % 检查支配关系
    %   if ind.dominates(otherInd)
    %       fprintf('ind支配otherInd\n');
    %   end
    %
    %   % 深拷贝
    %   ind2 = ind.clone();


    properties
        variables;              % 决策变量值向量
        objectives;             % 目标函数值向量
        constraints;            % 约束值向量
        constraintViolation;    % 总约束违反度
        rank;                   % Pareto秩（用于NSGA-II等）
        crowdingDistance;       % 拥挤距离（用于NSGA-II等）
        evaluated;              % 是否已评估
    end

    properties (Access = private)
        dominationCount;        % 被支配次数
        dominatedSolutions;     % 被该解支配的解的索引集合
        userData;               % 用户自定义数据
    end

    methods
        function obj = Individual(variables)
            % Individual 构造函数
            %
            % 输入:
            %   variables - (可选) 决策变量值向量
            %
            % 示例:
            %   ind = Individual([1.0, 2.0, 3.0]);
            %   ind = Individual(); % 空个体

            if nargin < 1
                obj.variables = [];
            else
                obj.variables = variables;
            end

            obj.objectives = [];
            obj.constraints = [];
            obj.constraintViolation = 0;
            obj.rank = 0;
            obj.crowdingDistance = 0;
            obj.evaluated = false;
            obj.dominationCount = 0;
            obj.dominatedSolutions = [];
            obj.userData = struct();
        end

        function setVariables(obj, variables)
            % setVariables 设置决策变量
            %
            % 输入:
            %   variables - 变量值向量
            %
            % 示例:
            %   ind.setVariables([1.0, 2.0, 3.0]);

            obj.variables = variables;
            obj.evaluated = false; % 变量改变，需要重新评估
        end

        function vars = getVariables(obj)
            % getVariables 获取决策变量
            %
            % 输出:
            %   vars - 变量值向量
            %
            % 示例:
            %   x = ind.getVariables();

            vars = obj.variables;
        end

        function setObjectives(obj, objectives)
            % setObjectives 设置目标函数值
            %
            % 输入:
            %   objectives - 目标值向量
            %
            % 示例:
            %   ind.setObjectives([10.5, 20.3]);

            obj.objectives = objectives;
            obj.evaluated = true;
        end

        function objs = getObjectives(obj)
            % getObjectives 获取目标函数值
            %
            % 输出:
            %   objs - 目标值向量
            %
            % 示例:
            %   f = ind.getObjectives();

            objs = obj.objectives;
        end

        function obj_val = getObjective(obj, index)
            % getObjective 获取指定目标函数值
            %
            % 输入:
            %   index - 目标索引
            %
            % 输出:
            %   obj_val - 目标值
            %
            % 示例:
            %   f1 = ind.getObjective(1);

            if index > 0 && index <= length(obj.objectives)
                obj_val = obj.objectives(index);
            else
                error('Individual:InvalidIndex', '目标索引超出范围');
            end
        end

        function setConstraints(obj, constraints)
            % setConstraints 设置约束值
            %
            % 输入:
            %   constraints - 约束值向量
            %
            % 示例:
            %   ind.setConstraints([0.1, -0.5]);

            obj.constraints = constraints;
            obj.updateConstraintViolation();
        end

        function cons = getConstraints(obj)
            % getConstraints 获取约束值
            %
            % 输出:
            %   cons - 约束值向量
            %
            % 示例:
            %   g = ind.getConstraints();

            cons = obj.constraints;
        end

        function viol = getConstraintViolation(obj)
            % getConstraintViolation 获取总约束违反度
            %
            % 输出:
            %   viol - 约束违反度
            %
            % 示例:
            %   cv = ind.getConstraintViolation();

            viol = obj.constraintViolation;
        end

        function tf = isFeasible(obj, tolerance)
            % isFeasible 检查解是否可行
            %
            % 输入:
            %   tolerance - (可选) 容差，默认1e-6
            %
            % 输出:
            %   tf - 布尔值，true表示可行
            %
            % 示例:
            %   if ind.isFeasible()

            if nargin < 2
                tolerance = 1e-6;
            end

            tf = obj.constraintViolation <= tolerance;
        end

        function tf = isEvaluated(obj)
            % isEvaluated 检查是否已评估
            %
            % 输出:
            %   tf - 布尔值
            %
            % 示例:
            %   if ind.isEvaluated()

            tf = obj.evaluated;
        end

        function tf = dominates(obj, other)
            % dominates 判断是否Pareto支配另一个解
            %
            % 输入:
            %   other - 另一个Individual对象
            %
            % 输出:
            %   tf - 布尔值，true表示obj支配other
            %
            % 说明:
            %   解x支配解y当且仅当：
            %   1. x在所有目标上不劣于y
            %   2. x至少在一个目标上严格优于y
            %   假设所有目标都是最小化
            %
            % 示例:
            %   if ind1.dominates(ind2)

            if isempty(obj.objectives) || isempty(other.objectives)
                error('Individual:NotEvaluated', '个体未评估');
            end

            if length(obj.objectives) ~= length(other.objectives)
                error('Individual:SizeMismatch', '目标数量不匹配');
            end

            % 首先比较约束违反度
            objViol = obj.constraintViolation;
            otherViol = other.constraintViolation;

            % 如果一个可行一个不可行，可行的支配不可行的
            if objViol <= 0 && otherViol > 0
                tf = true;
                return;
            elseif objViol > 0 && otherViol <= 0
                tf = false;
                return;
            elseif objViol > 0 && otherViol > 0
                % 都不可行，比较约束违反度（违反度小的更好）
                tf = objViol < otherViol;
                return;
            end

            % 都可行，比较目标值
            objVals = obj.objectives;
            otherVals = other.objectives;

            % 检查是否所有目标都不劣于other
            notWorse = all(objVals <= otherVals);

            % 检查是否至少有一个目标严格优于other
            strictlyBetter = any(objVals < otherVals);

            tf = notWorse && strictlyBetter;
        end

        function result = compare(obj, other, index)
            % compare 按指定目标比较两个解
            %
            % 输入:
            %   other - 另一个Individual对象
            %   index - 目标索引
            %
            % 输出:
            %   result - -1: obj < other, 0: obj == other, 1: obj > other
            %
            % 示例:
            %   cmp = ind1.compare(ind2, 1);

            if obj.objectives(index) < other.objectives(index)
                result = -1;
            elseif obj.objectives(index) > other.objectives(index)
                result = 1;
            else
                result = 0;
            end
        end

        function tf = equals(obj, other, tolerance)
            % equals 判断两个解是否相等
            %
            % 输入:
            %   other - 另一个Individual对象
            %   tolerance - (可选) 容差，默认1e-10
            %
            % 输出:
            %   tf - 布尔值
            %
            % 示例:
            %   if ind1.equals(ind2)

            if nargin < 3
                tolerance = 1e-10;
            end

            if length(obj.variables) ~= length(other.variables)
                tf = false;
                return;
            end

            tf = all(abs(obj.variables - other.variables) < tolerance);
        end

        function copy = clone(obj)
            % clone 深拷贝个体
            %
            % 输出:
            %   copy - 新的Individual对象
            %
            % 示例:
            %   ind2 = ind1.clone();

            copy = Individual(obj.variables);
            copy.objectives = obj.objectives;
            copy.constraints = obj.constraints;
            copy.constraintViolation = obj.constraintViolation;
            copy.rank = obj.rank;
            copy.crowdingDistance = obj.crowdingDistance;
            copy.evaluated = obj.evaluated;
            copy.dominationCount = obj.dominationCount;
            copy.dominatedSolutions = obj.dominatedSolutions;
            copy.userData = obj.userData;
        end

        function setRank(obj, rank)
            % setRank 设置Pareto秩
            %
            % 输入:
            %   rank - 秩值
            %
            % 示例:
            %   ind.setRank(1);

            obj.rank = rank;
        end

        function r = getRank(obj)
            % getRank 获取Pareto秩
            %
            % 输出:
            %   r - 秩值
            %
            % 示例:
            %   rank = ind.getRank();

            r = obj.rank;
        end

        function setCrowdingDistance(obj, distance)
            % setCrowdingDistance 设置拥挤距离
            %
            % 输入:
            %   distance - 拥挤距离值
            %
            % 示例:
            %   ind.setCrowdingDistance(1.5);

            obj.crowdingDistance = distance;
        end

        function d = getCrowdingDistance(obj)
            % getCrowdingDistance 获取拥挤距离
            %
            % 输出:
            %   d - 拥挤距离值
            %
            % 示例:
            %   dist = ind.getCrowdingDistance();

            d = obj.crowdingDistance;
        end

        function incrementDominationCount(obj)
            % incrementDominationCount 增加被支配计数
            %
            % 说明:
            %   用于非支配排序算法

            obj.dominationCount = obj.dominationCount + 1;
        end

        function decrementDominationCount(obj)
            % decrementDominationCount 减少被支配计数
            %
            % 说明:
            %   用于非支配排序算法

            obj.dominationCount = obj.dominationCount - 1;
        end

        function count = getDominationCount(obj)
            % getDominationCount 获取被支配计数
            %
            % 输出:
            %   count - 被支配次数
            %
            % 示例:
            %   n = ind.getDominationCount();

            count = obj.dominationCount;
        end

        function resetDominationCount(obj)
            % resetDominationCount 重置被支配计数
            %
            % 说明:
            %   用于非支配排序算法

            obj.dominationCount = 0;
        end

        function addDominatedSolution(obj, index)
            % addDominatedSolution 添加被该解支配的解索引
            %
            % 输入:
            %   index - 解的索引
            %
            % 说明:
            %   用于非支配排序算法

            obj.dominatedSolutions(end+1) = index;
        end

        function indices = getDominatedSolutions(obj)
            % getDominatedSolutions 获取被该解支配的解索引集合
            %
            % 输出:
            %   indices - 索引向量
            %
            % 示例:
            %   dominated = ind.getDominatedSolutions();

            indices = obj.dominatedSolutions;
        end

        function clearDominatedSolutions(obj)
            % clearDominatedSolutions 清空被支配解集合
            %
            % 说明:
            %   用于非支配排序算法

            obj.dominatedSolutions = [];
        end

        function setUserData(obj, key, value)
            % setUserData 设置用户自定义数据
            %
            % 输入:
            %   key - 键名
            %   value - 值
            %
            % 示例:
            %   ind.setUserData('fitness', 0.95);

            obj.userData.(key) = value;
        end

        function value = getUserData(obj, key, defaultValue)
            % getUserData 获取用户自定义数据
            %
            % 输入:
            %   key - 键名
            %   defaultValue - (可选) 默认值
            %
            % 输出:
            %   value - 数据值
            %
            % 示例:
            %   fitness = ind.getUserData('fitness', 0);

            if nargin < 3
                defaultValue = [];
            end

            if isfield(obj.userData, key)
                value = obj.userData.(key);
            else
                value = defaultValue;
            end
        end

        function display(obj)
            % display 显示个体信息
            %
            % 示例:
            %   ind.display();

            fprintf('========================================\n');
            fprintf('Individual\n');
            fprintf('========================================\n');

            if ~isempty(obj.variables)
                fprintf('Variables (%d): ', length(obj.variables));
                if length(obj.variables) <= 5
                    fprintf('[');
                    fprintf('%.4g ', obj.variables);
                    fprintf(']\n');
                else
                    fprintf('[%.4g %.4g ... %.4g %.4g]\n', ...
                            obj.variables(1), obj.variables(2), ...
                            obj.variables(end-1), obj.variables(end));
                end
            else
                fprintf('Variables: None\n');
            end

            if ~isempty(obj.objectives)
                fprintf('Objectives (%d): [', length(obj.objectives));
                fprintf('%.6g ', obj.objectives);
                fprintf(']\n');
            else
                fprintf('Objectives: Not evaluated\n');
            end

            fprintf('Feasible: %s\n', mat2str(obj.isFeasible()));
            if ~obj.isFeasible()
                fprintf('Constraint Violation: %.6g\n', obj.constraintViolation);
            end

            fprintf('Rank: %d\n', obj.rank);
            fprintf('Crowding Distance: %.6g\n', obj.crowdingDistance);
            fprintf('========================================\n');
        end
    end

    methods (Access = private)
        function updateConstraintViolation(obj)
            % updateConstraintViolation 更新总约束违反度
            %
            % 说明:
            %   计算所有约束的总违反度
            %   约束值 <= 0 表示满足，> 0 表示违反

            if isempty(obj.constraints)
                obj.constraintViolation = 0;
            else
                % 只累计违反的约束（正值）
                obj.constraintViolation = sum(max(0, obj.constraints));
            end
        end
    end

    methods (Static)
        function sorted = sortByObjective(individuals, objectiveIndex, ascending)
            % sortByObjective 按指定目标排序个体数组
            %
            % 输入:
            %   individuals - Individual对象数组
            %   objectiveIndex - 目标索引
            %   ascending - (可选) 是否升序，默认true
            %
            % 输出:
            %   sorted - 排序后的Individual对象数组
            %
            % 示例:
            %   sorted = Individual.sortByObjective(population, 1);

            if nargin < 3
                ascending = true;
            end

            % 提取目标值
            objValues = zeros(length(individuals), 1);
            for i = 1:length(individuals)
                objValues(i) = individuals(i).getObjective(objectiveIndex);
            end

            % 排序
            if ascending
                [~, idx] = sort(objValues, 'ascend');
            else
                [~, idx] = sort(objValues, 'descend');
            end

            sorted = individuals(idx);
        end

        function sorted = sortByRank(individuals)
            % sortByRank 按Pareto秩排序个体
            %
            % 输入:
            %   individuals - Individual对象数组
            %
            % 输出:
            %   sorted - 排序后的Individual对象数组
            %
            % 示例:
            %   sorted = Individual.sortByRank(population);

            ranks = zeros(length(individuals), 1);
            for i = 1:length(individuals)
                ranks(i) = individuals(i).getRank();
            end

            [~, idx] = sort(ranks, 'ascend');
            sorted = individuals(idx);
        end

        function sorted = sortByCrowdingDistance(individuals, ascending)
            % sortByCrowdingDistance 按拥挤距离排序个体
            %
            % 输入:
            %   individuals - Individual对象数组
            %   ascending - (可选) 是否升序，默认false（降序）
            %
            % 输出:
            %   sorted - 排序后的Individual对象数组
            %
            % 示例:
            %   sorted = Individual.sortByCrowdingDistance(population);

            if nargin < 2
                ascending = false; % 默认降序（拥挤距离大的优先）
            end

            distances = zeros(length(individuals), 1);
            for i = 1:length(individuals)
                distances(i) = individuals(i).getCrowdingDistance();
            end

            if ascending
                [~, idx] = sort(distances, 'ascend');
            else
                [~, idx] = sort(distances, 'descend');
            end

            sorted = individuals(idx);
        end
    end
end
