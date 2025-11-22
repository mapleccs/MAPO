classdef MATLABSimulator < SimulatorBase
    % MATLABSimulator MATLAB函数仿真器
    % 通过MATLAB函数进行仿真计算
    %
    % 功能:
    %   - 执行MATLAB函数作为仿真模型
    %   - 支持函数句柄和函数名字符串
    %   - 传递变量作为函数参数
    %   - 返回结果结构体或向量
    %   - 超时控制
    %   - 函数缓存机制
    %
    % 示例:
    %   % 方式1: 使用函数句柄
    %   config = SimulatorConfig('MATLAB');
    %   config.set('functionHandle', @mySimulationFunction);
    %   config.set('timeout', 60);
    %
    %   simulator = MATLABSimulator();
    %   simulator.connect(config);
    %   simulator.setVariables([1.0, 2.0, 3.0]);
    %   success = simulator.run();
    %   results = simulator.getResults({'obj1', 'obj2'});
    %
    %   % 方式2: 使用函数名
    %   config = SimulatorConfig('MATLAB');
    %   config.set('functionName', 'mySimulationFunction');
    %   config.set('functionPath', 'C:/Functions');
    %   config.set('resultKeys', {'obj1', 'obj2', 'constraint1'});


    properties (Access = private)
        functionHandle;     % 函数句柄
        functionName;       % 函数名称
        functionPath;       % 函数路径
        currentVariables;   % 当前变量值
        lastResults;        % 最后一次结果
        resultKeys;         % 结果键名列表
        outputFormat;       % 输出格式 ('struct' 或 'vector')
        inputFormat;        % 输入格式 ('vector', 'struct', 'cell')
        pathAdded;          % 是否已添加路径
    end

    methods
        function obj = MATLABSimulator()
            % MATLABSimulator 构造函数
            %
            % 示例:
            %   simulator = MATLABSimulator();

            % 调用父类构造函数
            obj@SimulatorBase();

            % 初始化属性
            obj.functionHandle = [];
            obj.functionName = '';
            obj.functionPath = '';
            obj.currentVariables = [];
            obj.lastResults = struct();
            obj.resultKeys = {};
            obj.outputFormat = 'struct';
            obj.inputFormat = 'vector';
            obj.pathAdded = false;
        end

        function connect(obj, config)
            % connect 连接MATLAB仿真器
            %
            % 输入:
            %   config - SimulatorConfig对象
            %
            % 配置参数:
            %   functionHandle - 函数句柄（优先）
            %   functionName - 函数名称字符串
            %   functionPath - 函数文件路径（可选）
            %   resultKeys - 结果键名的cell array
            %   outputFormat - 'struct' 或 'vector'（默认'struct'）
            %   inputFormat - 'vector', 'struct', 'cell'（默认'vector'）
            %
            % 抛出:
            %   错误 - 如果配置无效

            obj.config = config;

            % 验证配置
            if ~obj.validate()
                error('MATLABSimulator:InvalidConfig', '配置验证失败');
            end

            obj.logMessage('INFO', '正在连接MATLAB仿真器...');

            % 获取函数句柄
            funcHandle = obj.getConfigValue('functionHandle', []);
            if ~isempty(funcHandle) && isa(funcHandle, 'function_handle')
                obj.functionHandle = funcHandle;
                obj.functionName = func2str(funcHandle);
                obj.logMessage('INFO', '使用函数句柄: %s', obj.functionName);
            else
                % 使用函数名称
                obj.functionName = obj.getConfigValue('functionName', '');
                if isempty(obj.functionName)
                    error('MATLABSimulator:NoFunction', ...
                          '必须提供functionHandle或functionName');
                end

                % 添加函数路径
                obj.functionPath = obj.getConfigValue('functionPath', '');
                if ~isempty(obj.functionPath)
                    if exist(obj.functionPath, 'dir')
                        addpath(obj.functionPath);
                        obj.pathAdded = true;
                        obj.logMessage('INFO', '已添加路径: %s', obj.functionPath);
                    else
                        warning('MATLABSimulator:PathNotFound', ...
                                '函数路径不存在: %s', obj.functionPath);
                    end
                end

                % 检查函数是否存在
                if exist(obj.functionName, 'file') ~= 2
                    error('MATLABSimulator:FunctionNotFound', ...
                          '函数不存在: %s', obj.functionName);
                end

                % 创建函数句柄
                try
                    obj.functionHandle = str2func(obj.functionName);
                    obj.logMessage('INFO', '使用函数: %s', obj.functionName);
                catch ME
                    error('MATLABSimulator:InvalidFunction', ...
                          '无法创建函数句柄: %s', ME.message);
                end
            end

            % 获取其他配置
            obj.resultKeys = obj.getConfigValue('resultKeys', {});
            obj.outputFormat = obj.getConfigValue('outputFormat', 'struct');
            obj.inputFormat = obj.getConfigValue('inputFormat', 'vector');

            % 设置变量名称
            if isa(obj.config, 'SimulatorConfig')
                varNames = obj.config.getVariableNames();
                if ~isempty(varNames)
                    obj.setVariableNames(varNames);
                end
            end

            % 设置连接状态
            obj.setConnected(true);
            obj.logMessage('INFO', 'MATLAB仿真器连接成功');
        end

        function disconnect(obj)
            % disconnect 断开MATLAB仿真器连接

            if ~obj.connected
                return;
            end

            obj.logMessage('INFO', '正在断开MATLAB仿真器连接...');

            % 移除添加的路径
            if obj.pathAdded && ~isempty(obj.functionPath)
                try
                    rmpath(obj.functionPath);
                    obj.logMessage('INFO', '已移除路径: %s', obj.functionPath);
                catch
                    % 忽略错误
                end
                obj.pathAdded = false;
            end

            % 清理
            obj.functionHandle = [];
            obj.currentVariables = [];
            obj.lastResults = struct();

            obj.setConnected(false);
            obj.logMessage('INFO', 'MATLAB仿真器已断开');
        end

        function setVariables(obj, variables)
            % setVariables 设置仿真变量
            %
            % 输入:
            %   variables - 变量值向量、结构体或cell array

            obj.ensureConnected();

            obj.logMessage('DEBUG', '设置变量...');

            % 验证变量
            if ~isempty(obj.variableNames)
                obj.validateVariables(variables);
            end

            % 保存变量
            obj.currentVariables = variables;

            obj.logMessage('INFO', '变量设置完成');
        end

        function success = run(obj, timeout)
            % run 运行MATLAB仿真
            %
            % 输入:
            %   timeout - (可选) 超时时间（秒）
            %
            % 输出:
            %   success - 布尔值，仿真是否成功

            obj.ensureConnected();

            if nargin < 2
                timeout = obj.getConfigValue('timeout', 300);
            end

            if isempty(obj.currentVariables)
                error('MATLABSimulator:NoVariables', '未设置变量');
            end

            obj.logMessage('INFO', '开始运行仿真 (超时: %d秒)...', timeout);

            startTime = tic;

            try
                % 准备输入参数
                inputArgs = obj.prepareInputArgs();

                % 执行函数（使用超时）
                timerObj = timer('StartDelay', timeout, ...
                                 'TimerFcn', @(~,~) error('MATLABSimulator:Timeout', '仿真超时'));
                start(timerObj);

                try
                    % 调用函数
                    obj.logMessage('DEBUG', '执行函数: %s', obj.functionName);
                    result = obj.functionHandle(inputArgs{:});

                    % 停止定时器
                    stop(timerObj);
                    delete(timerObj);

                catch ME
                    % 停止定时器
                    try
                        stop(timerObj);
                        delete(timerObj);
                    catch
                    end
                    rethrow(ME);
                end

                elapsed = toc(startTime);

                % 处理结果
                obj.lastResults = obj.processResults(result);

                success = true;
                obj.setLastRunStatus(true);
                obj.logMessage('INFO', '仿真成功完成 (耗时: %.2f秒)', elapsed);

            catch ME
                elapsed = toc(startTime);

                success = false;
                obj.setLastRunStatus(false, ME.message);
                obj.handleError(ME);
                obj.logMessage('ERROR', '仿真失败 (耗时: %.2f秒): %s', elapsed, ME.message);
            end
        end

        function results = getResults(obj, keys)
            % getResults 获取仿真结果
            %
            % 输入:
            %   keys - 结果键的cell array（可选）
            %
            % 输出:
            %   results - 结果结构体

            obj.ensureConnected();

            if isempty(obj.lastResults)
                error('MATLABSimulator:NoResults', '没有可用结果');
            end

            if nargin < 2 || isempty(keys)
                % 返回所有结果
                results = obj.lastResults;
                obj.logMessage('DEBUG', '返回所有结果 (%d个)', length(fieldnames(results)));
            else
                % 返回指定键的结果
                results = struct();
                obj.logMessage('DEBUG', '获取%d个结果...', length(keys));

                for i = 1:length(keys)
                    key = keys{i};
                    if isfield(obj.lastResults, key)
                        results.(key) = obj.lastResults.(key);
                        obj.logMessage('DEBUG', '  %s = %.6g', key, results.(key));
                    else
                        warning('MATLABSimulator:KeyNotFound', ...
                                '结果中不存在键: %s', key);
                        results.(key) = NaN;
                    end
                end
            end

            obj.logMessage('INFO', '结果获取完成');
        end

        function clearResults(obj)
            % clearResults 清除上次结果
            %
            % 示例:
            %   simulator.clearResults();

            obj.lastResults = struct();
        end
    end

    methods (Access = protected)
        function valid = validate(obj)
            % validate 验证配置

            valid = false;

            if isempty(obj.config)
                warning('MATLABSimulator:NoConfig', '缺少配置');
                return;
            end

            % 检查函数配置
            funcHandle = obj.getConfigValue('functionHandle', []);
            funcName = obj.getConfigValue('functionName', '');

            if isempty(funcHandle) && isempty(funcName)
                warning('MATLABSimulator:NoFunction', ...
                        '必须提供functionHandle或functionName');
                return;
            end

            valid = true;
        end

        function inputArgs = prepareInputArgs(obj)
            % prepareInputArgs 准备函数输入参数
            %
            % 输出:
            %   inputArgs - cell array of arguments

            switch lower(obj.inputFormat)
                case 'vector'
                    % 向量形式：单个参数
                    if isstruct(obj.currentVariables)
                        % 如果是结构体，转换为向量
                        if ~isempty(obj.variableNames)
                            vec = zeros(1, length(obj.variableNames));
                            for i = 1:length(obj.variableNames)
                                varName = obj.variableNames{i};
                                if isfield(obj.currentVariables, varName)
                                    vec(i) = obj.currentVariables.(varName);
                                end
                            end
                            inputArgs = {vec};
                        else
                            values = struct2cell(obj.currentVariables);
                            inputArgs = {cell2mat(values)};
                        end
                    else
                        inputArgs = {obj.currentVariables};
                    end

                case 'struct'
                    % 结构体形式：单个参数
                    if isstruct(obj.currentVariables)
                        inputArgs = {obj.currentVariables};
                    else
                        % 向量转结构体
                        if ~isempty(obj.variableNames)
                            s = struct();
                            for i = 1:length(obj.variableNames)
                                varName = obj.variableNames{i};
                                s.(varName) = obj.currentVariables(i);
                            end
                            inputArgs = {s};
                        else
                            error('MATLABSimulator:NoVariableNames', ...
                                  '结构体输入格式需要变量名称');
                        end
                    end

                case 'cell'
                    % Cell array形式：多个参数
                    if iscell(obj.currentVariables)
                        inputArgs = obj.currentVariables;
                    elseif isstruct(obj.currentVariables)
                        inputArgs = struct2cell(obj.currentVariables);
                    else
                        inputArgs = num2cell(obj.currentVariables);
                    end

                otherwise
                    error('MATLABSimulator:InvalidInputFormat', ...
                          '无效的输入格式: %s', obj.inputFormat);
            end
        end

        function results = processResults(obj, result)
            % processResults 处理函数返回结果
            %
            % 输入:
            %   result - 函数返回值
            %
            % 输出:
            %   results - 结果结构体

            if isstruct(result)
                % 已经是结构体
                results = result;

            elseif isnumeric(result)
                % 数值向量/矩阵
                if strcmp(obj.outputFormat, 'struct')
                    % 转换为结构体
                    results = struct();

                    if ~isempty(obj.resultKeys)
                        % 使用提供的键名
                        for i = 1:min(length(obj.resultKeys), length(result))
                            key = obj.resultKeys{i};
                            results.(key) = result(i);
                        end
                    else
                        % 使用默认键名
                        for i = 1:length(result)
                            key = sprintf('result%d', i);
                            results.(key) = result(i);
                        end
                    end
                else
                    % 保持向量形式，但包装在结构体中
                    results.values = result;
                end

            elseif iscell(result)
                % Cell array
                results = struct();
                if ~isempty(obj.resultKeys)
                    for i = 1:min(length(obj.resultKeys), length(result))
                        key = obj.resultKeys{i};
                        results.(key) = result{i};
                    end
                else
                    for i = 1:length(result)
                        key = sprintf('result%d', i);
                        results.(key) = result{i};
                    end
                end

            else
                % 其他类型
                warning('MATLABSimulator:UnexpectedResultType', ...
                        '意外的结果类型: %s', class(result));
                results.value = result;
            end
        end
    end

    methods (Static)
        function type = getSimulatorType()
            % getSimulatorType 获取仿真器类型
            %
            % 输出:
            %   type - 'MATLAB'

            type = 'MATLAB';
        end

        function result = exampleFunction(x)
            % exampleFunction 示例仿真函数
            %
            % 输入:
            %   x - 变量向量 [1×n]
            %
            % 输出:
            %   result - 结果结构体
            %
            % 示例:
            %   x = [1.0, 2.0, 3.0];
            %   result = MATLABSimulator.exampleFunction(x);

            % 示例：简单的数学函数
            result = struct();
            result.obj1 = sum(x.^2);
            result.obj2 = sum((x - 1).^2);
            result.constraint1 = sum(x) - 5;
        end
    end
end
