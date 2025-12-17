classdef SimulatorConfig < handle
    % SimulatorConfig 仿真器配置类
    % 管理仿真器的配置参数
    %
    % 功能:
    %   - 存储仿真器配置信息
    %   - 从文件或Config对象加载
    %   - 配置验证
    %   - 节点映射管理
    %
    % 示例:
    %   % 创建配置
    %   config = SimulatorConfig('Aspen');
    %   config.set('modelPath', 'C:/Models/distillation.bkp');
    %   config.set('timeout', 300);
    %   config.set('visible', false);
    %
    %   % 从文件加载
    %   config = SimulatorConfig.fromFile('simulator_config.json');
    %
    %   % 设置节点映射
    %   config.setNodeMapping('x1', 'B1.TEMP');
    %   config.setNodeMapping('x2', 'B2.NSTAGE');


    properties
        simulatorType;   % 仿真器类型 ('Aspen', 'MATLAB', 'Python'等)
        modelPath;       % 模型文件路径
        timeout;         % 超时时间（秒）
        visible;         % 是否显示仿真器GUI
        nodeMapping;     % 变量名到仿真器节点的映射 (containers.Map)
        resultMapping;   % 结果名到仿真器节点的映射 (containers.Map)
    end

    properties (Access = private)
        additionalConfig;  % 额外的配置参数（结构体）
        variableOrder;     % 变量名的插入顺序 (cell array)
        resultOrder;       % 结果名的插入顺序 (cell array)
    end

    methods
        function obj = SimulatorConfig(simulatorType, varargin)
            % SimulatorConfig 构造函数
            %
            % 输入:
            %   simulatorType - 仿真器类型字符串
            %   varargin - 可选参数
            %              'ModelPath', path - 模型文件路径
            %              'Timeout', t - 超时时间（秒）
            %              'Visible', v - 是否可见（布尔值）
            %
            % 示例:
            %   config = SimulatorConfig('Aspen');
            %   config = SimulatorConfig('Aspen', 'ModelPath', 'model.bkp', 'Timeout', 300);

            if nargin < 1
                obj.simulatorType = 'Generic';
            else
                obj.simulatorType = simulatorType;
            end

            % 默认配置
            obj.modelPath = '';
            obj.timeout = 300;  % 默认5分钟
            obj.visible = false;
            obj.nodeMapping = containers.Map('KeyType', 'char', 'ValueType', 'char');
            obj.resultMapping = containers.Map('KeyType', 'char', 'ValueType', 'char');
            obj.additionalConfig = struct();
            obj.variableOrder = {};
            obj.resultOrder = {};

            % 解析可选参数
            if ~isempty(varargin)
                p = inputParser;
                addParameter(p, 'ModelPath', '', @ischar);
                addParameter(p, 'Timeout', 300, @isnumeric);
                addParameter(p, 'Visible', false, @islogical);
                parse(p, varargin{:});

                obj.modelPath = p.Results.ModelPath;
                obj.timeout = p.Results.Timeout;
                obj.visible = p.Results.Visible;
            end
        end

        function value = get(obj, key, defaultValue)
            % get 获取配置值
            %
            % 输入:
            %   key - 配置键名
            %   defaultValue - (可选) 默认值
            %
            % 输出:
            %   value - 配置值
            %
            % 示例:
            %   timeout = config.get('timeout');
            %   value = config.get('customParam', 100);

            if nargin < 3
                defaultValue = [];
            end

            % 首先检查标准属性
            switch lower(key)
                case 'simulatortype'
                    value = obj.simulatorType;
                case 'modelpath'
                    value = obj.modelPath;
                case 'timeout'
                    value = obj.timeout;
                case 'visible'
                    value = obj.visible;
                otherwise
                    % 检查额外配置
                    if isfield(obj.additionalConfig, key)
                        value = obj.additionalConfig.(key);
                    else
                        value = defaultValue;
                    end
            end
        end

        function set(obj, key, value)
            % set 设置配置值
            %
            % 输入:
            %   key - 配置键名
            %   value - 配置值
            %
            % 示例:
            %   config.set('timeout', 600);
            %   config.set('customParam', 'value');

            % 首先检查标准属性
            switch lower(key)
                case 'simulatortype'
                    obj.simulatorType = value;
                case 'modelpath'
                    obj.modelPath = value;
                case 'timeout'
                    obj.timeout = value;
                case 'visible'
                    obj.visible = value;
                otherwise
                    % 存储到额外配置
                    obj.additionalConfig.(key) = value;
            end
        end

        function setNodeMapping(obj, variableName, nodePath)
            % setNodeMapping 设置变量到节点的映射
            %
            % 输入:
            %   variableName - 变量名称
            %   nodePath - 仿真器节点路径
            %
            % 示例:
            %   config.setNodeMapping('temperature', 'B1.TEMP');
            %   config.setNodeMapping('stages', 'B2.NSTAGE');

            nodePath = SimulatorConfig.ensureChar(nodePath);
            if strcmpi(obj.simulatorType, 'Aspen')
                nodePath = SimulatorConfig.normalizeAspenNodePath(nodePath);
            end
            obj.nodeMapping(variableName) = nodePath;

            % 记录插入顺序（如果是新变量）
            if ~ismember(variableName, obj.variableOrder)
                obj.variableOrder{end+1} = variableName;
            end
        end

        function nodePath = getNodePath(obj, variableName)
            % getNodePath 获取变量对应的节点路径
            %
            % 输入:
            %   variableName - 变量名称
            %
            % 输出:
            %   nodePath - 节点路径
            %
            % 示例:
            %   path = config.getNodePath('temperature');

            if obj.nodeMapping.isKey(variableName)
                nodePath = obj.nodeMapping(variableName);
            else
                error('SimulatorConfig:NodeNotFound', ...
                      '变量 ''%s'' 没有对应的节点映射', variableName);
            end
        end

        function tf = hasNodeMapping(obj, variableName)
            % hasNodeMapping 检查是否存在节点映射
            %
            % 输入:
            %   variableName - 变量名称
            %
            % 输出:
            %   tf - 布尔值
            %
            % 示例:
            %   if config.hasNodeMapping('temperature')

            tf = obj.nodeMapping.isKey(variableName);
        end

        function clearNodeMapping(obj)
            % clearNodeMapping 清空所有节点映射
            %
            % 示例:
            %   config.clearNodeMapping();

            obj.nodeMapping = containers.Map('KeyType', 'char', 'ValueType', 'char');
            obj.variableOrder = {};
        end

        function names = getVariableNames(obj)
            % getVariableNames 获取所有已映射的变量名称（按插入顺序）
            %
            % 输出:
            %   names - 变量名称的cell array（保持插入顺序）
            %
            % 示例:
            %   varNames = config.getVariableNames();

            % 返回按插入顺序的变量名
            names = obj.variableOrder;
        end

        function setResultMapping(obj, resultName, nodePath)
            % setResultMapping 设置结果到节点的映射
            %
            % 输入:
            %   resultName - 结果名称
            %   nodePath - 仿真器节点路径
            %
            % 示例:
            %   config.setResultMapping('conversion', 'R1.CONV');
            %   config.setResultMapping('ADN_FRAC', '\\Data\\Streams\\0320\\Output\\MASSFRAC\\MIXED\\ADN');

            nodePath = SimulatorConfig.ensureChar(nodePath);
            if strcmpi(obj.simulatorType, 'Aspen')
                nodePath = SimulatorConfig.normalizeAspenNodePath(nodePath);
            end
            obj.resultMapping(resultName) = nodePath;

            % 记录插入顺序（如果是新结果）
            if ~ismember(resultName, obj.resultOrder)
                obj.resultOrder{end+1} = resultName;
            end
        end

        function nodePath = getResultPath(obj, resultName)
            % getResultPath 获取结果对应的节点路径
            %
            % 输入:
            %   resultName - 结果名称
            %
            % 输出:
            %   nodePath - 节点路径
            %
            % 示例:
            %   path = config.getResultPath('conversion');

            if obj.resultMapping.isKey(resultName)
                nodePath = obj.resultMapping(resultName);
            else
                error('SimulatorConfig:ResultNotFound', ...
                      '结果 ''%s'' 没有对应的节点映射', resultName);
            end
        end

        function tf = hasResultMapping(obj, resultName)
            % hasResultMapping 检查是否存在结果映射
            %
            % 输入:
            %   resultName - 结果名称
            %
            % 输出:
            %   tf - 布尔值
            %
            % 示例:
            %   if config.hasResultMapping('conversion')

            tf = obj.resultMapping.isKey(resultName);
        end

        function clearResultMapping(obj)
            % clearResultMapping 清空所有结果映射
            %
            % 示例:
            %   config.clearResultMapping();

            obj.resultMapping = containers.Map('KeyType', 'char', 'ValueType', 'char');
            obj.resultOrder = {};
        end

        function names = getResultNames(obj)
            % getResultNames 获取所有已映射的结果名称（按插入顺序）
            %
            % 输出:
            %   names - 结果名称的cell array（保持插入顺序）
            %
            % 示例:
            %   resultNames = config.getResultNames();

            % 返回按插入顺序的结果名
            names = obj.resultOrder;
        end

        function loadFromFile(obj, filename)
            % loadFromFile 从JSON文件加载配置
            %
            % 输入:
            %   filename - JSON配置文件路径
            %
            % 示例:
            %   config.loadFromFile('simulator_config.json');

            if ~exist(filename, 'file')
                error('SimulatorConfig:FileNotFound', '配置文件不存在: %s', filename);
            end

            % 使用Config类加载
            cfg = Config(filename);
            obj.loadFromConfig(cfg);
        end

        function loadFromConfig(obj, config)
            % loadFromConfig 从Config对象加载配置
            %
            % 输入:
            %   config - Config对象或结构体
            %
            % 示例:
            %   globalConfig = Config('config.json');
            %   simulatorConfig.loadFromConfig(globalConfig);

            % 转换为结构体
            if isa(config, 'Config')
                configData = config.toStruct();
            elseif isstruct(config)
                configData = config;
            else
                error('SimulatorConfig:InvalidInput', '输入必须是Config对象或结构体');
            end

            % 获取simulator配置
            if isfield(configData, 'simulator')
                simConfig = configData.simulator;
            else
                error('SimulatorConfig:MissingField', '配置中缺少simulator字段');
            end

            % 加载基本配置
            if isfield(simConfig, 'type')
                obj.simulatorType = simConfig.type;
            end

            if isfield(simConfig, 'config')
                simDetails = simConfig.config;

                if isfield(simDetails, 'backupPath')
                    obj.modelPath = simDetails.backupPath;
                elseif isfield(simDetails, 'modelPath')
                    obj.modelPath = simDetails.modelPath;
                end

                if isfield(simDetails, 'timeout')
                    obj.timeout = simDetails.timeout;
                end

                if isfield(simDetails, 'visible')
                    obj.visible = simDetails.visible;
                end

                % 加载节点映射
                if isfield(simDetails, 'nodeMapping')
                    obj.clearNodeMapping();
                    mapping = simDetails.nodeMapping;
                    varNames = fieldnames(mapping);
                    for i = 1:length(varNames)
                        varName = varNames{i};
                        nodePath = mapping.(varName);
                        obj.setNodeMapping(varName, nodePath);
                    end
                end

                % 加载结果映射
                if isfield(simDetails, 'resultMapping')
                    obj.clearResultMapping();
                    mapping = simDetails.resultMapping;
                    resultNames = fieldnames(mapping);
                    for i = 1:length(resultNames)
                        resultName = resultNames{i};
                        nodePath = mapping.(resultName);
                        obj.setResultMapping(resultName, nodePath);
                    end
                end

                % 加载其他额外配置
                excludeFields = {'backupPath', 'modelPath', 'timeout', 'visible', 'nodeMapping', 'resultMapping'};
                allFields = fieldnames(simDetails);
                for i = 1:length(allFields)
                    field = allFields{i};
                    if ~ismember(field, excludeFields)
                        obj.additionalConfig.(field) = simDetails.(field);
                    end
                end
            end
        end

        function tf = validate(obj)
            % validate 验证配置的有效性
            %
            % 输出:
            %   tf - 布尔值，配置是否有效
            %
            % 示例:
            %   if config.validate()

            tf = true;

            % 检查仿真器类型
            if isempty(obj.simulatorType)
                warning('SimulatorConfig:MissingType', '缺少仿真器类型');
                tf = false;
            end

            % 检查超时时间
            if obj.timeout <= 0
                warning('SimulatorConfig:InvalidTimeout', '超时时间必须为正数');
                tf = false;
            end

            % 对于某些仿真器类型，检查模型路径
            if strcmp(obj.simulatorType, 'Aspen') || strcmp(obj.simulatorType, 'HYSYS')
                if isempty(obj.modelPath)
                    warning('SimulatorConfig:MissingModelPath', '缺少模型文件路径');
                    tf = false;
                elseif ~exist(obj.modelPath, 'file')
                    warning('SimulatorConfig:ModelFileNotFound', '模型文件不存在: %s', obj.modelPath);
                    tf = false;
                end
            end
        end

        function s = toStruct(obj)
            % toStruct 将配置转换为结构体
            %
            % 输出:
            %   s - 配置结构体
            %
            % 示例:
            %   structData = config.toStruct();

            s = struct();
            s.simulatorType = obj.simulatorType;
            s.modelPath = obj.modelPath;
            s.timeout = obj.timeout;
            s.visible = obj.visible;

            % 转换节点映射
            if ~isempty(obj.nodeMapping)
                varNames = keys(obj.nodeMapping);
                s.nodeMapping = struct();
                for i = 1:length(varNames)
                    varName = varNames{i};
                    s.nodeMapping.(varName) = obj.nodeMapping(varName);
                end
            else
                s.nodeMapping = struct();
            end

            % 转换结果映射
            if ~isempty(obj.resultMapping)
                resultNames = keys(obj.resultMapping);
                s.resultMapping = struct();
                for i = 1:length(resultNames)
                    resultName = resultNames{i};
                    s.resultMapping.(resultName) = obj.resultMapping(resultName);
                end
            else
                s.resultMapping = struct();
            end

            % 包含额外配置
            extraFields = fieldnames(obj.additionalConfig);
            for i = 1:length(extraFields)
                field = extraFields{i};
                s.(field) = obj.additionalConfig.(field);
            end
        end

        function display(obj)
            % display 显示配置信息
            %
            % 示例:
            %   config.display();

            fprintf('========================================\n');
            fprintf('Simulator Configuration\n');
            fprintf('========================================\n');
            fprintf('Type:       %s\n', obj.simulatorType);
            fprintf('Model Path: %s\n', obj.modelPath);
            fprintf('Timeout:    %d seconds\n', obj.timeout);
            fprintf('Visible:    %s\n', mat2str(obj.visible));
            fprintf('\n');

            fprintf('Node Mapping (%d):\n', obj.nodeMapping.Count);
            if ~isempty(obj.nodeMapping)
                varNames = keys(obj.nodeMapping);
                for i = 1:length(varNames)
                    varName = varNames{i};
                    nodePath = obj.nodeMapping(varName);
                    fprintf('  %s -> %s\n', varName, nodePath);
                end
            else
                fprintf('  None\n');
            end
            fprintf('\n');

            fprintf('Result Mapping (%d):\n', obj.resultMapping.Count);
            if ~isempty(obj.resultMapping)
                resultNames = keys(obj.resultMapping);
                for i = 1:length(resultNames)
                    resultName = resultNames{i};
                    nodePath = obj.resultMapping(resultName);
                    fprintf('  %s -> %s\n', resultName, nodePath);
                end
            else
                fprintf('  None\n');
            end
            fprintf('========================================\n');
        end
    end

    methods (Static)
        function obj = fromFile(filename)
            % fromFile 从文件创建SimulatorConfig对象
            %
            % 输入:
            %   filename - JSON配置文件路径
            %
            % 输出:
            %   obj - SimulatorConfig对象
            %
            % 示例:
            %   config = SimulatorConfig.fromFile('config.json');

            obj = SimulatorConfig('Generic');
            obj.loadFromFile(filename);
        end

        function obj = fromConfig(config)
            % fromConfig 从Config对象创建SimulatorConfig对象
            %
            % 输入:
            %   config - Config对象
            %
            % 输出:
            %   obj - SimulatorConfig对象
            %
            % 示例:
            %   globalConfig = Config('config.json');
            %   simConfig = SimulatorConfig.fromConfig(globalConfig);

            obj = SimulatorConfig('Generic');
            obj.loadFromConfig(config);
        end
    end

    methods (Static, Access = private)
        function s = ensureChar(value)
            if ischar(value)
                s = value;
                return;
            end
            if isstring(value) && isscalar(value)
                s = char(value);
                return;
            end
            try
                s = char(string(value));
            catch
                s = '';
            end
        end

        function nodePath = normalizeAspenNodePath(nodePath)
            nodePath = strtrim(nodePath);
            if isempty(nodePath)
                return;
            end

            % Aspen Tree 路径使用反斜杠
            nodePath = strrep(nodePath, '/', '\');

            % 处理用户从 JSON 复制导致的双反斜杠
            while contains(nodePath, '\\')
                nodePath = strrep(nodePath, '\\', '\');
            end

            % 如果用户遗漏了开头的反斜杠，补上
            if startsWith(nodePath, 'Data\')
                nodePath = ['\' nodePath];
            end
        end
    end
end
