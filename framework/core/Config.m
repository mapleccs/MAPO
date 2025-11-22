classdef Config < handle
    % Config 配置系统
    % 支持JSON配置文件加载和动态配置管理
    %
    % 功能:
    %   - 从JSON文件加载配置
    %   - 支持嵌套键访问 (如 'problem.variables')
    %   - 配置值获取和设置
    %   - 默认值机制
    %   - 配置验证
    %   - 配置合并
    %
    % 示例:
    %   % 从文件加载配置
    %   config = Config('config.json');
    %
    %   % 获取配置值
    %   name = config.get('problem.name', 'DefaultName');
    %
    %   % 设置配置值
    %   config.set('algorithm.populationSize', 100);
    %
    %   % 合并其他配置
    %   otherConfig = Config('other.json');
    %   config.merge(otherConfig);


    properties (Access = private)
        configData;  % 配置数据结构体
    end

    methods
        function obj = Config(filename)
            % Config 构造函数
            %
            % 输入:
            %   filename - (可选) JSON配置文件路径
            %
            % 输出:
            %   obj - Config对象实例
            %
            % 示例:
            %   config = Config();              % 创建空配置
            %   config = Config('config.json'); % 从文件加载

            if nargin > 0 && ~isempty(filename)
                obj.loadFromFile(filename);
            else
                obj.configData = struct();
            end
        end

        function loadFromFile(obj, filename)
            % loadFromFile 从JSON文件加载配置
            %
            % 输入:
            %   filename - JSON配置文件路径
            %
            % 抛出:
            %   错误 - 如果文件不存在或JSON格式无效
            %
            % 示例:
            %   config.loadFromFile('config.json');

            if ~exist(filename, 'file')
                error('Config:FileNotFound', '配置文件不存在: %s', filename);
            end

            try
                % 读取文件内容
                fid = fopen(filename, 'r', 'n', 'UTF-8');
                if fid == -1
                    error('Config:FileReadError', '无法打开配置文件: %s', filename);
                end

                jsonText = fread(fid, '*char')';
                fclose(fid);

                % 解析JSON
                obj.configData = jsondecode(jsonText);

            catch ME
                if exist('fid', 'var') && fid ~= -1
                    fclose(fid);
                end
                error('Config:ParseError', '解析JSON文件失败: %s\n原因: %s', ...
                      filename, ME.message);
            end
        end

        function value = get(obj, key, defaultValue)
            % get 获取配置值
            %
            % 输入:
            %   key - 配置键，支持嵌套访问 (如 'problem.name')
            %   defaultValue - (可选) 默认值，键不存在时返回
            %
            % 输出:
            %   value - 配置值
            %
            % 示例:
            %   name = config.get('problem.name');
            %   size = config.get('algorithm.populationSize', 50);
            %   vars = config.get('problem.variables');

            if nargin < 3
                defaultValue = [];
            end

            try
                value = obj.getNestedValue(obj.configData, key);
            catch
                value = defaultValue;
            end
        end

        function set(obj, key, value)
            % set 设置配置值
            %
            % 输入:
            %   key - 配置键，支持嵌套访问 (如 'problem.name')
            %   value - 要设置的值
            %
            % 示例:
            %   config.set('problem.name', 'MyProblem');
            %   config.set('algorithm.populationSize', 100);

            obj.configData = obj.setNestedValue(obj.configData, key, value);
        end

        function isValid = validate(obj, requiredKeys)
            % validate 验证配置是否包含必需的键
            %
            % 输入:
            %   requiredKeys - (可选) 必需键的cell数组
            %
            % 输出:
            %   isValid - 配置是否有效
            %
            % 示例:
            %   isValid = config.validate();
            %   isValid = config.validate({'problem.name', 'algorithm.type'});

            if nargin < 2 || isempty(requiredKeys)
                % 基本验证：检查是否为空
                isValid = ~isempty(fieldnames(obj.configData));
                return;
            end

            isValid = true;
            for i = 1:length(requiredKeys)
                key = requiredKeys{i};
                try
                    value = obj.getNestedValue(obj.configData, key);
                    if isempty(value)
                        isValid = false;
                        warning('Config:MissingKey', '必需的配置键为空: %s', key);
                    end
                catch
                    isValid = false;
                    warning('Config:MissingKey', '缺少必需的配置键: %s', key);
                end
            end
        end

        function merge(obj, otherConfig)
            % merge 合并另一个配置对象
            %
            % 输入:
            %   otherConfig - 另一个Config对象或结构体
            %
            % 说明:
            %   otherConfig中的值会覆盖当前配置中的同名键
            %
            % 示例:
            %   config1.merge(config2);
            %   config.merge(struct('problem', struct('name', 'NewName')));

            if isa(otherConfig, 'Config')
                otherData = otherConfig.configData;
            elseif isstruct(otherConfig)
                otherData = otherConfig;
            else
                error('Config:InvalidInput', ...
                      'merge方法需要Config对象或结构体作为输入');
            end

            obj.configData = obj.mergeStructs(obj.configData, otherData);
        end

        function data = toStruct(obj)
            % toStruct 将配置转换为结构体
            %
            % 输出:
            %   data - 配置数据的结构体副本
            %
            % 示例:
            %   structData = config.toStruct();

            data = obj.configData;
        end

        function saveToFile(obj, filename)
            % saveToFile 将配置保存到JSON文件
            %
            % 输入:
            %   filename - 目标JSON文件路径
            %
            % 示例:
            %   config.saveToFile('output_config.json');

            try
                jsonText = jsonencode(obj.configData);

                % 格式化JSON (美化输出)
                jsonText = obj.prettifyJson(jsonText);

                fid = fopen(filename, 'w', 'n', 'UTF-8');
                if fid == -1
                    error('Config:FileWriteError', '无法创建文件: %s', filename);
                end

                fprintf(fid, '%s', jsonText);
                fclose(fid);

            catch ME
                if exist('fid', 'var') && fid ~= -1
                    fclose(fid);
                end
                error('Config:SaveError', '保存配置文件失败: %s\n原因: %s', ...
                      filename, ME.message);
            end
        end

        function keys = getAllKeys(obj)
            % getAllKeys 获取所有配置键的列表
            %
            % 输出:
            %   keys - 所有键的cell数组 (包括嵌套键)
            %
            % 示例:
            %   allKeys = config.getAllKeys();

            keys = obj.extractKeys(obj.configData, '');
        end
    end

    methods (Access = private)
        function value = getNestedValue(~, data, key)
            % getNestedValue 从嵌套结构体中获取值
            %
            % 输入:
            %   data - 结构体数据
            %   key - 键路径 (如 'problem.variables')
            %
            % 输出:
            %   value - 对应的值

            keys = strsplit(key, '.');
            value = data;

            for i = 1:length(keys)
                if isstruct(value) && isfield(value, keys{i})
                    value = value.(keys{i});
                else
                    error('Config:KeyNotFound', '配置键不存在: %s', key);
                end
            end
        end

        function data = setNestedValue(obj, data, key, value)
            % setNestedValue 在嵌套结构体中设置值
            %
            % 输入:
            %   data - 结构体数据
            %   key - 键路径 (如 'problem.name')
            %   value - 要设置的值
            %
            % 输出:
            %   data - 更新后的结构体

            keys = strsplit(key, '.');

            if length(keys) == 1
                data.(keys{1}) = value;
            else
                if ~isstruct(data) || ~isfield(data, keys{1})
                    data.(keys{1}) = struct();
                end
                remainingKey = strjoin(keys(2:end), '.');
                data.(keys{1}) = obj.setNestedValue(data.(keys{1}), remainingKey, value);
            end
        end

        function result = mergeStructs(obj, struct1, struct2)
            % mergeStructs 递归合并两个结构体
            %
            % 输入:
            %   struct1 - 基础结构体
            %   struct2 - 要合并的结构体 (优先级更高)
            %
            % 输出:
            %   result - 合并后的结构体

            result = struct1;

            if ~isstruct(struct2)
                result = struct2;
                return;
            end

            fields = fieldnames(struct2);
            for i = 1:length(fields)
                field = fields{i};

                if isfield(result, field) && isstruct(result.(field)) && isstruct(struct2.(field))
                    % 递归合并嵌套结构体
                    result.(field) = obj.mergeStructs(result.(field), struct2.(field));
                else
                    % 直接覆盖
                    result.(field) = struct2.(field);
                end
            end
        end

        function keys = extractKeys(obj, data, prefix)
            % extractKeys 递归提取所有键
            %
            % 输入:
            %   data - 结构体数据
            %   prefix - 键前缀
            %
            % 输出:
            %   keys - 键列表

            keys = {};

            if ~isstruct(data)
                return;
            end

            fields = fieldnames(data);
            for i = 1:length(fields)
                field = fields{i};

                if isempty(prefix)
                    fullKey = field;
                else
                    fullKey = [prefix '.' field];
                end

                keys{end+1} = fullKey; %#ok<AGROW>

                if isstruct(data.(field))
                    subKeys = obj.extractKeys(data.(field), fullKey);
                    keys = [keys subKeys]; %#ok<AGROW>
                end
            end
        end

        function jsonText = prettifyJson(~, jsonText)
            % prettifyJson 美化JSON文本 (添加缩进和换行)
            %
            % 输入:
            %   jsonText - 压缩的JSON字符串
            %
            % 输出:
            %   jsonText - 格式化的JSON字符串

            % 简单的JSON美化 (MATLAB R2016b+)
            jsonText = strrep(jsonText, ',', sprintf(',\n  '));
            jsonText = strrep(jsonText, '{', sprintf('{\n  '));
            jsonText = strrep(jsonText, '}', sprintf('\n}'));
            jsonText = strrep(jsonText, '[', sprintf('[\n  '));
            jsonText = strrep(jsonText, ']', sprintf('\n]'));
        end
    end
end
