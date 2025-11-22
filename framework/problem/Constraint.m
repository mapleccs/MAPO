classdef Constraint < handle
    % Constraint 约束条件类
    % 定义优化问题的约束条件
    %
    % 功能:
    %   - 等式约束和不等式约束
    %   - 约束验证和违反度计算
    %   - 支持双边界约束
    %   - 序列化支持
    %
    % 示例:
    %   % 不等式约束: g(x) <= 0
    %   c1 = Constraint('c1', 'inequality', 'UpperBound', 0);
    %
    %   % 等式约束: h(x) = 0
    %   c2 = Constraint('c2', 'equality', 'Target', 0);
    %
    %   % 双边界约束: -5 <= g(x) <= 10
    %   c3 = Constraint('c3', 'inequality', 'LowerBound', -5, 'UpperBound', 10);
    %
    %   % 验证约束
    %   isSatisfied = c1.validate(value);
    %   viol = c1.violation(value);


    properties (Constant)
        TYPE_INEQUALITY = 'inequality';  % 不等式约束
        TYPE_EQUALITY = 'equality';      % 等式约束
    end

    properties
        name;         % 约束名称
        type;         % 约束类型 ('inequality' 或 'equality')
        lowerBound;   % 下界（不等式约束）
        upperBound;   % 上界（不等式约束）
        target;       % 目标值（等式约束）
        tolerance;    % 等式约束的容差（默认1e-6）
        description;  % 约束描述
    end

    methods
        function obj = Constraint(name, type, varargin)
            % Constraint 构造函数
            %
            % 输入:
            %   name - 约束名称
            %   type - 约束类型 ('inequality' 或 'equality')
            %   varargin - 可选参数
            %              'LowerBound', lb - 下界（不等式）
            %              'UpperBound', ub - 上界（不等式）
            %              'Target', t - 目标值（等式，默认0）
            %              'Tolerance', tol - 等式约束容差（默认1e-6）
            %              'Description', desc - 约束描述
            %
            % 示例:
            %   % g(x) <= 0
            %   c1 = Constraint('c1', 'inequality', 'UpperBound', 0);
            %
            %   % h(x) = 5
            %   c2 = Constraint('c2', 'equality', 'Target', 5);
            %
            %   % -10 <= g(x) <= 10
            %   c3 = Constraint('c3', 'inequality', 'LowerBound', -10, 'UpperBound', 10);

            if nargin < 2
                error('Constraint:InsufficientArgs', '需要至少2个参数: name, type');
            end

            % 设置基本属性
            obj.name = name;
            obj.type = lower(type);
            obj.description = '';
            obj.lowerBound = -inf;
            obj.upperBound = inf;
            obj.target = 0;
            obj.tolerance = 1e-6;

            % 验证类型
            if ~strcmp(obj.type, Constraint.TYPE_INEQUALITY) && ...
               ~strcmp(obj.type, Constraint.TYPE_EQUALITY)
                error('Constraint:InvalidType', ...
                      '无效的约束类型: %s。支持的类型: inequality, equality', type);
            end

            % 解析可选参数
            p = inputParser;
            addParameter(p, 'LowerBound', -inf, @isnumeric);
            addParameter(p, 'UpperBound', inf, @isnumeric);
            addParameter(p, 'Target', 0, @isnumeric);
            addParameter(p, 'Tolerance', 1e-6, @isnumeric);
            addParameter(p, 'Description', '', @ischar);
            parse(p, varargin{:});

            obj.lowerBound = p.Results.LowerBound;
            obj.upperBound = p.Results.UpperBound;
            obj.target = p.Results.Target;
            obj.tolerance = p.Results.Tolerance;
            obj.description = p.Results.Description;

            % 验证边界
            if obj.lowerBound > obj.upperBound
                error('Constraint:InvalidBounds', '下界必须小于或等于上界');
            end

            % 验证容差
            if obj.tolerance <= 0
                error('Constraint:InvalidTolerance', '容差必须为正数');
            end
        end

        function tf = validate(obj, value)
            % validate 验证约束是否满足
            %
            % 输入:
            %   value - 约束函数值
            %
            % 输出:
            %   tf - 布尔值，true表示满足约束
            %
            % 示例:
            %   isSatisfied = constraint.validate(5.0);

            if obj.isEquality()
                % 等式约束: |value - target| <= tolerance
                tf = abs(value - obj.target) <= obj.tolerance;
            else
                % 不等式约束: lowerBound <= value <= upperBound
                tf = (value >= obj.lowerBound) && (value <= obj.upperBound);
            end
        end

        function viol = violation(obj, value)
            % violation 计算约束违反度
            %
            % 输入:
            %   value - 约束函数值
            %
            % 输出:
            %   viol - 违反度（非负值，0表示满足约束）
            %
            % 说明:
            %   - 等式约束: viol = |value - target|
            %   - 不等式约束: viol = max(0, value - upperBound, lowerBound - value)
            %
            % 示例:
            %   v = constraint.violation(15.0);

            if obj.isEquality()
                % 等式约束违反度
                viol = abs(value - obj.target);
            else
                % 不等式约束违反度
                violUpper = max(0, value - obj.upperBound);
                violLower = max(0, obj.lowerBound - value);
                viol = max(violUpper, violLower);
            end
        end

        function tf = isEquality(obj)
            % isEquality 判断是否为等式约束
            %
            % 输出:
            %   tf - 布尔值
            %
            % 示例:
            %   if constraint.isEquality()

            tf = strcmp(obj.type, Constraint.TYPE_EQUALITY);
        end

        function tf = isInequality(obj)
            % isInequality 判断是否为不等式约束
            %
            % 输出:
            %   tf - 布尔值
            %
            % 示例:
            %   if constraint.isInequality()

            tf = strcmp(obj.type, Constraint.TYPE_INEQUALITY);
        end

        function setTolerance(obj, tolerance)
            % setTolerance 设置等式约束的容差
            %
            % 输入:
            %   tolerance - 容差值（必须为正数）
            %
            % 示例:
            %   constraint.setTolerance(1e-8);

            if tolerance <= 0
                error('Constraint:InvalidTolerance', '容差必须为正数');
            end
            obj.tolerance = tolerance;
        end

        function setBounds(obj, lowerBound, upperBound)
            % setBounds 设置不等式约束的边界
            %
            % 输入:
            %   lowerBound - 下界
            %   upperBound - 上界
            %
            % 示例:
            %   constraint.setBounds(-10, 10);

            if lowerBound > upperBound
                error('Constraint:InvalidBounds', '下界必须小于或等于上界');
            end

            obj.lowerBound = lowerBound;
            obj.upperBound = upperBound;
        end

        function setTarget(obj, target)
            % setTarget 设置等式约束的目标值
            %
            % 输入:
            %   target - 目标值
            %
            % 示例:
            %   constraint.setTarget(5.0);

            obj.target = target;
        end

        function s = toStruct(obj)
            % toStruct 将约束对象转换为结构体
            %
            % 输出:
            %   s - 包含约束信息的结构体
            %
            % 示例:
            %   structData = constraint.toStruct();

            s = struct();
            s.name = obj.name;
            s.type = obj.type;
            s.description = obj.description;

            if obj.isEquality()
                s.target = obj.target;
                s.tolerance = obj.tolerance;
            else
                s.lowerBound = obj.lowerBound;
                s.upperBound = obj.upperBound;
            end
        end

        function str = toString(obj)
            % toString 返回约束的字符串表示
            %
            % 输出:
            %   str - 字符串表示
            %
            % 示例:
            %   disp(constraint.toString());

            if obj.isEquality()
                str = sprintf('Constraint ''%s'' (equality): target=%.4g, tol=%.2g', ...
                              obj.name, obj.target, obj.tolerance);
            else
                if isinf(obj.lowerBound) && isinf(obj.upperBound)
                    str = sprintf('Constraint ''%s'' (inequality): unconstrained', obj.name);
                elseif isinf(obj.lowerBound)
                    str = sprintf('Constraint ''%s'' (inequality): <= %.4g', ...
                                  obj.name, obj.upperBound);
                elseif isinf(obj.upperBound)
                    str = sprintf('Constraint ''%s'' (inequality): >= %.4g', ...
                                  obj.name, obj.lowerBound);
                else
                    str = sprintf('Constraint ''%s'' (inequality): [%.4g, %.4g]', ...
                                  obj.name, obj.lowerBound, obj.upperBound);
                end
            end

            if ~isempty(obj.description)
                str = sprintf('%s - %s', str, obj.description);
            end
        end

        function penalty = computePenalty(obj, value, penaltyFactor)
            % computePenalty 计算约束违反的惩罚值
            %
            % 输入:
            %   value - 约束函数值
            %   penaltyFactor - 惩罚因子（默认1000）
            %
            % 输出:
            %   penalty - 惩罚值
            %
            % 示例:
            %   p = constraint.computePenalty(5.0, 1000);

            if nargin < 3
                penaltyFactor = 1000;
            end

            viol = obj.violation(value);
            penalty = penaltyFactor * viol^2;
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            % fromStruct 从结构体创建Constraint对象
            %
            % 输入:
            %   s - 结构体（通常来自toStruct()）
            %
            % 输出:
            %   obj - Constraint对象
            %
            % 示例:
            %   constraint = Constraint.fromStruct(structData);

            if ~isfield(s, 'name') || ~isfield(s, 'type')
                error('Constraint:InvalidStruct', '结构体缺少必要字段');
            end

            % 构建可选参数
            args = {};

            if strcmp(lower(s.type), 'equality')
                if isfield(s, 'target')
                    args = [args, {'Target', s.target}];
                end
                if isfield(s, 'tolerance')
                    args = [args, {'Tolerance', s.tolerance}];
                end
            else
                if isfield(s, 'lowerBound')
                    args = [args, {'LowerBound', s.lowerBound}];
                end
                if isfield(s, 'upperBound')
                    args = [args, {'UpperBound', s.upperBound}];
                end
            end

            if isfield(s, 'description') && ~isempty(s.description)
                args = [args, {'Description', s.description}];
            end

            obj = Constraint(s.name, s.type, args{:});
        end

        function obj = createLessEqual(name, upperBound, varargin)
            % createLessEqual 创建 <= 类型的不等式约束
            %
            % 输入:
            %   name - 约束名称
            %   upperBound - 上界
            %   varargin - 其他可选参数
            %
            % 输出:
            %   obj - Constraint对象
            %
            % 示例:
            %   c = Constraint.createLessEqual('c1', 10);

            obj = Constraint(name, 'inequality', 'UpperBound', upperBound, varargin{:});
        end

        function obj = createGreaterEqual(name, lowerBound, varargin)
            % createGreaterEqual 创建 >= 类型的不等式约束
            %
            % 输入:
            %   name - 约束名称
            %   lowerBound - 下界
            %   varargin - 其他可选参数
            %
            % 输出:
            %   obj - Constraint对象
            %
            % 示例:
            %   c = Constraint.createGreaterEqual('c1', 5);

            obj = Constraint(name, 'inequality', 'LowerBound', lowerBound, varargin{:});
        end

        function obj = createEqual(name, target, varargin)
            % createEqual 创建 = 类型的等式约束
            %
            % 输入:
            %   name - 约束名称
            %   target - 目标值
            %   varargin - 其他可选参数
            %
            % 输出:
            %   obj - Constraint对象
            %
            % 示例:
            %   c = Constraint.createEqual('c1', 0);

            obj = Constraint(name, 'equality', 'Target', target, varargin{:});
        end
    end
end
