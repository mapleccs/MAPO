classdef Objective < handle
    % Objective 目标函数类
    % 定义优化问题的目标函数
    %
    % 功能:
    %   - 目标函数定义（最小化/最大化）
    %   - 权重设置（多目标优化）
    %   - 序列化支持
    %
    % 示例:
    %   % 创建最小化目标
    %   obj1 = Objective('cost', 'minimize', 'Description', '总成本');
    %
    %   % 创建最大化目标
    %   obj2 = Objective('efficiency', 'maximize', 'Weight', 2.0);
    %
    %   % 检查类型
    %   if obj1.isMinimize()
    %       fprintf('最小化目标\n');
    %   end


    properties (Constant)
        TYPE_MINIMIZE = 'minimize';  % 最小化
        TYPE_MAXIMIZE = 'maximize';  % 最大化
    end

    properties
        name;         % 目标函数名称
        type;         % 目标类型 ('minimize' 或 'maximize')
        description;  % 目标描述
        weight;       % 权重（用于加权多目标优化，默认为1.0）
    end

    methods
        function obj = Objective(name, type, varargin)
            % Objective 构造函数
            %
            % 输入:
            %   name - 目标函数名称
            %   type - 目标类型 ('minimize' 或 'maximize')
            %   varargin - 可选参数
            %              'Description', desc - 目标描述
            %              'Weight', w - 权重（默认1.0）
            %
            % 示例:
            %   obj = Objective('cost', 'minimize');
            %   obj = Objective('profit', 'maximize', 'Description', '年利润', 'Weight', 2.0);

            if nargin < 2
                error('Objective:InsufficientArgs', '需要至少2个参数: name, type');
            end

            % 设置基本属性
            obj.name = name;
            obj.type = lower(type);
            obj.description = '';
            obj.weight = 1.0;

            % 验证类型
            if ~strcmp(obj.type, Objective.TYPE_MINIMIZE) && ...
               ~strcmp(obj.type, Objective.TYPE_MAXIMIZE)
                error('Objective:InvalidType', ...
                      '无效的目标类型: %s。支持的类型: minimize, maximize', type);
            end

            % 解析可选参数
            p = inputParser;
            addParameter(p, 'Description', '', @ischar);
            addParameter(p, 'Weight', 1.0, @isnumeric);
            parse(p, varargin{:});

            obj.description = p.Results.Description;
            obj.weight = p.Results.Weight;

            % 验证权重
            if obj.weight <= 0
                error('Objective:InvalidWeight', '权重必须为正数');
            end
        end

        function tf = isMinimize(obj)
            % isMinimize 判断是否为最小化目标
            %
            % 输出:
            %   tf - 布尔值
            %
            % 示例:
            %   if objective.isMinimize()

            tf = strcmp(obj.type, Objective.TYPE_MINIMIZE);
        end

        function tf = isMaximize(obj)
            % isMaximize 判断是否为最大化目标
            %
            % 输出:
            %   tf - 布尔值
            %
            % 示例:
            %   if objective.isMaximize()

            tf = strcmp(obj.type, Objective.TYPE_MAXIMIZE);
        end

        function setWeight(obj, weight)
            % setWeight 设置目标权重
            %
            % 输入:
            %   weight - 权重值（必须为正数）
            %
            % 示例:
            %   objective.setWeight(2.0);

            if weight <= 0
                error('Objective:InvalidWeight', '权重必须为正数');
            end
            obj.weight = weight;
        end

        function normalizedValue = normalize(obj, value)
            % normalize 归一化目标值（将最大化转换为最小化）
            %
            % 输入:
            %   value - 原始目标值
            %
            % 输出:
            %   normalizedValue - 归一化后的值
            %                     最小化: 保持不变
            %                     最大化: 取负值
            %
            % 说明:
            %   将最大化问题转换为最小化问题，便于统一处理
            %
            % 示例:
            %   normalized = objective.normalize(100);

            if obj.isMaximize()
                normalizedValue = -value;
            else
                normalizedValue = value;
            end
        end

        function s = toStruct(obj)
            % toStruct 将目标对象转换为结构体
            %
            % 输出:
            %   s - 包含目标信息的结构体
            %
            % 示例:
            %   structData = objective.toStruct();

            s = struct();
            s.name = obj.name;
            s.type = obj.type;
            s.description = obj.description;
            s.weight = obj.weight;
        end

        function str = toString(obj)
            % toString 返回目标的字符串表示
            %
            % 输出:
            %   str - 字符串表示
            %
            % 示例:
            %   disp(objective.toString());

            str = sprintf('Objective ''%s'' (%s)', obj.name, obj.type);

            if obj.weight ~= 1.0
                str = sprintf('%s, weight=%.2f', str, obj.weight);
            end

            if ~isempty(obj.description)
                str = sprintf('%s - %s', str, obj.description);
            end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            % fromStruct 从结构体创建Objective对象
            %
            % 输入:
            %   s - 结构体（通常来自toStruct()）
            %
            % 输出:
            %   obj - Objective对象
            %
            % 示例:
            %   objective = Objective.fromStruct(structData);

            if ~isfield(s, 'name') || ~isfield(s, 'type')
                error('Objective:InvalidStruct', '结构体缺少必要字段');
            end

            % 构建可选参数
            args = {};
            if isfield(s, 'description') && ~isempty(s.description)
                args = [args, {'Description', s.description}];
            end
            if isfield(s, 'weight')
                args = [args, {'Weight', s.weight}];
            end

            obj = Objective(s.name, s.type, args{:});
        end
    end
end
