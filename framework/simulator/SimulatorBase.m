classdef (Abstract) SimulatorBase < ISimulator
    % SimulatorBase 仿真器抽象基类
    % 继承ISimulator接口，提供通用功能实现
    %
    % 功能:
    %   - 实现ISimulator的部分通用方法
    %   - 提供日志记录功能
    %   - 提供错误处理机制
    %   - 提供状态管理辅助方法
    %   - 减少子类重复代码
    %
    % 使用方法:
    %   子类继承此基类，只需实现核心抽象方法
    %
    % 示例:
    %   classdef MySimulator < SimulatorBase
    %       methods
    %           function connect(obj, config)
    %               obj.config = config;
    %               % 实现连接逻辑
    %               obj.setConnected(true);
    %               obj.logMessage('INFO', '连接成功');
    %           end
    %
    %           % 实现其他抽象方法...
    %       end
    %   end

    properties (Access = protected)
        logger;              % Logger对象（可选）
        enableLogging;       % 是否启用日志
        variableNames;       % 变量名称列表
        lastError;           % 最后一次错误信息
        logFilePath;         % 日志文件路径
        logFileHandle;       % 日志文件句柄
    end

    methods
        function obj = SimulatorBase()
            % SimulatorBase 构造函数
            %
            % 示例:
            %   simulator = MySimulator();

            % 调用父类构造函数
            obj@ISimulator();

            % 初始化属性
            obj.logger = [];
            obj.enableLogging = false;
            obj.variableNames = {};
            obj.lastError = '';
            obj.logFilePath = '';
            obj.logFileHandle = [];
        end

        function setLogger(obj, logger)
            % setLogger 设置日志器
            %
            % 输入:
            %   logger - Logger对象
            %
            % 示例:
            %   logger = Logger(Logger.INFO, 'simulator.log');
            %   simulator.setLogger(logger);

            if isa(logger, 'Logger')
                obj.logger = logger;
                obj.enableLogging = true;
            else
                warning('SimulatorBase:InvalidLogger', '输入必须是Logger对象');
            end
        end

        function enableLog(obj, enable)
            % enableLog 启用/禁用日志
            %
            % 输入:
            %   enable - 布尔值
            %
            % 示例:
            %   simulator.enableLog(true);

            obj.enableLogging = enable;
        end

        function setLogFile(obj, logFilePath)
            % setLogFile 设置日志文件路径
            %
            % 输入:
            %   logFilePath - 日志文件路径（.txt文件）
            %
            % 示例:
            %   simulator.setLogFile('logs/simulation.txt');

            % 关闭之前的日志文件
            if ~isempty(obj.logFileHandle)
                try
                    fclose(obj.logFileHandle);
                catch
                end
                obj.logFileHandle = [];
            end

            % 确保目录存在
            [logDir, ~, ~] = fileparts(logFilePath);
            if ~isempty(logDir) && ~exist(logDir, 'dir')
                mkdir(logDir);
            end

            % 打开新的日志文件
            obj.logFilePath = logFilePath;
            try
                obj.logFileHandle = fopen(logFilePath, 'a');  % 追加模式
                if obj.logFileHandle == -1
                    warning('SimulatorBase:LogFileError', '无法打开日志文件: %s', logFilePath);
                    obj.logFilePath = '';
                else
                    % 写入分隔线和时间戳
                    fprintf(obj.logFileHandle, '\n========================================\n');
                    fprintf(obj.logFileHandle, '日志开始时间: %s\n', datestr(now));
                    fprintf(obj.logFileHandle, '========================================\n');
                end
            catch ME
                warning('SimulatorBase:LogFileError', '打开日志文件失败: %s', ME.message);
                obj.logFilePath = '';
                obj.logFileHandle = [];
            end
        end

        function reset(obj)
            % reset 重置仿真器状态
            %
            % 说明:
            %   重置运行计数器和状态标志
            %   子类可以覆盖此方法实现更复杂的重置逻辑
            %
            % 示例:
            %   simulator.reset();

            obj.lastRunSuccess = false;
            obj.lastError = '';
            obj.logMessage('INFO', '仿真器已重置');
        end

        function status = getStatus(obj)
            % getStatus 获取仿真器详细状态
            %
            % 输出:
            %   status - 状态结构体
            %
            % 示例:
            %   status = simulator.getStatus();
            %   disp(status);

            status = struct();
            status.connected = obj.connected;
            status.lastRunSuccess = obj.lastRunSuccess;
            status.runCount = obj.runCount;
            status.configType = '';
            status.lastError = obj.lastError;

            if ~isempty(obj.config)
                if isa(obj.config, 'SimulatorConfig')
                    status.configType = obj.config.simulatorType;
                else
                    status.configType = 'Custom';
                end
            end
        end

        function error = getLastError(obj)
            % getLastError 获取最后一次错误信息
            %
            % 输出:
            %   error - 错误信息字符串
            %
            % 示例:
            %   if ~simulator.wasLastRunSuccessful()
            %       fprintf('错误: %s\n', simulator.getLastError());
            %   end

            error = obj.lastError;
        end

        function validateVariables(obj, variables)
            % validateVariables 验证变量输入
            %
            % 输入:
            %   variables - 变量值向量或结构体
            %
            % 说明:
            %   验证变量的类型和数量
            %   子类可以覆盖此方法实现特定验证
            %
            % 抛出:
            %   错误 - 如果验证失败

            if isstruct(variables)
                % 结构体形式
                if ~isempty(obj.variableNames)
                    fields = fieldnames(variables);
                    if length(fields) ~= length(obj.variableNames)
                        error('SimulatorBase:VariableCountMismatch', ...
                              '变量数量不匹配: 期望%d，实际%d', ...
                              length(obj.variableNames), length(fields));
                    end
                end
            elseif isnumeric(variables)
                % 向量形式
                if ~isempty(obj.variableNames)
                    if length(variables) ~= length(obj.variableNames)
                        error('SimulatorBase:VariableCountMismatch', ...
                              '变量数量不匹配: 期望%d，实际%d', ...
                              length(obj.variableNames), length(variables));
                    end
                end
            else
                error('SimulatorBase:InvalidVariableType', ...
                      '变量必须是向量或结构体');
            end
        end

        function setVariableNames(obj, names)
            % setVariableNames 设置变量名称列表
            %
            % 输入:
            %   names - 变量名称的cell array
            %
            % 示例:
            %   simulator.setVariableNames({'x1', 'x2', 'x3'});

            if iscell(names)
                obj.variableNames = names;
            else
                error('SimulatorBase:InvalidInput', '变量名称必须是cell array');
            end
        end

        function names = getVariableNames(obj)
            % getVariableNames 获取变量名称列表
            %
            % 输出:
            %   names - 变量名称的cell array
            %
            % 示例:
            %   names = simulator.getVariableNames();

            names = obj.variableNames;
        end
    end

    methods (Access = protected)
        function logMessage(obj, level, message, varargin)
            % logMessage 记录日志消息
            %
            % 输入:
            %   level - 日志级别 ('DEBUG', 'INFO', 'WARNING', 'ERROR')
            %   message - 消息字符串（支持sprintf格式）
            %   varargin - 格式化参数
            %
            % 示例:
            %   obj.logMessage('INFO', '开始仿真');
            %   obj.logMessage('WARNING', '仿真耗时: %.2f秒', elapsedTime);

            % 格式化消息
            if ~isempty(varargin)
                message = sprintf(message, varargin{:});
            end

            % 添加时间戳和级别
            timestamp = datestr(now, 'HH:MM:SS');
            formattedMessage = sprintf('[%s] [%s] %s', timestamp, upper(level), message);

            % 输出到命令行窗口
            fprintf('%s\n', formattedMessage);

            % 输出到日志文件
            if ~isempty(obj.logFileHandle) && obj.logFileHandle ~= -1
                try
                    fprintf(obj.logFileHandle, '%s\n', formattedMessage);
                catch
                    % 忽略文件写入错误
                end
            end

            % 如果有logger且启用了日志，也使用logger
            if obj.enableLogging && ~isempty(obj.logger)
                % 根据级别调用logger方法
                switch upper(level)
                    case 'DEBUG'
                        obj.logger.debug(message);
                    case 'INFO'
                        obj.logger.info(message);
                    case 'WARNING'
                        obj.logger.warning(message);
                    case 'ERROR'
                        obj.logger.error(message);
                    otherwise
                        obj.logger.info(message);
                end
            end
        end

        function handleError(obj, ME)
            % handleError 处理错误
            %
            % 输入:
            %   ME - MException对象
            %
            % 说明:
            %   记录错误信息到日志和lastError属性

            obj.lastError = ME.message;
            obj.logMessage('ERROR', 'Error: %s', ME.message);
            obj.logMessage('ERROR', 'Stack: %s', ME.stack(1).name);
        end

        function setConnected(obj, connected)
            % setConnected 设置连接状态
            %
            % 输入:
            %   connected - 布尔值
            %
            % 说明:
            %   子类应在连接/断开时调用此方法

            obj.connected = connected;
            if connected
                obj.logMessage('INFO', '仿真器已连接');
            else
                obj.logMessage('INFO', '仿真器已断开');
            end
        end

        function incrementRunCount(obj)
            % incrementRunCount 增加运行计数
            %
            % 说明:
            %   子类在成功运行仿真后应调用此方法

            obj.runCount = obj.runCount + 1;
        end

        function setLastRunStatus(obj, success, errorMsg)
            % setLastRunStatus 设置上次运行状态
            %
            % 输入:
            %   success - 布尔值，是否成功
            %   errorMsg - (可选) 错误消息
            %
            % 说明:
            %   子类在运行仿真后应调用此方法

            if nargin < 3
                errorMsg = '';
            end

            obj.lastRunSuccess = success;

            if success
                obj.incrementRunCount();
                obj.lastError = '';
                obj.logMessage('INFO', '仿真运行成功 (第%d次)', obj.runCount);
            else
                obj.lastError = errorMsg;
                obj.logMessage('ERROR', '仿真运行失败: %s', errorMsg);
            end
        end

        function ensureConnected(obj)
            % ensureConnected 确保仿真器已连接
            %
            % 抛出:
            %   错误 - 如果未连接
            %
            % 说明:
            %   子类在运行仿真前应调用此方法检查连接状态

            if ~obj.connected
                error('SimulatorBase:NotConnected', '仿真器未连接');
            end
        end

        function value = getConfigValue(obj, key, defaultValue)
            % getConfigValue 从配置中获取值
            %
            % 输入:
            %   key - 配置键
            %   defaultValue - 默认值
            %
            % 输出:
            %   value - 配置值
            %
            % 说明:
            %   辅助方法，用于从配置对象中提取值

            if nargin < 3
                defaultValue = [];
            end

            if isempty(obj.config)
                value = defaultValue;
                return;
            end

            if isa(obj.config, 'SimulatorConfig')
                value = obj.config.get(key, defaultValue);
            elseif isstruct(obj.config) && isfield(obj.config, key)
                value = obj.config.(key);
            else
                value = defaultValue;
            end
        end

        function checkTimeout(obj, startTime, timeout)
            % checkTimeout 检查是否超时
            %
            % 输入:
            %   startTime - 开始时间（使用tic/toc）
            %   timeout - 超时时间（秒）
            %
            % 抛出:
            %   错误 - 如果超时
            %
            % 示例:
            %   startTime = tic;
            %   % ... 运行仿真 ...
            %   obj.checkTimeout(startTime, 300);

            elapsed = toc(startTime);
            if elapsed > timeout
                error('SimulatorBase:Timeout', ...
                      '仿真超时: %.1f秒 (限制: %.1f秒)', elapsed, timeout);
            end
        end

        function delete(obj)
            % delete 析构函数
            % 关闭日志文件句柄

            if ~isempty(obj.logFileHandle) && obj.logFileHandle ~= -1
                try
                    fprintf(obj.logFileHandle, '========================================\n');
                    fprintf(obj.logFileHandle, '日志结束时间: %s\n', datestr(now));
                    fprintf(obj.logFileHandle, '========================================\n\n');
                    fclose(obj.logFileHandle);
                catch
                    % 忽略关闭错误
                end
            end
        end
    end

    methods (Static)
        function type = getSimulatorType()
            % getSimulatorType 获取仿真器类型
            %
            % 输出:
            %   type - 仿真器类型字符串
            %
            % 说明:
            %   子类应覆盖此方法返回具体类型

            type = 'Base';
        end
    end
end
