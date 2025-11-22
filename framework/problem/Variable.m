classdef Variable < handle
    % Variable 优化变量类
    % 支持连续、整数、离散、分类变量
    %
    % 功能:
    %   - 4种变量类型 (Continuous/Integer/Discrete/Categorical)
    %   - 变量值验证
    %   - 归一化和反归一化
    %   - 随机采样
    %   - 序列化支持
    %
    % 示例:
    %   % 连续变量
    %   v1 = Variable('x1', 'continuous', [0, 10]);
    %
    %   % 整数变量
    %   v2 = Variable('x2', 'integer', [1, 20]);
    %
    %   % 离散变量
    %   v3 = Variable('x3', 'discrete', [1.0, 2.5, 5.0, 7.5, 10.0]);
    %
    %   % 分类变量
    %   v4 = Variable('material', 'categorical', {'steel', 'aluminum', 'titanium'});
    %
    %   % 验证和归一化
    %   isValid = v1.validate(5.5);
    %   normalized = v1.normalize(5.0);
    %   value = v1.denormalize(0.5);
    %
    %   % 随机采样
    %   randomValue = v1.sample();


    properties (Constant)
        TYPE_CONTINUOUS = 'continuous';   % 连续变量
        TYPE_INTEGER = 'integer';         % 整数变量
        TYPE_DISCRETE = 'discrete';       % 离散变量
        TYPE_CATEGORICAL = 'categorical'; % 分类变量
    end

    properties
        name;         % 变量名称
        type;         % 变量类型
        lowerBound;   % 下界（连续/整数变量）
        upperBound;   % 上界（连续/整数变量）
        values;       % 离散值集合（离散/分类变量）
        description;  % 变量描述
    end

    methods
        function obj = Variable(name, type, bounds, varargin)
            % Variable 构造函数
            %
            % 输入:
            %   name - 变量名称（字符串）
            %   type - 变量类型 ('continuous'/'integer'/'discrete'/'categorical')
            %   bounds - 边界或值集合
            %            连续/整数: [lower, upper]
            %            离散/分类: {value1, value2, ...} 或 [value1, value2, ...]
            %   varargin - 可选参数
            %              'Description', desc - 变量描述
            %
            % 示例:
            %   v1 = Variable('x1', 'continuous', [0, 10]);
            %   v2 = Variable('x2', 'integer', [1, 20], 'Description', '板数');
            %   v3 = Variable('x3', 'discrete', [1.0, 2.5, 5.0]);
            %   v4 = Variable('material', 'categorical', {'A', 'B', 'C'});

            % 参数检查
            if nargin < 3
                error('Variable:InsufficientArgs', '需要至少3个参数: name, type, bounds');
            end

            % 设置基本属性
            obj.name = name;
            obj.type = lower(type);
            obj.description = '';

            % 解析可选参数
            p = inputParser;
            addParameter(p, 'Description', '', @(x) ischar(x) || isstring(x) || isempty(x));
            parse(p, varargin{:});
            if isstring(p.Results.Description)
                obj.description = char(p.Results.Description);
            else
                obj.description = p.Results.Description;
            end

            % 根据类型设置边界或值集合
            switch obj.type
                case {Variable.TYPE_CONTINUOUS, Variable.TYPE_INTEGER}
                    % 连续或整数变量
                    if ~isnumeric(bounds) || length(bounds) ~= 2
                        error('Variable:InvalidBounds', ...
                              '连续/整数变量需要2元素向量 [lower, upper]');
                    end
                    obj.lowerBound = bounds(1);
                    obj.upperBound = bounds(2);
                    if obj.lowerBound >= obj.upperBound
                        error('Variable:InvalidBounds', ...
                              '下界必须小于上界');
                    end
                    obj.values = [];

                case {Variable.TYPE_DISCRETE, Variable.TYPE_CATEGORICAL}
                    % 离散或分类变量
                    if iscell(bounds)
                        obj.values = bounds;
                    elseif isnumeric(bounds)
                        obj.values = num2cell(bounds);
                    else
                        error('Variable:InvalidValues', ...
                              '离散/分类变量需要cell数组或数值向量');
                    end

                    if isempty(obj.values)
                        error('Variable:InvalidValues', ...
                              '离散/分类变量值集合不能为空');
                    end

                    % 分类变量的值必须是字符串或符号
                    if strcmp(obj.type, Variable.TYPE_CATEGORICAL)
                        for i = 1:length(obj.values)
                            if ~(ischar(obj.values{i}) || isstring(obj.values{i}))
                                error('Variable:InvalidValues', ...
                                      '分类变量的值必须是字符串');
                            end
                        end
                    end

                    obj.lowerBound = [];
                    obj.upperBound = [];

                otherwise
                    error('Variable:InvalidType', ...
                          '无效的变量类型: %s。支持的类型: continuous, integer, discrete, categorical', type);
            end
        end

        function valid = validate(obj, value)
            % validate 验证变量值是否有效
            %
            % 输入:
            %   value - 要验证的值
            %
            % 输出:
            %   valid - 布尔值，true表示有效
            %
            % 示例:
            %   isValid = variable.validate(5.5);

            switch obj.type
                case Variable.TYPE_CONTINUOUS
                    valid = isnumeric(value) && isscalar(value) && ...
                            value >= obj.lowerBound && value <= obj.upperBound;

                case Variable.TYPE_INTEGER
                    valid = isnumeric(value) && isscalar(value) && ...
                            value >= obj.lowerBound && value <= obj.upperBound && ...
                            value == floor(value);

                case Variable.TYPE_DISCRETE
                    valid = false;
                    for i = 1:length(obj.values)
                        if isequal(value, obj.values{i})
                            valid = true;
                            break;
                        end
                    end

                case Variable.TYPE_CATEGORICAL
                    valid = false;
                    for i = 1:length(obj.values)
                        if strcmp(value, obj.values{i})
                            valid = true;
                            break;
                        end
                    end

                otherwise
                    valid = false;
            end
        end

        function normalizedValue = normalize(obj, value)
            % normalize 将变量值归一化到[0,1]
            %
            % 输入:
            %   value - 原始值
            %
            % 输出:
            %   normalizedValue - 归一化后的值 (在[0,1]范围内)
            %
            % 说明:
            %   - 连续/整数变量: 线性归一化到[0,1]
            %   - 离散/分类变量: 映射到索引归一化值
            %
            % 示例:
            %   normalized = variable.normalize(5.0);

            if ~obj.validate(value)
                error('Variable:InvalidValue', ...
                      '变量值 %s 不在有效范围内', num2str(value));
            end

            switch obj.type
                case {Variable.TYPE_CONTINUOUS, Variable.TYPE_INTEGER}
                    % 线性归一化
                    normalizedValue = (value - obj.lowerBound) / ...
                                     (obj.upperBound - obj.lowerBound);

                case {Variable.TYPE_DISCRETE, Variable.TYPE_CATEGORICAL}
                    % 找到值的索引，归一化到[0,1]
                    idx = obj.findValueIndex(value);
                    n = length(obj.values);
                    if n == 1
                        normalizedValue = 0.5;  % 只有一个值，归一化为中点
                    else
                        normalizedValue = (idx - 1) / (n - 1);
                    end

                otherwise
                    error('Variable:UnsupportedType', '不支持的变量类型');
            end
        end

        function value = denormalize(obj, normalizedValue)
            % denormalize 将归一化值反归一化到原始范围
            %
            % 输入:
            %   normalizedValue - 归一化值 (应在[0,1]范围内)
            %
            % 输出:
            %   value - 反归一化后的原始值
            %
            % 示例:
            %   value = variable.denormalize(0.5);

            if normalizedValue < 0 || normalizedValue > 1
                warning('Variable:OutOfRange', ...
                        '归一化值 %.3f 超出[0,1]范围，将被截断', normalizedValue);
                normalizedValue = max(0, min(1, normalizedValue));
            end

            switch obj.type
                case Variable.TYPE_CONTINUOUS
                    % 线性反归一化
                    value = obj.lowerBound + normalizedValue * ...
                            (obj.upperBound - obj.lowerBound);

                case Variable.TYPE_INTEGER
                    % 线性反归一化并取整
                    value = round(obj.lowerBound + normalizedValue * ...
                                 (obj.upperBound - obj.lowerBound));
                    % 确保在边界内
                    value = max(obj.lowerBound, min(obj.upperBound, value));

                case {Variable.TYPE_DISCRETE, Variable.TYPE_CATEGORICAL}
                    % 映射到最近的离散值
                    n = length(obj.values);
                    if n == 1
                        idx = 1;
                    else
                        idx = round(normalizedValue * (n - 1)) + 1;
                        idx = max(1, min(n, idx));
                    end
                    value = obj.values{idx};

                otherwise
                    error('Variable:UnsupportedType', '不支持的变量类型');
            end
        end

        function value = sample(obj)
            % sample 在变量有效范围内随机采样
            %
            % 输出:
            %   value - 随机采样的值
            %
            % 示例:
            %   randomValue = variable.sample();

            switch obj.type
                case Variable.TYPE_CONTINUOUS
                    % 在[lower, upper]范围内均匀采样
                    value = obj.lowerBound + rand() * (obj.upperBound - obj.lowerBound);

                case Variable.TYPE_INTEGER
                    % 在[lower, upper]范围内随机整数
                    value = randi([obj.lowerBound, obj.upperBound]);

                case {Variable.TYPE_DISCRETE, Variable.TYPE_CATEGORICAL}
                    % 随机选择一个值
                    idx = randi(length(obj.values));
                    value = obj.values{idx};

                otherwise
                    error('Variable:UnsupportedType', '不支持的变量类型');
            end
        end

        function s = toStruct(obj)
            % toStruct 将变量对象转换为结构体
            %
            % 输出:
            %   s - 包含变量信息的结构体
            %
            % 示例:
            %   structData = variable.toStruct();

            s = struct();
            s.name = obj.name;
            s.type = obj.type;
            s.description = obj.description;

            switch obj.type
                case {Variable.TYPE_CONTINUOUS, Variable.TYPE_INTEGER}
                    s.lowerBound = obj.lowerBound;
                    s.upperBound = obj.upperBound;

                case {Variable.TYPE_DISCRETE, Variable.TYPE_CATEGORICAL}
                    s.values = obj.values;
            end
        end

        function str = toString(obj)
            % toString 返回变量的字符串表示
            %
            % 输出:
            %   str - 字符串表示
            %
            % 示例:
            %   disp(variable.toString());

            switch obj.type
                case {Variable.TYPE_CONTINUOUS, Variable.TYPE_INTEGER}
                    str = sprintf('Variable ''%s'' (%s): [%g, %g]', ...
                                  obj.name, obj.type, obj.lowerBound, obj.upperBound);

                case {Variable.TYPE_DISCRETE, Variable.TYPE_CATEGORICAL}
                    if length(obj.values) <= 5
                        valueStr = strjoin(cellfun(@(x) obj.valueToString(x), ...
                                          obj.values, 'UniformOutput', false), ', ');
                    else
                        valueStr = sprintf('%d values', length(obj.values));
                    end
                    str = sprintf('Variable ''%s'' (%s): {%s}', ...
                                  obj.name, obj.type, valueStr);
            end

            if ~isempty(obj.description)
                str = sprintf('%s - %s', str, obj.description);
            end
        end

        function n = getDimension(~)
            % getDimension 获取变量维度（单个变量始终为1）
            %
            % 输出:
            %   n - 维度（总是1）
            %
            % 示例:
            %   dim = variable.getDimension();

            n = 1;
        end

        function bounds = getBounds(obj)
            % getBounds 获取变量边界
            %
            % 输出:
            %   bounds - [lower, upper] 或 空数组（离散/分类变量）
            %
            % 示例:
            %   [lb, ub] = variable.getBounds();

            if strcmp(obj.type, Variable.TYPE_CONTINUOUS) || ...
               strcmp(obj.type, Variable.TYPE_INTEGER)
                bounds = [obj.lowerBound, obj.upperBound];
            else
                bounds = [];
            end
        end

        function tf = isInteger(obj)
            % isInteger 判断是否为整数变量
            %
            % 输出:
            %   tf - 布尔值
            %
            % 示例:
            %   if variable.isInteger()

            tf = strcmp(obj.type, Variable.TYPE_INTEGER);
        end

        function tf = isContinuous(obj)
            % isContinuous 判断是否为连续变量
            %
            % 输出:
            %   tf - 布尔值

            tf = strcmp(obj.type, Variable.TYPE_CONTINUOUS);
        end

        function tf = isDiscrete(obj)
            % isDiscrete 判断是否为离散变量
            %
            % 输出:
            %   tf - 布尔值

            tf = strcmp(obj.type, Variable.TYPE_DISCRETE);
        end

        function tf = isCategorical(obj)
            % isCategorical 判断是否为分类变量
            %
            % 输出:
            %   tf - 布尔值

            tf = strcmp(obj.type, Variable.TYPE_CATEGORICAL);
        end
    end

    methods (Access = private)
        function idx = findValueIndex(obj, value)
            % findValueIndex 在离散/分类变量中查找值的索引
            %
            % 输入:
            %   value - 要查找的值
            %
            % 输出:
            %   idx - 索引位置（1-based）

            idx = -1;
            for i = 1:length(obj.values)
                if isequal(value, obj.values{i})
                    idx = i;
                    break;
                end
            end

            if idx == -1
                error('Variable:ValueNotFound', '值未在变量的值集合中找到');
            end
        end

        function str = valueToString(~, value)
            % valueToString 将值转换为字符串
            %
            % 输入:
            %   value - 任意值
            %
            % 输出:
            %   str - 字符串表示

            if isnumeric(value)
                str = num2str(value);
            elseif ischar(value) || isstring(value)
                str = char(value);
            else
                str = '?';
            end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            % fromStruct 从结构体创建Variable对象
            %
            % 输入:
            %   s - 结构体（通常来自toStruct()）
            %
            % 输出:
            %   obj - Variable对象
            %
            % 示例:
            %   variable = Variable.fromStruct(structData);

            if isfield(s, 'lowerBound') && isfield(s, 'upperBound')
                bounds = [s.lowerBound, s.upperBound];
            elseif isfield(s, 'values')
                bounds = s.values;
            else
                error('Variable:InvalidStruct', '结构体缺少边界或值信息');
            end

            if isfield(s, 'description')
                obj = Variable(s.name, s.type, bounds, 'Description', s.description);
            else
                obj = Variable(s.name, s.type, bounds);
            end
        end
    end
end
