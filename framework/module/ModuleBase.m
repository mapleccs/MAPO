classdef (Abstract) ModuleBase < IModule
    % ModuleBase 模块基类
    % Base Class for Module Implementation
    %
    % 功能:
    %   - 实现IModule接口的通用功能
    %   - 提供配置管理辅助方法
    %   - 集成日志记录
    %   - 提供输入验证工具
    %   - 简化子类实现
    %
    % 继承示例:
    %   classdef MyModule < ModuleBase
    %       methods
    %           function obj = MyModule()
    %               % 调用父类构造函数
    %               obj@ModuleBase('MyModule', '1.0.0', '我的自定义模块');
    %
    %               % 可选：设置标签
    %               obj.tags = {'custom', 'example'};
    %
    %               % 可选：设置依赖
    %               obj.dependencies = {'ConfigModule'};
    %           end
    %
    %           function initialize(obj)
    %               obj.logInfo('初始化MyModule...');
    %               % 实现初始化逻辑
    %           end
    %
    %           function result = execute(obj, inputData)
    %               % 验证输入
    %               obj.validateInput(inputData, {'param1', 'param2'});
    %
    %               % 实现核心功能
    %               result = struct();
    %               result.output = inputData.param1 + inputData.param2;
    %           end
    %
    %           function finalize(obj)
    %               obj.logInfo('清理MyModule...');
    %               % 实现清理逻辑
    %           end
    %       end
    %   end


    properties (Access = protected)
        name;           % string, 模块名称
        version;        % string, 版本号
        description;    % string, 模块描述
        dependencies;   % cell array, 依赖列表
        tags;           % cell array, 标签列表
        author;         % string, 作者
        license;        % string, 许可证
        config;         % struct, 模块配置
        logger;         % Logger, 日志记录器
        initialized;    % logical, 是否已初始化
    end

    methods
        function obj = ModuleBase(name, version, description)
            % ModuleBase 构造函数
            %
            % 输入:
            %   name - string, 模块名称
            %   version - string, 版本号
            %   description - string, 模块描述
            %
            % 功能:
            %   - 设置模块基本信息
            %   - 初始化内部状态
            %   - 创建日志记录器

            % 参数验证
            if nargin < 3
                error('ModuleBase:InsufficientArgs', ...
                      '需要至少3个参数: name, version, description');
            end

            % 设置基本属性
            obj.name = name;
            obj.version = version;
            obj.description = description;

            % 初始化其他属性
            obj.dependencies = {};
            obj.tags = {};
            obj.author = '';
            obj.license = '';
            obj.config = struct();
            obj.initialized = false;

            % 创建日志记录器
            if exist('Logger', 'class')
                % 使用命名日志器，所有模块共享日志系统
                obj.logger = Logger.getLogger('ModuleSystem');
            else
                obj.logger = [];
            end
        end

        % ==================== IModule接口实现 ====================

        function name = getName(obj)
            % getName 获取模块名称
            name = obj.name;
        end

        function ver = getVersion(obj)
            % getVersion 获取模块版本
            ver = obj.version;
        end

        function desc = getDescription(obj)
            % getDescription 获取模块描述
            desc = obj.description;
        end

        function deps = getDependencies(obj)
            % getDependencies 获取依赖列表
            deps = obj.dependencies;
        end

        function tags = getTags(obj)
            % getTags 获取标签列表
            tags = obj.tags;
        end

        function author = getAuthor(obj)
            % getAuthor 获取作者
            author = obj.author;
        end

        function license = getLicense(obj)
            % getLicense 获取许可证
            license = obj.license;
        end

        function configure(obj, config)
            % configure 配置模块
            %
            % 输入:
            %   config - struct, 配置参数
            %
            % 功能:
            %   - 存储配置
            %   - 子类可以重写以添加自定义验证

            if ~isstruct(config)
                error('ModuleBase:InvalidConfig', '配置必须是struct类型');
            end

            obj.config = config;
            obj.logDebug('模块已配置');
        end

        function isValid = validate(obj)
            % validate 验证配置
            %
            % 输出:
            %   isValid - logical, 配置是否有效
            %
            % 功能:
            %   - 执行基本验证
            %   - 子类应该重写以添加自定义验证逻辑
            %
            % 默认实现：总是返回true

            isValid = true;
            obj.logDebug('配置验证通过（使用默认验证）');
        end

        function schema = getInputSchema(obj)
            % getInputSchema 获取输入数据架构
            %
            % 输出:
            %   schema - struct, 输入架构定义
            %
            % 默认实现：返回空架构（不限制输入）
            % 子类应该重写以定义具体的输入格式

            schema = struct();
            schema.fields = {};
        end

        function schema = getOutputSchema(obj)
            % getOutputSchema 获取输出数据架构
            %
            % 输出:
            %   schema - struct, 输出架构定义
            %
            % 默认实现：返回空架构（输出格式不固定）
            % 子类应该重写以定义具体的输出格式

            schema = struct();
            schema.fields = {};
        end

        % ==================== 辅助方法 ====================

        function validateInput(obj, inputData, requiredFields)
            % validateInput 验证输入数据
            %
            % 输入:
            %   inputData - struct, 输入数据
            %   requiredFields - cell array of strings, 必需字段列表
            %
            % 功能:
            %   - 检查输入是否为struct
            %   - 验证所有必需字段是否存在
            %   - 如果验证失败则抛出异常

            if ~isstruct(inputData)
                error('ModuleBase:InvalidInput', '输入数据必须是struct类型');
            end

            for i = 1:length(requiredFields)
                fieldName = requiredFields{i};
                if ~isfield(inputData, fieldName)
                    error('ModuleBase:MissingField', ...
                          '缺少必需字段: %s', fieldName);
                end
            end
        end

        function value = getConfigValue(obj, fieldName, defaultValue)
            % getConfigValue 获取配置值
            %
            % 输入:
            %   fieldName - string, 配置字段名
            %   defaultValue - any, 默认值（可选）
            %
            % 输出:
            %   value - any, 配置值或默认值
            %
            % 功能:
            %   - 安全地获取配置值
            %   - 如果字段不存在，返回默认值或抛出异常

            if isfield(obj.config, fieldName)
                value = obj.config.(fieldName);
            elseif nargin >= 3
                value = defaultValue;
            else
                error('ModuleBase:ConfigFieldNotFound', ...
                      '配置字段 "%s" 不存在', fieldName);
            end
        end

        function setConfigValue(obj, fieldName, value)
            % setConfigValue 设置配置值
            %
            % 输入:
            %   fieldName - string, 配置字段名
            %   value - any, 配置值
            %
            % 功能:
            %   - 动态设置配置字段

            obj.config.(fieldName) = value;
        end

        function tf = hasConfigField(obj, fieldName)
            % hasConfigField 检查配置字段是否存在
            %
            % 输入:
            %   fieldName - string, 配置字段名
            %
            % 输出:
            %   tf - logical, 字段是否存在

            tf = isfield(obj.config, fieldName);
        end

        function validateConfigFields(obj, requiredFields)
            % validateConfigFields 验证必需的配置字段
            %
            % 输入:
            %   requiredFields - cell array of strings, 必需字段列表
            %
            % 功能:
            %   - 检查所有必需配置字段是否存在
            %   - 如果缺少字段则抛出异常

            for i = 1:length(requiredFields)
                fieldName = requiredFields{i};
                if ~obj.hasConfigField(fieldName)
                    error('ModuleBase:MissingConfigField', ...
                          '缺少必需配置字段: %s', fieldName);
                end
            end
        end

        function result = createResultStruct(obj, varargin)
            % createResultStruct 创建结果结构体
            %
            % 输入:
            %   varargin - 字段名-值对
            %
            % 输出:
            %   result - struct, 结果结构体
            %
            % 功能:
            %   - 便捷地创建标准化的结果结构
            %   - 自动添加模块名称和时间戳
            %
            % 示例:
            %   result = obj.createResultStruct('cost', 1000, 'success', true);

            result = struct();
            result.moduleName = obj.name;
            result.timestamp = datetime('now');

            % 添加自定义字段
            for i = 1:2:length(varargin)
                if i+1 <= length(varargin)
                    fieldName = varargin{i};
                    fieldValue = varargin{i+1};
                    result.(fieldName) = fieldValue;
                end
            end
        end

        function checkInitialized(obj)
            % checkInitialized 检查模块是否已初始化
            %
            % 功能:
            %   - 验证模块已初始化
            %   - 如果未初始化则抛出异常

            if ~obj.initialized
                error('ModuleBase:NotInitialized', ...
                      '模块 "%s" 未初始化，请先调用initialize()', obj.name);
            end
        end

        function markInitialized(obj)
            % markInitialized 标记模块为已初始化
            %
            % 功能:
            %   - 设置initialized标志为true
            %   - 子类应在initialize()结束时调用

            obj.initialized = true;
        end

        function markFinalized(obj)
            % markFinalized 标记模块为已清理
            %
            % 功能:
            %   - 设置initialized标志为false
            %   - 子类应在finalize()结束时调用

            obj.initialized = false;
        end

        % ==================== 日志方法 ====================

        function logInfo(obj, message)
            % logInfo 记录信息日志
            %
            % 输入:
            %   message - string, 日志消息

            msg = sprintf('[%s] %s', obj.name, message);
            if ~isempty(obj.logger)
                obj.logger.info(msg);
            else
                fprintf('[INFO] %s\n', msg);
            end
        end

        function logWarning(obj, message)
            % logWarning 记录警告日志
            %
            % 输入:
            %   message - string, 日志消息

            msg = sprintf('[%s] %s', obj.name, message);
            if ~isempty(obj.logger)
                obj.logger.warning(msg);
            else
                fprintf('[WARN] %s\n', msg);
            end
        end

        function logError(obj, message)
            % logError 记录错误日志
            %
            % 输入:
            %   message - string, 日志消息

            msg = sprintf('[%s] %s', obj.name, message);
            if ~isempty(obj.logger)
                obj.logger.error(msg);
            else
                fprintf('[ERROR] %s\n', msg);
            end
        end

        function logDebug(obj, message)
            % logDebug 记录调试日志
            %
            % 输入:
            %   message - string, 日志消息

            msg = sprintf('[%s] %s', obj.name, message);
            if ~isempty(obj.logger)
                obj.logger.debug(msg);
            end
        end

        % ==================== 错误处理 ====================

        function handleError(obj, ME, context)
            % handleError 处理异常
            %
            % 输入:
            %   ME - MException, MATLAB异常对象
            %   context - string, 错误上下文描述
            %
            % 功能:
            %   - 记录错误日志
            %   - 格式化错误信息
            %   - 重新抛出异常

            errorMsg = sprintf('%s: %s', context, ME.message);
            obj.logError(errorMsg);

            % 创建新异常并保留堆栈信息
            newME = MException('ModuleBase:ExecutionError', ...
                              '[%s] %s', obj.name, errorMsg);
            newME = addCause(newME, ME);
            throw(newME);
        end

        % ==================== 性能监控 ====================

        function tic_id = startTimer(obj, operationName)
            % startTimer 开始计时
            %
            % 输入:
            %   operationName - string, 操作名称
            %
            % 输出:
            %   tic_id - uint64, 计时器ID
            %
            % 功能:
            %   - 开始性能计时
            %   - 记录开始日志

            obj.logDebug(sprintf('开始: %s', operationName));
            tic_id = tic;
        end

        function elapsed = stopTimer(obj, tic_id, operationName)
            % stopTimer 停止计时
            %
            % 输入:
            %   tic_id - uint64, 计时器ID
            %   operationName - string, 操作名称
            %
            % 输出:
            %   elapsed - double, 耗时（秒）
            %
            % 功能:
            %   - 停止性能计时
            %   - 记录耗时日志

            elapsed = toc(tic_id);
            obj.logDebug(sprintf('完成: %s (耗时: %.2f秒)', operationName, elapsed));
        end

        % ==================== 数据验证工具 ====================

        function validateNumericRange(obj, value, fieldName, minValue, maxValue)
            % validateNumericRange 验证数值范围
            %
            % 输入:
            %   value - double, 要验证的值
            %   fieldName - string, 字段名称
            %   minValue - double, 最小值
            %   maxValue - double, 最大值
            %
            % 功能:
            %   - 检查数值是否在指定范围内
            %   - 如果超出范围则抛出异常

            if ~isnumeric(value)
                error('ModuleBase:InvalidType', ...
                      '字段 "%s" 必须是数值类型', fieldName);
            end

            if value < minValue || value > maxValue
                error('ModuleBase:OutOfRange', ...
                      '字段 "%s" 的值 %.2f 超出范围 [%.2f, %.2f]', ...
                      fieldName, value, minValue, maxValue);
            end
        end

        function validateStringChoice(obj, value, fieldName, validChoices)
            % validateStringChoice 验证字符串选项
            %
            % 输入:
            %   value - string, 要验证的值
            %   fieldName - string, 字段名称
            %   validChoices - cell array of strings, 有效选项列表
            %
            % 功能:
            %   - 检查字符串是否在有效选项中
            %   - 如果无效则抛出异常

            if ~ischar(value) && ~isstring(value)
                error('ModuleBase:InvalidType', ...
                      '字段 "%s" 必须是字符串类型', fieldName);
            end

            if ~any(strcmp(value, validChoices))
                error('ModuleBase:InvalidChoice', ...
                      '字段 "%s" 的值 "%s" 无效。有效选项: %s', ...
                      fieldName, value, strjoin(validChoices, ', '));
            end
        end
    end

    methods (Abstract)
        % 子类必须实现这些方法
        initialize(obj)
        result = execute(obj, inputData)
        finalize(obj)
    end
end
