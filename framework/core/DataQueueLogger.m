classdef DataQueueLogger < Logger
    % DataQueueLogger 将日志事件通过 DataQueue 发送回客户端（用于 GUI 异步模式）
    %
    % 说明：
    %   - 继承 Logger 以兼容 AlgorithmBase.setLogger / SimulatorBase.setLogger 的类型检查
    %   - 不写文件、不输出控制台，仅发送结构体到 parallel.pool.DataQueue
    %
    % 发送数据格式：
    %   struct('type','log','level','INFO','message','...','source','Simulator')

    properties (Access = private)
        dataQueue
        source
        minLevel
    end

    methods
        function obj = DataQueueLogger(dataQueue, source, minLevel)
            if nargin < 2 || isempty(source)
                source = '';
            end
            if nargin < 3 || isempty(minLevel)
                minLevel = Logger.INFO;
            end

            obj@Logger(Logger.DEBUG, '', false, false);
            obj.dataQueue = dataQueue;
            obj.source = source;
            obj.minLevel = minLevel;
        end

        function debug(obj, message, varargin)
            obj.sendLog(Logger.DEBUG, 'DEBUG', message, varargin{:});
        end

        function info(obj, message, varargin)
            obj.sendLog(Logger.INFO, 'INFO', message, varargin{:});
        end

        function warning(obj, message, varargin)
            obj.sendLog(Logger.WARNING, 'WARNING', message, varargin{:});
        end

        function error(obj, message, varargin)
            obj.sendLog(Logger.ERROR, 'ERROR', message, varargin{:});
        end
    end

    methods (Access = private)
        function sendLog(obj, numericLevel, levelName, message, varargin)
            if numericLevel < obj.minLevel
                return;
            end

            if ~isempty(varargin)
                try
                    message = sprintf(message, varargin{:});
                catch
                end
            end

            payload = struct();
            payload.type = 'log';
            payload.level = levelName;
            payload.message = message;
            if ~isempty(obj.source)
                payload.source = obj.source;
            end

            try
                send(obj.dataQueue, payload);
            catch
                % 忽略 DataQueue 发送失败（例如任务已取消/GUI 已关闭）
            end
        end
    end
end

