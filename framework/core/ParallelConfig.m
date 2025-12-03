classdef ParallelConfig < handle
    % ParallelConfig 并行计算配置类
    % 管理MAPO框架的并行计算设置
    %
    % 功能:
    %   - 并行池管理
    %   - 并行模式配置
    %   - Worker数量设置
    %   - 负载均衡策略
    %
    % 示例:
    %   config = ParallelConfig();
    %   config.enableParallel = true;
    %   config.numWorkers = 4;
    %
    % 作者: MAPO Framework
    % 日期: 2024

    properties
        enableParallel      % 是否启用并行计算
        numWorkers          % Worker数量（0表示自动检测）
        chunkSize           % 任务分块大小
        timeout             % 单任务超时时间（秒）
        verboseParallel     % 是否显示并行计算详情
        loadBalancing       % 负载均衡策略 ('static', 'dynamic')
        fallbackToSequential % 并行失败时是否回退到顺序执行
    end

    properties (Access = private)
        poolHandle          % 并行池句柄
        isPoolOwner         % 是否是池的所有者（用于决定是否关闭池）
    end

    methods
        function obj = ParallelConfig(varargin)
            % ParallelConfig 构造函数
            %
            % 可选参数（名称-值对）:
            %   'EnableParallel' - 是否启用并行 (默认true)
            %   'NumWorkers' - Worker数量 (默认0，自动检测)
            %   'ChunkSize' - 分块大小 (默认0，自动计算)
            %   'Timeout' - 超时时间 (默认300秒)
            %   'Verbose' - 显示详情 (默认false)
            %   'LoadBalancing' - 负载均衡 (默认'static')

            p = inputParser;
            addParameter(p, 'EnableParallel', true, @islogical);
            addParameter(p, 'NumWorkers', 0, @isnumeric);
            addParameter(p, 'ChunkSize', 0, @isnumeric);
            addParameter(p, 'Timeout', 300, @isnumeric);
            addParameter(p, 'Verbose', false, @islogical);
            addParameter(p, 'LoadBalancing', 'static', @ischar);
            addParameter(p, 'FallbackToSequential', true, @islogical);
            parse(p, varargin{:});

            obj.enableParallel = p.Results.EnableParallel;
            obj.numWorkers = p.Results.NumWorkers;
            obj.chunkSize = p.Results.ChunkSize;
            obj.timeout = p.Results.Timeout;
            obj.verboseParallel = p.Results.Verbose;
            obj.loadBalancing = p.Results.LoadBalancing;
            obj.fallbackToSequential = p.Results.FallbackToSequential;
            obj.poolHandle = [];
            obj.isPoolOwner = false;
        end

        function pool = getOrCreatePool(obj)
            % getOrCreatePool 获取或创建并行池
            %
            % 输出:
            %   pool - 并行池对象

            if ~obj.enableParallel
                pool = [];
                return;
            end

            % 检查是否有现有池
            pool = gcp('nocreate');

            if isempty(pool)
                % 创建新池
                try
                    if obj.numWorkers > 0
                        pool = parpool('local', obj.numWorkers);
                    else
                        pool = parpool('local');
                    end
                    obj.poolHandle = pool;
                    obj.isPoolOwner = true;

                    if obj.verboseParallel
                        fprintf('[ParallelConfig] 创建并行池: %d workers\n', pool.NumWorkers);
                    end
                catch ME
                    warning('ParallelConfig:PoolCreationFailed', ...
                        '无法创建并行池: %s', ME.message);
                    pool = [];
                end
            else
                obj.poolHandle = pool;
                obj.isPoolOwner = false;

                if obj.verboseParallel
                    fprintf('[ParallelConfig] 使用现有并行池: %d workers\n', pool.NumWorkers);
                end
            end
        end

        function n = getActiveWorkers(obj)
            % getActiveWorkers 获取当前活动的Worker数量
            %
            % 输出:
            %   n - Worker数量，如果没有并行池则返回1

            pool = gcp('nocreate');
            if isempty(pool)
                n = 1;
            else
                n = pool.NumWorkers;
            end
        end

        function tf = isParallelAvailable(obj)
            % isParallelAvailable 检查并行计算是否可用
            %
            % 输出:
            %   tf - 布尔值

            tf = obj.enableParallel && ...
                 license('test', 'Distrib_Computing_Toolbox') && ...
                 ~isempty(ver('parallel'));
        end

        function closePool(obj)
            % closePool 关闭并行池（仅当是所有者时）

            if obj.isPoolOwner && ~isempty(obj.poolHandle)
                try
                    delete(obj.poolHandle);
                    if obj.verboseParallel
                        fprintf('[ParallelConfig] 并行池已关闭\n');
                    end
                catch
                    % 忽略关闭错误
                end
                obj.poolHandle = [];
                obj.isPoolOwner = false;
            end
        end

        function chunks = createChunks(obj, totalTasks)
            % createChunks 将任务分块
            %
            % 输入:
            %   totalTasks - 总任务数
            %
            % 输出:
            %   chunks - cell数组，每个元素是该块的任务索引

            if obj.chunkSize > 0
                chunkSz = obj.chunkSize;
            else
                % 自动计算分块大小
                nWorkers = obj.getActiveWorkers();
                chunkSz = max(1, ceil(totalTasks / (nWorkers * 2)));
            end

            numChunks = ceil(totalTasks / chunkSz);
            chunks = cell(numChunks, 1);

            for i = 1:numChunks
                startIdx = (i-1) * chunkSz + 1;
                endIdx = min(i * chunkSz, totalTasks);
                chunks{i} = startIdx:endIdx;
            end
        end

        function delete(obj)
            % delete 析构函数
            obj.closePool();
        end
    end

    methods (Static)
        function config = getDefault()
            % getDefault 获取默认并行配置
            %
            % 输出:
            %   config - 默认ParallelConfig对象

            config = ParallelConfig();
        end

        function tf = checkToolbox()
            % checkToolbox 检查Parallel Computing Toolbox是否安装
            %
            % 输出:
            %   tf - 布尔值

            tf = license('test', 'Distrib_Computing_Toolbox') && ...
                 ~isempty(ver('parallel'));

            if ~tf
                warning('ParallelConfig:NoToolbox', ...
                    'Parallel Computing Toolbox 未安装或未授权');
            end
        end

        function info = getSystemInfo()
            % getSystemInfo 获取系统并行计算信息
            %
            % 输出:
            %   info - 系统信息结构体

            info = struct();
            info.numCores = feature('numcores');
            info.numLogicalCPUs = maxNumCompThreads;
            info.hasToolbox = ParallelConfig.checkToolbox();

            pool = gcp('nocreate');
            if ~isempty(pool)
                info.poolActive = true;
                info.poolWorkers = pool.NumWorkers;
            else
                info.poolActive = false;
                info.poolWorkers = 0;
            end
        end
    end
end
