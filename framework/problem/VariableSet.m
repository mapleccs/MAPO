classdef VariableSet < handle
    % VariableSet 变量集合类
    % 管理多个优化变量，提供批量操作功能
    %
    % 功能:
    %   - 变量管理（添加、删除、获取）
    %   - 批量验证
    %   - 批量归一化和反归一化
    %   - 批量随机采样
    %   - 获取边界矩阵和整数变量索引
    %
    % 示例:
    %   % 创建变量集合
    %   varSet = VariableSet();
    %
    %   % 添加变量
    %   varSet.addVariable(Variable('x1', 'continuous', [0, 10]));
    %   varSet.addVariable(Variable('x2', 'integer', [1, 20]));
    %   varSet.addVariable(Variable('x3', 'discrete', [1, 2, 5, 10]));
    %
    %   % 批量操作
    %   values = [5, 10, 5];
    %   isValid = varSet.validate(values);
    %   normalized = varSet.normalize(values);
    %   randomValues = varSet.sample();
    %
    %   % 获取信息
    %   bounds = varSet.getBounds();
    %   intIndices = varSet.getIntegerIndices();


    properties (Access = private)
        variables;    % Cell array of Variable objects
        nameMap;      % Map from variable name to index
    end

    methods
        function obj = VariableSet()
            % VariableSet 构造函数
            %
            % 示例:
            %   varSet = VariableSet();

            obj.variables = {};
            obj.nameMap = containers.Map('KeyType', 'char', 'ValueType', 'double');
        end

        function addVariable(obj, variable)
            % addVariable 添加变量到集合
            %
            % 输入:
            %   variable - Variable对象
            %
            % 示例:
            %   varSet.addVariable(Variable('x1', 'continuous', [0, 10]));

            if ~isa(variable, 'Variable')
                error('VariableSet:InvalidInput', '输入必须是Variable对象');
            end

            % 检查是否已存在同名变量
            if obj.nameMap.isKey(variable.name)
                error('VariableSet:DuplicateName', ...
                      '变量名 ''%s'' 已存在', variable.name);
            end

            % 添加变量
            obj.variables{end+1} = variable;
            obj.nameMap(variable.name) = length(obj.variables);
        end

        function removeVariable(obj, name)
            % removeVariable 从集合中删除变量
            %
            % 输入:
            %   name - 变量名称
            %
            % 示例:
            %   varSet.removeVariable('x1');

            if ~obj.nameMap.isKey(name)
                error('VariableSet:VariableNotFound', ...
                      '变量 ''%s'' 不存在', name);
            end

            % 获取索引并删除
            idx = obj.nameMap(name);
            obj.variables(idx) = [];

            % 重建nameMap
            obj.nameMap = containers.Map('KeyType', 'char', 'ValueType', 'double');
            for i = 1:length(obj.variables)
                obj.nameMap(obj.variables{i}.name) = i;
            end
        end

        function variable = getVariable(obj, name)
            % getVariable 根据名称获取变量
            %
            % 输入:
            %   name - 变量名称
            %
            % 输出:
            %   variable - Variable对象
            %
            % 示例:
            %   var = varSet.getVariable('x1');

            if ~obj.nameMap.isKey(name)
                error('VariableSet:VariableNotFound', ...
                      '变量 ''%s'' 不存在', name);
            end

            idx = obj.nameMap(name);
            variable = obj.variables{idx};
        end

        function variable = getVariableByIndex(obj, idx)
            % getVariableByIndex 根据索引获取变量
            %
            % 输入:
            %   idx - 变量索引 (1-based)
            %
            % 输出:
            %   variable - Variable对象
            %
            % 示例:
            %   var = varSet.getVariableByIndex(2);

            if idx < 1 || idx > length(obj.variables)
                error('VariableSet:IndexOutOfRange', ...
                      '索引 %d 超出范围 [1, %d]', idx, length(obj.variables));
            end

            variable = obj.variables{idx};
        end

        function n = size(obj)
            % size 获取变量数量
            %
            % 输出:
            %   n - 变量数量
            %
            % 示例:
            %   numVars = varSet.size();

            n = length(obj.variables);
        end

        function tf = isEmpty(obj)
            % isEmpty 判断变量集合是否为空
            %
            % 输出:
            %   tf - 布尔值
            %
            % 示例:
            %   if varSet.isEmpty()

            tf = isempty(obj.variables);
        end

        function tf = hasVariable(obj, name)
            % hasVariable 检查是否存在指定名称的变量
            %
            % 输入:
            %   name - 变量名称
            %
            % 输出:
            %   tf - 布尔值
            %
            % 示例:
            %   if varSet.hasVariable('x1')

            tf = obj.nameMap.isKey(name);
        end

        function names = getNames(obj)
            % getNames 获取所有变量名称
            %
            % 输出:
            %   names - 变量名称的cell array
            %
            % 示例:
            %   names = varSet.getNames();

            names = cell(1, length(obj.variables));
            for i = 1:length(obj.variables)
                names{i} = obj.variables{i}.name;
            end
        end

        function valid = validate(obj, values)
            % validate 批量验证变量值
            %
            % 输入:
            %   values - 值向量 [1×n] 或 [n×1]
            %
            % 输出:
            %   valid - 布尔值，所有值都有效时为true
            %
            % 示例:
            %   isValid = varSet.validate([5, 10, 2]);

            if obj.isEmpty()
                error('VariableSet:EmptySet', '变量集合为空');
            end

            % 确保values是向量
            if ~isvector(values)
                error('VariableSet:InvalidInput', 'values必须是向量');
            end

            % 检查长度
            if length(values) ~= obj.size()
                error('VariableSet:SizeMismatch', ...
                      'values长度 (%d) 与变量数量 (%d) 不匹配', ...
                      length(values), obj.size());
            end

            % 验证每个值
            valid = true;
            for i = 1:length(obj.variables)
                if ~obj.variables{i}.validate(values(i))
                    valid = false;
                    break;
                end
            end
        end

        function normalizedValues = normalize(obj, values)
            % normalize 批量归一化变量值到[0,1]
            %
            % 输入:
            %   values - 原始值向量 [1×n] 或 [n×1]
            %
            % 输出:
            %   normalizedValues - 归一化后的值向量
            %
            % 示例:
            %   normalized = varSet.normalize([5, 10, 2]);

            if obj.isEmpty()
                error('VariableSet:EmptySet', '变量集合为空');
            end

            % 确保values是向量
            if ~isvector(values)
                error('VariableSet:InvalidInput', 'values必须是向量');
            end

            % 检查长度
            if length(values) ~= obj.size()
                error('VariableSet:SizeMismatch', ...
                      'values长度 (%d) 与变量数量 (%d) 不匹配', ...
                      length(values), obj.size());
            end

            % 归一化每个值
            normalizedValues = zeros(size(values));
            for i = 1:length(obj.variables)
                normalizedValues(i) = obj.variables{i}.normalize(values(i));
            end
        end

        function values = denormalize(obj, normalizedValues)
            % denormalize 批量反归一化值向量
            %
            % 输入:
            %   normalizedValues - 归一化值向量 [1×n] 或 [n×1]
            %
            % 输出:
            %   values - 反归一化后的原始值向量
            %
            % 示例:
            %   values = varSet.denormalize([0.5, 0.5, 0.3]);

            if obj.isEmpty()
                error('VariableSet:EmptySet', '变量集合为空');
            end

            % 确保normalizedValues是向量
            if ~isvector(normalizedValues)
                error('VariableSet:InvalidInput', 'normalizedValues必须是向量');
            end

            % 检查长度
            if length(normalizedValues) ~= obj.size()
                error('VariableSet:SizeMismatch', ...
                      'normalizedValues长度 (%d) 与变量数量 (%d) 不匹配', ...
                      length(normalizedValues), obj.size());
            end

            % 反归一化每个值
            values = zeros(size(normalizedValues));
            for i = 1:length(obj.variables)
                val = obj.variables{i}.denormalize(normalizedValues(i));
                % 处理分类变量（可能返回字符串）
                if isnumeric(val)
                    values(i) = val;
                else
                    % 对于分类变量，存储值的索引
                    values(i) = i;  % 临时处理
                end
            end
        end

        function values = sample(obj)
            % sample 批量随机采样
            %
            % 输出:
            %   values - 随机采样的值向量 [1×n]
            %
            % 示例:
            %   randomValues = varSet.sample();

            if obj.isEmpty()
                error('VariableSet:EmptySet', '变量集合为空');
            end

            n = obj.size();
            values = zeros(1, n);

            for i = 1:n
                val = obj.variables{i}.sample();
                if isnumeric(val)
                    values(i) = val;
                else
                    % 对于分类变量，返回索引
                    values(i) = 1;  % 临时处理
                end
            end
        end

        function bounds = getBounds(obj)
            % getBounds 获取所有变量的边界矩阵
            %
            % 输出:
            %   bounds - [n×2] 矩阵，每行为 [lower, upper]
            %            离散/分类变量返回 [1, numValues]
            %
            % 示例:
            %   bounds = varSet.getBounds();
            %   lowerBounds = bounds(:, 1);
            %   upperBounds = bounds(:, 2);

            if obj.isEmpty()
                bounds = [];
                return;
            end

            n = obj.size();
            bounds = zeros(n, 2);

            for i = 1:n
                var = obj.variables{i};
                if var.isContinuous() || var.isInteger()
                    bounds(i, :) = [var.lowerBound, var.upperBound];
                elseif var.isDiscrete() || var.isCategorical()
                    % 离散/分类变量：返回值的数量范围
                    bounds(i, :) = [1, length(var.values)];
                end
            end
        end

        function indices = getIntegerIndices(obj)
            % getIntegerIndices 获取整数变量的索引
            %
            % 输出:
            %   indices - 整数变量索引的向量
            %
            % 示例:
            %   intIndices = varSet.getIntegerIndices();

            indices = [];

            for i = 1:length(obj.variables)
                if obj.variables{i}.isInteger()
                    indices(end+1) = i; %#ok<AGROW>
                end
            end
        end

        function indices = getContinuousIndices(obj)
            % getContinuousIndices 获取连续变量的索引
            %
            % 输出:
            %   indices - 连续变量索引的向量

            indices = [];

            for i = 1:length(obj.variables)
                if obj.variables{i}.isContinuous()
                    indices(end+1) = i; %#ok<AGROW>
                end
            end
        end

        function indices = getDiscreteIndices(obj)
            % getDiscreteIndices 获取离散变量的索引
            %
            % 输出:
            %   indices - 离散变量索引的向量

            indices = [];

            for i = 1:length(obj.variables)
                if obj.variables{i}.isDiscrete()
                    indices(end+1) = i; %#ok<AGROW>
                end
            end
        end

        function indices = getCategoricalIndices(obj)
            % getCategoricalIndices 获取分类变量的索引
            %
            % 输出:
            %   indices - 分类变量索引的向量

            indices = [];

            for i = 1:length(obj.variables)
                if obj.variables{i}.isCategorical()
                    indices(end+1) = i; %#ok<AGROW>
                end
            end
        end

        function s = toStruct(obj)
            % toStruct 将变量集合转换为结构体
            %
            % 输出:
            %   s - 结构体，包含所有变量的信息
            %
            % 示例:
            %   structData = varSet.toStruct();

            s = struct();
            s.size = obj.size();
            s.variables = cell(1, s.size);

            for i = 1:s.size
                s.variables{i} = obj.variables{i}.toStruct();
            end
        end

        function clear(obj)
            % clear 清空所有变量
            %
            % 示例:
            %   varSet.clear();

            obj.variables = {};
            obj.nameMap = containers.Map('KeyType', 'char', 'ValueType', 'double');
        end

        function display(obj)
            % display 显示变量集合信息
            %
            % 示例:
            %   varSet.display();

            fprintf('VariableSet with %d variables:\n', obj.size());
            for i = 1:length(obj.variables)
                fprintf('  [%d] %s\n', i, obj.variables{i}.toString());
            end
        end

        function iterator = getIterator(obj)
            % getIterator 获取变量迭代器
            %
            % 输出:
            %   iterator - cell array of Variable objects
            %
            % 示例:
            %   for i = 1:length(iterator)
            %       var = iterator{i};
            %   end

            iterator = obj.variables;
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            % fromStruct 从结构体创建VariableSet对象
            %
            % 输入:
            %   s - 结构体（通常来自toStruct()）
            %
            % 输出:
            %   obj - VariableSet对象
            %
            % 示例:
            %   varSet = VariableSet.fromStruct(structData);

            obj = VariableSet();

            if isfield(s, 'variables')
                for i = 1:length(s.variables)
                    var = Variable.fromStruct(s.variables{i});
                    obj.addVariable(var);
                end
            end
        end

        function obj = fromVariables(variables)
            % fromVariables 从Variable对象数组创建VariableSet
            %
            % 输入:
            %   variables - Variable对象的cell array
            %
            % 输出:
            %   obj - VariableSet对象
            %
            % 示例:
            %   vars = {Variable('x1', 'continuous', [0, 10]), ...
            %           Variable('x2', 'integer', [1, 20])};
            %   varSet = VariableSet.fromVariables(vars);

            obj = VariableSet();

            for i = 1:length(variables)
                obj.addVariable(variables{i});
            end
        end
    end
end
