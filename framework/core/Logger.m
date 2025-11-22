classdef Logger < handle
    % Logger 日志系统
    % 支持多级别日志和文件输出
    %
    % 功能:
    %   - 4个日志级别 (DEBUG/INFO/WARNING/ERROR)
    %   - 控制台和文件输出
    %   - 时间戳和格式化
    %   - 日志级别过滤
    %   - 可配置的输出目标
    %
    % 示例:
    %   % 创建日志器
    %   logger = Logger(Logger.INFO, 'app.log');
    %
    %   % 输出不同级别的日志
    %   logger.debug('调试信息');
    %   logger.info('正常信息');
    %   logger.warning('警告信息');
    %   logger.error('错误信息');
    %
    %   % 格式化输出
    %   logger.info('优化进度: %d/%d', currentGen, maxGen);


    properties (Constant)
        DEBUG = 0;     % 调试级别
        INFO = 1;      % 信息级别
        WARNING = 2;   % 警告级别
        ERROR = 3;     % 错误级别
    end

    properties (Access = private)
        logLevel;         % 当前日志级别
        logFile;          % 日志文件路径
        enableConsole;    % 是否输出到控制台
        enableFile;       % 是否输出到文件
        fileHandle;       % 文件句柄
    end

    methods
        function obj = Logger(level, logFile, enableConsole, enableFile)
            % Logger 构造函数
            %
            % 输入:
            %   level - (可选) 日志级别，默认为INFO
            %   logFile - (可选) 日志文件路径，默认为空（不输出到文件）
            %   enableConsole - (可选) 是否输出到控制台，默认为true
            %   enableFile - (可选) 是否输出到文件，默认为true
            %
            % 示例:
            %   logger = Logger();                          % 只输出到控制台
            %   logger = Logger(Logger.DEBUG);              % 设置DEBUG级别
            %   logger = Logger(Logger.INFO, 'app.log');    % 输出到文件
            %   logger = Logger(Logger.WARNING, '', false); % 只输出到文件

            % 设置默认值
            if nargin < 1 || isempty(level)
                obj.logLevel = Logger.INFO;
            else
                obj.logLevel = level;
            end

            if nargin < 2
                logFile = '';
            end

            if nargin < 3
                enableConsole = true;
            end

            if nargin < 4
                enableFile = true;
            end

            obj.logFile = logFile;
            obj.enableConsole = enableConsole;
            obj.enableFile = enableFile;
            obj.fileHandle = -1;

            % 如果指定了日志文件且启用文件输出，打开文件
            if ~isempty(obj.logFile) && obj.enableFile
                obj.openLogFile();
            end
        end

        function delete(obj)
            % delete 析构函数，关闭日志文件
            obj.closeLogFile();
        end

        function debug(obj, message, varargin)
            % debug 输出DEBUG级别日志
            %
            % 输入:
            %   message - 日志消息（支持sprintf格式）
            %   varargin - 格式化参数
            %
            % 示例:
            %   logger.debug('变量值: x=%f, y=%f', x, y);

            obj.log(Logger.DEBUG, message, varargin{:});
        end

        function info(obj, message, varargin)
            % info 输出INFO级别日志
            %
            % 输入:
            %   message - 日志消息（支持sprintf格式）
            %   varargin - 格式化参数
            %
            % 示例:
            %   logger.info('开始优化，种群大小: %d', popSize);

            obj.log(Logger.INFO, message, varargin{:});
        end

        function warning(obj, message, varargin)
            % warning 输出WARNING级别日志
            %
            % 输入:
            %   message - 日志消息（支持sprintf格式）
            %   varargin - 格式化参数
            %
            % 示例:
            %   logger.warning('仿真耗时过长: %.2f秒', elapsedTime);

            obj.log(Logger.WARNING, message, varargin{:});
        end

        function error(obj, message, varargin)
            % error 输出ERROR级别日志
            %
            % 输入:
            %   message - 日志消息（支持sprintf格式）
            %   varargin - 格式化参数
            %
            % 示例:
            %   logger.error('仿真失败: %s', errorMsg);

            obj.log(Logger.ERROR, message, varargin{:});
        end

        function setLevel(obj, level)
            % setLevel 设置日志级别
            %
            % 输入:
            %   level - 新的日志级别
            %
            % 示例:
            %   logger.setLevel(Logger.DEBUG);

            obj.logLevel = level;
        end

        function level = getLevel(obj)
            % getLevel 获取当前日志级别
            %
            % 输出:
            %   level - 当前日志级别
            %
            % 示例:
            %   currentLevel = logger.getLevel();

            level = obj.logLevel;
        end

        function setEnableConsole(obj, enable)
            % setEnableConsole 设置是否输出到控制台
            %
            % 输入:
            %   enable - true/false
            %
            % 示例:
            %   logger.setEnableConsole(false);

            obj.enableConsole = enable;
        end

        function setEnableFile(obj, enable)
            % setEnableFile 设置是否输出到文件
            %
            % 输入:
            %   enable - true/false
            %
            % 示例:
            %   logger.setEnableFile(true);

            obj.enableFile = enable;

            if enable && ~isempty(obj.logFile) && obj.fileHandle == -1
                obj.openLogFile();
            elseif ~enable && obj.fileHandle ~= -1
                obj.closeLogFile();
            end
        end

        function setLogFile(obj, logFile)
            % setLogFile 设置日志文件路径
            %
            % 输入:
            %   logFile - 新的日志文件路径
            %
            % 示例:
            %   logger.setLogFile('new_log.log');

            % 关闭旧文件
            obj.closeLogFile();

            % 设置新文件
            obj.logFile = logFile;

            % 如果启用文件输出，打开新文件
            if obj.enableFile && ~isempty(obj.logFile)
                obj.openLogFile();
            end
        end
    end

    methods (Access = private)
        function log(obj, level, message, varargin)
            % log 内部日志方法
            %
            % 输入:
            %   level - 日志级别
            %   message - 日志消息
            %   varargin - 格式化参数

            % 级别过滤
            if level < obj.logLevel
                return;
            end

            % 格式化消息
            if ~isempty(varargin)
                try
                    message = sprintf(message, varargin{:});
                catch
                    % 格式化失败，使用原始消息
                end
            end

            % 获取时间戳
            timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');

            % 获取级别名称
            levelName = obj.getLevelName(level);

            % 构造日志行
            logLine = sprintf('[%s] [%s] %s', timestamp, levelName, message);

            % 输出到控制台
            if obj.enableConsole
                obj.printToConsole(level, logLine);
            end

            % 输出到文件
            if obj.enableFile && obj.fileHandle ~= -1
                obj.printToFile(logLine);
            end
        end

        function levelName = getLevelName(~, level)
            % getLevelName 获取级别名称
            %
            % 输入:
            %   level - 日志级别
            %
            % 输出:
            %   levelName - 级别名称字符串

            switch level
                case Logger.DEBUG
                    levelName = 'DEBUG';
                case Logger.INFO
                    levelName = 'INFO';
                case Logger.WARNING
                    levelName = 'WARNING';
                case Logger.ERROR
                    levelName = 'ERROR';
                otherwise
                    levelName = 'UNKNOWN';
            end
        end

        function printToConsole(~, level, logLine)
            % printToConsole 输出到控制台
            %
            % 输入:
            %   level - 日志级别
            %   logLine - 日志行

            % 根据级别使用不同的输出方式
            if level >= Logger.ERROR
                fprintf(2, '%s\n', logLine);  % 输出到stderr
            else
                fprintf('%s\n', logLine);
            end
        end

        function printToFile(obj, logLine)
            % printToFile 输出到文件
            %
            % 输入:
            %   logLine - 日志行

            if obj.fileHandle ~= -1
                try
                    fprintf(obj.fileHandle, '%s\n', logLine);
                    % 立即刷新到磁盘
                    fflush(obj.fileHandle);
                catch
                    % 写入失败，静默处理
                end
            end
        end

        function openLogFile(obj)
            % openLogFile 打开日志文件

            try
                % 确保日志文件目录存在
                [logDir, ~, ~] = fileparts(obj.logFile);
                if ~isempty(logDir) && ~exist(logDir, 'dir')
                    mkdir(logDir);
                end

                % 以追加模式打开文件
                obj.fileHandle = fopen(obj.logFile, 'a', 'n', 'UTF-8');

                if obj.fileHandle == -1
                    warning('Logger:FileOpenError', '无法打开日志文件: %s', obj.logFile);
                end
            catch ME
                warning('Logger:FileOpenError', '打开日志文件失败: %s\n原因: %s', ...
                        obj.logFile, ME.message);
            end
        end

        function closeLogFile(obj)
            % closeLogFile 关闭日志文件

            if obj.fileHandle ~= -1
                try
                    fclose(obj.fileHandle);
                catch
                    % 关闭失败，静默处理
                end
                obj.fileHandle = -1;
            end
        end
    end

    methods (Static)
        function logger = getLogger(name, level, logFile)
            % getLogger 获取或创建命名日志器（单例模式）
            %
            % 输入:
            %   name - 日志器名称
            %   level - (可选) 日志级别
            %   logFile - (可选) 日志文件路径
            %
            % 输出:
            %   logger - Logger实例
            %
            % 示例:
            %   logger = Logger.getLogger('OptimizationLogger');

            persistent loggerMap;

            if isempty(loggerMap)
                loggerMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
            end

            if ~loggerMap.isKey(name)
                if nargin < 2
                    level = Logger.INFO;
                end
                if nargin < 3
                    logFile = '';
                end
                loggerMap(name) = Logger(level, logFile);
            end

            logger = loggerMap(name);
        end

        function levelStr = levelToString(level)
            % levelToString 将级别转换为字符串
            %
            % 输入:
            %   level - 日志级别常量
            %
            % 输出:
            %   levelStr - 级别字符串
            %
            % 示例:
            %   str = Logger.levelToString(Logger.INFO);

            switch level
                case Logger.DEBUG
                    levelStr = 'DEBUG';
                case Logger.INFO
                    levelStr = 'INFO';
                case Logger.WARNING
                    levelStr = 'WARNING';
                case Logger.ERROR
                    levelStr = 'ERROR';
                otherwise
                    levelStr = 'UNKNOWN';
            end
        end

        function level = stringToLevel(levelStr)
            % stringToLevel 将字符串转换为级别
            %
            % 输入:
            %   levelStr - 级别字符串
            %
            % 输出:
            %   level - 日志级别常量
            %
            % 示例:
            %   level = Logger.stringToLevel('INFO');

            switch upper(levelStr)
                case 'DEBUG'
                    level = Logger.DEBUG;
                case 'INFO'
                    level = Logger.INFO;
                case {'WARNING', 'WARN'}
                    level = Logger.WARNING;
                case 'ERROR'
                    level = Logger.ERROR;
                otherwise
                    level = Logger.INFO;
            end
        end
    end
end
