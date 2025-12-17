%% MAPOGUI_Callbacks.m - MAPOGUI 回调函数实现参考
%
% 本文件包含 MAPOGUI.mlapp 中所有回调函数的完整实现代码。
% 在 App Designer 中创建对应控件后，将相应代码复制到回调函数中。
%
% 使用方法：
%   1. 在 App Designer 中创建控件
%   2. 右键控件 -> Callbacks -> 选择回调类型
%   3. 复制本文件中对应的代码到生成的回调函数中

%% ========================================
%% 初始化函数
%% ========================================

function startupFcn(app)
    %% startupFcn - App 启动时执行

    % 初始化 GUI 数据结构
    app.guiData = struct();
    app.guiData.problem = struct();
    app.guiData.simulator = struct();
    app.guiData.algorithm = struct();

    % 初始化配置和结果
    app.config = struct();
    app.configFilePath = '';
    app.results = struct();
    app.asyncFuture = [];
    app.dataQueue = [];
    app.callbacks = [];

    % 初始化表格数据
    app.VariablesTable.Data = cell(0, 6);
    app.ObjectivesTable.Data = cell(0, 4);
    app.ConstraintsTable.Data = cell(0, 4);
    app.VarMappingTable.Data = cell(0, 2);
    app.ResMappingTable.Data = cell(0, 2);
    app.ResultsTable.Data = cell(0, 0);

    % 初始化算法面板可见性
    app.NSGAIIPanel.Visible = 'on';
    app.PSOPanel.Visible = 'off';

    % 设置算法说明
    updateAlgorithmDescription(app);

    % 加载模板
    app.varTemplates = AspenNodeTemplates.getTemplateCategories();
    app.resTemplates = AspenNodeTemplates.getTemplateCategories();

    % 初始化模板下拉框
    app.VarTemplateDropDown.Items = app.varTemplates;
    app.ResTemplateDropDown.Items = app.resTemplates;

    % 添加框架路径
    frameworkPath = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'framework');
    if exist(frameworkPath, 'dir')
        addpath(genpath(frameworkPath));
    end

    % 记录日志
    logMessage(app, 'MAPO GUI 已启动');
    logMessage(app, sprintf('Framework path: %s', frameworkPath));

    % 更新配置状态
    updateConfigStatus(app);
end

%% ========================================
%% Tab 1: 问题配置 - 回调函数
%% ========================================

function AddVariableButtonPushed(app, event)
    %% 添加变量

    currentData = app.VariablesTable.Data;
    newRow = {'Var1', 'continuous', 0, 100, '', ''};
    app.VariablesTable.Data = [currentData; newRow];

    logMessage(app, '添加新变量');
end

function DeleteVariableButtonPushed(app, event)
    %% 删除选中的变量

    selection = app.VariablesTable.Selection;
    if isempty(selection)
        uialert(app.UIFigure, '请先选择要删除的变量', '删除变量');
        return;
    end

    currentData = app.VariablesTable.Data;
    rowsToDelete = unique(selection(:, 1));
    currentData(rowsToDelete, :) = [];
    app.VariablesTable.Data = currentData;

    logMessage(app, sprintf('删除 %d 个变量', length(rowsToDelete)));
end

function AddObjectiveButtonPushed(app, event)
    %% 添加目标

    currentData = app.ObjectivesTable.Data;
    newRow = {'Obj1', 'minimize', 1.0, ''};
    app.ObjectivesTable.Data = [currentData; newRow];

    logMessage(app, '添加新目标');
end

function DeleteObjectiveButtonPushed(app, event)
    %% 删除选中的目标

    selection = app.ObjectivesTable.Selection;
    if isempty(selection)
        uialert(app.UIFigure, '请先选择要删除的目标', '删除目标');
        return;
    end

    currentData = app.ObjectivesTable.Data;
    rowsToDelete = unique(selection(:, 1));
    currentData(rowsToDelete, :) = [];
    app.ObjectivesTable.Data = currentData;

    logMessage(app, sprintf('删除 %d 个目标', length(rowsToDelete)));
end

function AddConstraintButtonPushed(app, event)
    %% 添加约束

    currentData = app.ConstraintsTable.Data;
    newRow = {'Con1', 'inequality', 'x <= 100', ''};
    app.ConstraintsTable.Data = [currentData; newRow];

    logMessage(app, '添加新约束');
end

function DeleteConstraintButtonPushed(app, event)
    %% 删除选中的约束

    selection = app.ConstraintsTable.Selection;
    if isempty(selection)
        uialert(app.UIFigure, '请先选择要删除的约束', '删除约束');
        return;
    end

    currentData = app.ConstraintsTable.Data;
    rowsToDelete = unique(selection(:, 1));
    currentData(rowsToDelete, :) = [];
    app.ConstraintsTable.Data = currentData;

    logMessage(app, sprintf('删除 %d 个约束', length(rowsToDelete)));
end

%% ========================================
%% Tab 3: 仿真器配置 - 回调函数
%% ========================================

function BrowseModelButtonPushed(app, event)
    %% 浏览模型文件

    simType = app.SimulatorTypeDropDown.Value;

    switch simType
        case 'Aspen'
            [file, path] = uigetfile('*.bkp', '选择 Aspen Plus 模型文件');
        case 'MATLAB'
            [file, path] = uigetfile('*.m', '选择 MATLAB 脚本文件');
        case 'Python'
            [file, path] = uigetfile('*.py', '选择 Python 脚本文件');
        otherwise
            [file, path] = uigetfile('*.*', '选择模型文件');
    end

    if file ~= 0
        fullPath = fullfile(path, file);
        app.ModelPathField.Value = fullPath;
        logMessage(app, sprintf('选择模型文件: %s', fullPath));
    end
end

function AddVarMappingButtonPushed(app, event)
    %% 添加变量映射

    currentData = app.VarMappingTable.Data;
    newRow = {'VarName', '\Data\Streams\FEED\Input\TEMP\MIXED'};
    app.VarMappingTable.Data = [currentData; newRow];

    logMessage(app, '添加新变量映射');
end

function DeleteVarMappingButtonPushed(app, event)
    %% 删除变量映射

    selection = app.VarMappingTable.Selection;
    if isempty(selection)
        uialert(app.UIFigure, '请先选择要删除的映射', '删除映射');
        return;
    end

    currentData = app.VarMappingTable.Data;
    rowsToDelete = unique(selection(:, 1));
    currentData(rowsToDelete, :) = [];
    app.VarMappingTable.Data = currentData;

    logMessage(app, sprintf('删除 %d 个变量映射', length(rowsToDelete)));
end

function ApplyVarTemplateButtonPushed(app, event)
    %% 应用变量模板

    selectedCategory = app.VarTemplateDropDown.Value;
    [templateList, ~] = AspenNodeTemplates.getTemplatesForCategory(selectedCategory);

    if isempty(templateList)
        uialert(app.UIFigure, '所选类别没有可用模板', '应用模板');
        return;
    end

    % 创建选择对话框
    [selection, ok] = listdlg('ListString', templateList(:, 1), ...
        'SelectionMode', 'single', ...
        'Name', '选择模板', ...
        'PromptString', '请选择一个模板:');

    if ok
        templateName = templateList{selection, 1};
        templatePath = templateList{selection, 2};

        % 提取占位符
        placeholders = AspenNodeTemplates.extractPlaceholders(templatePath);

        if isempty(placeholders)
            % 无占位符，直接添加
            currentData = app.VarMappingTable.Data;
            newRow = {templateName, templatePath};
            app.VarMappingTable.Data = [currentData; newRow];
            logMessage(app, sprintf('应用模板: %s', templateName));
        else
            % 需要用户输入占位符值
            answers = inputdlg(placeholders, '填写占位符', 1, placeholders);
            if ~isempty(answers)
                % 构建路径
                buildPath = templatePath;
                for i = 1:length(placeholders)
                    buildPath = strrep(buildPath, ...
                        sprintf('{%s}', placeholders{i}), answers{i});
                end

                currentData = app.VarMappingTable.Data;
                newRow = {answers{1}, buildPath};
                app.VarMappingTable.Data = [currentData; newRow];
                logMessage(app, sprintf('应用模板: %s -> %s', templateName, buildPath));
            end
        end
    end
end

function AddResMappingButtonPushed(app, event)
    %% 添加结果映射

    currentData = app.ResMappingTable.Data;
    newRow = {'ResultName', '\Data\Streams\PROD\Output\TEMP\MIXED'};
    app.ResMappingTable.Data = [currentData; newRow];

    logMessage(app, '添加新结果映射');
end

function DeleteResMappingButtonPushed(app, event)
    %% 删除结果映射

    selection = app.ResMappingTable.Selection;
    if isempty(selection)
        uialert(app.UIFigure, '请先选择要删除的映射', '删除映射');
        return;
    end

    currentData = app.ResMappingTable.Data;
    rowsToDelete = unique(selection(:, 1));
    currentData(rowsToDelete, :) = [];
    app.ResMappingTable.Data = currentData;

    logMessage(app, sprintf('删除 %d 个结果映射', length(rowsToDelete)));
end

function ApplyResTemplateButtonPushed(app, event)
    %% 应用结果模板（与变量模板类似）

    selectedCategory = app.ResTemplateDropDown.Value;
    [templateList, ~] = AspenNodeTemplates.getTemplatesForCategory(selectedCategory);

    if isempty(templateList)
        uialert(app.UIFigure, '所选类别没有可用模板', '应用模板');
        return;
    end

    % 创建选择对话框
    [selection, ok] = listdlg('ListString', templateList(:, 1), ...
        'SelectionMode', 'single', ...
        'Name', '选择模板', ...
        'PromptString', '请选择一个模板:');

    if ok
        templateName = templateList{selection, 1};
        templatePath = templateList{selection, 2};

        % 提取占位符
        placeholders = AspenNodeTemplates.extractPlaceholders(templatePath);

        if isempty(placeholders)
            % 无占位符，直接添加
            currentData = app.ResMappingTable.Data;
            newRow = {templateName, templatePath};
            app.ResMappingTable.Data = [currentData; newRow];
            logMessage(app, sprintf('应用模板: %s', templateName));
        else
            % 需要用户输入占位符值
            answers = inputdlg(placeholders, '填写占位符', 1, placeholders);
            if ~isempty(answers)
                % 构建路径
                buildPath = templatePath;
                for i = 1:length(placeholders)
                    buildPath = strrep(buildPath, ...
                        sprintf('{%s}', placeholders{i}), answers{i});
                end

                currentData = app.ResMappingTable.Data;
                newRow = {answers{1}, buildPath};
                app.ResMappingTable.Data = [currentData; newRow];
                logMessage(app, sprintf('应用模板: %s -> %s', templateName, buildPath));
            end
        end
    end
end

function TestConnectionButtonPushed(app, event)
    %% 测试仿真器连接

    logMessage(app, '开始测试连接...');
    app.TestConnectionButton.Enable = 'off';
    app.ConnectionStatusLabel.Text = '状态: 连接中...';
    drawnow;

    try
        % 收集仿真器配置
        simType = app.SimulatorTypeDropDown.Value;
        modelPath = app.ModelPathField.Value;

        if isempty(modelPath)
            error('请先选择模型文件');
        end

        if ~exist(modelPath, 'file')
            error('模型文件不存在: %s', modelPath);
        end

        % 创建仿真器配置
        simConfig = SimulatorConfig(simType);
        simConfig.set('modelPath', modelPath);
        simConfig.set('timeout', app.SimTimeoutSpinner.Value);
        simConfig.set('visible', app.VisibleCheckBox.Value);
        simConfig.set('suppressWarnings', app.SuppressWarningsCheckBox.Value);

        % 创建仿真器实例
        switch upper(simType)
            case 'ASPEN'
                simulator = AspenPlusSimulator();
            case 'MATLAB'
                simulator = MATLABSimulator();
            case 'PYTHON'
                simulator = PythonSimulator();
            otherwise
                error('不支持的仿真器类型: %s', simType);
        end

        % 连接
        simulator.connect(simConfig);

        % 断开
        simulator.disconnect();

        % 成功
        app.ConnectionStatusLabel.Text = '状态: ✓ 连接成功';
        logMessage(app, '仿真器连接测试成功');
        uialert(app.UIFigure, '仿真器连接测试成功！', '测试成功', 'Icon', 'success');

    catch ME
        app.ConnectionStatusLabel.Text = '状态: ✗ 连接失败';
        logMessage(app, sprintf('连接测试失败: %s', ME.message));
        uialert(app.UIFigure, sprintf('连接失败: %s', ME.message), '测试失败', 'Icon', 'error');
    end

    app.TestConnectionButton.Enable = 'on';
end

function ValidatePathsButtonPushed(app, event)
    %% 验证节点路径

    logMessage(app, '验证节点路径...');

    % 检查变量映射
    varData = app.VarMappingTable.Data;
    invalidVarPaths = {};

    for i = 1:size(varData, 1)
        path = varData{i, 2};
        if ~AspenNodeTemplates.validateNodePath(path)
            invalidVarPaths{end+1} = sprintf('Row %d: %s', i, path);
        end
    end

    % 检查结果映射
    resData = app.ResMappingTable.Data;
    invalidResPaths = {};

    for i = 1:size(resData, 1)
        path = resData{i, 2};
        if ~AspenNodeTemplates.validateNodePath(path)
            invalidResPaths{end+1} = sprintf('Row %d: %s', i, path);
        end
    end

    % 显示结果
    if isempty(invalidVarPaths) && isempty(invalidResPaths)
        uialert(app.UIFigure, '所有节点路径格式正确！', '验证成功', 'Icon', 'success');
        logMessage(app, '所有节点路径验证通过');
    else
        msg = '发现无效路径:\n\n';
        if ~isempty(invalidVarPaths)
            msg = [msg, '变量映射:\n', strjoin(invalidVarPaths, '\n'), '\n\n'];
        end
        if ~isempty(invalidResPaths)
            msg = [msg, '结果映射:\n', strjoin(invalidResPaths, '\n')];
        end
        uialert(app.UIFigure, sprintf(msg), '验证失败', 'Icon', 'warning');
        logMessage(app, sprintf('发现 %d 个无效路径', length(invalidVarPaths) + length(invalidResPaths)));
    end
end

%% ========================================
%% Tab 4: 算法配置 - 回调函数
%% ========================================

function AlgorithmDropDownValueChanged(app, event)
    %% 算法类型切换

    value = app.AlgorithmDropDown.Value;

    switch value
        case 'NSGA-II'
            app.NSGAIIPanel.Visible = 'on';
            app.PSOPanel.Visible = 'off';
        case 'PSO'
            app.NSGAIIPanel.Visible = 'off';
            app.PSOPanel.Visible = 'on';
    end

    updateAlgorithmDescription(app);
    updateEstimations(app);
    logMessage(app, sprintf('切换算法: %s', value));
end

function CrossoverSlider_NSGAIIValueChanged(app, event)
    %% 更新交叉概率标签
    value = app.CrossoverSlider_NSGAII.Value;
    app.CrossoverValueLabel_NSGAII.Text = sprintf('%.2f', value);
    updateEstimations(app);
end

function MutationSlider_NSGAIIValueChanged(app, event)
    %% 更新变异概率标签
    value = app.MutationSlider_NSGAII.Value;
    app.MutationValueLabel_NSGAII.Text = sprintf('%.2f', value);
end

function InertiaSlider_PSOValueChanged(app, event)
    %% 更新惯性权重标签
    value = app.InertiaSlider_PSO.Value;
    app.InertiaValueLabel_PSO.Text = sprintf('%.2f', value);
end

function CognitiveSlider_PSOValueChanged(app, event)
    %% 更新认知系数标签
    value = app.CognitiveSlider_PSO.Value;
    app.CognitiveValueLabel_PSO.Text = sprintf('%.2f', value);
end

function SocialSlider_PSOValueChanged(app, event)
    %% 更新社会系数标签
    value = app.SocialSlider_PSO.Value;
    app.SocialValueLabel_PSO.Text = sprintf('%.2f', value);
end

function MaxVelSlider_PSOValueChanged(app, event)
    %% 更新最大速度比例标签
    value = app.MaxVelSlider_PSO.Value;
    app.MaxVelValueLabel_PSO.Text = sprintf('%.2f', value);
end

function PopSizeSpinner_NSGAIIValueChanged(app, event)
    updateEstimations(app);
end

function MaxGenSpinner_NSGAIIValueChanged(app, event)
    updateEstimations(app);
end

function SwarmSizeSpinner_PSOValueChanged(app, event)
    updateEstimations(app);
end

function MaxIterSpinner_PSOValueChanged(app, event)
    updateEstimations(app);
end

%% ========================================
%% Tab 5: 运行与结果 - 回调函数
%% ========================================

function RunButtonPushed(app, event)
    %% 开始优化

    logMessage(app, '========================================');
    logMessage(app, '准备开始优化...');

    % 验证配置
    if ~validateConfiguration(app)
        return;
    end

    % 收集 GUI 数据
    collectGUIData(app);

    % 构建配置
    try
        app.config = ConfigBuilder.buildConfig(app.guiData);
    catch ME
        uialert(app.UIFigure, sprintf('构建配置失败: %s', ME.message), '错误', 'Icon', 'error');
        logMessage(app, sprintf('构建配置失败: %s', ME.message));
        return;
    end

    % 验证配置
    [valid, errors, warnings] = ConfigValidator.validate(app.config);
    if ~valid
        msg = sprintf('配置验证失败:\n\n%s', strjoin(errors, '\n'));
        uialert(app.UIFigure, msg, '配置错误', 'Icon', 'error');
        logMessage(app, '配置验证失败');
        for i = 1:length(errors)
            logMessage(app, sprintf('  ERROR: %s', errors{i}));
        end
        return;
    end

    % 显示警告
    if ~isempty(warnings)
        logMessage(app, '配置警告:');
        for i = 1:length(warnings)
            logMessage(app, sprintf('  WARNING: %s', warnings{i}));
        end
    end

    % 保存配置到临时文件
    tempDir = fullfile(pwd, 'temp');
    if ~exist(tempDir, 'dir')
        mkdir(tempDir);
    end

    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    app.configFilePath = fullfile(tempDir, sprintf('config_%s.json', timestamp));
    ConfigBuilder.toJSON(app.config, app.configFilePath);
    logMessage(app, sprintf('配置已保存: %s', app.configFilePath));

    % 创建回调
    app.callbacks = OptimizationCallbacks(app);
    app.callbacks.setMaxIterations(app.config.algorithm.parameters.maxGenerations);
    app.callbacks.resetStartTime();
    app.optimizationStartTime = tic;

    % 启动优化
    try
        [app.asyncFuture, app.dataQueue] = runOptimizationAsync(app.configFilePath, app.callbacks);

        if isa(app.asyncFuture, 'parallel.FevalFuture')
            % 异步模式
            logMessage(app, '使用异步模式运行');
            afterEach(app.dataQueue, @(data) handleOptimizationDataGUI(app, data));
        else
            % 同步模式
            logMessage(app, '使用同步模式运行');
            app.callbacks.onAlgorithmEndCallback(app.asyncFuture);
            app.results = app.asyncFuture;

            % 更新按钮状态
            app.RunButton.Enable = 'on';
            app.StopButton.Enable = 'off';
            app.SaveResultsButton.Enable = 'on';

            logMessage(app, '优化完成（同步模式）');

            % 询问是否保存
            promptSaveResults(app);
        end

        % 更新按钮状态（异步模式）
        if isa(app.asyncFuture, 'parallel.FevalFuture')
            app.RunButton.Enable = 'off';
            app.StopButton.Enable = 'on';
            app.SaveConfigButton.Enable = 'off';
            app.LoadConfigButton.Enable = 'off';
        end

    catch ME
        uialert(app.UIFigure, sprintf('启动优化失败: %s', ME.message), '错误', 'Icon', 'error');
        logMessage(app, sprintf('启动优化失败: %s', ME.message));
    end
end

function StopButtonPushed(app, event)
    %% 停止优化

    if ~isempty(app.asyncFuture) && isa(app.asyncFuture, 'parallel.FevalFuture')
        try
            cancel(app.asyncFuture);
            logMessage(app, '优化已取消');

            % 恢复按钮状态
            app.RunButton.Enable = 'on';
            app.StopButton.Enable = 'off';
            app.SaveConfigButton.Enable = 'on';
            app.LoadConfigButton.Enable = 'on';
        catch ME
            logMessage(app, sprintf('取消失败: %s', ME.message));
        end
    end
end

function SaveConfigButtonPushed(app, event)
    %% 保存配置文件

    % 收集数据
    collectGUIData(app);

    % 构建配置
    try
        config = ConfigBuilder.buildConfig(app.guiData);
    catch ME
        uialert(app.UIFigure, sprintf('构建配置失败: %s', ME.message), '错误', 'Icon', 'error');
        return;
    end

    % 选择保存位置
    defaultName = sprintf('%s_config.json', config.problem.name);
    [file, path] = uiputfile('*.json', '保存配置文件', defaultName);

    if file ~= 0
        fullPath = fullfile(path, file);
        ConfigBuilder.toJSON(config, fullPath);
        logMessage(app, sprintf('配置已保存: %s', fullPath));
        uialert(app.UIFigure, '配置保存成功！', '保存成功', 'Icon', 'success');
    end
end

function LoadConfigButtonPushed(app, event)
    %% 加载配置文件

    [file, path] = uigetfile('*.json', '选择配置文件');

    if file ~= 0
        fullPath = fullfile(path, file);

        try
            config = ConfigBuilder.fromJSON(fullPath);
            guiData = ConfigBuilder.toGUIData(config);
            loadGUIData(app, guiData);

            logMessage(app, sprintf('配置已加载: %s', fullPath));
            uialert(app.UIFigure, '配置加载成功！', '加载成功', 'Icon', 'success');

            % 更新状态
            updateConfigStatus(app);
        catch ME
            uialert(app.UIFigure, sprintf('加载配置失败: %s', ME.message), '错误', 'Icon', 'error');
            logMessage(app, sprintf('加载配置失败: %s', ME.message));
        end
    end
end

function SaveResultsButtonPushed(app, event)
    %% 保存结果

    if isempty(app.results)
        uialert(app.UIFigure, '没有可保存的结果', '保存结果');
        return;
    end

    promptSaveResults(app);
end

function ClearLogButtonPushed(app, event)
    %% 清除日志
    app.LogTextArea.Value = {};
    logMessage(app, '日志已清除');
end

function ExportResultsButtonPushed(app, event)
    %% 导出结果表格

    if isempty(app.ResultsTable.Data)
        uialert(app.UIFigure, '没有可导出的数据', '导出结果');
        return;
    end

    [file, path] = uiputfile('*.csv', '导出结果', 'pareto_solutions.csv');

    if file ~= 0
        fullPath = fullfile(path, file);

        try
            % 转换为表格
            columnNames = app.ResultsTable.ColumnName;
            dataTable = array2table(app.ResultsTable.Data, 'VariableNames', columnNames);
            writetable(dataTable, fullPath);

            logMessage(app, sprintf('结果已导出: %s', fullPath));
            uialert(app.UIFigure, '结果导出成功！', '导出成功', 'Icon', 'success');
        catch ME
            uialert(app.UIFigure, sprintf('导出失败: %s', ME.message), '错误', 'Icon', 'error');
        end
    end
end

%% ========================================
%% 辅助函数
%% ========================================

function updateConfigStatus(app)
    %% 更新配置状态显示

    % 检查问题配置
    hasVariables = ~isempty(app.VariablesTable.Data);
    hasObjectives = ~isempty(app.ObjectivesTable.Data);
    problemConfigured = hasVariables && hasObjectives;

    if problemConfigured
        app.ProblemStatusLabel.Text = '问题: ✓ 已配置';
    else
        app.ProblemStatusLabel.Text = '问题: ✗ 未配置';
    end

    % 检查仿真器配置
    hasModel = ~isempty(app.ModelPathField.Value);
    hasVarMapping = ~isempty(app.VarMappingTable.Data);
    hasResMapping = ~isempty(app.ResMappingTable.Data);
    simConfigured = hasModel && hasVarMapping && hasResMapping;

    if simConfigured
        app.SimulatorStatusLabel.Text = '仿真器: ✓ 已配置';
    else
        app.SimulatorStatusLabel.Text = '仿真器: ✗ 未配置';
    end

    % 算法默认已配置
    app.AlgorithmStatusLabel.Text = '算法: ✓ 已配置';
end

function valid = validateConfiguration(app)
    %% 验证当前配置

    valid = true;
    errors = {};

    % 检查问题配置
    if isempty(app.VariablesTable.Data)
        errors{end+1} = '至少需要定义一个决策变量';
        valid = false;
    end

    if isempty(app.ObjectivesTable.Data)
        errors{end+1} = '至少需要定义一个优化目标';
        valid = false;
    end

    % 检查仿真器配置
    if isempty(app.ModelPathField.Value)
        errors{end+1} = '请选择仿真器模型文件';
        valid = false;
    end

    if isempty(app.VarMappingTable.Data)
        errors{end+1} = '至少需要定义一个变量节点映射';
        valid = false;
    end

    if isempty(app.ResMappingTable.Data)
        errors{end+1} = '至少需要定义一个结果节点映射';
        valid = false;
    end

    % 检查节点映射名称是否合法（必须为合法 MATLAB 标识符）
    if valid
        invalidVarNames = {};
        varData = app.VarMappingTable.Data;
        for i = 1:size(varData, 1)
            nameVal = varData{i, 1};
            nameStr = char(string(nameVal));
            if isempty(nameStr) || ~isvarname(nameStr)
                invalidVarNames{end+1} = sprintf('Row %d: %s', i, nameStr); %#ok<AGROW>
            end
        end

        invalidResNames = {};
        resData = app.ResMappingTable.Data;
        for i = 1:size(resData, 1)
            nameVal = resData{i, 1};
            nameStr = char(string(nameVal));
            if isempty(nameStr) || ~isvarname(nameStr)
                invalidResNames{end+1} = sprintf('Row %d: %s', i, nameStr); %#ok<AGROW>
            end
        end

        if ~isempty(invalidVarNames) || ~isempty(invalidResNames)
            msg = '发现无效的节点映射名称（必须是合法 MATLAB 标识符）。这些行在构建配置时会被忽略：\n\n';
            if ~isempty(invalidVarNames)
                msg = [msg, '变量映射:\n', strjoin(invalidVarNames, '\n'), '\n\n'];
            end
            if ~isempty(invalidResNames)
                msg = [msg, '结果映射:\n', strjoin(invalidResNames, '\n')];
            end
            uialert(app.UIFigure, sprintf(msg), '无效映射名称', 'Icon', 'warning');
            logMessage(app, '发现无效的节点映射名称（已提示用户）');
        end
    end

    % 显示错误
    if ~valid
        msg = sprintf('配置不完整:\n\n%s', strjoin(errors, '\n'));
        uialert(app.UIFigure, msg, '配置错误', 'Icon', 'error');
        logMessage(app, '配置验证失败');
        for i = 1:length(errors)
            logMessage(app, sprintf('  - %s', errors{i}));
        end
    end
end

function logMessage(app, message)
    %% 添加日志消息

    timestamp = datestr(now, 'HH:MM:SS');
    logMsg = sprintf('[%s] %s', timestamp, message);

    currentLog = app.LogTextArea.Value;
    if ischar(currentLog)
        currentLog = {currentLog};
    end

    currentLog{end+1} = logMsg;

    % 限制日志长度
    if length(currentLog) > 1000
        currentLog = currentLog(end-999:end);
    end

    app.LogTextArea.Value = currentLog;
    drawnow limitrate;
end

function updateAlgorithmDescription(app)
    %% 更新算法说明

    algType = app.AlgorithmDropDown.Value;

    switch algType
        case 'NSGA-II'
            desc = ['NSGA-II (Non-dominated Sorting Genetic Algorithm II)\n\n', ...
                    '快速非支配排序遗传算法，适用于多目标优化问题。\n\n', ...
                    '主要特点：\n', ...
                    '• 快速非支配排序\n', ...
                    '• 拥挤距离保持种群多样性\n', ...
                    '• 精英保留策略\n', ...
                    '• SBX 交叉和多项式变异\n\n', ...
                    '适用场景：多目标优化、需要 Pareto 前沿'];

        case 'PSO'
            desc = ['PSO (Particle Swarm Optimization)\n\n', ...
                    '粒子群优化算法，模拟鸟群觅食行为。\n\n', ...
                    '主要特点：\n', ...
                    '• 实现简单，参数少\n', ...
                    '• 收敛速度快\n', ...
                    '• 全局搜索能力强\n', ...
                    '• 适合连续优化问题\n\n', ...
                    '适用场景：单目标/多目标优化、连续变量'];

        otherwise
            desc = '请选择算法类型';
    end

    app.AlgorithmDescArea.Value = desc;
end

function updateEstimations(app)
    %% 更新预估信息

    algType = app.AlgorithmDropDown.Value;

    switch algType
        case 'NSGA-II'
            popSize = app.PopSizeSpinner_NSGAII.Value;
            maxGen = app.MaxGenSpinner_NSGAII.Value;
            totalEvals = popSize * (maxGen + 1);

        case 'PSO'
            swarmSize = app.SwarmSizeSpinner_PSO.Value;
            maxIter = app.MaxIterSpinner_PSO.Value;
            totalEvals = swarmSize * (maxIter + 1);
    end

    app.TotalEvalsLabel.Text = sprintf('预估总评估次数: %d', totalEvals);

    % 预估时间（假设每次评估 30 秒）
    estSeconds = totalEvals * 30;
    estHours = floor(estSeconds / 3600);
    estMinutes = floor(mod(estSeconds, 3600) / 60);

    if estHours > 0
        app.EstTimeLabel.Text = sprintf('预估运行时间: ~%d 小时 %d 分钟', estHours, estMinutes);
    else
        app.EstTimeLabel.Text = sprintf('预估运行时间: ~%d 分钟', estMinutes);
    end
end

function collectGUIData(app)
    %% 从 GUI 控件收集数据到 app.guiData

    % 问题基本信息
    app.guiData.problem.name = app.ProblemNameField.Value;
    app.guiData.problem.description = strjoin(app.ProblemDescArea.Value, '\n');

    % 决策变量
    varData = app.VariablesTable.Data;
    app.guiData.problem.variables = struct([]);
    for i = 1:size(varData, 1)
        app.guiData.problem.variables(i).name = varData{i, 1};
        app.guiData.problem.variables(i).type = varData{i, 2};
        app.guiData.problem.variables(i).lowerBound = varData{i, 3};
        app.guiData.problem.variables(i).upperBound = varData{i, 4};
        app.guiData.problem.variables(i).unit = varData{i, 5};
        app.guiData.problem.variables(i).description = varData{i, 6};
    end

    % 优化目标
    objData = app.ObjectivesTable.Data;
    app.guiData.problem.objectives = struct([]);
    for i = 1:size(objData, 1)
        app.guiData.problem.objectives(i).name = objData{i, 1};
        app.guiData.problem.objectives(i).type = objData{i, 2};
        app.guiData.problem.objectives(i).weight = objData{i, 3};
        app.guiData.problem.objectives(i).description = objData{i, 4};
    end

    % 约束条件
    conData = app.ConstraintsTable.Data;
    app.guiData.problem.constraints = struct([]);
    for i = 1:size(conData, 1)
        app.guiData.problem.constraints(i).name = conData{i, 1};
        app.guiData.problem.constraints(i).type = conData{i, 2};
        app.guiData.problem.constraints(i).expression = conData{i, 3};
        app.guiData.problem.constraints(i).description = conData{i, 4};
    end

    % 评估器
    app.guiData.problem.evaluator.type = char(string(app.EvaluatorTypeDropDown.Value));
    app.guiData.problem.evaluator.timeout = app.EvaluatorTimeoutSpinner.Value;
    app.guiData.problem.evaluator.economicParameters = struct();

    paramData = app.EvaluatorParamsTable.Data;
    if ~isempty(paramData)
        for i = 1:size(paramData, 1)
            nameStr = char(string(paramData{i, 1}));
            if isempty(strtrim(nameStr)) || ~isvarname(nameStr)
                continue;
            end
            app.guiData.problem.evaluator.economicParameters.(nameStr) = paramData{i, 2};
        end
    end

    % 仿真器
    app.guiData.simulator.type = app.SimulatorTypeDropDown.Value;
    app.guiData.simulator.settings.modelPath = app.ModelPathField.Value;
    app.guiData.simulator.settings.timeout = app.SimTimeoutSpinner.Value;
    app.guiData.simulator.settings.maxRetries = app.MaxRetriesSpinner.Value;
    app.guiData.simulator.settings.retryDelay = app.RetryDelaySpinner.Value;
    app.guiData.simulator.settings.visible = app.VisibleCheckBox.Value;
    app.guiData.simulator.settings.suppressWarnings = app.SuppressWarningsCheckBox.Value;

    % 节点映射 - 变量
    varMapData = app.VarMappingTable.Data;
    app.guiData.simulator.nodeMapping.variables = struct();
    for i = 1:size(varMapData, 1)
        varName = varMapData{i, 1};
        nodePath = varMapData{i, 2};
        % 使用动态字段名
        if isvarname(varName)
            app.guiData.simulator.nodeMapping.variables.(varName) = nodePath;
        end
    end

    % 节点映射 - 结果
    resMapData = app.ResMappingTable.Data;
    app.guiData.simulator.nodeMapping.results = struct();
    for i = 1:size(resMapData, 1)
        resName = resMapData{i, 1};
        nodePath = resMapData{i, 2};
        % 使用动态字段名
        if isvarname(resName)
            app.guiData.simulator.nodeMapping.results.(resName) = nodePath;
        end
    end

    % 算法
    app.guiData.algorithm.type = app.AlgorithmDropDown.Value;

    switch app.AlgorithmDropDown.Value
        case 'NSGA-II'
            app.guiData.algorithm.parameters.populationSize = app.PopSizeSpinner_NSGAII.Value;
            app.guiData.algorithm.parameters.maxGenerations = app.MaxGenSpinner_NSGAII.Value;
            app.guiData.algorithm.parameters.crossoverRate = app.CrossoverSlider_NSGAII.Value;
            app.guiData.algorithm.parameters.mutationRate = app.MutationSlider_NSGAII.Value;
            app.guiData.algorithm.parameters.crossoverDistIndex = app.CrossoverDistSpinner_NSGAII.Value;
            app.guiData.algorithm.parameters.mutationDistIndex = app.MutationDistSpinner_NSGAII.Value;

        case 'PSO'
            app.guiData.algorithm.parameters.swarmSize = app.SwarmSizeSpinner_PSO.Value;
            app.guiData.algorithm.parameters.maxIterations = app.MaxIterSpinner_PSO.Value;
            app.guiData.algorithm.parameters.inertiaWeight = app.InertiaSlider_PSO.Value;
            app.guiData.algorithm.parameters.cognitiveCoeff = app.CognitiveSlider_PSO.Value;
            app.guiData.algorithm.parameters.socialCoeff = app.SocialSlider_PSO.Value;
            app.guiData.algorithm.parameters.maxVelocityRatio = app.MaxVelSlider_PSO.Value;
    end
end

function loadGUIData(app, guiData)
    %% 从数据加载到 GUI 控件

    % 问题基本信息
    if isfield(guiData.problem, 'name')
        app.ProblemNameField.Value = guiData.problem.name;
    end
    if isfield(guiData.problem, 'description')
        app.ProblemDescArea.Value = {guiData.problem.description};
    end

    % 决策变量
    if isfield(guiData.problem, 'variables')
        varData = cell(length(guiData.problem.variables), 6);
        for i = 1:length(guiData.problem.variables)
            var = guiData.problem.variables(i);
            varData{i, 1} = var.name;
            varData{i, 2} = var.type;
            varData{i, 3} = var.lowerBound;
            varData{i, 4} = var.upperBound;
            varData{i, 5} = var.unit;
            varData{i, 6} = var.description;
        end
        app.VariablesTable.Data = varData;
    end

    % 优化目标
    if isfield(guiData.problem, 'objectives')
        objData = cell(length(guiData.problem.objectives), 4);
        for i = 1:length(guiData.problem.objectives)
            obj = guiData.problem.objectives(i);
            objData{i, 1} = obj.name;
            objData{i, 2} = obj.type;
            objData{i, 3} = obj.weight;
            objData{i, 4} = obj.description;
        end
        app.ObjectivesTable.Data = objData;
    end

    % 约束条件
    if isfield(guiData.problem, 'constraints')
        conData = cell(length(guiData.problem.constraints), 4);
        for i = 1:length(guiData.problem.constraints)
            con = guiData.problem.constraints(i);
            conData{i, 1} = con.name;
            conData{i, 2} = con.type;
            conData{i, 3} = con.expression;
            conData{i, 4} = con.description;
        end
        app.ConstraintsTable.Data = conData;
    end

    % 评估器
    if isfield(guiData.problem, 'evaluator')
        if isfield(guiData.problem.evaluator, 'type')
            evalType = char(string(guiData.problem.evaluator.type));
            items = app.EvaluatorTypeDropDown.Items;
            if isstring(items)
                items = cellstr(items);
            end
            if ~iscell(items)
                items = {};
            end
            if ~ismember(evalType, items)
                items{end+1} = evalType; %#ok<AGROW>
                app.EvaluatorTypeDropDown.Items = items;
            end
            app.EvaluatorTypeDropDown.Value = evalType;
        end
        if isfield(guiData.problem.evaluator, 'timeout')
            app.EvaluatorTimeoutSpinner.Value = guiData.problem.evaluator.timeout;
        end
        if isfield(guiData.problem.evaluator, 'economicParameters') && isstruct(guiData.problem.evaluator.economicParameters)
            eco = guiData.problem.evaluator.economicParameters;
            f = fieldnames(eco);
            tableData = cell(length(f), 2);
            for i = 1:length(f)
                tableData{i, 1} = f{i};
                tableData{i, 2} = eco.(f{i});
            end
            app.EvaluatorParamsTable.Data = tableData;
        end
    end

    % 仿真器
    if isfield(guiData.simulator, 'type')
        app.SimulatorTypeDropDown.Value = guiData.simulator.type;
    end
    if isfield(guiData.simulator, 'settings')
        settings = guiData.simulator.settings;
        if isfield(settings, 'modelPath')
            app.ModelPathField.Value = settings.modelPath;
        end
        if isfield(settings, 'timeout')
            app.SimTimeoutSpinner.Value = settings.timeout;
        end
        if isfield(settings, 'maxRetries')
            app.MaxRetriesSpinner.Value = settings.maxRetries;
        end
        if isfield(settings, 'retryDelay')
            app.RetryDelaySpinner.Value = settings.retryDelay;
        end
        if isfield(settings, 'visible')
            app.VisibleCheckBox.Value = settings.visible;
        end
        if isfield(settings, 'suppressWarnings')
            app.SuppressWarningsCheckBox.Value = settings.suppressWarnings;
        end
    end

    % 节点映射 - 变量
    if isfield(guiData.simulator, 'nodeMapping') && isfield(guiData.simulator.nodeMapping, 'variables')
        varNames = fieldnames(guiData.simulator.nodeMapping.variables);
        varMapData = cell(length(varNames), 2);
        for i = 1:length(varNames)
            varMapData{i, 1} = varNames{i};
            varMapData{i, 2} = guiData.simulator.nodeMapping.variables.(varNames{i});
        end
        app.VarMappingTable.Data = varMapData;
    end

    % 节点映射 - 结果
    if isfield(guiData.simulator, 'nodeMapping') && isfield(guiData.simulator.nodeMapping, 'results')
        resNames = fieldnames(guiData.simulator.nodeMapping.results);
        resMapData = cell(length(resNames), 2);
        for i = 1:length(resNames)
            resMapData{i, 1} = resNames{i};
            resMapData{i, 2} = guiData.simulator.nodeMapping.results.(resNames{i});
        end
        app.ResMappingTable.Data = resMapData;
    end

    % 算法
    if isfield(guiData.algorithm, 'type')
        app.AlgorithmDropDown.Value = guiData.algorithm.type;

        switch guiData.algorithm.type
            case 'NSGA-II'
                app.NSGAIIPanel.Visible = 'on';
                app.PSOPanel.Visible = 'off';

                if isfield(guiData.algorithm, 'parameters')
                    params = guiData.algorithm.parameters;
                    if isfield(params, 'populationSize')
                        app.PopSizeSpinner_NSGAII.Value = params.populationSize;
                    end
                    if isfield(params, 'maxGenerations')
                        app.MaxGenSpinner_NSGAII.Value = params.maxGenerations;
                    end
                    if isfield(params, 'crossoverRate')
                        app.CrossoverSlider_NSGAII.Value = params.crossoverRate;
                        app.CrossoverValueLabel_NSGAII.Text = sprintf('%.2f', params.crossoverRate);
                    end
                    if isfield(params, 'mutationRate')
                        app.MutationSlider_NSGAII.Value = params.mutationRate;
                        app.MutationValueLabel_NSGAII.Text = sprintf('%.2f', params.mutationRate);
                    end
                    if isfield(params, 'crossoverDistIndex')
                        app.CrossoverDistSpinner_NSGAII.Value = params.crossoverDistIndex;
                    end
                    if isfield(params, 'mutationDistIndex')
                        app.MutationDistSpinner_NSGAII.Value = params.mutationDistIndex;
                    end
                end

            case 'PSO'
                app.NSGAIIPanel.Visible = 'off';
                app.PSOPanel.Visible = 'on';

                if isfield(guiData.algorithm, 'parameters')
                    params = guiData.algorithm.parameters;
                    if isfield(params, 'swarmSize')
                        app.SwarmSizeSpinner_PSO.Value = params.swarmSize;
                    end
                    if isfield(params, 'maxIterations')
                        app.MaxIterSpinner_PSO.Value = params.maxIterations;
                    end
                    if isfield(params, 'inertiaWeight')
                        app.InertiaSlider_PSO.Value = params.inertiaWeight;
                        app.InertiaValueLabel_PSO.Text = sprintf('%.2f', params.inertiaWeight);
                    end
                    if isfield(params, 'cognitiveCoeff')
                        app.CognitiveSlider_PSO.Value = params.cognitiveCoeff;
                        app.CognitiveValueLabel_PSO.Text = sprintf('%.2f', params.cognitiveCoeff);
                    end
                    if isfield(params, 'socialCoeff')
                        app.SocialSlider_PSO.Value = params.socialCoeff;
                        app.SocialValueLabel_PSO.Text = sprintf('%.2f', params.socialCoeff);
                    end
                    if isfield(params, 'maxVelocityRatio')
                        app.MaxVelSlider_PSO.Value = params.maxVelocityRatio;
                        app.MaxVelValueLabel_PSO.Text = sprintf('%.2f', params.maxVelocityRatio);
                    end
                end
        end
    end

    updateAlgorithmDescription(app);
    updateEstimations(app);
end

function handleOptimizationDataGUI(app, data)
    %% 处理优化数据（GUI 版本，包装 handleOptimizationData）

    % 处理来自 worker 的日志/错误事件（异步模式）
    if isstruct(data) && isfield(data, 'type')
        try
            msgType = lower(char(string(data.type)));
        catch
            msgType = '';
        end

        switch msgType
            case 'log'
                source = '';
                level = '';
                message = '';
                if isfield(data, 'source')
                    source = char(string(data.source));
                end
                if isfield(data, 'level')
                    level = char(string(data.level));
                end
                if isfield(data, 'message')
                    message = char(string(data.message));
                end

                prefix = '';
                if ~isempty(source) && ~isempty(level)
                    prefix = sprintf('[%s][%s] ', source, level);
                elseif ~isempty(source)
                    prefix = sprintf('[%s] ', source);
                elseif ~isempty(level)
                    prefix = sprintf('[%s] ', level);
                end

                logMessage(app, [prefix, message]);
                return;

            case 'error'
                errMsg = '未知错误';
                if isfield(data, 'message')
                    errMsg = char(string(data.message));
                end

                logMessage(app, '========================================');
                logMessage(app, sprintf('优化失败: %s', errMsg));

                % 恢复按钮状态
                app.RunButton.Enable = 'on';
                app.StopButton.Enable = 'off';
                app.SaveConfigButton.Enable = 'on';
                app.LoadConfigButton.Enable = 'on';
                app.SaveResultsButton.Enable = 'off';

                try
                    uialert(app.UIFigure, sprintf('优化失败: %s', errMsg), '错误', 'Icon', 'error');
                catch
                end
                return;
        end
    end

    if isfield(data, 'isFinal') && data.isFinal
        % 最终结果
        app.results = data.results;
        app.callbacks.onAlgorithmEndCallback(data.results);

        % 恢复按钮状态
        app.RunButton.Enable = 'on';
        app.StopButton.Enable = 'off';
        app.SaveConfigButton.Enable = 'on';
        app.LoadConfigButton.Enable = 'on';
        app.SaveResultsButton.Enable = 'on';

        logMessage(app, '========================================');
        logMessage(app, '优化完成！');

        % 询问是否保存
        promptSaveResults(app);

    else
        % 迭代数据
        iteration = 0;
        if isfield(data, 'iteration')
            iteration = data.iteration;
        end
        app.callbacks.onIterationCallback(iteration, data);
    end
end

function promptSaveResults(app)
    %% 询问是否保存结果

    answer = questdlg('是否保存优化结果？', '保存结果', '是', '否', '是');

    if strcmp(answer, '是')
        defaultName = sprintf('%s_results', app.config.problem.name);
        [file, path] = uiputfile('*.mat', '保存结果', defaultName);

        if file ~= 0
            try
                elapsedTime = toc(app.optimizationStartTime);
                resultsDir = ResultsSaver.saveAll(app.results, app.config, ...
                    elapsedTime, path, app.configFilePath);

                logMessage(app, sprintf('结果已保存至: %s', resultsDir));
                uialert(app.UIFigure, sprintf('结果已保存至:\n%s', resultsDir), ...
                    '保存成功', 'Icon', 'success');
            catch ME
                logMessage(app, sprintf('保存结果失败: %s', ME.message));
                uialert(app.UIFigure, sprintf('保存失败: %s', ME.message), ...
                    '错误', 'Icon', 'error');
            end
        end
    end
end
