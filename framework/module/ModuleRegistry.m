classdef ModuleRegistry < handle
    % ModuleRegistry 模块注册表
    % Module Registry for Plugin Discovery and Management
    %
    % 功能:
    %   - 模块自动发现（扫描指定目录）
    %   - 模块注册和注销
    %   - 模块查询（按名称、类型、标签）
    %   - 版本管理和冲突检测
    %   - 持久化注册信息
    %
    % 使用示例:
    %   % 创建注册表
    %   registry = ModuleRegistry();
    %
    %   % 扫描目录自动发现模块
    %   registry.scanDirectory('framework/module/builtin');
    %
    %   % 手动注册模块类
    %   registry.registerModuleClass('SeiderCostModule', ...
    %       'framework/module/builtin/SeiderCostModule.m');
    %
    %   % 查询模块
    %   modules = registry.findModulesByTag('cost');
    %   info = registry.getModuleInfo('SeiderCostModule');
    %
    %   % 创建模块实例
    %   module = registry.createModuleInstance('SeiderCostModule');
    %
    %   % 保存注册表
    %   registry.saveRegistry('module_registry.mat');
    %
    %   % 加载注册表
    %   registry.loadRegistry('module_registry.mat');


    properties (Access = private)
        moduleClasses;      % containers.Map, 模块类信息 (className -> info struct)
        modulePaths;        % containers.Map, 模块路径 (className -> filePath)
        moduleInstances;    % containers.Map, 缓存的模块实例 (className -> instance)
        tagIndex;           % containers.Map, 标签索引 (tag -> {classNames})
        logger;             % Logger, 日志记录器
    end

    methods
        function obj = ModuleRegistry()
            % ModuleRegistry 构造函数
            %
            % 功能:
            %   - 初始化内部数据结构
            %   - 创建日志记录器

            obj.moduleClasses = containers.Map();
            obj.modulePaths = containers.Map();
            obj.moduleInstances = containers.Map();
            obj.tagIndex = containers.Map();

            % 创建日志记录器
            if exist('Logger', 'class')
                obj.logger = Logger.getLogger('ModuleRegistry');
            else
                obj.logger = [];
            end
        end

        % ==================== 模块注册 ====================

        function registerModuleClass(obj, className, filePath, varargin)
            % registerModuleClass 注册模块类
            %
            % 输入:
            %   className - string, 模块类名
            %   filePath - string, 模块文件路径
            %   varargin - 可选参数
            %       'Force', true/false - 是否强制覆盖已注册的模块（默认false）
            %
            % 功能:
            %   - 验证模块类是否存在
            %   - 提取模块元数据
            %   - 构建标签索引

            % 解析可选参数
            p = inputParser;
            addParameter(p, 'Force', false, @islogical);
            parse(p, varargin{:});
            forceRegister = p.Results.Force;

            % 检查是否已注册
            if obj.moduleClasses.isKey(className)
                if ~forceRegister
                    obj.logWarning(sprintf('模块类 "%s" 已注册，跳过', className));
                    return;
                else
                    obj.logWarning(sprintf('模块类 "%s" 已注册，强制覆盖', className));
                end
            end

            % 验证文件存在
            if ~exist(filePath, 'file')
                error('ModuleRegistry:FileNotFound', '文件不存在: %s', filePath);
            end

            % 验证类存在
            if ~exist(className, 'class')
                error('ModuleRegistry:ClassNotFound', '类不存在: %s', className);
            end

            % 创建临时实例以提取元数据
            try
                tempInstance = feval(className);

                % 验证是否实现IModule接口
                if ~isa(tempInstance, 'IModule')
                    error('ModuleRegistry:NotIModule', ...
                          '类 "%s" 未实现IModule接口', className);
                end

                % 提取元数据
                info = tempInstance.getInfo();
                info.className = className;
                info.filePath = filePath;
                info.registeredAt = datetime('now');

                % 存储信息
                obj.moduleClasses(className) = info;
                obj.modulePaths(className) = filePath;

                % 构建标签索引
                obj.updateTagIndex(className, info.tags);

                obj.logInfo(sprintf('已注册模块类: %s (v%s)', className, info.version));

            catch ME
                obj.logError(sprintf('注册模块类 "%s" 失败: %s', className, ME.message));
                rethrow(ME);
            end
        end

        function unregisterModuleClass(obj, className)
            % unregisterModuleClass 注销模块类
            %
            % 输入:
            %   className - string, 模块类名
            %
            % 功能:
            %   - 移除模块注册信息
            %   - 清理标签索引
            %   - 清除缓存的实例

            if ~obj.moduleClasses.isKey(className)
                error('ModuleRegistry:ClassNotFound', '模块类 "%s" 未注册', className);
            end

            % 获取模块信息
            info = obj.moduleClasses(className);

            % 清理标签索引
            for i = 1:length(info.tags)
                tag = info.tags{i};
                if obj.tagIndex.isKey(tag)
                    classList = obj.tagIndex(tag);
                    classList(strcmp(classList, className)) = [];
                    if isempty(classList)
                        obj.tagIndex.remove(tag);
                    else
                        obj.tagIndex(tag) = classList;
                    end
                end
            end

            % 移除注册信息
            obj.moduleClasses.remove(className);
            obj.modulePaths.remove(className);

            % 清除缓存的实例
            if obj.moduleInstances.isKey(className)
                obj.moduleInstances.remove(className);
            end

            obj.logInfo(sprintf('已注销模块类: %s', className));
        end

        % ==================== 模块发现 ====================

        function count = scanDirectory(obj, dirPath, varargin)
            % scanDirectory 扫描目录自动发现模块
            %
            % 输入:
            %   dirPath - string, 要扫描的目录路径
            %   varargin - 可选参数
            %       'Recursive', true/false - 是否递归扫描（默认true）
            %       'Pattern', '*.m' - 文件匹配模式（默认'*.m'）
            %
            % 输出:
            %   count - int, 发现并注册的模块数量
            %
            % 功能:
            %   - 递归扫描目录查找.m文件
            %   - 尝试加载并验证每个类
            %   - 自动注册实现IModule接口的类

            % 解析可选参数
            p = inputParser;
            addParameter(p, 'Recursive', true, @islogical);
            addParameter(p, 'Pattern', '*.m', @ischar);
            parse(p, varargin{:});
            recursive = p.Results.Recursive;
            pattern = p.Results.Pattern;

            % 验证目录存在
            if ~exist(dirPath, 'dir')
                error('ModuleRegistry:DirectoryNotFound', '目录不存在: %s', dirPath);
            end

            obj.logInfo(sprintf('开始扫描目录: %s', dirPath));

            % 添加路径
            addpath(genpath(dirPath));

            % 查找文件
            if recursive
                files = dir(fullfile(dirPath, '**', pattern));
            else
                files = dir(fullfile(dirPath, pattern));
            end

            count = 0;
            for i = 1:length(files)
                filePath = fullfile(files(i).folder, files(i).name);
                [~, className, ~] = fileparts(files(i).name);

                % 跳过抽象类和接口
                if startsWith(className, 'I') || contains(className, 'Base')
                    continue;
                end

                % 尝试注册
                try
                    obj.registerModuleClass(className, filePath);
                    count = count + 1;
                catch ME
                    % 不是模块类，跳过
                    obj.logDebug(sprintf('跳过 %s: %s', className, ME.message));
                end
            end

            obj.logInfo(sprintf('扫描完成，发现 %d 个模块', count));
        end

        % ==================== 模块查询 ====================

        function classNames = getAllModuleClasses(obj)
            % getAllModuleClasses 获取所有已注册的模块类名
            %
            % 输出:
            %   classNames - cell array of strings, 模块类名列表

            classNames = obj.moduleClasses.keys();
        end

        function info = getModuleInfo(obj, className)
            % getModuleInfo 获取模块元数据
            %
            % 输入:
            %   className - string, 模块类名
            %
            % 输出:
            %   info - struct, 模块元数据

            if ~obj.moduleClasses.isKey(className)
                error('ModuleRegistry:ClassNotFound', '模块类 "%s" 未注册', className);
            end

            info = obj.moduleClasses(className);
        end

        function classNames = findModulesByTag(obj, tag)
            % findModulesByTag 按标签查找模块
            %
            % 输入:
            %   tag - string, 标签
            %
            % 输出:
            %   classNames - cell array of strings, 匹配的模块类名列表

            if ~obj.tagIndex.isKey(tag)
                classNames = {};
            else
                classNames = obj.tagIndex(tag);
            end
        end

        function classNames = findModulesByName(obj, namePattern)
            % findModulesByName 按名称模式查找模块
            %
            % 输入:
            %   namePattern - string, 名称模式（支持通配符*）
            %
            % 输出:
            %   classNames - cell array of strings, 匹配的模块类名列表

            allClasses = obj.moduleClasses.keys();
            classNames = {};

            % 转换通配符为正则表达式
            pattern = strrep(namePattern, '*', '.*');
            pattern = ['^', pattern, '$'];

            for i = 1:length(allClasses)
                className = allClasses{i};
                if ~isempty(regexp(className, pattern, 'once'))
                    classNames{end+1} = className;
                end
            end
        end

        function classNames = findModulesByAuthor(obj, author)
            % findModulesByAuthor 按作者查找模块
            %
            % 输入:
            %   author - string, 作者名称
            %
            % 输出:
            %   classNames - cell array of strings, 匹配的模块类名列表

            allClasses = obj.moduleClasses.keys();
            classNames = {};

            for i = 1:length(allClasses)
                className = allClasses{i};
                info = obj.moduleClasses(className);
                if contains(info.author, author)
                    classNames{end+1} = className;
                end
            end
        end

        % ==================== 模块实例化 ====================

        function instance = createModuleInstance(obj, className, varargin)
            % createModuleInstance 创建模块实例
            %
            % 输入:
            %   className - string, 模块类名
            %   varargin - 可选参数
            %       'UseCache', true/false - 是否使用缓存的实例（默认false）
            %
            % 输出:
            %   instance - IModule, 模块实例
            %
            % 功能:
            %   - 验证模块类已注册
            %   - 创建新实例或返回缓存实例
            %   - 验证实例实现IModule接口

            % 解析可选参数
            p = inputParser;
            addParameter(p, 'UseCache', false, @islogical);
            parse(p, varargin{:});
            useCache = p.Results.UseCache;

            if ~obj.moduleClasses.isKey(className)
                error('ModuleRegistry:ClassNotFound', '模块类 "%s" 未注册', className);
            end

            % 检查缓存
            if useCache && obj.moduleInstances.isKey(className)
                instance = obj.moduleInstances(className);
                obj.logDebug(sprintf('使用缓存的模块实例: %s', className));
                return;
            end

            % 创建新实例
            try
                instance = feval(className);

                % 验证接口
                if ~isa(instance, 'IModule')
                    error('ModuleRegistry:NotIModule', ...
                          '类 "%s" 未实现IModule接口', className);
                end

                % 缓存实例
                if useCache
                    obj.moduleInstances(className) = instance;
                end

                obj.logDebug(sprintf('创建模块实例: %s', className));

            catch ME
                obj.logError(sprintf('创建模块实例 "%s" 失败: %s', className, ME.message));
                rethrow(ME);
            end
        end

        % ==================== 版本管理 ====================

        function conflicts = checkVersionConflicts(obj)
            % checkVersionConflicts 检查版本冲突
            %
            % 输出:
            %   conflicts - cell array, 冲突列表
            %
            % 功能:
            %   - 检查是否有同名但不同版本的模块
            %   - 返回冲突信息

            conflicts = {};
            allClasses = obj.moduleClasses.keys();
            nameMap = containers.Map();

            for i = 1:length(allClasses)
                className = allClasses{i};
                info = obj.moduleClasses(className);

                if nameMap.isKey(info.name)
                    % 发现重名模块
                    existingInfo = nameMap(info.name);
                    if ~strcmp(existingInfo.version, info.version)
                        conflict = struct();
                        conflict.name = info.name;
                        conflict.version1 = existingInfo.version;
                        conflict.class1 = existingInfo.className;
                        conflict.version2 = info.version;
                        conflict.class2 = className;
                        conflicts{end+1} = conflict;
                    end
                else
                    nameMap(info.name) = info;
                end
            end

            if ~isempty(conflicts)
                obj.logWarning(sprintf('发现 %d 个版本冲突', length(conflicts)));
            end
        end

        % ==================== 持久化 ====================

        function saveRegistry(obj, filePath)
            % saveRegistry 保存注册表到文件
            %
            % 输入:
            %   filePath - string, 保存路径
            %
            % 功能:
            %   - 将注册表信息序列化
            %   - 保存到.mat文件

            data = struct();
            data.moduleClasses = obj.moduleClasses;
            data.modulePaths = obj.modulePaths;
            data.tagIndex = obj.tagIndex;
            data.savedAt = datetime('now');

            save(filePath, 'data');
            obj.logInfo(sprintf('注册表已保存到: %s', filePath));
        end

        function loadRegistry(obj, filePath)
            % loadRegistry 从文件加载注册表
            %
            % 输入:
            %   filePath - string, 文件路径
            %
            % 功能:
            %   - 从.mat文件加载注册表
            %   - 恢复注册表状态

            if ~exist(filePath, 'file')
                error('ModuleRegistry:FileNotFound', '文件不存在: %s', filePath);
            end

            loaded = load(filePath);
            data = loaded.data;

            obj.moduleClasses = data.moduleClasses;
            obj.modulePaths = data.modulePaths;
            obj.tagIndex = data.tagIndex;

            obj.logInfo(sprintf('注册表已从 %s 加载 (%s)', ...
                        filePath, char(data.savedAt)));
        end

        % ==================== 显示方法 ====================

        function printRegistry(obj)
            % printRegistry 打印注册表内容
            %
            % 功能:
            %   - 列出所有已注册的模块
            %   - 显示模块详细信息

            classNames = obj.moduleClasses.keys();
            fprintf('========================================\n');
            fprintf('模块注册表\n');
            fprintf('========================================\n');
            fprintf('已注册模块数: %d\n\n', length(classNames));

            for i = 1:length(classNames)
                className = classNames{i};
                info = obj.moduleClasses(className);

                fprintf('[%d] %s\n', i, className);
                fprintf('    名称: %s (v%s)\n', info.name, info.version);
                fprintf('    描述: %s\n', info.description);
                fprintf('    文件: %s\n', info.filePath);

                if ~isempty(info.tags)
                    fprintf('    标签: %s\n', strjoin(info.tags, ', '));
                end

                if ~isempty(info.dependencies)
                    fprintf('    依赖: %s\n', strjoin(info.dependencies, ', '));
                end

                if ~isempty(info.author)
                    fprintf('    作者: %s\n', info.author);
                end

                fprintf('\n');
            end

            fprintf('========================================\n');
        end

        function printTags(obj)
            % printTags 打印标签索引
            %
            % 功能:
            %   - 列出所有标签
            %   - 显示每个标签对应的模块

            tags = obj.tagIndex.keys();
            fprintf('========================================\n');
            fprintf('标签索引\n');
            fprintf('========================================\n');
            fprintf('标签数量: %d\n\n', length(tags));

            for i = 1:length(tags)
                tag = tags{i};
                classList = obj.tagIndex(tag);
                fprintf('[%s] (%d个模块)\n', tag, length(classList));
                for j = 1:length(classList)
                    fprintf('  - %s\n', classList{j});
                end
                fprintf('\n');
            end

            fprintf('========================================\n');
        end

        % ==================== 内部辅助方法 ====================

        function updateTagIndex(obj, className, tags)
            % updateTagIndex 更新标签索引
            %
            % 输入:
            %   className - string, 模块类名
            %   tags - cell array, 标签列表

            for i = 1:length(tags)
                tag = tags{i};

                if obj.tagIndex.isKey(tag)
                    classList = obj.tagIndex(tag);
                    if ~any(strcmp(classList, className))
                        classList{end+1} = className;
                        obj.tagIndex(tag) = classList;
                    end
                else
                    obj.tagIndex(tag) = {className};
                end
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
