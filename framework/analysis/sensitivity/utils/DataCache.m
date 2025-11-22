classdef DataCache < handle
    % DataCache - 数据缓存管理器
    %
    % 描述:
    %   提供灵敏度分析的数据缓存和检查点恢复功能
    %   支持自动保存、增量更新和断点续传
    %
    % 作者: MAPO Framework
    % 日期: 2024

    properties
        cacheDirectory = 'cache'       % 缓存目录
        cachePrefix = 'sensitivity'    % 缓存文件前缀
        autoSave = true                % 是否自动保存
        saveInterval = 10              % 自动保存间隔（次数）
        compression = true             % 是否压缩存储
        maxCacheAge = 7                % 最大缓存时间（天）
    end

    properties (Access = private)
        cacheData = struct()           % 内存缓存
        updateCount = 0                % 更新计数器
        lastSaveTime = datetime()      % 上次保存时间
        cacheFilePath                  % 缓存文件路径
    end

    methods
        function obj = DataCache(varargin)
            % 构造函数
            %
            % 可选参数（名称-值对）:
            %   'CacheDirectory' - 缓存目录
            %   'CachePrefix' - 缓存文件前缀
            %   'AutoSave' - 是否自动保存
            %   'SaveInterval' - 自动保存间隔
            %   'Compression' - 是否压缩存储

            if nargin > 0
                p = inputParser;
                addParameter(p, 'CacheDirectory', 'cache', @ischar);
                addParameter(p, 'CachePrefix', 'sensitivity', @ischar);
                addParameter(p, 'AutoSave', true, @islogical);
                addParameter(p, 'SaveInterval', 10, @(x) x > 0);
                addParameter(p, 'Compression', true, @islogical);
                addParameter(p, 'MaxCacheAge', 7, @(x) x > 0);
                parse(p, varargin{:});

                obj.cacheDirectory = p.Results.CacheDirectory;
                obj.cachePrefix = p.Results.CachePrefix;
                obj.autoSave = p.Results.AutoSave;
                obj.saveInterval = p.Results.SaveInterval;
                obj.compression = p.Results.Compression;
                obj.maxCacheAge = p.Results.MaxCacheAge;
            end

            % 初始化缓存目录
            if ~exist(obj.cacheDirectory, 'dir')
                mkdir(obj.cacheDirectory);
            end

            % 设置缓存文件路径
            obj.cacheFilePath = fullfile(obj.cacheDirectory, ...
                sprintf('%s_cache.mat', obj.cachePrefix));

            % 清理过期缓存
            obj.cleanOldCache();
        end

        function success = store(obj, key, data, metadata)
            % 存储数据到缓存
            %
            % 输入:
            %   key - 缓存键
            %   data - 要缓存的数据
            %   metadata - 元数据（可选）
            %
            % 输出:
            %   success - 是否成功存储

            success = false;
            try
                % 创建缓存条目
                entry = struct();
                entry.data = data;
                entry.timestamp = datetime('now');
                entry.key = key;

                if nargin >= 4
                    entry.metadata = metadata;
                else
                    entry.metadata = struct();
                end

                % 存储到内存缓存
                obj.cacheData.(obj.sanitizeKey(key)) = entry;
                obj.updateCount = obj.updateCount + 1;

                % 检查是否需要自动保存
                if obj.autoSave && mod(obj.updateCount, obj.saveInterval) == 0
                    obj.saveToDisk();
                end

                success = true;
            catch ME
                warning('DataCache:StoreError', ...
                    '存储缓存失败: %s', ME.message);
            end
        end

        function [data, found] = retrieve(obj, key)
            % 从缓存检索数据
            %
            % 输入:
            %   key - 缓存键
            %
            % 输出:
            %   data - 缓存的数据（如果未找到则为空）
            %   found - 是否找到数据

            data = [];
            found = false;

            safeKey = obj.sanitizeKey(key);

            % 首先检查内存缓存
            if isfield(obj.cacheData, safeKey)
                entry = obj.cacheData.(safeKey);
                data = entry.data;
                found = true;
                return;
            end

            % 尝试从磁盘加载
            if obj.loadFromDisk()
                if isfield(obj.cacheData, safeKey)
                    entry = obj.cacheData.(safeKey);
                    data = entry.data;
                    found = true;
                end
            end
        end

        function exists = hasCache(obj, key)
            % 检查缓存是否存在
            %
            % 输入:
            %   key - 缓存键
            %
            % 输出:
            %   exists - 是否存在

            safeKey = obj.sanitizeKey(key);
            exists = isfield(obj.cacheData, safeKey);

            % 如果内存中没有，尝试从磁盘加载
            if ~exists && exist(obj.cacheFilePath, 'file')
                obj.loadFromDisk();
                exists = isfield(obj.cacheData, safeKey);
            end
        end

        function success = saveToDisk(obj)
            % 保存缓存到磁盘
            %
            % 输出:
            %   success - 是否成功保存

            success = false;
            try
                cacheData = obj.cacheData;
                saveOptions = {};

                if obj.compression
                    saveOptions = {'-v7.3'};  % 支持压缩的格式
                else
                    saveOptions = {'-v7'};
                end

                % 添加保存元信息
                cacheInfo = struct();
                cacheInfo.version = '1.0';
                cacheInfo.saveTime = datetime('now');
                cacheInfo.entryCount = numel(fieldnames(cacheData));

                % 保存到文件
                save(obj.cacheFilePath, 'cacheData', 'cacheInfo', saveOptions{:});
                obj.lastSaveTime = datetime('now');

                success = true;
                fprintf('缓存已保存到磁盘: %s\n', obj.cacheFilePath);
            catch ME
                warning('DataCache:SaveError', ...
                    '保存缓存失败: %s', ME.message);
            end
        end

        function success = loadFromDisk(obj)
            % 从磁盘加载缓存
            %
            % 输出:
            %   success - 是否成功加载

            success = false;
            if ~exist(obj.cacheFilePath, 'file')
                return;
            end

            try
                loaded = load(obj.cacheFilePath);
                if isfield(loaded, 'cacheData')
                    obj.cacheData = loaded.cacheData;
                    success = true;

                    if isfield(loaded, 'cacheInfo')
                        fprintf('加载缓存: %d个条目 (保存时间: %s)\n', ...
                            loaded.cacheInfo.entryCount, ...
                            char(loaded.cacheInfo.saveTime));
                    end
                end
            catch ME
                warning('DataCache:LoadError', ...
                    '加载缓存失败: %s', ME.message);
            end
        end

        function clear(obj)
            % 清除所有缓存

            obj.cacheData = struct();
            obj.updateCount = 0;

            % 删除磁盘文件
            if exist(obj.cacheFilePath, 'file')
                delete(obj.cacheFilePath);
            end

            fprintf('缓存已清除\n');
        end

        function clearKey(obj, key)
            % 清除特定键的缓存
            %
            % 输入:
            %   key - 要清除的缓存键

            safeKey = obj.sanitizeKey(key);
            if isfield(obj.cacheData, safeKey)
                obj.cacheData = rmfield(obj.cacheData, safeKey);
                fprintf('缓存键已清除: %s\n', key);
            end
        end

        function stats = getStatistics(obj)
            % 获取缓存统计信息
            %
            % 输出:
            %   stats - 统计信息结构体

            stats = struct();
            stats.entryCount = numel(fieldnames(obj.cacheData));
            stats.updateCount = obj.updateCount;
            stats.lastSaveTime = obj.lastSaveTime;
            stats.cacheFile = obj.cacheFilePath;

            % 计算缓存大小
            if exist(obj.cacheFilePath, 'file')
                fileInfo = dir(obj.cacheFilePath);
                stats.diskSize = fileInfo.bytes;
                stats.diskSizeMB = fileInfo.bytes / 1024 / 1024;
            else
                stats.diskSize = 0;
                stats.diskSizeMB = 0;
            end

            % 获取最旧和最新的条目时间
            if stats.entryCount > 0
                timestamps = [];
                fields = fieldnames(obj.cacheData);
                for i = 1:length(fields)
                    entry = obj.cacheData.(fields{i});
                    if isfield(entry, 'timestamp')
                        timestamps = [timestamps; entry.timestamp];
                    end
                end

                if ~isempty(timestamps)
                    stats.oldestEntry = min(timestamps);
                    stats.newestEntry = max(timestamps);
                end
            end
        end

        function exportToFile(obj, filename)
            % 导出缓存到文件
            %
            % 输入:
            %   filename - 导出文件名

            try
                % 准备导出数据
                exportData = struct();
                exportData.cacheData = obj.cacheData;
                exportData.exportTime = datetime('now');
                exportData.statistics = obj.getStatistics();

                % 保存到文件
                [~, ~, ext] = fileparts(filename);
                if strcmpi(ext, '.mat')
                    save(filename, 'exportData', '-v7.3');
                elseif strcmpi(ext, '.json')
                    jsonStr = jsonencode(exportData);
                    fid = fopen(filename, 'w');
                    fprintf(fid, '%s', jsonStr);
                    fclose(fid);
                else
                    error('不支持的文件格式: %s', ext);
                end

                fprintf('缓存已导出到: %s\n', filename);
            catch ME
                error('DataCache:ExportError', ...
                    '导出缓存失败: %s', ME.message);
            end
        end
    end

    methods (Access = private)
        function safeKey = sanitizeKey(obj, key)
            % 清理键名以确保是有效的字段名
            %
            % 输入:
            %   key - 原始键名
            %
            % 输出:
            %   safeKey - 清理后的键名

            safeKey = regexprep(key, '[^a-zA-Z0-9]', '_');
            if ~isvarname(safeKey)
                safeKey = ['key_', safeKey];
            end
        end

        function cleanOldCache(obj)
            % 清理过期的缓存文件

            if ~exist(obj.cacheDirectory, 'dir')
                return;
            end

            % 获取缓存目录中的所有文件
            files = dir(fullfile(obj.cacheDirectory, '*.mat'));
            currentTime = datetime('now');

            for i = 1:length(files)
                fileAge = currentTime - datetime(files(i).datenum, ...
                    'ConvertFrom', 'datenum');

                % 如果文件超过最大缓存时间，删除它
                if days(fileAge) > obj.maxCacheAge
                    fullPath = fullfile(obj.cacheDirectory, files(i).name);
                    delete(fullPath);
                    fprintf('删除过期缓存: %s\n', files(i).name);
                end
            end
        end
    end
end