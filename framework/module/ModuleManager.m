classdef ModuleManager < handle
    % ModuleManager 模块管理器
    % Module Manager for Plugin System
    %
    % 功能:
    %   - 模块生命周期管理（加载、初始化、执行、卸载）
    %   - 依赖解析和自动加载
    %   - 模块调用链编排
    %   - 错误处理和回滚
    %   - 事件发布（模块加载/卸载事件）
    %
    % 使用示例:
    %   % 创建模块管理器
    %   manager = ModuleManager();
    %
    %   % 注册模块实例
    %   costModule = SeiderCostModule();
    %   manager.registerModule('cost', costModule);
    %
    %   % 配置和初始化模块
    %   config = struct('baseCost', 1000);
    %   manager.configureModule('cost', config);
    %   manager.initializeModule('cost');
    %
    %   % 执行模块
    %   inputData = struct('equipmentType', 'tower');
    %   result = manager.executeModule('cost', inputData);
    %
    %   % 执行模块链
    %   pipeline = {'cost', 'emission'};
    %   results = manager.executePipeline(pipeline, inputData);
    %
    %   % 清理资源
    %   manager.finalizeModule('cost');
    %   manager.unregisterModule('cost');


    properties (Access = private)
        modules;            % containers.Map, 已注册的模块实例 (name -> module)
        moduleConfigs;      % containers.Map, 模块配置 (name -> config)
        moduleStates;       % containers.Map, 模块状态 (name -> state)
        dependencyGraph;    % containers.Map, 依赖图 (name -> dependencies)
        logger;             % Logger, 日志记录器
        eventBus;           % EventBus, 事件总线（可选）
    end

    properties (Constant)
        % 模块状态常量
        STATE_REGISTERED = 'registered';      % 已注册
        STATE_CONFIGURED = 'configured';      % 已配置
        STATE_INITIALIZED = 'initialized';    % 已初始化
        STATE_FINALIZED = 'finalized';        % 已清理
    end

    methods
        function obj = ModuleManager()
            % ModuleManager 构造函数
            %
            % 功能:
            %   - 初始化内部数据结构
            %   - 创建日志记录器

            obj.modules = containers.Map();
            obj.moduleConfigs = containers.Map();
            obj.moduleStates = containers.Map();
            obj.dependencyGraph = containers.Map();

            % 创建日志记录器
            if exist('Logger', 'class')
                obj.logger = Logger.getLogger('ModuleManager');
            else
                obj.logger = [];
            end

            obj.eventBus = [];
        end

        % ==================== 模块注册和注销 ====================

        function registerModule(obj, name, module)
            % registerModule 注册模块实例
            %
            % 输入:
            %   name - string, 模块名称（用于引用）
            %   module - IModule, 模块实例
            %
            % 功能:
            %   - 检查模块是否实现IModule接口
            %   - 存储模块实例
            %   - 构建依赖图
            %   - 发布模块注册事件

            % 参数验证
            if ~ischar(name) && ~isstring(name)
                error('ModuleManager:InvalidName', '模块名称必须是字符串');
            end

            if ~isa(module, 'IModule')
                error('ModuleManager:InvalidModule', '模块必须实现IModule接口');
            end

            % 检查是否已注册
            if obj.modules.isKey(name)
                obj.logWarning(sprintf('模块 "%s" 已注册，将被覆盖', name));
            end

            % 注册模块
            obj.modules(name) = module;
            obj.moduleStates(name) = obj.STATE_REGISTERED;

            % 构建依赖图
            deps = module.getDependencies();
            obj.dependencyGraph(name) = deps;

            obj.logInfo(sprintf('模块 "%s" (v%s) 已注册', name, module.getVersion()));

            % 发布事件
            obj.publishEvent('module.registered', struct('name', name, 'module', module));
        end

        function unregisterModule(obj, name)
            % unregisterModule 注销模块
            %
            % 输入:
            %   name - string, 模块名称
            %
            % 功能:
            %   - 检查模块是否可以安全注销
            %   - 清理模块资源
            %   - 移除模块引用
            %   - 发布模块注销事件

            if ~obj.modules.isKey(name)
                error('ModuleManager:ModuleNotFound', '模块 "%s" 未注册', name);
            end

            % 检查是否有其他模块依赖此模块
            dependents = obj.findDependents(name);
            if ~isempty(dependents)
                error('ModuleManager:HasDependents', ...
                      '无法注销模块 "%s"，以下模块依赖它: %s', ...
                      name, strjoin(dependents, ', '));
            end

            % 如果模块已初始化，先清理
            if strcmp(obj.moduleStates(name), obj.STATE_INITIALIZED)
                obj.finalizeModule(name);
            end

            % 移除模块
            module = obj.modules(name);
            obj.modules.remove(name);
            obj.moduleStates.remove(name);
            obj.dependencyGraph.remove(name);

            if obj.moduleConfigs.isKey(name)
                obj.moduleConfigs.remove(name);
            end

            obj.logInfo(sprintf('模块 "%s" 已注销', name));

            % 发布事件
            obj.publishEvent('module.unregistered', struct('name', name));
        end

        % ==================== 模块配置 ====================

        function configureModule(obj, name, config)
            % configureModule 配置模块
            %
            % 输入:
            %   name - string, 模块名称
            %   config - struct, 配置参数
            %
            % 功能:
            %   - 调用模块的configure()方法
            %   - 存储配置以便后续使用
            %   - 更新模块状态

            if ~obj.modules.isKey(name)
                error('ModuleManager:ModuleNotFound', '模块 "%s" 未注册', name);
            end

            module = obj.modules(name);

            % 配置模块
            module.configure(config);
            obj.moduleConfigs(name) = config;
            obj.moduleStates(name) = obj.STATE_CONFIGURED;

            obj.logInfo(sprintf('模块 "%s" 已配置', name));
        end

        function isValid = validateModule(obj, name)
            % validateModule 验证模块配置
            %
            % 输入:
            %   name - string, 模块名称
            %
            % 输出:
            %   isValid - logical, 配置是否有效

            if ~obj.modules.isKey(name)
                error('ModuleManager:ModuleNotFound', '模块 "%s" 未注册', name);
            end

            module = obj.modules(name);
            isValid = module.validate();

            if isValid
                obj.logInfo(sprintf('模块 "%s" 配置验证通过', name));
            else
                obj.logWarning(sprintf('模块 "%s" 配置验证失败', name));
            end
        end

        % ==================== 模块生命周期 ====================

        function initializeModule(obj, name, varargin)
            % initializeModule 初始化模块
            %
            % 输入:
            %   name - string, 模块名称
            %   varargin - 可选参数
            %       'AutoLoadDeps', true/false - 是否自动加载依赖（默认true）
            %
            % 功能:
            %   - 检查并初始化依赖模块
            %   - 调用模块的initialize()方法
            %   - 更新模块状态

            % 解析可选参数
            p = inputParser;
            addParameter(p, 'AutoLoadDeps', true, @islogical);
            parse(p, varargin{:});
            autoLoadDeps = p.Results.AutoLoadDeps;

            if ~obj.modules.isKey(name)
                error('ModuleManager:ModuleNotFound', '模块 "%s" 未注册', name);
            end

            % 检查状态
            state = obj.moduleStates(name);
            if strcmp(state, obj.STATE_INITIALIZED)
                obj.logWarning(sprintf('模块 "%s" 已经初始化', name));
                return;
            end

            % 自动加载依赖
            if autoLoadDeps
                obj.initializeDependencies(name);
            end

            % 初始化模块
            module = obj.modules(name);
            try
                module.initialize();
                obj.moduleStates(name) = obj.STATE_INITIALIZED;
                obj.logInfo(sprintf('模块 "%s" 已初始化', name));

                % 发布事件
                obj.publishEvent('module.initialized', struct('name', name));
            catch ME
                obj.logError(sprintf('模块 "%s" 初始化失败: %s', name, ME.message));
                rethrow(ME);
            end
        end

        function result = executeModule(obj, name, inputData)
            % executeModule 执行模块
            %
            % 输入:
            %   name - string, 模块名称
            %   inputData - struct, 输入数据
            %
            % 输出:
            %   result - struct, 模块执行结果
            %
            % 功能:
            %   - 检查模块状态
            %   - 调用模块的execute()方法
            %   - 返回执行结果

            if ~obj.modules.isKey(name)
                error('ModuleManager:ModuleNotFound', '模块 "%s" 未注册', name);
            end

            % 检查状态
            state = obj.moduleStates(name);
            if ~strcmp(state, obj.STATE_INITIALIZED)
                error('ModuleManager:NotInitialized', ...
                      '模块 "%s" 未初始化（当前状态: %s）', name, state);
            end

            % 执行模块
            module = obj.modules(name);
            try
                obj.logDebug(sprintf('执行模块 "%s"', name));
                result = module.execute(inputData);

                % 发布事件
                obj.publishEvent('module.executed', struct('name', name, 'result', result));
            catch ME
                obj.logError(sprintf('模块 "%s" 执行失败: %s', name, ME.message));
                rethrow(ME);
            end
        end

        function finalizeModule(obj, name)
            % finalizeModule 清理模块
            %
            % 输入:
            %   name - string, 模块名称
            %
            % 功能:
            %   - 调用模块的finalize()方法
            %   - 更新模块状态

            if ~obj.modules.isKey(name)
                error('ModuleManager:ModuleNotFound', '模块 "%s" 未注册', name);
            end

            module = obj.modules(name);
            try
                module.finalize();
                obj.moduleStates(name) = obj.STATE_FINALIZED;
                obj.logInfo(sprintf('模块 "%s" 已清理', name));

                % 发布事件
                obj.publishEvent('module.finalized', struct('name', name));
            catch ME
                obj.logError(sprintf('模块 "%s" 清理失败: %s', name, ME.message));
                rethrow(ME);
            end
        end

        % ==================== 模块管道执行 ====================

        function results = executePipeline(obj, pipeline, inputData)
            % executePipeline 执行模块管道
            %
            % 输入:
            %   pipeline - cell array of strings, 模块名称列表
            %   inputData - struct, 初始输入数据
            %
            % 输出:
            %   results - cell array, 每个模块的执行结果
            %
            % 功能:
            %   - 按顺序执行多个模块
            %   - 将前一个模块的输出作为下一个模块的输入
            %   - 收集所有模块的执行结果

            if ~iscell(pipeline)
                error('ModuleManager:InvalidPipeline', '管道必须是cell数组');
            end

            results = cell(length(pipeline), 1);
            currentData = inputData;

            for i = 1:length(pipeline)
                moduleName = pipeline{i};
                obj.logInfo(sprintf('管道执行 [%d/%d]: %s', i, length(pipeline), moduleName));

                % 执行模块
                result = obj.executeModule(moduleName, currentData);
                results{i} = result;

                % 将结果作为下一个模块的输入
                currentData = result;
            end

            obj.logInfo('管道执行完成');
        end

        % ==================== 依赖管理 ====================

        function initializeDependencies(obj, name)
            % initializeDependencies 初始化模块的所有依赖
            %
            % 输入:
            %   name - string, 模块名称
            %
            % 功能:
            %   - 递归初始化所有依赖模块
            %   - 检测循环依赖

            if ~obj.dependencyGraph.isKey(name)
                return;
            end

            deps = obj.dependencyGraph(name);
            for i = 1:length(deps)
                depName = deps{i};

                % 检查依赖是否已注册
                if ~obj.modules.isKey(depName)
                    error('ModuleManager:DependencyNotFound', ...
                          '模块 "%s" 的依赖 "%s" 未注册', name, depName);
                end

                % 如果依赖未初始化，则初始化
                if ~strcmp(obj.moduleStates(depName), obj.STATE_INITIALIZED)
                    obj.initializeModule(depName, 'AutoLoadDeps', true);
                end
            end
        end

        function dependents = findDependents(obj, name)
            % findDependents 查找依赖指定模块的所有模块
            %
            % 输入:
            %   name - string, 模块名称
            %
            % 输出:
            %   dependents - cell array of strings, 依赖此模块的模块列表

            dependents = {};
            moduleNames = obj.modules.keys();

            for i = 1:length(moduleNames)
                moduleName = moduleNames{i};
                deps = obj.dependencyGraph(moduleName);

                if any(strcmp(deps, name))
                    dependents{end+1} = moduleName;
                end
            end
        end

        % ==================== 查询方法 ====================

        function modules = getRegisteredModules(obj)
            % getRegisteredModules 获取所有已注册的模块名称
            %
            % 输出:
            %   modules - cell array of strings, 模块名称列表

            modules = obj.modules.keys();
        end

        function module = getModule(obj, name)
            % getModule 获取模块实例
            %
            % 输入:
            %   name - string, 模块名称
            %
            % 输出:
            %   module - IModule, 模块实例

            if ~obj.modules.isKey(name)
                error('ModuleManager:ModuleNotFound', '模块 "%s" 未注册', name);
            end

            module = obj.modules(name);
        end

        function state = getModuleState(obj, name)
            % getModuleState 获取模块状态
            %
            % 输入:
            %   name - string, 模块名称
            %
            % 输出:
            %   state - string, 模块状态

            if ~obj.moduleStates.isKey(name)
                error('ModuleManager:ModuleNotFound', '模块 "%s" 未注册', name);
            end

            state = obj.moduleStates(name);
        end

        function printStatus(obj)
            % printStatus 打印所有模块的状态
            %
            % 功能:
            %   - 列出所有已注册的模块
            %   - 显示每个模块的状态和依赖

            moduleNames = obj.modules.keys();
            fprintf('========================================\n');
            fprintf('模块管理器状态\n');
            fprintf('========================================\n');
            fprintf('已注册模块数: %d\n\n', length(moduleNames));

            for i = 1:length(moduleNames)
                name = moduleNames{i};
                module = obj.modules(name);
                state = obj.moduleStates(name);
                deps = obj.dependencyGraph(name);

                fprintf('[%d] %s (v%s)\n', i, name, module.getVersion());
                fprintf('    状态: %s\n', state);
                fprintf('    描述: %s\n', module.getDescription());

                if ~isempty(deps)
                    fprintf('    依赖: %s\n', strjoin(deps, ', '));
                end

                fprintf('\n');
            end

            fprintf('========================================\n');
        end

        % ==================== 事件管理 ====================

        function setEventBus(obj, eventBus)
            % setEventBus 设置事件总线
            %
            % 输入:
            %   eventBus - EventBus, 事件总线实例

            obj.eventBus = eventBus;
        end

        function publishEvent(obj, eventType, data)
            % publishEvent 发布事件
            %
            % 输入:
            %   eventType - string, 事件类型
            %   data - struct, 事件数据

            if ~isempty(obj.eventBus)
                obj.eventBus.publish(eventType, data);
            end
        end

        % ==================== 日志方法 ====================

        function logInfo(obj, message)
            if ~isempty(obj.logger)
                obj.logger.info(message);
            else
                fprintf('[INFO] %s\n', message);
            end
        end

        function logWarning(obj, message)
            if ~isempty(obj.logger)
                obj.logger.warning(message);
            else
                fprintf('[WARN] %s\n', message);
            end
        end

        function logError(obj, message)
            if ~isempty(obj.logger)
                obj.logger.error(message);
            else
                fprintf('[ERROR] %s\n', message);
            end
        end

        function logDebug(obj, message)
            if ~isempty(obj.logger)
                obj.logger.debug(message);
            end
        end
    end
end
