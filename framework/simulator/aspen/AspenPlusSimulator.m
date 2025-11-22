classdef AspenPlusSimulator < SimulatorBase
    % AspenPlusSimulator Aspen Plus仿真器适配器
    % 通过COM接口与Aspen Plus交互
    %
    % 功能:
    %   - 连接到Aspen Plus
    %   - 加载备份文件(.bkp)
    %   - 设置变量到Aspen节点
    %   - 运行仿真并获取结果
    %   - RPC错误自动重连
    %
    % 示例:
    %   % 创建配置
    %   config = SimulatorConfig('Aspen');
    %   config.set('modelPath', 'C:/Models/distillation.bkp');
    %   config.set('timeout', 300);
    %   config.set('visible', false);
    %   config.setNodeMapping('temperature', '\Data\Blocks\B1\Input\TEMP');
    %   config.setNodeMapping('stages', '\Data\Blocks\B2\Input\NSTAGE');
    %
    %   % 创建并使用仿真器
    %   simulator = AspenPlusSimulator();
    %   simulator.connect(config);
    %   simulator.setVariables([100, 20]);
    %   success = simulator.run(300);
    %   results = simulator.getResults({'TAC', 'Purity'});
    %   simulator.disconnect();


    properties (Access = private)
        aspenApp;           % Aspen COM对象
        maxRetries;         % 最大重连次数
        retryDelay;         % 重连延迟（秒）
        autoSave;           % 是否自动保存
    end

    methods
        function obj = AspenPlusSimulator()
            % AspenPlusSimulator 构造函数
            %
            % 示例:
            %   simulator = AspenPlusSimulator();

            % 调用父类构造函数
            obj@SimulatorBase();

            % 初始化属性
            obj.aspenApp = [];
            obj.maxRetries = 3;
            obj.retryDelay = 2;
            obj.autoSave = false;
        end

        function connect(obj, config)
            % connect 连接到Aspen Plus
            %
            % 输入:
            %   config - SimulatorConfig对象
            %
            % 抛出:
            %   错误 - 如果连接失败

            obj.config = config;

            % 验证配置
            if ~obj.validate()
                error('AspenPlusSimulator:InvalidConfig', '配置验证失败');
            end

            % 获取配置参数
            modelPath = obj.getConfigValue('modelPath', '');
            visible = obj.getConfigValue('visible', false);
            obj.autoSave = obj.getConfigValue('autoSave', false);

            % 检查文件是否存在
            if ~exist(modelPath, 'file')
                error('AspenPlusSimulator:FileNotFound', ...
                      '备份文件不存在: %s', modelPath);
            end

            obj.logMessage('INFO', '正在连接Aspen Plus...');
            obj.logMessage('INFO', '模型文件: %s', modelPath);
            obj.logMessage('INFO', 'Aspen窗口可见性: %s', mat2str(visible));

            try
                % 创建Aspen COM对象
                obj.aspenApp = actxserver('Apwn.Document');

                % 使用invoke方法从备份文件初始化
                obj.aspenApp.invoke('InitFromArchive2', modelPath);

                % 设置Aspen窗口可见性和对话框抑制
                if visible
                    obj.aspenApp.Visible = 1;
                else
                    obj.aspenApp.Visible = 0;
                end
                obj.aspenApp.SuppressDialogs = 1;

                % 首次运行以初始化
                obj.logMessage('INFO', '正在进行首次初始化运行...');
                obj.aspenApp.Engine.Run2(1);
                obj.waitForSimulation(obj.getConfigValue('timeout', 300));

                % 设置连接状态
                obj.setConnected(true);
                obj.logMessage('INFO', 'Aspen Plus连接成功');

            catch ME
                % 清理COM对象
                if ~isempty(obj.aspenApp)
                    try
                        delete(obj.aspenApp);
                    catch
                    end
                    obj.aspenApp = [];
                end
                obj.handleError(ME);
                error('AspenPlusSimulator:ConnectionFailed', ...
                      '连接Aspen Plus失败: %s', ME.message);
            end
        end

        function disconnect(obj)
            % disconnect 断开与Aspen Plus的连接

            if ~obj.connected
                return;
            end

            obj.logMessage('INFO', '正在断开Aspen Plus连接...');

            try
                % 保存（如果启用）
                if obj.autoSave && ~isempty(obj.aspenApp)
                    obj.logMessage('INFO', '保存模型...');
                    obj.aspenApp.Save();
                end

                % 关闭Aspen
                if ~isempty(obj.aspenApp)
                    obj.aspenApp.Close();
                    delete(obj.aspenApp);
                    obj.aspenApp = [];
                end

                obj.setConnected(false);
                obj.logMessage('INFO', 'Aspen Plus已断开');

            catch ME
                obj.handleError(ME);
                warning('AspenPlusSimulator:DisconnectWarning', ...
                        '断开连接时出现警告: %s', ME.message);
            end
        end

        function setVariables(obj, variables)
            % setVariables 设置变量到Aspen节点
            %
            % 输入:
            %   variables - 变量值向量 [1×n] 或结构体

            obj.ensureConnected();

            % 获取节点映射
            if ~isa(obj.config, 'SimulatorConfig')
                error('AspenPlusSimulator:InvalidConfig', ...
                      '配置必须是SimulatorConfig对象');
            end

            varNames = obj.config.getVariableNames();

            if isempty(varNames)
                error('AspenPlusSimulator:NoMapping', '未定义节点映射');
            end

            obj.logMessage('DEBUG', '设置%d个变量...', length(varNames));

            try
                if isstruct(variables)
                    % 结构体形式
                    for i = 1:length(varNames)
                        varName = varNames{i};
                        if isfield(variables, varName)
                            value = variables.(varName);
                            nodePath = obj.config.getNodePath(varName);
                            obj.setNodeValue(nodePath, value);
                        end
                    end
                else
                    % 向量形式
                    if length(variables) ~= length(varNames)
                        error('AspenPlusSimulator:SizeMismatch', ...
                              '变量数量不匹配: 期望%d，实际%d', ...
                              length(varNames), length(variables));
                    end

                    for i = 1:length(varNames)
                        varName = varNames{i};
                        value = variables(i);
                        nodePath = obj.config.getNodePath(varName);
                        obj.setNodeValue(nodePath, value);
                        obj.logMessage('DEBUG', '  %s = %.4g -> %s', ...
                                      varName, value, nodePath);
                    end
                end

                obj.logMessage('INFO', '变量设置完成');

            catch ME
                % 检查是否为RPC错误
                if obj.isRPCError(ME)
                    obj.handleRPCError();
                    % 重试设置变量
                    obj.setVariables(variables);
                else
                    obj.handleError(ME);
                    error('AspenPlusSimulator:SetVariablesFailed', ...
                          '设置变量失败: %s', ME.message);
                end
            end
        end

        function success = run(obj, timeout)
            % run 运行Aspen Plus仿真
            %
            % 输入:
            %   timeout - (可选) 超时时间（秒），默认从配置读取
            %
            % 输出:
            %   success - 布尔值，仿真是否成功

            obj.ensureConnected();

            if nargin < 2
                timeout = obj.getConfigValue('timeout', 300);
            end

            obj.logMessage('INFO', '开始运行仿真 (超时: %d秒)...', timeout);

            startTime = tic;

            try
                % Reinit - 在Reinit之前添加延迟，确保所有参数设置完成
                pause(0.5);
                obj.logMessage('DEBUG', '执行Reinit...');
                obj.aspenApp.Reinit();

                % Reinit和Run2之间添加延迟
                pause(0.2);
                obj.checkTimeout(startTime, timeout);

                % Run - 使用Engine.Run2(1)
                obj.logMessage('DEBUG', '执行Run...');
                obj.aspenApp.Engine.Run2(1);

                % 等待仿真完成（使用2秒间隔，与成功项目一致）
                while obj.aspenApp.Engine.IsRunning == 1
                    pause(2);
                    obj.checkTimeout(startTime, timeout);
                end

                obj.logMessage('DEBUG', 'Engine已停止运行');

                elapsed = toc(startTime);

                % 检查收敛状态（通过历史文件检查）
                converged = obj.checkConvergence();

                if converged
                    success = true;
                    obj.setLastRunStatus(true);
                    obj.logMessage('INFO', '仿真成功完成 (耗时: %.2f秒)', elapsed);
                else
                    success = false;
                    obj.setLastRunStatus(false, '仿真未收敛');
                    obj.logMessage('WARNING', '仿真未收敛 (耗时: %.2f秒)', elapsed);
                end

            catch ME
                elapsed = toc(startTime);

                % 检查RPC错误
                if obj.isRPCError(ME)
                    obj.handleRPCError();
                    % 重试运行
                    success = obj.run(timeout);
                    return;
                end

                success = false;
                obj.setLastRunStatus(false, ME.message);
                obj.handleError(ME);
                obj.logMessage('ERROR', '仿真失败 (耗时: %.2f秒)', elapsed);
            end
        end

        function value = getVariable(obj, varName)
            % getVariable 获取单个结果变量
            %
            % 输入:
            %   varName - 结果变量名称（在resultMapping中定义）
            %
            % 输出:
            %   value - 变量值
            %
            % 示例:
            %   adnFrac = simulator.getVariable('ADN_FRAC');

            obj.ensureConnected();

            % 检查是否有结果映射
            if isempty(obj.config) || ~isa(obj.config, 'SimulatorConfig')
                error('AspenPlusSimulator:NoConfig', '配置未设置');
            end

            % 获取节点路径
            if obj.config.hasResultMapping(varName)
                nodePath = obj.config.getResultPath(varName);
                value = obj.getNodeValue(nodePath);
                obj.logMessage('DEBUG', '获取结果: %s = %.6g', varName, value);
            else
                error('AspenPlusSimulator:NoMapping', ...
                      '结果变量 ''%s'' 没有映射', varName);
            end
        end

        function results = getResults(obj, keys)
            % getResults 从Aspen获取结果
            %
            % 输入:
            %   keys - 结果节点路径的cell array
            %
            % 输出:
            %   results - 结果结构体

            obj.ensureConnected();

            results = struct();

            obj.logMessage('DEBUG', '获取%d个结果...', length(keys));

            try
                for i = 1:length(keys)
                    key = keys{i};
                    value = obj.getNodeValue(key);
                    results.(obj.sanitizeFieldName(key)) = value;
                    obj.logMessage('DEBUG', '  %s = %.6g', key, value);
                end

                obj.logMessage('INFO', '结果获取完成');

            catch ME
                % 检查RPC错误
                if obj.isRPCError(ME)
                    obj.handleRPCError();
                    % 重试获取结果
                    results = obj.getResults(keys);
                else
                    obj.handleError(ME);
                    error('AspenPlusSimulator:GetResultsFailed', ...
                          '获取结果失败: %s', ME.message);
                end
            end
        end
    end

    methods (Access = protected)
        function valid = validate(obj)
            % validate 验证配置

            valid = false;

            if isempty(obj.config)
                warning('AspenPlusSimulator:NoConfig', '缺少配置');
                return;
            end

            % 检查模型路径
            modelPath = obj.getConfigValue('modelPath', '');
            if isempty(modelPath)
                warning('AspenPlusSimulator:NoModelPath', '缺少模型路径');
                return;
            end

            valid = true;
        end

        function setNodeValue(obj, nodePath, value)
            % setNodeValue 设置Aspen节点值
            %
            % 输入:
            %   nodePath - 节点路径
            %   value - 值

            try
                % 查找节点
                node = obj.aspenApp.Tree.FindNode(nodePath);

                % ★ 增强的节点有效性检查 ★
                % 检查节点是否存在
                if isempty(node)
                    error('节点路径不存在: %s', nodePath);
                end

                % 检查是否为无效的handle对象（关键检查）
                if strcmp(class(node), 'handle')
                    error('节点路径返回无效的handle对象，路径可能不存在或拼写错误: %s', nodePath);
                end

                % 尝试先读取值以验证节点可访问性
                try
                    currentValue = node.Value;
                    obj.logMessage('DEBUG', '  节点当前值: %s = %s', nodePath, num2str(currentValue));
                catch
                    error('节点不支持Value属性访问，可能是只读节点或路径错误: %s', nodePath);
                end

                % 设置新值
                node.Value = value;
                obj.logMessage('DEBUG', '  节点设置成功: %s = %s', nodePath, num2str(value));

                % 添加延迟，确保COM接口有时间处理
                pause(0.5);

            catch ME
                % 提供更详细的错误诊断信息
                if exist('node', 'var')
                    nodeClass = class(node);
                else
                    nodeClass = 'undefined';
                end

                error('AspenPlusSimulator:SetNodeError', ...
                      '设置节点失败\n  路径: %s\n  值: %s\n  节点类型: %s\n  错误: %s', ...
                      nodePath, num2str(value), nodeClass, ME.message);
            end
        end

        function value = getNodeValue(obj, nodePath)
            % getNodeValue 获取Aspen节点值
            %
            % 输入:
            %   nodePath - 节点路径
            %
            % 输出:
            %   value - 节点值

            try
                % 查找节点
                node = obj.aspenApp.Tree.FindNode(nodePath);

                % ★ 增强的节点有效性检查 ★
                if isempty(node)
                    error('节点路径不存在: %s', nodePath);
                end

                % 检查是否为无效的handle对象
                if strcmp(class(node), 'handle')
                    error('节点路径返回无效的handle对象，路径可能不存在: %s', nodePath);
                end

                % 获取值
                value = node.Value;

                % 记录调试信息
                obj.logMessage('DEBUG', '  节点读取成功: %s = %s', nodePath, num2str(value));

            catch ME
                % 提供详细错误信息
                if exist('node', 'var')
                    nodeClass = class(node);
                else
                    nodeClass = 'undefined';
                end

                error('AspenPlusSimulator:GetNodeError', ...
                      '获取节点值失败\n  路径: %s\n  节点类型: %s\n  错误: %s', ...
                      nodePath, nodeClass, ME.message);
            end
        end

        function converged = checkConvergence(obj)
            % checkConvergence 检查仿真是否收敛
            % 通过读取Aspen历史文件(.his)检查是否有错误信息
            %
            % 输出:
            %   converged - 布尔值

            try
                % 获取RUNID以确定历史文件名
                runIdNode = obj.aspenApp.Tree.FindNode('\Data\Results Summary\Run-Status\Output\RUNID');
                runId = runIdNode.Value;

                % 获取模型文件所在目录
                modelPath = obj.getConfigValue('modelPath', '');
                [modelDir, ~, ~] = fileparts(modelPath);

                % 构建历史文件路径
                hisFilePath = fullfile(modelDir, [runId, '.his']);

                obj.logMessage('DEBUG', '检查历史文件: %s', hisFilePath);

                % 检查文件是否存在
                if ~exist(hisFilePath, 'file')
                    obj.logMessage('WARNING', '历史文件不存在: %s', hisFilePath);
                    % 如果历史文件不存在，退回到检查UOSSTAT
                    converged = obj.checkUOSSTAT();
                    return;
                end

                % 读取历史文件
                fid = fopen(hisFilePath, 'r');
                if fid == -1
                    obj.logMessage('WARNING', '无法打开历史文件: %s', hisFilePath);
                    converged = obj.checkUOSSTAT();
                    return;
                end

                % 读取所有行
                Data = textscan(fid, '%s', 'delimiter', '\n', 'whitespace', ' ');
                fclose(fid);
                contents = Data{1};

                % 搜索错误字符串
                SearchingStrings = {'SEVERE ERROR', 'ERROR'};
                isError = false;

                for i = 1:length(SearchingStrings)
                    isStringExist = strfind(contents, SearchingStrings{i});
                    if any(~cellfun('isempty', isStringExist))
                        isError = true;
                        obj.logMessage('DEBUG', '在历史文件中发现错误: %s', SearchingStrings{i});
                        break;
                    end
                end

                % 收敛 = 没有错误
                converged = ~isError;

                if converged
                    obj.logMessage('DEBUG', '仿真收敛成功（历史文件无错误）');
                else
                    obj.logMessage('WARNING', '仿真未收敛（历史文件包含错误）');
                end

            catch ME
                % 如果无法读取历史文件，退回到检查UOSSTAT
                obj.logMessage('WARNING', '读取历史文件时出错: %s，退回到UOSSTAT检查', ME.message);
                converged = obj.checkUOSSTAT();
            end
        end

        function converged = checkUOSSTAT(obj)
            % checkUOSSTAT 通过UOSSTAT节点检查收敛状态（备用方法）
            %
            % 输出:
            %   converged - 布尔值

            try
                runStatusNode = obj.aspenApp.Tree.FindNode('\Data\Results Summary\Run-Status\Output\UOSSTAT');
                runStatus = runStatusNode.Value;

                obj.logMessage('DEBUG', '运行状态 (UOSSTAT): %s', num2str(runStatus));

                converged = (runStatus == 1);

                if converged
                    obj.logMessage('DEBUG', '仿真收敛成功 (UOSSTAT)');
                else
                    obj.logMessage('WARNING', '仿真未收敛，UOSSTAT = %s', num2str(runStatus));

                    % 获取额外的错误信息
                    try
                        perErrorNode = obj.aspenApp.Tree.FindNode('\Data\Results Summary\Run-Status\Output\PER_ERROR');
                        perError = perErrorNode.Value;
                        obj.logMessage('DEBUG', 'PER_ERROR = %s', num2str(perError));
                    catch
                    end
                end

            catch ME
                obj.logMessage('WARNING', '无法获取收敛状态: %s', ME.message);
                converged = false;
            end
        end

        function tf = isRPCError(~, ME)
            % isRPCError 检查是否为RPC错误
            %
            % 输入:
            %   ME - MException对象
            %
            % 输出:
            %   tf - 布尔值

            tf = contains(ME.message, 'RPC') || ...
                 contains(ME.message, 'server') || ...
                 contains(ME.identifier, 'MATLAB:COM');
        end

        function handleRPCError(obj)
            % handleRPCError 处理RPC错误（尝试重连）

            obj.logMessage('WARNING', '检测到RPC错误，尝试重连...');

            for retry = 1:obj.maxRetries
                obj.logMessage('INFO', '重连尝试 %d/%d', retry, obj.maxRetries);

                try
                    % 断开当前连接
                    if ~isempty(obj.aspenApp)
                        try
                            delete(obj.aspenApp);
                        catch
                        end
                        obj.aspenApp = [];
                    end

                    % 等待
                    pause(obj.retryDelay);

                    % 重新连接
                    obj.setConnected(false);
                    obj.connect(obj.config);

                    obj.logMessage('INFO', '重连成功');
                    return;

                catch ME
                    obj.logMessage('WARNING', '重连失败: %s', ME.message);
                    if retry == obj.maxRetries
                        error('AspenPlusSimulator:ReconnectFailed', ...
                              '重连失败，已达到最大重试次数');
                    end
                end
            end
        end

        function fieldName = sanitizeFieldName(~, str)
            % sanitizeFieldName 清理字符串作为结构体字段名
            %
            % 输入:
            %   str - 原始字符串
            %
            % 输出:
            %   fieldName - 有效的字段名

            % 移除非法字符
            fieldName = regexprep(str, '[^\w]', '_');

            % 确保以字母开头
            if ~isempty(fieldName) && ~isletter(fieldName(1))
                fieldName = ['x' fieldName];
            end
        end

        function success = waitForSimulation(obj, timeout)
            % waitForSimulation 等待Aspen仿真完成或超时
            %
            % 输入:
            %   timeout - 超时时间（秒）
            %
            % 输出:
            %   success - 是否正常完成 (true为正常, false为超时)

            timeElapsed = 0;

            while obj.aspenApp.Engine.IsRunning == 1
                pause(0.5);
                timeElapsed = timeElapsed + 0.5;

                % 检查是否超时
                if timeElapsed >= timeout
                    obj.aspenApp.Engine.Stop();
                    obj.logMessage('WARNING', 'Aspen仿真超时 (%d秒)', timeout);
                    success = false;
                    return;
                end
            end

            success = true;
        end
    end

    methods (Static)
        function type = getSimulatorType()
            % getSimulatorType 获取仿真器类型
            %
            % 输出:
            %   type - 'AspenPlus'

            type = 'AspenPlus';
        end
    end
end
