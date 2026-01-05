classdef MAPOGUI < handle
    % MAPOGUI - MAPO 交互式图形用户界面 (布局修复版)
    %
    % 版本: v1.2 - 修复布局问题 (使用 Grid Layout 替代绝对定位)
    % 日期: 2025-12-12

    properties (Access = {?OptimizationCallbacks})
        % GUI 组件 - 主结构
        UIFigure                    % 主窗口
        MainGridLayout              % 主网格布局
        TabGroup                    % 标签页组
        StatusPanel                 % 状态栏面板
        StatusLabel                 % 状态栏标签
        ConfigStatusLabel           % 配置状态标签

        % Tab 1: 问题配置
        ProblemTab                  % 问题配置标签页
        ProblemNameField            % 问题名称输入框
        ProblemDescArea             % 问题描述文本区
        VariablesTable              % 决策变量表格
        AddVariableButton           % 添加变量按钮
        DeleteVariableButton        % 删除变量按钮
        ObjectivesTable             % 优化目标表格
        AddObjectiveButton          % 添加目标按钮
        DeleteObjectiveButton       % 删除目标按钮
        ConstraintsTable            % 约束条件表格
        AddConstraintButton         % 添加约束按钮
        DeleteConstraintButton      % 删除约束按钮

        % Tab 2: 评估器配置
        EvaluatorTab                    % 评估器配置标签页
        EvaluatorTypeDropDown           % 评估器类型下拉框（可编辑）
        EvaluatorRefreshButton          % 刷新评估器列表
        EvaluatorTimeoutSpinner         % 评估器超时时间选择器
        EvaluatorParamsTable            % 评估器参数表（写入 economicParameters）
        AddEvaluatorParamButton         % 添加参数
        DeleteEvaluatorParamButton      % 删除参数
        AutoFillEvaluatorParamsButton   % 推荐参数填充
        EvaluatorInfoArea               % 评估器说明/状态

        % Tab 3: 仿真器配置
        SimulatorTab                % 仿真器配置标签页
        SimulatorTypeDropDown       % 仿真器类型下拉框
        ModelPathField              % 模型路径输入框
        BrowseModelButton           % 浏览模型按钮
        SimTimeoutSpinner           % 仿真器超时设置
        MaxRetriesSpinner           % 最大重试次数
        RetryDelaySpinner           % 重试延迟
        VisibleCheckBox             % 可见运行
        SuppressWarningsCheckBox    % 抑制警告
        VarTemplateDropDown         % 变量模板类别下拉框
        ResTemplateDropDown         % 结果模板类别下拉框
        VarMappingTable             % 变量节点映射表
        ResMappingTable             % 结果节点映射表
        AddVarMappingButton         % 添加变量映射
        SyncVarMappingButton        % 同步变量映射（从问题变量名下拉选择）
        SyncResMappingButton        % 同步结果映射（从问题目标名下拉选择）
        DeleteVarMappingButton      % 删除变量映射
        ApplyVarTemplateButton      % 应用变量模板
        AddResMappingButton         % 添加结果映射
        DeleteResMappingButton      % 删除结果映射
        ApplyResTemplateButton      % 应用结果模板
        TestConnectionButton        % 测试连接按钮
        ValidatePathsButton         % 验证路径按钮
        ConnectionStatusLabel       % 连接状态标签

        % Tab 4: 算法配置
        AlgorithmTab                % 算法配置标签页
        AlgorithmDropDown           % 算法选择下拉框
        AlgorithmRefreshButton      % 刷新算法列表按钮
        AlgorithmDescArea           % 算法说明文本框
        NSGAIIPanel                 % NSGA-II 参数面板
        PSOPanel                    % PSO 参数面板
        GenericAlgorithmPanel       % 通用算法参数面板（新算法/自定义）
        AlgorithmParamsTable        % 通用算法参数表
        AddAlgorithmParamButton     % 添加算法参数
        DeleteAlgorithmParamButton  % 删除算法参数
        AutoFillAlgorithmParamsButton % 填充默认算法参数
        PopSizeSpinner_NSGAII       % NSGA-II 种群大小
        MaxGenSpinner_NSGAII        % NSGA-II 最大代数
        CrossoverSlider_NSGAII      % NSGA-II 交叉概率
        CrossoverValueLabel_NSGAII  % NSGA-II 交叉概率显示
        MutationSlider_NSGAII       % NSGA-II 变异概率
        MutationValueLabel_NSGAII   % NSGA-II 变异概率显示
        CrossoverDistSpinner_NSGAII % NSGA-II 交叉分布指数
        MutationDistSpinner_NSGAII  % NSGA-II 变异分布指数
        SwarmSizeSpinner_PSO        % PSO 粒子群大小
        MaxIterSpinner_PSO          % PSO 最大迭代数
        InertiaSlider_PSO           % PSO 惯性权重
        InertiaValueLabel_PSO       % PSO 惯性权重显示
        CognitiveSlider_PSO         % PSO 认知系数
        CognitiveValueLabel_PSO     % PSO 认知系数显示
        SocialSlider_PSO            % PSO 社会系数
        SocialValueLabel_PSO        % PSO 社会系数显示
        MaxVelSlider_PSO            % PSO 最大速度比例
        MaxVelValueLabel_PSO        % PSO 最大速度比例显示
        TotalEvalsLabel             % 预估评估次数标签
        EstTimeLabel                % 预估时间标签

        % Tab 5: 运行与结果
        RunResultsTab               % 运行与结果标签页
        RunButton                   % 开始优化按钮
        PauseButton                 % 暂停按钮（占位）
        StopButton                  % 停止按钮
        SaveConfigButton            % 保存配置按钮
        LoadConfigButton            % 加载配置按钮
        SaveResultsButton           % 保存结果按钮
        ClearLogButton              % 清除日志按钮
        ExportResultsButton         % 导出结果按钮
        ProblemStatusLabel          % 问题配置状态
        SimulatorStatusLabel        % 仿真器配置状态
        AlgorithmStatusLabel        % 算法配置状态
        ProgressBar                 % 进度条（0-100）
        ParetoAxes                  % Pareto 前沿坐标轴
        ConvergenceAxes             % 收敛曲线坐标轴
        LogTextArea                 % 日志输出
        ResultsTable                % 结果表格

        % GUI 数据结构
        guiData struct              % 存储所有 GUI 数据
        config struct               % 配置结构体
        configFilePath char         % 配置文件路径
        configBaseDir char          % 配置基准目录（用于解析相对路径）
        results struct              % 优化结果

        % 异步运行与回调
        asyncFuture                 % parfeval Future 或同步结果
        dataQueue                   % DataQueue（异步模式）
        callbacks                   % OptimizationCallbacks 实例
        optimizationStartTime       % tic 起始时间
    end

    methods (Access = public)

        function app = MAPOGUI()
            % MAPOGUI 构造函数
            
            % 创建主窗口
            createMainWindow(app);

            % 创建标签页组
            createTabGroup(app);

            % 创建所有 Tab
            createProblemTab(app);
            createEvaluatorTab(app);
            createSimulatorTab(app);
            createAlgorithmTab(app);
            createRunResultsTab(app);

            % 初始化数据
            initializeData(app);

            % 显示窗口
            app.UIFigure.Visible = 'on';

            % 更新状态
            updateStatus(app, 'GUI 已就绪');
            updateConfigStatus(app);
        end

        function delete(app)
            % 析构函数
            if isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
        end
    end

    methods (Access = private)

        %% 界面创建方法

        function createMainWindow(app)
            % 创建主窗口
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Name = 'MAPO - MATLAB-Aspen Process Optimizer v2.0';
            app.UIFigure.Position = [100, 50, 1400, 850];
            app.UIFigure.Color = [0.94, 0.94, 0.94];

            % 主布局
            app.MainGridLayout = uigridlayout(app.UIFigure);
            app.MainGridLayout.RowHeight = {'1x', 35}; % 内容区自适应，状态栏固定35px
            app.MainGridLayout.ColumnWidth = {'1x'};
            app.MainGridLayout.Padding = [0, 0, 0, 0];
            app.MainGridLayout.RowSpacing = 0;

            % --- 状态栏区域 ---
            app.StatusPanel = uipanel(app.MainGridLayout);
            app.StatusPanel.Layout.Row = 2;
            app.StatusPanel.Layout.Column = 1;
            app.StatusPanel.BorderType = 'none'; % 去掉边框看起来更平滑
            app.StatusPanel.BackgroundColor = [0.2, 0.2, 0.2]; % 深灰色底

            statusGrid = uigridlayout(app.StatusPanel);
            statusGrid.RowHeight = {'1x'};
            statusGrid.ColumnWidth = {'1x', 'fit'};
            statusGrid.Padding = [15, 0, 15, 0];

            app.StatusLabel = uilabel(statusGrid);
            app.StatusLabel.Text = '状态: 正在初始化...';
            app.StatusLabel.FontColor = [1, 1, 1];
            
            app.ConfigStatusLabel = uilabel(statusGrid);
            app.ConfigStatusLabel.Text = '配置: 未完成';
            app.ConfigStatusLabel.FontColor = [1, 0.8, 0];
            app.ConfigStatusLabel.HorizontalAlignment = 'right';
        end

        function createTabGroup(app)
            app.TabGroup = uitabgroup(app.MainGridLayout);
            app.TabGroup.Layout.Row = 1;
            app.TabGroup.Layout.Column = 1;
        end

        function createProblemTab(app)
            % 创建 Tab 1: 问题配置
            app.ProblemTab = uitab(app.TabGroup);
            app.ProblemTab.Title = '1. 问题配置';
            app.ProblemTab.BackgroundColor = [0.96, 0.96, 0.96];

            % 创建可滚动的网格布局
            % 使用固定像素高度，总高度超过窗口高度会自动显示滚动条
            gridLayout = uigridlayout(app.ProblemTab, [4, 1]);
            gridLayout.ColumnWidth = {'1x'};
            % 每个面板给予充足空间，总高度约 1150px，超过窗口高度（约 750px）
            gridLayout.RowHeight = {180, 350, 300, 280};
            gridLayout.Padding = [20, 20, 20, 20];
            gridLayout.RowSpacing = 15;
            gridLayout.Scrollable = 'on';  % 启用垂直滚动条

            % Panel 1: 基本信息
            createBasicInfoPanel(app, gridLayout, 1);

            % Panel 2: 决策变量
            createVariablesPanel(app, gridLayout, 2);

            % Panel 3: 优化目标
            createObjectivesPanel(app, gridLayout, 3);

            % Panel 4: 约束条件
            createConstraintsPanel(app, gridLayout, 4);
        end

        function createBasicInfoPanel(app, parent, row)
            % 创建基本信息面板 (使用 Grid Layout)
            panel = uipanel(parent);
            panel.Title = '基本信息';
            panel.Layout.Row = row;
            panel.Layout.Column = 1;
            panel.FontWeight = 'bold';
            panel.BackgroundColor = [0.95, 0.95, 1];
            
            % 面板内部布局：2行2列
            innerGrid = uigridlayout(panel);
            innerGrid.ColumnWidth = {'fit', '1x'}; % 标签自适应宽度，输入框占满剩余
            innerGrid.RowHeight = {30, '1x'};      % 第一行30px，第二行占满剩余
            innerGrid.Padding = [15, 10, 15, 10];
            innerGrid.RowSpacing = 10;
            innerGrid.ColumnSpacing = 15;

            % 1. 问题名称
            lbl1 = uilabel(innerGrid);
            lbl1.Text = '问题名称:';
            lbl1.FontWeight = 'bold';
            lbl1.Layout.Row = 1; 
            lbl1.Layout.Column = 1;
            
            app.ProblemNameField = uieditfield(innerGrid, 'text');
            app.ProblemNameField.Layout.Row = 1;
            app.ProblemNameField.Layout.Column = 2;
            app.ProblemNameField.Placeholder = '请输入问题名称（例如: ORC_Optimization）';
            app.ProblemNameField.ValueChangedFcn = @(src, event) updateConfigStatus(app);

            % 2. 问题描述
            lbl2 = uilabel(innerGrid);
            lbl2.Text = '问题描述:';
            lbl2.FontWeight = 'bold';
            lbl2.VerticalAlignment = 'top'; % 文字顶对齐
            lbl2.Layout.Row = 2;
            lbl2.Layout.Column = 1;
            
            app.ProblemDescArea = uitextarea(innerGrid);
            app.ProblemDescArea.Layout.Row = 2;
            app.ProblemDescArea.Layout.Column = 2;
            app.ProblemDescArea.Placeholder = '请简要描述优化问题（可选）';
        end

        function createVariablesPanel(app, parent, row)
            % 创建决策变量面板 (使用 Grid Layout)
            panel = uipanel(parent);
            panel.Title = '决策变量配置';
            panel.Layout.Row = row;
            panel.Layout.Column = 1;
            panel.FontWeight = 'bold';
            panel.BackgroundColor = [1, 0.95, 0.95];

            % 面板内部布局：2行1列
            innerGrid = uigridlayout(panel);
            innerGrid.ColumnWidth = {'1x'};
            innerGrid.RowHeight = {35, '1x'}; % 第一行按钮，第二行表格
            innerGrid.Padding = [10, 5, 10, 10];
            innerGrid.RowSpacing = 5;

            % --- 按钮区域 (子网格) ---
            btnGrid = uigridlayout(innerGrid);
            btnGrid.Layout.Row = 1;
            btnGrid.Layout.Column = 1;
            btnGrid.RowHeight = {'1x'};
            btnGrid.ColumnWidth = {110, 110, '1x'}; % 按钮固定宽，右侧留白
            btnGrid.Padding = [0,0,0,0];
            btnGrid.BackgroundColor = [1, 0.95, 0.95]; % 与背景融合

            app.AddVariableButton = uibutton(btnGrid, 'push');
            app.AddVariableButton.Text = '+ 添加变量';
            app.AddVariableButton.BackgroundColor = [0.2, 0.7, 0.3];
            app.AddVariableButton.FontColor = [1, 1, 1];
            app.AddVariableButton.FontWeight = 'bold';
            app.AddVariableButton.ButtonPushedFcn = @(src, event) addVariableButtonPushed(app);

            app.DeleteVariableButton = uibutton(btnGrid, 'push');
            app.DeleteVariableButton.Text = '- 删除变量';
            app.DeleteVariableButton.BackgroundColor = [0.8, 0.2, 0.2];
            app.DeleteVariableButton.FontColor = [1, 1, 1];
            app.DeleteVariableButton.FontWeight = 'bold';
            app.DeleteVariableButton.ButtonPushedFcn = @(src, event) deleteVariableButtonPushed(app);

            % --- 表格区域 ---
            app.VariablesTable = uitable(innerGrid);
            app.VariablesTable.Layout.Row = 2;
            app.VariablesTable.Layout.Column = 1;
            app.VariablesTable.ColumnName = {'变量名', '类型', '下界', '上界', '单位', '描述'};
            app.VariablesTable.ColumnEditable = [true, true, true, true, true, true];
            app.VariablesTable.ColumnFormat = {'char', {'continuous', 'integer', 'discrete'}, ...
                                                'numeric', 'numeric', 'char', 'char'};
            % 让表格列宽稍微智能一点，描述列宽一些
            app.VariablesTable.ColumnWidth = {150, 100, 80, 80, 80, 'auto'}; 
            app.VariablesTable.Data = cell(0, 6);
            app.VariablesTable.RowName = 'numbered';
            app.VariablesTable.CellEditCallback = @(src, event) updateConfigStatus(app);
        end

        function createObjectivesPanel(app, parent, row)
            % 创建优化目标面板
            panel = uipanel(parent);
            panel.Title = '优化目标配置';
            panel.Layout.Row = row;
            panel.Layout.Column = 1;
            panel.FontWeight = 'bold';
            panel.BackgroundColor = [0.95, 1, 0.95];

            innerGrid = uigridlayout(panel);
            innerGrid.ColumnWidth = {'1x'};
            innerGrid.RowHeight = {35, '1x'};
            innerGrid.Padding = [10, 5, 10, 10];
            innerGrid.RowSpacing = 5;

            % 按钮区域
            btnGrid = uigridlayout(innerGrid);
            btnGrid.Layout.Row = 1;
            btnGrid.Layout.Column = 1;
            btnGrid.RowHeight = {'1x'};
            btnGrid.ColumnWidth = {110, 110, '1x'};
            btnGrid.Padding = [0,0,0,0];
            btnGrid.BackgroundColor = [0.95, 1, 0.95];

            app.AddObjectiveButton = uibutton(btnGrid, 'push');
            app.AddObjectiveButton.Text = '+ 添加目标';
            app.AddObjectiveButton.BackgroundColor = [0.2, 0.7, 0.3];
            app.AddObjectiveButton.FontColor = [1, 1, 1];
            app.AddObjectiveButton.FontWeight = 'bold';
            app.AddObjectiveButton.ButtonPushedFcn = @(src, event) addObjectiveButtonPushed(app);

            app.DeleteObjectiveButton = uibutton(btnGrid, 'push');
            app.DeleteObjectiveButton.Text = '- 删除目标';
            app.DeleteObjectiveButton.BackgroundColor = [0.8, 0.2, 0.2];
            app.DeleteObjectiveButton.FontColor = [1, 1, 1];
            app.DeleteObjectiveButton.FontWeight = 'bold';
            app.DeleteObjectiveButton.ButtonPushedFcn = @(src, event) deleteObjectiveButtonPushed(app);

            % 表格
            app.ObjectivesTable = uitable(innerGrid);
            app.ObjectivesTable.Layout.Row = 2;
            app.ObjectivesTable.Layout.Column = 1;
            app.ObjectivesTable.ColumnName = {'目标名', '类型', '权重', '描述'};
            app.ObjectivesTable.ColumnEditable = [true, true, true, true];
            app.ObjectivesTable.ColumnFormat = {'char', {'minimize', 'maximize'}, 'numeric', 'char'};
            app.ObjectivesTable.ColumnWidth = {200, 100, 80, 'auto'};
            app.ObjectivesTable.Data = cell(0, 4);
            app.ObjectivesTable.RowName = 'numbered';
            app.ObjectivesTable.CellEditCallback = @(src, event) updateConfigStatus(app);
        end

        function createConstraintsPanel(app, parent, row)
            % 创建约束条件面板
            panel = uipanel(parent);
            panel.Title = '约束条件配置（可选）';
            panel.Layout.Row = row;
            panel.Layout.Column = 1;
            panel.FontWeight = 'bold';
            panel.BackgroundColor = [1, 1, 0.95];

            innerGrid = uigridlayout(panel);
            innerGrid.ColumnWidth = {'1x'};
            innerGrid.RowHeight = {35, '1x'};
            innerGrid.Padding = [10, 5, 10, 10];
            innerGrid.RowSpacing = 5;

            % 按钮区域
            btnGrid = uigridlayout(innerGrid);
            btnGrid.Layout.Row = 1;
            btnGrid.Layout.Column = 1;
            btnGrid.RowHeight = {'1x'};
            btnGrid.ColumnWidth = {110, 110, '1x'};
            btnGrid.Padding = [0,0,0,0];
            btnGrid.BackgroundColor = [1, 1, 0.95];

            app.AddConstraintButton = uibutton(btnGrid, 'push');
            app.AddConstraintButton.Text = '+ 添加约束';
            app.AddConstraintButton.BackgroundColor = [0.2, 0.7, 0.3];
            app.AddConstraintButton.FontColor = [1, 1, 1];
            app.AddConstraintButton.FontWeight = 'bold';
            app.AddConstraintButton.ButtonPushedFcn = @(src, event) addConstraintButtonPushed(app);

            app.DeleteConstraintButton = uibutton(btnGrid, 'push');
            app.DeleteConstraintButton.Text = '- 删除约束';
            app.DeleteConstraintButton.BackgroundColor = [0.8, 0.2, 0.2];
            app.DeleteConstraintButton.FontColor = [1, 1, 1];
            app.DeleteConstraintButton.FontWeight = 'bold';
            app.DeleteConstraintButton.ButtonPushedFcn = @(src, event) deleteConstraintButtonPushed(app);

            % 表格
            app.ConstraintsTable = uitable(innerGrid);
            app.ConstraintsTable.Layout.Row = 2;
            app.ConstraintsTable.Layout.Column = 1;
            app.ConstraintsTable.ColumnName = {'约束名', '类型', '表达式', '描述'};
            app.ConstraintsTable.ColumnEditable = [true, true, true, true];
            app.ConstraintsTable.ColumnFormat = {'char', {'inequality', 'equality'}, 'char', 'char'};
            app.ConstraintsTable.ColumnWidth = {150, 100, 300, 'auto'};
            app.ConstraintsTable.Data = cell(0, 4);
            app.ConstraintsTable.RowName = 'numbered';
            app.ConstraintsTable.CellEditCallback = @(src, event) updateConfigStatus(app);
        end

        function createEvaluatorTab(app)
            % 创建 Tab 2: 评估器配置（支持自定义评估器与参数表）
            app.EvaluatorTab = uitab(app.TabGroup);
            app.EvaluatorTab.Title = '2. 评估器配置';
            app.EvaluatorTab.BackgroundColor = [0.96, 0.96, 0.96];

            outerGrid = uigridlayout(app.EvaluatorTab, [2, 2]);
            outerGrid.RowHeight = {180, '1x'};
            outerGrid.ColumnWidth = {520, '1x'};
            outerGrid.Padding = [20, 20, 20, 20];
            outerGrid.RowSpacing = 15;
            outerGrid.ColumnSpacing = 15;

            %% 左上：评估器设置
            settingsPanel = uipanel(outerGrid);
            settingsPanel.Title = '评估器设置';
            settingsPanel.FontWeight = 'bold';
            settingsPanel.BackgroundColor = [0.97, 0.97, 0.97];
            settingsPanel.Layout.Row = 1;
            settingsPanel.Layout.Column = 1;

            settingsGrid = uigridlayout(settingsPanel, [2, 3]);
            settingsGrid.RowHeight = {35, 35};
            settingsGrid.ColumnWidth = {110, '1x', 110};
            settingsGrid.Padding = [15, 10, 15, 10];
            settingsGrid.RowSpacing = 10;
            settingsGrid.ColumnSpacing = 10;

            typeLabel = uilabel(settingsGrid);
            typeLabel.Text = '评估器类型:';
            typeLabel.FontWeight = 'bold';
            typeLabel.Layout.Row = 1;
            typeLabel.Layout.Column = 1;

            app.EvaluatorTypeDropDown = uidropdown(settingsGrid);
            app.EvaluatorTypeDropDown.Layout.Row = 1;
            app.EvaluatorTypeDropDown.Layout.Column = 2;
            app.EvaluatorTypeDropDown.Items = getAvailableEvaluatorTypes(app);
            if isempty(app.EvaluatorTypeDropDown.Items)
                app.EvaluatorTypeDropDown.Items = {'MyCaseEvaluator'};
            end
            if ismember('ORCEvaluator', app.EvaluatorTypeDropDown.Items)
                app.EvaluatorTypeDropDown.Value = 'ORCEvaluator';
            else
                app.EvaluatorTypeDropDown.Value = app.EvaluatorTypeDropDown.Items{1};
            end
            app.EvaluatorTypeDropDown.Editable = 'on';
            app.EvaluatorTypeDropDown.Tooltip = '评估器类名（支持自定义），例如: ORCEvaluator, MyCaseEvaluator';
            app.EvaluatorTypeDropDown.ValueChangedFcn = @(src, event) evaluatorTypeChanged(app);

            app.EvaluatorRefreshButton = uibutton(settingsGrid, 'push');
            app.EvaluatorRefreshButton.Text = '刷新';
            app.EvaluatorRefreshButton.Layout.Row = 1;
            app.EvaluatorRefreshButton.Layout.Column = 3;
            app.EvaluatorRefreshButton.ButtonPushedFcn = @(src, event) refreshEvaluatorList(app);

            timeoutLabel = uilabel(settingsGrid);
            timeoutLabel.Text = '超时时间(秒):';
            timeoutLabel.FontWeight = 'bold';
            timeoutLabel.Layout.Row = 2;
            timeoutLabel.Layout.Column = 1;

            app.EvaluatorTimeoutSpinner = uispinner(settingsGrid);
            app.EvaluatorTimeoutSpinner.Layout.Row = 2;
            app.EvaluatorTimeoutSpinner.Layout.Column = 2;
            app.EvaluatorTimeoutSpinner.Value = 300;
            app.EvaluatorTimeoutSpinner.Limits = [10, 3600];
            app.EvaluatorTimeoutSpinner.Step = 10;
            app.EvaluatorTimeoutSpinner.ValueChangedFcn = @(src, event) updateConfigStatus(app);

            hintLabel = uilabel(settingsGrid);
            hintLabel.Text = '可实现 setProblem(problem)';
            hintLabel.FontColor = [0.3, 0.3, 0.3];
            hintLabel.Layout.Row = 2;
            hintLabel.Layout.Column = 3;

            %% 左下：评估器参数表
            paramsPanel = uipanel(outerGrid);
            paramsPanel.Title = '评估器参数';
            paramsPanel.FontWeight = 'bold';
            paramsPanel.BackgroundColor = [0.97, 0.97, 0.97];
            paramsPanel.Layout.Row = 2;
            paramsPanel.Layout.Column = 1;

            paramsGrid = uigridlayout(paramsPanel, [2, 1]);
            paramsGrid.RowHeight = {35, '1x'};
            paramsGrid.ColumnWidth = {'1x'};
            paramsGrid.Padding = [15, 10, 15, 10];
            paramsGrid.RowSpacing = 10;

            controlGrid = uigridlayout(paramsGrid, [1, 4]);
            controlGrid.RowHeight = {'1x'};
            controlGrid.ColumnWidth = {'1x', 'fit', 'fit', 'fit'};
            controlGrid.Padding = [0, 0, 0, 0];
            controlGrid.ColumnSpacing = 8;

            paramsHint = uilabel(controlGrid);
            paramsHint.Text = '写入 problem.evaluator.economicParameters（名称需为合法 MATLAB 标识符）';
            paramsHint.FontColor = [0.3, 0.3, 0.3];
            paramsHint.Layout.Row = 1;
            paramsHint.Layout.Column = 1;

            app.AddEvaluatorParamButton = uibutton(controlGrid, 'push');
            app.AddEvaluatorParamButton.Text = '+ 添加';
            app.AddEvaluatorParamButton.Layout.Row = 1;
            app.AddEvaluatorParamButton.Layout.Column = 2;
            app.AddEvaluatorParamButton.ButtonPushedFcn = @(src, event) addEvaluatorParamButtonPushed(app);

            app.DeleteEvaluatorParamButton = uibutton(controlGrid, 'push');
            app.DeleteEvaluatorParamButton.Text = '删除';
            app.DeleteEvaluatorParamButton.Layout.Row = 1;
            app.DeleteEvaluatorParamButton.Layout.Column = 3;
            app.DeleteEvaluatorParamButton.ButtonPushedFcn = @(src, event) deleteEvaluatorParamButtonPushed(app);

            app.AutoFillEvaluatorParamsButton = uibutton(controlGrid, 'push');
            app.AutoFillEvaluatorParamsButton.Text = '推荐填充';
            app.AutoFillEvaluatorParamsButton.Layout.Row = 1;
            app.AutoFillEvaluatorParamsButton.Layout.Column = 4;
            app.AutoFillEvaluatorParamsButton.ButtonPushedFcn = @(src, event) autoFillEvaluatorParamsButtonPushed(app);

            app.EvaluatorParamsTable = uitable(paramsGrid);
            app.EvaluatorParamsTable.Layout.Row = 2;
            app.EvaluatorParamsTable.Layout.Column = 1;
            app.EvaluatorParamsTable.ColumnName = {'参数名', '值'};
            app.EvaluatorParamsTable.ColumnEditable = [true, true];
            app.EvaluatorParamsTable.ColumnFormat = {'char', 'numeric'};
            app.EvaluatorParamsTable.ColumnWidth = {200, 'auto'};
            app.EvaluatorParamsTable.Data = cell(0, 2);
            app.EvaluatorParamsTable.RowName = 'numbered';
            app.EvaluatorParamsTable.CellEditCallback = @(src, event) updateConfigStatus(app);

            %% 右侧：说明/状态
            infoPanel = uipanel(outerGrid);
            infoPanel.Title = '说明 / 自定义评估器';
            infoPanel.FontWeight = 'bold';
            infoPanel.BackgroundColor = [0.97, 0.97, 0.97];
            infoPanel.Layout.Row = [1, 2];
            infoPanel.Layout.Column = 2;

            infoGrid = uigridlayout(infoPanel, [1, 1]);
            infoGrid.RowHeight = {'1x'};
            infoGrid.ColumnWidth = {'1x'};
            infoGrid.Padding = [15, 10, 15, 10];

            app.EvaluatorInfoArea = uitextarea(infoGrid);
            app.EvaluatorInfoArea.Layout.Row = 1;
            app.EvaluatorInfoArea.Layout.Column = 1;
            app.EvaluatorInfoArea.Editable = 'off';

            updateEvaluatorInfo(app);
        end

        function createSimulatorTab(app)
            % 创建 Tab 3: 仿真器配置
            app.SimulatorTab = uitab(app.TabGroup);
            app.SimulatorTab.Title = '3. 仿真器配置';
            app.SimulatorTab.BackgroundColor = [0.96, 0.96, 0.96];

            outerGrid = uigridlayout(app.SimulatorTab, [3, 2]);
            outerGrid.RowHeight = {210, '1x', 120};
            outerGrid.ColumnWidth = {'1x', '1x'};
            outerGrid.Padding = [20, 20, 20, 20];
            outerGrid.RowSpacing = 15;
            outerGrid.ColumnSpacing = 15;

            % Panel 1: 仿真器设置（跨两列）
            settingsPanel = uipanel(outerGrid);
            settingsPanel.Title = '仿真器设置';
            settingsPanel.FontWeight = 'bold';
            settingsPanel.BackgroundColor = [0.97, 0.97, 0.97];
            settingsPanel.Layout.Row = 1;
            settingsPanel.Layout.Column = [1, 2];

            settingsGrid = uigridlayout(settingsPanel);
            settingsGrid.RowHeight = {30, 30, 30, 30};
            settingsGrid.ColumnWidth = {120, '1x', 120, '1x', 90};
            settingsGrid.Padding = [15, 10, 15, 10];
            settingsGrid.RowSpacing = 10;
            settingsGrid.ColumnSpacing = 10;

            % 仿真器类型
            typeLabel = uilabel(settingsGrid);
            typeLabel.Text = '仿真器类型:';
            typeLabel.FontWeight = 'bold';
            typeLabel.Layout.Row = 1;
            typeLabel.Layout.Column = 1;

            app.SimulatorTypeDropDown = uidropdown(settingsGrid);
            app.SimulatorTypeDropDown.Items = {'Aspen', 'MATLAB', 'Python'};
            app.SimulatorTypeDropDown.Value = 'Aspen';
            app.SimulatorTypeDropDown.Layout.Row = 1;
            app.SimulatorTypeDropDown.Layout.Column = [2, 5];
            app.SimulatorTypeDropDown.ValueChangedFcn = @(src, event) updateConfigStatus(app);

            % 模型路径
            pathLabel = uilabel(settingsGrid);
            pathLabel.Text = '模型文件路径:';
            pathLabel.FontWeight = 'bold';
            pathLabel.Layout.Row = 2;
            pathLabel.Layout.Column = 1;

            app.ModelPathField = uieditfield(settingsGrid, 'text');
            app.ModelPathField.Layout.Row = 2;
            app.ModelPathField.Layout.Column = [2, 4];
            app.ModelPathField.Tooltip = '请选择或输入模型文件的绝对路径';
            app.ModelPathField.ValueChangedFcn = @(src, event) updateConfigStatus(app);

            app.BrowseModelButton = uibutton(settingsGrid, 'push');
            app.BrowseModelButton.Text = '浏览...';
            app.BrowseModelButton.Layout.Row = 2;
            app.BrowseModelButton.Layout.Column = 5;
            app.BrowseModelButton.ButtonPushedFcn = @(src, event) browseModelButtonPushed(app);

            % 超时与重试
            timeoutLabel = uilabel(settingsGrid);
            timeoutLabel.Text = '超时(秒):';
            timeoutLabel.FontWeight = 'bold';
            timeoutLabel.Layout.Row = 3;
            timeoutLabel.Layout.Column = 1;

            app.SimTimeoutSpinner = uispinner(settingsGrid);
            app.SimTimeoutSpinner.Limits = [10, 3600];
            app.SimTimeoutSpinner.Step = 10;
            app.SimTimeoutSpinner.Value = 300;
            app.SimTimeoutSpinner.Layout.Row = 3;
            app.SimTimeoutSpinner.Layout.Column = 2;

            retryLabel = uilabel(settingsGrid);
            retryLabel.Text = '最大重试:';
            retryLabel.FontWeight = 'bold';
            retryLabel.Layout.Row = 3;
            retryLabel.Layout.Column = 3;

            app.MaxRetriesSpinner = uispinner(settingsGrid);
            app.MaxRetriesSpinner.Limits = [0, 50];
            app.MaxRetriesSpinner.Step = 1;
            app.MaxRetriesSpinner.Value = 3;
            app.MaxRetriesSpinner.Layout.Row = 3;
            app.MaxRetriesSpinner.Layout.Column = 4;

            delayLabel = uilabel(settingsGrid);
            delayLabel.Text = '重试延迟(秒):';
            delayLabel.FontWeight = 'bold';
            delayLabel.Layout.Row = 4;
            delayLabel.Layout.Column = 1;

            app.RetryDelaySpinner = uispinner(settingsGrid);
            app.RetryDelaySpinner.Limits = [0, 600];
            app.RetryDelaySpinner.Step = 1;
            app.RetryDelaySpinner.Value = 5;
            app.RetryDelaySpinner.Layout.Row = 4;
            app.RetryDelaySpinner.Layout.Column = 2;

            app.VisibleCheckBox = uicheckbox(settingsGrid);
            app.VisibleCheckBox.Text = '可见运行';
            app.VisibleCheckBox.Value = false;
            app.VisibleCheckBox.Layout.Row = 4;
            app.VisibleCheckBox.Layout.Column = 3;

            app.SuppressWarningsCheckBox = uicheckbox(settingsGrid);
            app.SuppressWarningsCheckBox.Text = '抑制警告';
            app.SuppressWarningsCheckBox.Value = true;
            app.SuppressWarningsCheckBox.Layout.Row = 4;
            app.SuppressWarningsCheckBox.Layout.Column = 4;

            % Panel 2: 变量节点映射
            varPanel = uipanel(outerGrid);
            varPanel.Title = '变量节点映射';
            varPanel.FontWeight = 'bold';
            varPanel.BackgroundColor = [0.97, 0.97, 1.0];
            varPanel.Layout.Row = 2;
            varPanel.Layout.Column = 1;

            varGrid = uigridlayout(varPanel);
            varGrid.RowHeight = {35, '1x'};
            varGrid.ColumnWidth = {'1x'};
            varGrid.Padding = [10, 8, 10, 10];
            varGrid.RowSpacing = 8;

            varTopGrid = uigridlayout(varGrid);
            varTopGrid.Layout.Row = 1;
            varTopGrid.Layout.Column = 1;
            varTopGrid.RowHeight = {'1x'};
            varTopGrid.ColumnWidth = {'1x', 90, 90, 90, 90};
            varTopGrid.Padding = [0, 0, 0, 0];
            varTopGrid.ColumnSpacing = 8;

            app.VarTemplateDropDown = uidropdown(varTopGrid);
            app.VarTemplateDropDown.Items = AspenNodeTemplates.getTemplateCategories();
            app.VarTemplateDropDown.Value = app.VarTemplateDropDown.Items{1};

            app.SyncVarMappingButton = uibutton(varTopGrid, 'push');
            app.SyncVarMappingButton.Text = '同步';
            app.SyncVarMappingButton.Tooltip = '从“问题配置”中的变量名同步映射行（保留已填写的节点路径）';
            app.SyncVarMappingButton.ButtonPushedFcn = @(src, event) syncVarMappingButtonPushed(app);

            app.ApplyVarTemplateButton = uibutton(varTopGrid, 'push');
            app.ApplyVarTemplateButton.Text = '应用模板';
            app.ApplyVarTemplateButton.ButtonPushedFcn = @(src, event) applyVarTemplateButtonPushed(app);

            app.AddVarMappingButton = uibutton(varTopGrid, 'push');
            app.AddVarMappingButton.Text = '+添加';
            app.AddVarMappingButton.ButtonPushedFcn = @(src, event) addVarMappingButtonPushed(app);

            app.DeleteVarMappingButton = uibutton(varTopGrid, 'push');
            app.DeleteVarMappingButton.Text = '删除';
            app.DeleteVarMappingButton.ButtonPushedFcn = @(src, event) deleteVarMappingButtonPushed(app);

            app.VarMappingTable = uitable(varGrid);
            app.VarMappingTable.Layout.Row = 2;
            app.VarMappingTable.Layout.Column = 1;
            app.VarMappingTable.ColumnName = {'变量名', '节点路径'};
            app.VarMappingTable.ColumnEditable = [true, true];
            app.VarMappingTable.ColumnFormat = {'char', 'char'};
            app.VarMappingTable.ColumnWidth = {140, 'auto'};
            app.VarMappingTable.Data = cell(0, 2);
            app.VarMappingTable.RowName = 'numbered';
            app.VarMappingTable.CellEditCallback = @(src, event) updateConfigStatus(app);
            refreshVarMappingDropdown(app);

            % Panel 3: 结果节点映射
            resPanel = uipanel(outerGrid);
            resPanel.Title = '结果节点映射';
            resPanel.FontWeight = 'bold';
            resPanel.BackgroundColor = [1.0, 0.97, 0.97];
            resPanel.Layout.Row = 2;
            resPanel.Layout.Column = 2;

            resGrid = uigridlayout(resPanel);
            resGrid.RowHeight = {35, '1x'};
            resGrid.ColumnWidth = {'1x'};
            resGrid.Padding = [10, 8, 10, 10];
            resGrid.RowSpacing = 8;

            resTopGrid = uigridlayout(resGrid);
            resTopGrid.Layout.Row = 1;
            resTopGrid.Layout.Column = 1;
            resTopGrid.RowHeight = {'1x'};
            resTopGrid.ColumnWidth = {'1x', 90, 90, 90, 90};
            resTopGrid.Padding = [0, 0, 0, 0];
            resTopGrid.ColumnSpacing = 8;

            app.ResTemplateDropDown = uidropdown(resTopGrid);
            app.ResTemplateDropDown.Items = AspenNodeTemplates.getTemplateCategories();
            app.ResTemplateDropDown.Value = app.ResTemplateDropDown.Items{1};

            app.SyncResMappingButton = uibutton(resTopGrid, 'push');
            app.SyncResMappingButton.Text = '同步';
            app.SyncResMappingButton.Tooltip = '从“问题配置”中的目标名同步映射行（保留已填写的节点路径）';
            app.SyncResMappingButton.ButtonPushedFcn = @(src, event) syncResMappingButtonPushed(app);

            app.ApplyResTemplateButton = uibutton(resTopGrid, 'push');
            app.ApplyResTemplateButton.Text = '应用模板';
            app.ApplyResTemplateButton.ButtonPushedFcn = @(src, event) applyResTemplateButtonPushed(app);

            app.AddResMappingButton = uibutton(resTopGrid, 'push');
            app.AddResMappingButton.Text = '+添加';
            app.AddResMappingButton.ButtonPushedFcn = @(src, event) addResMappingButtonPushed(app);

            app.DeleteResMappingButton = uibutton(resTopGrid, 'push');
            app.DeleteResMappingButton.Text = '删除';
            app.DeleteResMappingButton.ButtonPushedFcn = @(src, event) deleteResMappingButtonPushed(app);

            app.ResMappingTable = uitable(resGrid);
            app.ResMappingTable.Layout.Row = 2;
            app.ResMappingTable.Layout.Column = 1;
            app.ResMappingTable.ColumnName = {'结果名', '节点路径'};
            app.ResMappingTable.ColumnEditable = [true, true];
            app.ResMappingTable.ColumnFormat = {'char', 'char'};
            app.ResMappingTable.ColumnWidth = {140, 'auto'};
            app.ResMappingTable.Data = cell(0, 2);
            app.ResMappingTable.RowName = 'numbered';
            app.ResMappingTable.CellEditCallback = @(src, event) updateConfigStatus(app);
            refreshResMappingDropdown(app);

            % Panel 4: 测试与验证（跨两列）
            testPanel = uipanel(outerGrid);
            testPanel.Title = '测试与验证';
            testPanel.FontWeight = 'bold';
            testPanel.BackgroundColor = [0.97, 0.97, 0.97];
            testPanel.Layout.Row = 3;
            testPanel.Layout.Column = [1, 2];

            testGrid = uigridlayout(testPanel);
            testGrid.RowHeight = {35};
            testGrid.ColumnWidth = {120, 120, '1x'};
            testGrid.Padding = [10, 10, 10, 10];
            testGrid.ColumnSpacing = 10;

            app.TestConnectionButton = uibutton(testGrid, 'push');
            app.TestConnectionButton.Text = '测试连接';
            app.TestConnectionButton.Layout.Row = 1;
            app.TestConnectionButton.Layout.Column = 1;
            app.TestConnectionButton.ButtonPushedFcn = @(src, event) testConnectionButtonPushed(app);

            app.ValidatePathsButton = uibutton(testGrid, 'push');
            app.ValidatePathsButton.Text = '验证路径';
            app.ValidatePathsButton.Layout.Row = 1;
            app.ValidatePathsButton.Layout.Column = 2;
            app.ValidatePathsButton.ButtonPushedFcn = @(src, event) validatePathsButtonPushed(app);

            app.ConnectionStatusLabel = uilabel(testGrid);
            app.ConnectionStatusLabel.Text = '状态: 未连接';
            app.ConnectionStatusLabel.Layout.Row = 1;
            app.ConnectionStatusLabel.Layout.Column = 3;
            app.ConnectionStatusLabel.FontColor = [0.4, 0.4, 0.4];
        end

        function createAlgorithmTab(app)
            % 创建 Tab 4: 算法配置
            app.AlgorithmTab = uitab(app.TabGroup);
            app.AlgorithmTab.Title = '4. 算法配置';
            app.AlgorithmTab.BackgroundColor = [0.96, 0.96, 0.96];

            outerGrid = uigridlayout(app.AlgorithmTab, [2, 2]);
            outerGrid.RowHeight = {'1x', 100};
            outerGrid.ColumnWidth = {360, '1x'};
            outerGrid.Padding = [20, 20, 20, 20];
            outerGrid.RowSpacing = 15;
            outerGrid.ColumnSpacing = 15;

            % 左侧：算法选择与说明
            leftPanel = uipanel(outerGrid);
            leftPanel.Title = '算法选择';
            leftPanel.FontWeight = 'bold';
            leftPanel.BackgroundColor = [0.97, 0.97, 0.97];
            leftPanel.Layout.Row = 1;
            leftPanel.Layout.Column = 1;

            leftGrid = uigridlayout(leftPanel);
            leftGrid.RowHeight = {30, 25, '1x'};
            leftGrid.ColumnWidth = {100, '1x', 70};
            leftGrid.Padding = [15, 10, 15, 10];
            leftGrid.RowSpacing = 8;
            leftGrid.ColumnSpacing = 10;

            algLabel = uilabel(leftGrid);
            algLabel.Text = '算法类型:';
            algLabel.FontWeight = 'bold';
            algLabel.Layout.Row = 1;
            algLabel.Layout.Column = 1;

            app.AlgorithmDropDown = uidropdown(leftGrid);
            app.AlgorithmDropDown.Items = getAvailableAlgorithmTypes(app);
            if isempty(app.AlgorithmDropDown.Items)
                app.AlgorithmDropDown.Items = {'NSGA-II', 'PSO'};
            end
            if ismember('NSGA-II', app.AlgorithmDropDown.Items)
                app.AlgorithmDropDown.Value = 'NSGA-II';
            else
                app.AlgorithmDropDown.Value = app.AlgorithmDropDown.Items{1};
            end
            app.AlgorithmDropDown.Layout.Row = 1;
            app.AlgorithmDropDown.Layout.Column = 2;
            app.AlgorithmDropDown.Editable = 'on';
            app.AlgorithmDropDown.Tooltip = '算法类型（支持自定义），例如: NSGA-II, PSO, ANN-NSGA-II';
            app.AlgorithmDropDown.ValueChangedFcn = @(src, event) algorithmDropDownValueChanged(app);

            app.AlgorithmRefreshButton = uibutton(leftGrid, 'push');
            app.AlgorithmRefreshButton.Text = '刷新';
            app.AlgorithmRefreshButton.Layout.Row = 1;
            app.AlgorithmRefreshButton.Layout.Column = 3;
            app.AlgorithmRefreshButton.ButtonPushedFcn = @(src, event) refreshAlgorithmList(app);

            descLabel = uilabel(leftGrid);
            descLabel.Text = '算法说明:';
            descLabel.FontWeight = 'bold';
            descLabel.Layout.Row = 2;
            descLabel.Layout.Column = [1, 3];

            app.AlgorithmDescArea = uitextarea(leftGrid);
            app.AlgorithmDescArea.Layout.Row = 3;
            app.AlgorithmDescArea.Layout.Column = [1, 3];
            app.AlgorithmDescArea.Editable = 'off';

            % 右侧：参数面板容器
            rightPanel = uipanel(outerGrid);
            rightPanel.Title = '参数配置';
            rightPanel.FontWeight = 'bold';
            rightPanel.BackgroundColor = [0.97, 0.97, 0.97];
            rightPanel.Layout.Row = 1;
            rightPanel.Layout.Column = 2;

            rightGrid = uigridlayout(rightPanel, [1, 1]);
            rightGrid.Padding = [10, 10, 10, 10];

            % NSGA-II 面板（默认可见）
            app.NSGAIIPanel = uipanel(rightGrid);
            app.NSGAIIPanel.Title = 'NSGA-II 参数';
            app.NSGAIIPanel.FontWeight = 'bold';
            app.NSGAIIPanel.Layout.Row = 1;
            app.NSGAIIPanel.Layout.Column = 1;

            nsGrid = uigridlayout(app.NSGAIIPanel);
            nsGrid.RowHeight = {30, 30, 30, 30, 30, 30, '1x'};
            nsGrid.ColumnWidth = {150, '1x', 70};
            nsGrid.Padding = [15, 10, 15, 10];
            nsGrid.RowSpacing = 10;
            nsGrid.ColumnSpacing = 10;

            % 种群大小
            nsPopLabel = uilabel(nsGrid);
            nsPopLabel.Text = '种群大小:';
            nsPopLabel.FontWeight = 'bold';
            nsPopLabel.Layout.Row = 1;
            nsPopLabel.Layout.Column = 1;

            app.PopSizeSpinner_NSGAII = uispinner(nsGrid);
            app.PopSizeSpinner_NSGAII.Limits = [10, 1000];
            app.PopSizeSpinner_NSGAII.Value = 50;
            app.PopSizeSpinner_NSGAII.Step = 1;
            app.PopSizeSpinner_NSGAII.Layout.Row = 1;
            app.PopSizeSpinner_NSGAII.Layout.Column = 2;
            app.PopSizeSpinner_NSGAII.ValueChangedFcn = @(src, event) updateEstimations(app);

            % 最大代数
            nsGenLabel = uilabel(nsGrid);
            nsGenLabel.Text = '最大代数:';
            nsGenLabel.FontWeight = 'bold';
            nsGenLabel.Layout.Row = 2;
            nsGenLabel.Layout.Column = 1;

            app.MaxGenSpinner_NSGAII = uispinner(nsGrid);
            app.MaxGenSpinner_NSGAII.Limits = [1, 1000];
            app.MaxGenSpinner_NSGAII.Value = 30;
            app.MaxGenSpinner_NSGAII.Step = 1;
            app.MaxGenSpinner_NSGAII.Layout.Row = 2;
            app.MaxGenSpinner_NSGAII.Layout.Column = 2;
            app.MaxGenSpinner_NSGAII.ValueChangedFcn = @(src, event) updateEstimations(app);

            % 交叉概率
            nsCrossLabel = uilabel(nsGrid);
            nsCrossLabel.Text = '交叉概率:';
            nsCrossLabel.FontWeight = 'bold';
            nsCrossLabel.Layout.Row = 3;
            nsCrossLabel.Layout.Column = 1;

            app.CrossoverSlider_NSGAII = uislider(nsGrid);
            app.CrossoverSlider_NSGAII.Limits = [0.6, 1.0];
            app.CrossoverSlider_NSGAII.Value = 0.9;
            app.CrossoverSlider_NSGAII.Layout.Row = 3;
            app.CrossoverSlider_NSGAII.Layout.Column = 2;
            app.CrossoverSlider_NSGAII.ValueChangedFcn = @(src, event) crossoverSliderNSGAIIValueChanged(app);

            app.CrossoverValueLabel_NSGAII = uilabel(nsGrid);
            app.CrossoverValueLabel_NSGAII.Text = sprintf('%.2f', app.CrossoverSlider_NSGAII.Value);
            app.CrossoverValueLabel_NSGAII.Layout.Row = 3;
            app.CrossoverValueLabel_NSGAII.Layout.Column = 3;

            % 变异率
            nsMutLabel = uilabel(nsGrid);
            nsMutLabel.Text = '变异率:';
            nsMutLabel.FontWeight = 'bold';
            nsMutLabel.Layout.Row = 4;
            nsMutLabel.Layout.Column = 1;

            app.MutationSlider_NSGAII = uislider(nsGrid);
            app.MutationSlider_NSGAII.Limits = [0.0, 2.0];
            app.MutationSlider_NSGAII.Value = 1.0;
            app.MutationSlider_NSGAII.Layout.Row = 4;
            app.MutationSlider_NSGAII.Layout.Column = 2;
            app.MutationSlider_NSGAII.ValueChangedFcn = @(src, event) mutationSliderNSGAIIValueChanged(app);

            app.MutationValueLabel_NSGAII = uilabel(nsGrid);
            app.MutationValueLabel_NSGAII.Text = sprintf('%.2f', app.MutationSlider_NSGAII.Value);
            app.MutationValueLabel_NSGAII.Layout.Row = 4;
            app.MutationValueLabel_NSGAII.Layout.Column = 3;

            % 交叉分布指数
            nsCDILabel = uilabel(nsGrid);
            nsCDILabel.Text = '交叉分布指数:';
            nsCDILabel.FontWeight = 'bold';
            nsCDILabel.Layout.Row = 5;
            nsCDILabel.Layout.Column = 1;

            app.CrossoverDistSpinner_NSGAII = uispinner(nsGrid);
            app.CrossoverDistSpinner_NSGAII.Limits = [1, 100];
            app.CrossoverDistSpinner_NSGAII.Value = 20;
            app.CrossoverDistSpinner_NSGAII.Step = 1;
            app.CrossoverDistSpinner_NSGAII.Layout.Row = 5;
            app.CrossoverDistSpinner_NSGAII.Layout.Column = 2;

            % 变异分布指数
            nsMDILabel = uilabel(nsGrid);
            nsMDILabel.Text = '变异分布指数:';
            nsMDILabel.FontWeight = 'bold';
            nsMDILabel.Layout.Row = 6;
            nsMDILabel.Layout.Column = 1;

            app.MutationDistSpinner_NSGAII = uispinner(nsGrid);
            app.MutationDistSpinner_NSGAII.Limits = [1, 100];
            app.MutationDistSpinner_NSGAII.Value = 20;
            app.MutationDistSpinner_NSGAII.Step = 1;
            app.MutationDistSpinner_NSGAII.Layout.Row = 6;
            app.MutationDistSpinner_NSGAII.Layout.Column = 2;

            % PSO 面板（默认隐藏）
            app.PSOPanel = uipanel(rightGrid);
            app.PSOPanel.Title = 'PSO 参数';
            app.PSOPanel.FontWeight = 'bold';
            app.PSOPanel.Layout.Row = 1;
            app.PSOPanel.Layout.Column = 1;
            app.PSOPanel.Visible = 'off';

            psoGrid = uigridlayout(app.PSOPanel);
            psoGrid.RowHeight = {30, 30, 30, 30, 30, 30, '1x'};
            psoGrid.ColumnWidth = {150, '1x', 70};
            psoGrid.Padding = [15, 10, 15, 10];
            psoGrid.RowSpacing = 10;
            psoGrid.ColumnSpacing = 10;

            % 粒子群大小
            psoSwarmLabel = uilabel(psoGrid);
            psoSwarmLabel.Text = '粒子群大小:';
            psoSwarmLabel.FontWeight = 'bold';
            psoSwarmLabel.Layout.Row = 1;
            psoSwarmLabel.Layout.Column = 1;

            app.SwarmSizeSpinner_PSO = uispinner(psoGrid);
            app.SwarmSizeSpinner_PSO.Limits = [10, 1000];
            app.SwarmSizeSpinner_PSO.Value = 50;
            app.SwarmSizeSpinner_PSO.Step = 1;
            app.SwarmSizeSpinner_PSO.Layout.Row = 1;
            app.SwarmSizeSpinner_PSO.Layout.Column = 2;
            app.SwarmSizeSpinner_PSO.ValueChangedFcn = @(src, event) updateEstimations(app);

            % 最大迭代数
            psoIterLabel = uilabel(psoGrid);
            psoIterLabel.Text = '最大迭代数:';
            psoIterLabel.FontWeight = 'bold';
            psoIterLabel.Layout.Row = 2;
            psoIterLabel.Layout.Column = 1;

            app.MaxIterSpinner_PSO = uispinner(psoGrid);
            app.MaxIterSpinner_PSO.Limits = [1, 1000];
            app.MaxIterSpinner_PSO.Value = 200;
            app.MaxIterSpinner_PSO.Step = 1;
            app.MaxIterSpinner_PSO.Layout.Row = 2;
            app.MaxIterSpinner_PSO.Layout.Column = 2;
            app.MaxIterSpinner_PSO.ValueChangedFcn = @(src, event) updateEstimations(app);

            % 惯性权重
            psoInertiaLabel = uilabel(psoGrid);
            psoInertiaLabel.Text = '惯性权重:';
            psoInertiaLabel.FontWeight = 'bold';
            psoInertiaLabel.Layout.Row = 3;
            psoInertiaLabel.Layout.Column = 1;

            app.InertiaSlider_PSO = uislider(psoGrid);
            app.InertiaSlider_PSO.Limits = [0, 1];
            app.InertiaSlider_PSO.Value = 0.7;
            app.InertiaSlider_PSO.Layout.Row = 3;
            app.InertiaSlider_PSO.Layout.Column = 2;
            app.InertiaSlider_PSO.ValueChangedFcn = @(src, event) inertiaSliderPSOValueChanged(app);

            app.InertiaValueLabel_PSO = uilabel(psoGrid);
            app.InertiaValueLabel_PSO.Text = sprintf('%.2f', app.InertiaSlider_PSO.Value);
            app.InertiaValueLabel_PSO.Layout.Row = 3;
            app.InertiaValueLabel_PSO.Layout.Column = 3;

            % 认知系数
            psoCogLabel = uilabel(psoGrid);
            psoCogLabel.Text = '认知系数:';
            psoCogLabel.FontWeight = 'bold';
            psoCogLabel.Layout.Row = 4;
            psoCogLabel.Layout.Column = 1;

            app.CognitiveSlider_PSO = uislider(psoGrid);
            app.CognitiveSlider_PSO.Limits = [0, 4];
            app.CognitiveSlider_PSO.Value = 1.5;
            app.CognitiveSlider_PSO.Layout.Row = 4;
            app.CognitiveSlider_PSO.Layout.Column = 2;
            app.CognitiveSlider_PSO.ValueChangedFcn = @(src, event) cognitiveSliderPSOValueChanged(app);

            app.CognitiveValueLabel_PSO = uilabel(psoGrid);
            app.CognitiveValueLabel_PSO.Text = sprintf('%.2f', app.CognitiveSlider_PSO.Value);
            app.CognitiveValueLabel_PSO.Layout.Row = 4;
            app.CognitiveValueLabel_PSO.Layout.Column = 3;

            % 社会系数
            psoSocLabel = uilabel(psoGrid);
            psoSocLabel.Text = '社会系数:';
            psoSocLabel.FontWeight = 'bold';
            psoSocLabel.Layout.Row = 5;
            psoSocLabel.Layout.Column = 1;

            app.SocialSlider_PSO = uislider(psoGrid);
            app.SocialSlider_PSO.Limits = [0, 4];
            app.SocialSlider_PSO.Value = 1.5;
            app.SocialSlider_PSO.Layout.Row = 5;
            app.SocialSlider_PSO.Layout.Column = 2;
            app.SocialSlider_PSO.ValueChangedFcn = @(src, event) socialSliderPSOValueChanged(app);

            app.SocialValueLabel_PSO = uilabel(psoGrid);
            app.SocialValueLabel_PSO.Text = sprintf('%.2f', app.SocialSlider_PSO.Value);
            app.SocialValueLabel_PSO.Layout.Row = 5;
            app.SocialValueLabel_PSO.Layout.Column = 3;

            % 最大速度比例
            psoVLabel = uilabel(psoGrid);
            psoVLabel.Text = '最大速度比例:';
            psoVLabel.FontWeight = 'bold';
            psoVLabel.Layout.Row = 6;
            psoVLabel.Layout.Column = 1;

            app.MaxVelSlider_PSO = uislider(psoGrid);
            app.MaxVelSlider_PSO.Limits = [0.1, 1.0];
            app.MaxVelSlider_PSO.Value = 0.2;
            app.MaxVelSlider_PSO.Layout.Row = 6;
            app.MaxVelSlider_PSO.Layout.Column = 2;
            app.MaxVelSlider_PSO.ValueChangedFcn = @(src, event) maxVelSliderPSOValueChanged(app);

            app.MaxVelValueLabel_PSO = uilabel(psoGrid);
            app.MaxVelValueLabel_PSO.Text = sprintf('%.2f', app.MaxVelSlider_PSO.Value);
            app.MaxVelValueLabel_PSO.Layout.Row = 6;
            app.MaxVelValueLabel_PSO.Layout.Column = 3;

            % 通用算法参数面板（用于新算法/自定义算法，默认隐藏）
            app.GenericAlgorithmPanel = uipanel(rightGrid);
            app.GenericAlgorithmPanel.Title = '通用参数';
            app.GenericAlgorithmPanel.FontWeight = 'bold';
            app.GenericAlgorithmPanel.Layout.Row = 1;
            app.GenericAlgorithmPanel.Layout.Column = 1;
            app.GenericAlgorithmPanel.Visible = 'off';

            genericGrid = uigridlayout(app.GenericAlgorithmPanel, [2, 4]);
            genericGrid.RowHeight = {35, '1x'};
            genericGrid.ColumnWidth = {90, 90, 120, '1x'};
            genericGrid.Padding = [15, 10, 15, 10];
            genericGrid.RowSpacing = 8;
            genericGrid.ColumnSpacing = 10;

            app.AddAlgorithmParamButton = uibutton(genericGrid, 'push');
            app.AddAlgorithmParamButton.Text = '添加';
            app.AddAlgorithmParamButton.Layout.Row = 1;
            app.AddAlgorithmParamButton.Layout.Column = 1;
            app.AddAlgorithmParamButton.ButtonPushedFcn = @(src, event) addAlgorithmParamButtonPushed(app);

            app.DeleteAlgorithmParamButton = uibutton(genericGrid, 'push');
            app.DeleteAlgorithmParamButton.Text = '删除';
            app.DeleteAlgorithmParamButton.Layout.Row = 1;
            app.DeleteAlgorithmParamButton.Layout.Column = 2;
            app.DeleteAlgorithmParamButton.ButtonPushedFcn = @(src, event) deleteAlgorithmParamButtonPushed(app);

            app.AutoFillAlgorithmParamsButton = uibutton(genericGrid, 'push');
            app.AutoFillAlgorithmParamsButton.Text = '填充默认';
            app.AutoFillAlgorithmParamsButton.Layout.Row = 1;
            app.AutoFillAlgorithmParamsButton.Layout.Column = 3;
            app.AutoFillAlgorithmParamsButton.ButtonPushedFcn = @(src, event) autoFillAlgorithmParamsButtonPushed(app);

            hint = uilabel(genericGrid);
            hint.Text = '提示: 支持 dotted key（如 surrogate.type），数组用 JSON 形式 [1,2]';
            hint.FontColor = [0.35, 0.35, 0.35];
            hint.HorizontalAlignment = 'left';
            hint.Layout.Row = 1;
            hint.Layout.Column = 4;

            app.AlgorithmParamsTable = uitable(genericGrid);
            app.AlgorithmParamsTable.Data = cell(0, 2);
            app.AlgorithmParamsTable.ColumnName = {'参数', '值'};
            app.AlgorithmParamsTable.ColumnEditable = [true, true];
            app.AlgorithmParamsTable.Layout.Row = 2;
            app.AlgorithmParamsTable.Layout.Column = [1, 4];
            app.AlgorithmParamsTable.CellEditCallback = @(src, event) algorithmParamsTableEdited(app);

            % 底部：预估信息（跨两列）
            estPanel = uipanel(outerGrid);
            estPanel.Title = '预估信息';
            estPanel.FontWeight = 'bold';
            estPanel.BackgroundColor = [0.97, 0.97, 0.97];
            estPanel.Layout.Row = 2;
            estPanel.Layout.Column = [1, 2];

            estGrid = uigridlayout(estPanel);
            estGrid.RowHeight = {30, 30};
            estGrid.ColumnWidth = {'1x'};
            estGrid.Padding = [15, 10, 15, 10];
            estGrid.RowSpacing = 6;

            app.TotalEvalsLabel = uilabel(estGrid);
            app.TotalEvalsLabel.Text = '预估总评估次数: 0';
            app.TotalEvalsLabel.FontWeight = 'bold';
            app.TotalEvalsLabel.Layout.Row = 1;
            app.TotalEvalsLabel.Layout.Column = 1;

            app.EstTimeLabel = uilabel(estGrid);
            app.EstTimeLabel.Text = '预估运行时间: --';
            app.EstTimeLabel.FontColor = [0.35, 0.35, 0.35];
            app.EstTimeLabel.Layout.Row = 2;
            app.EstTimeLabel.Layout.Column = 1;

            updateAlgorithmDescription(app);
            updateEstimations(app);
        end

        function createRunResultsTab(app)
            % 创建 Tab 5: 运行与结果
            app.RunResultsTab = uitab(app.TabGroup);
            app.RunResultsTab.Title = '5. 运行与结果';
            app.RunResultsTab.BackgroundColor = [0.96, 0.96, 0.96];

            outerGrid = uigridlayout(app.RunResultsTab, [3, 2]);
            outerGrid.RowHeight = {120, '1x', 260};
            outerGrid.ColumnWidth = {'1x', '1x'};
            outerGrid.Padding = [20, 20, 20, 20];
            outerGrid.RowSpacing = 15;
            outerGrid.ColumnSpacing = 15;

            % 顶部：运行控制与状态（跨两列）
            topPanel = uipanel(outerGrid);
            topPanel.Title = '运行控制';
            topPanel.FontWeight = 'bold';
            topPanel.BackgroundColor = [0.97, 0.97, 0.97];
            topPanel.Layout.Row = 1;
            topPanel.Layout.Column = [1, 2];

            topGrid = uigridlayout(topPanel, [1, 2]);
            topGrid.ColumnWidth = {'2x', '1x'};
            topGrid.RowHeight = {'1x'};
            topGrid.Padding = [10, 10, 10, 10];
            topGrid.ColumnSpacing = 15;

            % 左侧按钮区
            btnGrid = uigridlayout(topGrid, [2, 7]);
            btnGrid.Layout.Row = 1;
            btnGrid.Layout.Column = 1;
            btnGrid.RowHeight = {35, 35};
            btnGrid.ColumnWidth = {90, 90, 90, 110, 110, 110, '1x'};
            btnGrid.RowSpacing = 6;
            btnGrid.ColumnSpacing = 8;
            btnGrid.Padding = [0, 0, 0, 0];

            app.RunButton = uibutton(btnGrid, 'push');
            app.RunButton.Text = '开始';
            app.RunButton.Layout.Row = 1;
            app.RunButton.Layout.Column = 1;
            app.RunButton.ButtonPushedFcn = @(src, event) runButtonPushed(app);

            app.PauseButton = uibutton(btnGrid, 'push');
            app.PauseButton.Text = '暂停';
            app.PauseButton.Layout.Row = 1;
            app.PauseButton.Layout.Column = 2;
            app.PauseButton.Enable = 'off';
            app.PauseButton.ButtonPushedFcn = @(src, event) uialert(app.UIFigure, '暂停功能尚未实现', '提示');

            app.StopButton = uibutton(btnGrid, 'push');
            app.StopButton.Text = '停止';
            app.StopButton.Layout.Row = 1;
            app.StopButton.Layout.Column = 3;
            app.StopButton.Enable = 'off';
            app.StopButton.ButtonPushedFcn = @(src, event) stopButtonPushed(app);

            app.SaveConfigButton = uibutton(btnGrid, 'push');
            app.SaveConfigButton.Text = '保存配置';
            app.SaveConfigButton.Layout.Row = 1;
            app.SaveConfigButton.Layout.Column = 4;
            app.SaveConfigButton.ButtonPushedFcn = @(src, event) saveConfigButtonPushed(app);

            app.LoadConfigButton = uibutton(btnGrid, 'push');
            app.LoadConfigButton.Text = '加载配置';
            app.LoadConfigButton.Layout.Row = 1;
            app.LoadConfigButton.Layout.Column = 5;
            app.LoadConfigButton.ButtonPushedFcn = @(src, event) loadConfigButtonPushed(app);

            app.SaveResultsButton = uibutton(btnGrid, 'push');
            app.SaveResultsButton.Text = '保存结果';
            app.SaveResultsButton.Layout.Row = 1;
            app.SaveResultsButton.Layout.Column = 6;
            app.SaveResultsButton.Enable = 'off';
            app.SaveResultsButton.ButtonPushedFcn = @(src, event) saveResultsButtonPushed(app);

            % 右侧状态与进度
            statusGrid = uigridlayout(topGrid);
            statusGrid.Layout.Row = 1;
            statusGrid.Layout.Column = 2;
            statusGrid.RowHeight = {22, 22, 22, 30};
            statusGrid.ColumnWidth = {'1x'};
            statusGrid.Padding = [0, 0, 0, 0];
            statusGrid.RowSpacing = 4;

            app.ProblemStatusLabel = uilabel(statusGrid);
            app.ProblemStatusLabel.Text = '问题: ✗ 未配置';
            app.ProblemStatusLabel.Layout.Row = 1;
            app.ProblemStatusLabel.Layout.Column = 1;

            app.SimulatorStatusLabel = uilabel(statusGrid);
            app.SimulatorStatusLabel.Text = '仿真器: ✗ 未配置';
            app.SimulatorStatusLabel.Layout.Row = 2;
            app.SimulatorStatusLabel.Layout.Column = 1;

            app.AlgorithmStatusLabel = uilabel(statusGrid);
            app.AlgorithmStatusLabel.Text = '算法: ✓ 已配置';
            app.AlgorithmStatusLabel.Layout.Row = 3;
            app.AlgorithmStatusLabel.Layout.Column = 1;

            app.ProgressBar = uigauge(statusGrid, 'linear');
            app.ProgressBar.Layout.Row = 4;
            app.ProgressBar.Layout.Column = 1;
            app.ProgressBar.Limits = [0, 100];
            app.ProgressBar.Value = 0;

            % 中部：图表
            paretoPanel = uipanel(outerGrid);
            paretoPanel.Title = 'Pareto 前沿';
            paretoPanel.FontWeight = 'bold';
            paretoPanel.BackgroundColor = [0.97, 0.97, 0.97];
            paretoPanel.Layout.Row = 2;
            paretoPanel.Layout.Column = 1;

            paretoGrid = uigridlayout(paretoPanel);
            paretoGrid.Padding = [10, 10, 10, 10];
            paretoGrid.RowHeight = {'1x'};
            paretoGrid.ColumnWidth = {'1x'};
            app.ParetoAxes = uiaxes(paretoGrid);

            convPanel = uipanel(outerGrid);
            convPanel.Title = '收敛曲线';
            convPanel.FontWeight = 'bold';
            convPanel.BackgroundColor = [0.97, 0.97, 0.97];
            convPanel.Layout.Row = 2;
            convPanel.Layout.Column = 2;

            convGrid = uigridlayout(convPanel);
            convGrid.Padding = [10, 10, 10, 10];
            convGrid.RowHeight = {'1x'};
            convGrid.ColumnWidth = {'1x'};
            app.ConvergenceAxes = uiaxes(convGrid);

            % 底部：日志与结果
            logPanel = uipanel(outerGrid);
            logPanel.Title = '日志输出';
            logPanel.FontWeight = 'bold';
            logPanel.BackgroundColor = [0.97, 0.97, 0.97];
            logPanel.Layout.Row = 3;
            logPanel.Layout.Column = 1;

            logGrid = uigridlayout(logPanel);
            logGrid.RowHeight = {35, '1x'};
            logGrid.ColumnWidth = {'1x'};
            logGrid.Padding = [10, 10, 10, 10];
            logGrid.RowSpacing = 8;

            app.ClearLogButton = uibutton(logGrid, 'push');
            app.ClearLogButton.Text = '清除日志';
            app.ClearLogButton.Layout.Row = 1;
            app.ClearLogButton.Layout.Column = 1;
            app.ClearLogButton.ButtonPushedFcn = @(src, event) clearLogButtonPushed(app);

            app.LogTextArea = uitextarea(logGrid);
            app.LogTextArea.Layout.Row = 2;
            app.LogTextArea.Layout.Column = 1;
            app.LogTextArea.Editable = 'off';
            app.LogTextArea.Value = cell(0, 1);

            resultsPanel = uipanel(outerGrid);
            resultsPanel.Title = '结果表格';
            resultsPanel.FontWeight = 'bold';
            resultsPanel.BackgroundColor = [0.97, 0.97, 0.97];
            resultsPanel.Layout.Row = 3;
            resultsPanel.Layout.Column = 2;

            resultsGrid = uigridlayout(resultsPanel);
            resultsGrid.RowHeight = {35, '1x'};
            resultsGrid.ColumnWidth = {'1x'};
            resultsGrid.Padding = [10, 10, 10, 10];
            resultsGrid.RowSpacing = 8;

            app.ExportResultsButton = uibutton(resultsGrid, 'push');
            app.ExportResultsButton.Text = '导出 CSV';
            app.ExportResultsButton.Layout.Row = 1;
            app.ExportResultsButton.Layout.Column = 1;
            app.ExportResultsButton.ButtonPushedFcn = @(src, event) exportResultsButtonPushed(app);

            app.ResultsTable = uitable(resultsGrid);
            app.ResultsTable.Layout.Row = 2;
            app.ResultsTable.Layout.Column = 1;
            app.ResultsTable.Data = cell(0, 0);
            app.ResultsTable.RowName = 'numbered';
        end

        %% 数据初始化方法

        function initializeData(app)
            % 初始化 GUI 数据结构
            app.guiData = struct();
            app.guiData.problem = struct();
            app.guiData.simulator = struct();
            app.guiData.algorithm = struct();

            % 初始化配置与运行状态
            app.config = [];
            app.configFilePath = '';
            app.configBaseDir = '';
            app.results = [];
            app.asyncFuture = [];
            app.dataQueue = [];
            app.callbacks = [];
            app.optimizationStartTime = [];

            % 初始化表格数据（防御：确保为 cell）
            app.VariablesTable.Data = cell(0, 6);
            app.ObjectivesTable.Data = cell(0, 4);
            app.ConstraintsTable.Data = cell(0, 4);
            app.EvaluatorParamsTable.Data = cell(0, 2);
            app.VarMappingTable.Data = cell(0, 2);
            app.ResMappingTable.Data = cell(0, 2);
            app.ResultsTable.Data = cell(0, 0);

            % 算法面板默认可见性
            app.NSGAIIPanel.Visible = 'on';
            app.PSOPanel.Visible = 'off';
            app.GenericAlgorithmPanel.Visible = 'off';

            % 按钮默认状态
            app.StopButton.Enable = 'off';
            app.SaveResultsButton.Enable = 'off';

            logMessage(app, 'MAPO GUI 已启动');
        end

        %% 回调函数
        % 保持原有逻辑不变

        function addVariableButtonPushed(app)
            currentData = app.VariablesTable.Data;
            newRow = {'Var1', 'continuous', 0, 100, '', ''};
            app.VariablesTable.Data = [currentData; newRow];
            updateStatus(app, '已添加变量');
            logMessage(app, '添加新变量');
            updateConfigStatus(app);
        end

        function deleteVariableButtonPushed(app)
            selection = app.VariablesTable.Selection;
            if isempty(selection)
                uialert(app.UIFigure, '请先选择要删除的变量', '删除变量');
                return;
            end

            currentData = app.VariablesTable.Data;
            rowsToDelete = unique(selection(:, 1));
            currentData(rowsToDelete, :) = [];
            app.VariablesTable.Data = currentData;

            updateStatus(app, '已删除变量');
            logMessage(app, sprintf('删除 %d 个变量', length(rowsToDelete)));
            updateConfigStatus(app);
        end

        function addObjectiveButtonPushed(app)
            currentData = app.ObjectivesTable.Data;
            newRow = {'Obj1', 'minimize', 1.0, ''};
            app.ObjectivesTable.Data = [currentData; newRow];
            updateStatus(app, '已添加目标');
            logMessage(app, '添加新目标');
            updateConfigStatus(app);
        end

        function deleteObjectiveButtonPushed(app)
            selection = app.ObjectivesTable.Selection;
            if isempty(selection)
                uialert(app.UIFigure, '请先选择要删除的目标', '删除目标');
                return;
            end

            currentData = app.ObjectivesTable.Data;
            rowsToDelete = unique(selection(:, 1));
            currentData(rowsToDelete, :) = [];
            app.ObjectivesTable.Data = currentData;

            updateStatus(app, '已删除目标');
            logMessage(app, sprintf('删除 %d 个目标', length(rowsToDelete)));
            updateConfigStatus(app);
        end

        function addConstraintButtonPushed(app)
            currentData = app.ConstraintsTable.Data;
            newRow = {'Con1', 'inequality', 'x <= 100', ''};
            app.ConstraintsTable.Data = [currentData; newRow];
            updateStatus(app, '已添加约束');
            logMessage(app, '添加新约束');
        end

        function deleteConstraintButtonPushed(app)
            selection = app.ConstraintsTable.Selection;
            if isempty(selection)
                uialert(app.UIFigure, '请先选择要删除的约束', '删除约束');
                return;
            end

            currentData = app.ConstraintsTable.Data;
            rowsToDelete = unique(selection(:, 1));
            currentData(rowsToDelete, :) = [];
            app.ConstraintsTable.Data = currentData;

            updateStatus(app, '已删除约束');
            logMessage(app, sprintf('删除 %d 个约束', length(rowsToDelete)));
        end

        %% ========================================
        %% Tab 2: 评估器配置 - 回调函数
        %% ========================================

        function evaluatorTypeChanged(app)
            updateEvaluatorInfo(app);
            updateConfigStatus(app);
        end

        function refreshEvaluatorList(app)
            currentValue = char(string(app.EvaluatorTypeDropDown.Value));
            types = getAvailableEvaluatorTypes(app);
            if isempty(types)
                types = {'MyCaseEvaluator'};
            end

            if ~ismember(currentValue, types)
                types{end+1} = currentValue; %#ok<AGROW>
            end

            app.EvaluatorTypeDropDown.Items = types;
            app.EvaluatorTypeDropDown.Value = currentValue;
            updateEvaluatorInfo(app);
            updateConfigStatus(app);
            logMessage(app, '已刷新评估器列表');
        end

        function addEvaluatorParamButtonPushed(app)
            currentData = app.EvaluatorParamsTable.Data;
            if isempty(currentData)
                currentData = cell(0, 2);
            end
            newRow = {'', 0};
            app.EvaluatorParamsTable.Data = [currentData; newRow];
            updateStatus(app, '已添加评估器参数');
            updateConfigStatus(app);
        end

        function deleteEvaluatorParamButtonPushed(app)
            selection = app.EvaluatorParamsTable.Selection;
            if isempty(selection)
                uialert(app.UIFigure, '请先选择要删除的参数行', '删除参数');
                return;
            end

            currentData = app.EvaluatorParamsTable.Data;
            rowsToDelete = unique(selection(:, 1));
            currentData(rowsToDelete, :) = [];
            app.EvaluatorParamsTable.Data = currentData;

            updateStatus(app, '已删除评估器参数');
            updateConfigStatus(app);
        end

        function autoFillEvaluatorParamsButtonPushed(app)
            evaluatorType = char(string(app.EvaluatorTypeDropDown.Value));
            recommended = getRecommendedEvaluatorParams(app, evaluatorType);
            fields = fieldnames(recommended);

            if isempty(fields)
                uialert(app.UIFigure, sprintf('未找到 %s 的推荐参数。', evaluatorType), ...
                    '推荐填充', 'Icon', 'info');
                return;
            end

            data = app.EvaluatorParamsTable.Data;
            if isempty(data)
                data = cell(0, 2);
            end

            existingNames = strings(0, 1);
            if ~isempty(data)
                existingNames = string(data(:, 1));
            end

            for i = 1:length(fields)
                name = fields{i};
                value = recommended.(name);
                idx = find(existingNames == string(name), 1);
                if isempty(idx)
                    data(end+1, :) = {name, value}; %#ok<AGROW>
                    existingNames(end+1, 1) = string(name); %#ok<AGROW>
                else
                    data{idx, 2} = value;
                end
            end

            app.EvaluatorParamsTable.Data = data;
            updateStatus(app, '已填充推荐参数');
            updateConfigStatus(app);
        end

        function updateEvaluatorInfo(app)
            evaluatorType = char(string(app.EvaluatorTypeDropDown.Value));

            classExists = exist(evaluatorType, 'class') == 8;
            classPath = '';
            if classExists
                classPath = which(evaluatorType);
                if isempty(classPath)
                    classPath = '(unknown path)';
                end
            end

            hasSetProblem = false;
            hasEvaluate = false;
            try
                mc = meta.class.fromName(evaluatorType);
                if ~isempty(mc)
                    methodNames = {mc.MethodList.Name};
                    hasSetProblem = any(strcmp(methodNames, 'setProblem'));
                    hasEvaluate = any(strcmp(methodNames, 'evaluate'));
                end
            catch
                % ignore
            end

            recommended = getRecommendedEvaluatorParams(app, evaluatorType);
            recFields = fieldnames(recommended);

            existsText = '否';
            if classExists
                existsText = '是';
            end

            evaluateText = '未知/否';
            if hasEvaluate
                evaluateText = '是';
            end

            setProblemText = '否（可选）';
            if hasSetProblem
                setProblemText = '是（推荐）';
            end

            lines = {};
            lines{end+1} = sprintf('当前评估器: %s', evaluatorType); %#ok<AGROW>
            lines{end+1} = sprintf('类存在: %s', existsText); %#ok<AGROW>
            if classExists
                lines{end+1} = sprintf('类文件: %s', classPath); %#ok<AGROW>
            end
            lines{end+1} = sprintf('包含 evaluate(x): %s', evaluateText); %#ok<AGROW>
            lines{end+1} = sprintf('支持 setProblem(problem): %s', setProblemText); %#ok<AGROW>
            lines{end+1} = ' '; %#ok<AGROW>
            lines{end+1} = '接口约定:'; %#ok<AGROW>
            lines{end+1} = '  - evaluate(x) 返回结构体 result:'; %#ok<AGROW>
            lines{end+1} = '      result.objectives   [1 x nObj]'; %#ok<AGROW>
            lines{end+1} = '      result.constraints  [1 x nCon] (可选)'; %#ok<AGROW>
            lines{end+1} = '      result.success      true/false'; %#ok<AGROW>
            lines{end+1} = '      result.message      字符串(可选)'; %#ok<AGROW>
            lines{end+1} = '  - 若实现 setProblem(problem)，MAPO 会在运行前注入问题对象（可读取变量/目标/约束信息）'; %#ok<AGROW>
            lines{end+1} = ' '; %#ok<AGROW>
            lines{end+1} = '参数表说明:'; %#ok<AGROW>
            lines{end+1} = '  - 参数将写入 problem.evaluator.economicParameters'; %#ok<AGROW>
            lines{end+1} = '  - 运行时会按同名属性写入 evaluator（isprop 匹配）'; %#ok<AGROW>

            if ~isempty(recFields)
                lines{end+1} = ' '; %#ok<AGROW>
                lines{end+1} = '推荐参数:'; %#ok<AGROW>
                for i = 1:length(recFields)
                    name = recFields{i};
                    lines{end+1} = sprintf('  - %s = %g', name, recommended.(name)); %#ok<AGROW>
                end
            end

            app.EvaluatorInfoArea.Value = lines;
        end

        function types = getAvailableEvaluatorTypes(app) %#ok<MANU>
            types = {};

            % 1) Prefer factory list when available
            if exist('EvaluatorFactory', 'class') == 8
                try
                    types = EvaluatorFactory.getAvailableTypes();
                catch
                    types = {};
                end
            end

            % 2) Scan built-in evaluator directory
            try
                projectRoot = fileparts(fileparts(mfilename('fullpath')));
                evaluatorDir = fullfile(projectRoot, 'framework', 'problem', 'evaluator');
                if exist(evaluatorDir, 'dir')
                    files = dir(fullfile(evaluatorDir, '*Evaluator.m'));
                    for i = 1:length(files)
                        [~, className, ~] = fileparts(files(i).name);
                        if strcmp(className, 'Evaluator') || strcmp(className, 'MATLABFunctionEvaluator')
                            continue;
                        end
                        if ~ismember(className, types)
                            types{end+1} = className; %#ok<AGROW>
                        end
                    end
                end
            catch
                % ignore
            end

            % Normalize to cellstr and sort
            if isstring(types)
                types = cellstr(types);
            end
            if ~iscell(types)
                types = {};
            end
            types = unique(types, 'stable');
            types = sort(types);
        end

        function types = getAvailableAlgorithmTypes(app) %#ok<MANU>
            types = {};

            % 1) Prefer metadata-driven list (low coupling)
            if exist('AlgorithmMetadata', 'class') == 8
                try
                    types = AlgorithmMetadata.listTypes();
                catch
                    types = {};
                end
            end

            % 2) Fallback to common built-ins / registered algorithms
            if isempty(types) && exist('AlgorithmFactory', 'class') == 8
                candidates = {'NSGA-II', 'PSO', 'ANN-NSGA-II'};
                for i = 1:length(candidates)
                    t = candidates{i};
                    try
                        if AlgorithmFactory.isRegistered(t)
                            types{end+1} = t; %#ok<AGROW>
                        end
                    catch
                    end
                end

                if isempty(types)
                    try
                        types = AlgorithmFactory.listAvailableAlgorithms();
                    catch
                        types = {};
                    end
                end
            end

            % 3) If factory is available, only keep registered algorithms
            if exist('AlgorithmFactory', 'class') == 8 && ~isempty(types)
                filtered = {};
                for i = 1:length(types)
                    t = types{i};
                    try
                        if AlgorithmFactory.isRegistered(t)
                            filtered{end+1} = t; %#ok<AGROW>
                        end
                    catch
                    end
                end
                if ~isempty(filtered)
                    types = filtered;
                end
            end

            % Normalize to cellstr and sort
            if isstring(types)
                types = cellstr(types);
            end
            if ~iscell(types)
                types = {};
            end
            types = unique(types, 'stable');
            types = sort(types);
        end

        function params = getRecommendedEvaluatorParams(app, evaluatorType) %#ok<MANU>
            params = struct();

            switch char(evaluatorType)
                case 'ORCEvaluator'
                    params.electricityPrice = 0.1;
                    params.operatingHours = 8000;
                    params.coolingWaterCost = 0.354;
                case 'MyCaseEvaluator'
                    params.productPrice = 1000;
                    params.energyCost = 0.1;
                    params.operatingHours = 8000;
                case 'ADNProductionEvaluator'
                    params.productPrice = 1000;
                    params.rawMaterialCost = 500;
                case 'DistillationEvaluator'
                    params.minPurity = 0.995;
                    params.maxEnergyRatio = 10.0;
                otherwise
                    % no defaults
            end
        end

        %% ========================================
        %% Tab 3: 仿真器配置 - 回调函数
        %% ========================================

        function browseModelButtonPushed(app)
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
                updateConfigStatus(app);
            end
        end

        function addVarMappingButtonPushed(app)
            currentData = app.VarMappingTable.Data;

            varNames = getProblemVariableNames(app);
            defaultName = '';
            if ~isempty(varNames)
                usedNames = {};
                if ~isempty(currentData)
                    usedNames = cellfun(@(x) char(string(x)), currentData(:, 1), 'UniformOutput', false);
                    usedNames = usedNames(~cellfun(@isempty, usedNames));
                end

                remaining = setdiff(varNames, usedNames, 'stable');
                if ~isempty(remaining)
                    defaultName = remaining{1};
                else
                    defaultName = varNames{1};
                end
            end

            newRow = {defaultName, ''};
            app.VarMappingTable.Data = [currentData; newRow];
            logMessage(app, '添加新变量映射');
            updateConfigStatus(app);
        end

        function syncVarMappingButtonPushed(app)
            %% 同步变量节点映射（按问题变量名生成/补齐行）

            varNames = getProblemVariableNames(app);
            if isempty(varNames)
                uialert(app.UIFigure, '请先在“问题配置”中添加决策变量，然后再同步映射。', '同步变量映射', 'Icon', 'warning');
                return;
            end

            currentData = app.VarMappingTable.Data;

            % 记录已填写的节点路径（优先保留非空路径）
            pathMap = containers.Map('KeyType', 'char', 'ValueType', 'char');
            extraRows = cell(0, 2);

            if ~isempty(currentData)
                for i = 1:size(currentData, 1)
                    nameStr = char(string(currentData{i, 1}));
                    pathStr = char(string(currentData{i, 2}));

                    if isempty(strtrim(nameStr))
                        continue;
                    end

                    if ismember(nameStr, varNames)
                        if ~isKey(pathMap, nameStr)
                            pathMap(nameStr) = pathStr;
                        elseif isempty(strtrim(pathMap(nameStr))) && ~isempty(strtrim(pathStr))
                            pathMap(nameStr) = pathStr;
                        end
                    else
                        % 额外映射：保留在表格末尾（框架会忽略）
                        extraRows(end+1, :) = {nameStr, pathStr}; %#ok<AGROW>
                    end
                end
            end

            newData = cell(numel(varNames), 2);
            for i = 1:numel(varNames)
                vn = varNames{i};
                newData{i, 1} = vn;
                if isKey(pathMap, vn)
                    newData{i, 2} = pathMap(vn);
                else
                    newData{i, 2} = '';
                end
            end

            app.VarMappingTable.Data = [newData; extraRows];
            refreshVarMappingDropdown(app);
            logMessage(app, sprintf('变量映射已同步: %d 个变量', numel(varNames)));
            updateConfigStatus(app);
        end

        function deleteVarMappingButtonPushed(app)
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
            updateConfigStatus(app);
        end

        function applyVarTemplateButtonPushed(app)
            selectedCategory = app.VarTemplateDropDown.Value;
            [templateList, ~] = AspenNodeTemplates.getTemplatesForCategory(selectedCategory);

            if isempty(templateList)
                uialert(app.UIFigure, '所选类别没有可用模板', '应用模板');
                return;
            end

            tableSelection = app.VarMappingTable.Selection;
            if isempty(tableSelection)
                uialert(app.UIFigure, '请先在变量映射表中选择要应用模板的行（建议先点击“同步”）。', '应用模板', 'Icon', 'warning');
                return;
            end

            [templateSelection, ok] = listdlg('ListString', templateList(:, 1), ...
                'SelectionMode', 'single', ...
                'Name', '选择模板', ...
                'PromptString', '请选择一个模板:');

            if ok
                templateName = templateList{templateSelection, 1};
                templatePath = templateList{templateSelection, 2};

                placeholders = AspenNodeTemplates.extractPlaceholders(templatePath);

                buildPath = templatePath;
                if ~isempty(placeholders)
                    answers = inputdlg(placeholders, '填写占位符', 1, placeholders);
                    if isempty(answers)
                        return;
                    end
                    for i = 1:length(placeholders)
                        buildPath = strrep(buildPath, ...
                            sprintf('{%s}', placeholders{i}), answers{i});
                    end
                end

                currentData = app.VarMappingTable.Data;
                rowsToUpdate = unique(tableSelection(:, 1));
                for r = 1:numel(rowsToUpdate)
                    rowIdx = rowsToUpdate(r);
                    if rowIdx >= 1 && rowIdx <= size(currentData, 1)
                        currentData{rowIdx, 2} = buildPath;
                    end
                end
                app.VarMappingTable.Data = currentData;
                logMessage(app, sprintf('应用变量模板: %s', templateName));

                updateConfigStatus(app);
            end
        end

        function addResMappingButtonPushed(app)
            currentData = app.ResMappingTable.Data;

            objNames = getProblemObjectiveNames(app);
            defaultName = '';
            if ~isempty(objNames)
                usedNames = {};
                if ~isempty(currentData)
                    usedNames = cellfun(@(x) char(string(x)), currentData(:, 1), 'UniformOutput', false);
                    usedNames = usedNames(~cellfun(@isempty, usedNames));
                end

                remaining = setdiff(objNames, usedNames, 'stable');
                if ~isempty(remaining)
                    defaultName = remaining{1};
                else
                    defaultName = objNames{1};
                end
            end

            newRow = {defaultName, ''};
            app.ResMappingTable.Data = [currentData; newRow];
            logMessage(app, '添加新结果映射');
            updateConfigStatus(app);
        end

        function syncResMappingButtonPushed(app)
            %% 同步结果节点映射（按问题目标名生成/补齐行）

            objNames = getProblemObjectiveNames(app);
            if isempty(objNames)
                uialert(app.UIFigure, '请先在“问题配置”中添加优化目标，然后再同步映射。', ...
                    '同步结果映射', 'Icon', 'warning');
                return;
            end

            currentData = app.ResMappingTable.Data;

            % 记录已填写的节点路径（优先保留非空路径）
            pathMap = containers.Map('KeyType', 'char', 'ValueType', 'char');
            extraRows = cell(0, 2);

            if ~isempty(currentData)
                for i = 1:size(currentData, 1)
                    nameStr = char(string(currentData{i, 1}));
                    pathStr = char(string(currentData{i, 2}));

                    if isempty(strtrim(nameStr))
                        continue;
                    end

                    if ismember(nameStr, objNames)
                        if ~isKey(pathMap, nameStr)
                            pathMap(nameStr) = pathStr;
                        elseif isempty(strtrim(pathMap(nameStr))) && ~isempty(strtrim(pathStr))
                            pathMap(nameStr) = pathStr;
                        end
                    else
                        % 额外映射：保留在表格末尾（框架会忽略不需要的字段）
                        extraRows(end+1, :) = {nameStr, pathStr}; %#ok<AGROW>
                    end
                end
            end

            newData = cell(numel(objNames), 2);
            for i = 1:numel(objNames)
                on = objNames{i};
                newData{i, 1} = on;
                if isKey(pathMap, on)
                    newData{i, 2} = pathMap(on);
                else
                    newData{i, 2} = '';
                end
            end

            app.ResMappingTable.Data = [newData; extraRows];
            refreshResMappingDropdown(app);
            logMessage(app, sprintf('结果映射已同步 %d 个目标', numel(objNames)));
            updateConfigStatus(app);
        end

        function deleteResMappingButtonPushed(app)
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
            updateConfigStatus(app);
        end

        function applyResTemplateButtonPushed(app)
            selectedCategory = app.ResTemplateDropDown.Value;
            [templateList, ~] = AspenNodeTemplates.getTemplatesForCategory(selectedCategory);

            if isempty(templateList)
                uialert(app.UIFigure, '所选类别没有可用模板', '应用模板');
                return;
            end

            [selection, ok] = listdlg('ListString', templateList(:, 1), ...
                'SelectionMode', 'single', ...
                'Name', '选择模板', ...
                'PromptString', '请选择一个模板:');

            if ok
                templateName = templateList{selection, 1};
                templatePath = templateList{selection, 2};

                placeholders = AspenNodeTemplates.extractPlaceholders(templatePath);

                if isempty(placeholders)
                    currentData = app.ResMappingTable.Data;
                    newRow = {templateName, templatePath};
                    app.ResMappingTable.Data = [currentData; newRow];
                    logMessage(app, sprintf('应用模板: %s', templateName));
                else
                    answers = inputdlg(placeholders, '填写占位符', 1, placeholders);
                    if ~isempty(answers)
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

                updateConfigStatus(app);
            end
        end

        function testConnectionButtonPushed(app)
            logMessage(app, '开始测试连接...');
            app.TestConnectionButton.Enable = 'off';
            app.ConnectionStatusLabel.Text = '状态: 连接中...';
            drawnow;

            try
                simType = app.SimulatorTypeDropDown.Value;
                modelPath = app.ModelPathField.Value;

                if isempty(modelPath)
                    error('请先选择模型文件');
                end
                if ~exist(modelPath, 'file')
                    error('模型文件不存在: %s', modelPath);
                end

                simConfig = SimulatorConfig(simType);
                simConfig.set('modelPath', modelPath);
                simConfig.set('timeout', app.SimTimeoutSpinner.Value);
                simConfig.set('visible', app.VisibleCheckBox.Value);
                simConfig.set('suppressWarnings', app.SuppressWarningsCheckBox.Value);
                simConfig.set('maxRetries', app.MaxRetriesSpinner.Value);
                simConfig.set('retryDelay', app.RetryDelaySpinner.Value);

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

                simulator.connect(simConfig);
                simulator.disconnect();

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

        function validatePathsButtonPushed(app)
            logMessage(app, '验证节点路径...');

            varData = app.VarMappingTable.Data;
            invalidVarPaths = {};
            for i = 1:size(varData, 1)
                path = varData{i, 2};
                if ~AspenNodeTemplates.validateNodePath(path)
                    invalidVarPaths{end+1} = sprintf('Row %d: %s', i, path); %#ok<AGROW>
                end
            end

            resData = app.ResMappingTable.Data;
            invalidResPaths = {};
            for i = 1:size(resData, 1)
                path = resData{i, 2};
                if ~AspenNodeTemplates.validateNodePath(path)
                    invalidResPaths{end+1} = sprintf('Row %d: %s', i, path); %#ok<AGROW>
                end
            end

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

        function refreshAlgorithmList(app)
            % Force reload metadata cache so newly added algorithms can show up
            if exist('AlgorithmMetadata', 'class') == 8
                try
                    AlgorithmMetadata.getAll(true);
                catch
                end
            end

            % Also refresh AlgorithmFactory registry from metadata (no restart needed)
            if exist('AlgorithmFactory', 'class') == 8
                try
                    AlgorithmFactory.refreshFromMetadata();
                catch
                end
            end

            currentValue = char(string(app.AlgorithmDropDown.Value));
            types = getAvailableAlgorithmTypes(app);
            if isempty(types)
                types = {'NSGA-II', 'PSO'};
            end

            if ~ismember(currentValue, types)
                types{end+1} = currentValue; %#ok<AGROW>
            end

            app.AlgorithmDropDown.Items = types;
            app.AlgorithmDropDown.Value = currentValue;

            updateAlgorithmDescription(app);
            updateEstimations(app);
            logMessage(app, '已刷新算法列表');
        end

        function addAlgorithmParamButtonPushed(app)
            currentData = app.AlgorithmParamsTable.Data;
            if isempty(currentData)
                currentData = cell(0, 2);
            end
            app.AlgorithmParamsTable.Data = [currentData; {'', ''}];
            updateConfigStatus(app);
            updateEstimations(app);
        end

        function deleteAlgorithmParamButtonPushed(app)
            selection = app.AlgorithmParamsTable.Selection;
            if isempty(selection)
                uialert(app.UIFigure, '请先选择要删除的参数行', '删除参数');
                return;
            end

            currentData = app.AlgorithmParamsTable.Data;
            rowsToDelete = unique(selection(:, 1));
            currentData(rowsToDelete, :) = [];
            app.AlgorithmParamsTable.Data = currentData;

            updateConfigStatus(app);
            updateEstimations(app);
        end

        function autoFillAlgorithmParamsButtonPushed(app)
            algType = char(string(app.AlgorithmDropDown.Value));

            defaults = struct();
            if exist('AlgorithmMetadata', 'class') == 8
                try
                    defaults = AlgorithmMetadata.getDefaultParameters(algType);
                catch
                    defaults = struct();
                end
            end

            if isempty(fieldnames(defaults))
                uialert(app.UIFigure, sprintf('未找到 %s 的默认参数（可通过 algorithm_meta.json 提供）。', algType), ...
                    '默认参数', 'Icon', 'info');
                return;
            end

            defaultRows = AlgorithmMetadata.toTableData(defaults);
            data = app.AlgorithmParamsTable.Data;
            if isempty(data)
                data = cell(0, 2);
            end

            existingKeys = strings(0, 1);
            if ~isempty(data)
                existingKeys = string(data(:, 1));
            end

            for i = 1:size(defaultRows, 1)
                key = char(string(defaultRows{i, 1}));
                value = defaultRows{i, 2};
                idx = find(existingKeys == string(key), 1);
                if isempty(idx)
                    data(end+1, :) = {key, value}; %#ok<AGROW>
                    existingKeys(end+1, 1) = string(key); %#ok<AGROW>
                else
                    data{idx, 2} = value;
                end
            end

            app.AlgorithmParamsTable.Data = data;
            updateConfigStatus(app);
            updateEstimations(app);
        end

        function algorithmParamsTableEdited(app)
            updateConfigStatus(app);
            updateEstimations(app);
        end

        function algorithmDropDownValueChanged(app)
            value = app.AlgorithmDropDown.Value;

            switch value
                case 'NSGA-II'
                    app.NSGAIIPanel.Visible = 'on';
                    app.PSOPanel.Visible = 'off';
                    app.GenericAlgorithmPanel.Visible = 'off';
                case 'PSO'
                    app.NSGAIIPanel.Visible = 'off';
                    app.PSOPanel.Visible = 'on';
                    app.GenericAlgorithmPanel.Visible = 'off';
                otherwise
                    app.NSGAIIPanel.Visible = 'off';
                    app.PSOPanel.Visible = 'off';
                    app.GenericAlgorithmPanel.Visible = 'on';

                    % 自动填充默认参数（仅在表为空时）
                    try
                        data = app.AlgorithmParamsTable.Data;
                        isEmpty = isempty(data) || all(cellfun(@(x) isempty(strtrim(char(string(x)))), data(:, 1)));
                    catch
                        isEmpty = true;
                    end

                    if isEmpty && exist('AlgorithmMetadata', 'class') == 8
                        try
                            defaults = AlgorithmMetadata.getDefaultParameters(value);
                            if ~isempty(fieldnames(defaults))
                                app.AlgorithmParamsTable.Data = AlgorithmMetadata.toTableData(defaults);
                            end
                        catch
                        end
                    end
            end

            updateAlgorithmDescription(app);
            updateEstimations(app);
            logMessage(app, sprintf('切换算法: %s', value));
        end

        function crossoverSliderNSGAIIValueChanged(app)
            value = app.CrossoverSlider_NSGAII.Value;
            app.CrossoverValueLabel_NSGAII.Text = sprintf('%.2f', value);
            updateEstimations(app);
        end

        function mutationSliderNSGAIIValueChanged(app)
            value = app.MutationSlider_NSGAII.Value;
            app.MutationValueLabel_NSGAII.Text = sprintf('%.2f', value);
        end

        function inertiaSliderPSOValueChanged(app)
            value = app.InertiaSlider_PSO.Value;
            app.InertiaValueLabel_PSO.Text = sprintf('%.2f', value);
        end

        function cognitiveSliderPSOValueChanged(app)
            value = app.CognitiveSlider_PSO.Value;
            app.CognitiveValueLabel_PSO.Text = sprintf('%.2f', value);
        end

        function socialSliderPSOValueChanged(app)
            value = app.SocialSlider_PSO.Value;
            app.SocialValueLabel_PSO.Text = sprintf('%.2f', value);
        end

        function maxVelSliderPSOValueChanged(app)
            value = app.MaxVelSlider_PSO.Value;
            app.MaxVelValueLabel_PSO.Text = sprintf('%.2f', value);
        end

        %% ========================================
        %% Tab 5: 运行与结果 - 回调函数
        %% ========================================

        function runButtonPushed(app)
            logMessage(app, '========================================');
            logMessage(app, '准备开始优化...');

            if ~validateConfiguration(app)
                return;
            end

            collectGUIData(app);

            try
                app.config = ConfigBuilder.buildConfig(app.guiData);
            catch ME
                uialert(app.UIFigure, sprintf('构建配置失败: %s', ME.message), '错误', 'Icon', 'error');
                logMessage(app, sprintf('构建配置失败: %s', ME.message));
                return;
            end

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

            if ~isempty(warnings)
                logMessage(app, '配置警告:');
                for i = 1:length(warnings)
                    logMessage(app, sprintf('  WARNING: %s', warnings{i}));
                end
            end

            % 运行上下文：用于异步 worker 解析相对路径（例如 Aspen 模型文件路径）
            baseDir = app.configBaseDir;
            if isempty(baseDir)
                baseDir = pwd;
            end
            if ~isfield(app.config, 'runtime') || ~isstruct(app.config.runtime)
                app.config.runtime = struct();
            end
            app.config.runtime.baseDir = baseDir;

            % 保存配置到临时文件（runOptimizationAsync 需要绝对路径）
            tempDir = fullfile(tempdir, 'MAPO');
            if ~exist(tempDir, 'dir')
                mkdir(tempDir);
            end

            timestamp = datestr(now, 'yyyymmdd_HHMMSS');
            app.configFilePath = fullfile(tempDir, sprintf('config_%s.json', timestamp));
            ConfigBuilder.toJSON(app.config, app.configFilePath);
            logMessage(app, sprintf('配置已保存: %s', app.configFilePath));

            % 重置显示
            app.ProgressBar.Value = 0;
            app.SaveResultsButton.Enable = 'off';

            % 创建回调
            app.callbacks = OptimizationCallbacks(app);
            app.callbacks.setMaxIterations(app.config.algorithm.parameters.maxGenerations);
            app.callbacks.resetStartTime();
            app.optimizationStartTime = tic;

            try
                [app.asyncFuture, app.dataQueue] = runOptimizationAsync(app.configFilePath, app.callbacks);

                if isa(app.asyncFuture, 'parallel.FevalFuture')
                    logMessage(app, '使用异步模式运行');
                    afterEach(app.dataQueue, @(data) handleOptimizationDataGUI(app, data));

                    app.RunButton.Enable = 'off';
                    app.StopButton.Enable = 'on';
                    app.SaveConfigButton.Enable = 'off';
                    app.LoadConfigButton.Enable = 'off';
                else
                    logMessage(app, '使用同步模式运行');
                    app.callbacks.onAlgorithmEndCallback(app.asyncFuture);
                    app.results = app.asyncFuture;

                    app.RunButton.Enable = 'on';
                    app.StopButton.Enable = 'off';
                    app.SaveResultsButton.Enable = 'on';

                    logMessage(app, '优化完成（同步模式）');
                    promptSaveResults(app);
                end

            catch ME
                uialert(app.UIFigure, sprintf('启动优化失败: %s', ME.message), '错误', 'Icon', 'error');
                logMessage(app, sprintf('启动优化失败: %s', ME.message));

                app.RunButton.Enable = 'on';
                app.StopButton.Enable = 'off';
                app.SaveConfigButton.Enable = 'on';
                app.LoadConfigButton.Enable = 'on';
            end
        end

        function stopButtonPushed(app)
            if ~isempty(app.asyncFuture) && isa(app.asyncFuture, 'parallel.FevalFuture')
                try
                    cancel(app.asyncFuture);
                    logMessage(app, '优化已取消');

                    app.RunButton.Enable = 'on';
                    app.StopButton.Enable = 'off';
                    app.SaveConfigButton.Enable = 'on';
                    app.LoadConfigButton.Enable = 'on';
                catch ME
                    logMessage(app, sprintf('取消失败: %s', ME.message));
                end
            end
        end

        function saveConfigButtonPushed(app)
            collectGUIData(app);

            try
                config = ConfigBuilder.buildConfig(app.guiData);
            catch ME
                uialert(app.UIFigure, sprintf('构建配置失败: %s', ME.message), '错误', 'Icon', 'error');
                return;
            end

            defaultName = sprintf('%s_config.json', config.problem.name);
            [file, path] = uiputfile('*.json', '保存配置文件', defaultName);

            if file ~= 0
                fullPath = fullfile(path, file);
                ConfigBuilder.toJSON(config, fullPath);
                logMessage(app, sprintf('配置已保存: %s', fullPath));
                uialert(app.UIFigure, '配置保存成功！', '保存成功', 'Icon', 'success');
            end
        end

        function loadConfigButtonPushed(app)
            [file, path] = uigetfile('*.json', '选择配置文件');

            if file ~= 0
                fullPath = fullfile(path, file);

                try
                    config = ConfigBuilder.fromJSON(fullPath);
                    guiData = ConfigBuilder.toGUIData(config);
                    loadGUIData(app, guiData);

                    % 记录配置所在目录，用于运行时解析相对路径（如 Aspen 的 modelPath）
                    app.configBaseDir = fileparts(fullPath);

                    logMessage(app, sprintf('配置已加载: %s', fullPath));
                    uialert(app.UIFigure, '配置加载成功！', '加载成功', 'Icon', 'success');

                    updateConfigStatus(app);
                catch ME
                    uialert(app.UIFigure, sprintf('加载配置失败: %s', ME.message), '错误', 'Icon', 'error');
                    logMessage(app, sprintf('加载配置失败: %s', ME.message));
                end
            end
        end

        function saveResultsButtonPushed(app)
            if isempty(app.results)
                uialert(app.UIFigure, '没有可保存的结果', '保存结果');
                return;
            end
            promptSaveResults(app);
        end

        function clearLogButtonPushed(app)
            app.LogTextArea.Value = cell(0, 1);
            logMessage(app, '日志已清除');
        end

        function exportResultsButtonPushed(app)
            if isempty(app.ResultsTable.Data)
                uialert(app.UIFigure, '没有可导出的数据', '导出结果');
                return;
            end

            [file, path] = uiputfile('*.csv', '导出结果', 'pareto_solutions.csv');
            if file == 0
                return;
            end

            fullPath = fullfile(path, file);

            try
                columnNames = app.ResultsTable.ColumnName;
                if isstring(columnNames)
                    columnNames = cellstr(columnNames);
                end
                if ischar(columnNames)
                    columnNames = {columnNames};
                end
                columnNames = matlab.lang.makeValidName(columnNames, 'ReplacementStyle', 'delete');

                dataTable = cell2table(app.ResultsTable.Data, 'VariableNames', columnNames);
                writetable(dataTable, fullPath);

                logMessage(app, sprintf('结果已导出: %s', fullPath));
                uialert(app.UIFigure, '结果导出成功！', '导出成功', 'Icon', 'success');
            catch ME
                uialert(app.UIFigure, sprintf('导出失败: %s', ME.message), '错误', 'Icon', 'error');
            end
        end

        %% ========================================
        %% 配置与运行 - 关键方法（Tab3-Tab5）
        %% ========================================

        function valid = validateConfiguration(app)
            %% 验证当前配置

            valid = true;
            errors = {};

            % 问题配置
            if isempty(strtrim(app.ProblemNameField.Value))
                errors{end+1} = '请输入问题名称';
                valid = false;
            end
            if isempty(app.VariablesTable.Data)
                errors{end+1} = '至少需要定义一个决策变量';
                valid = false;
            end
            if isempty(app.ObjectivesTable.Data)
                errors{end+1} = '至少需要定义一个优化目标';
                valid = false;
            end

            % 评估器配置
            if isempty(strtrim(char(string(app.EvaluatorTypeDropDown.Value))))
                errors{end+1} = '请选择评估器类型';
                valid = false;
            end

            % 评估器参数表（economicParameters）校验：参数名必须可作为 struct 字段，值必须为数值标量
            if valid
                paramData = app.EvaluatorParamsTable.Data;
                if isempty(paramData)
                    paramData = cell(0, 2);
                end

                paramErrors = {};
                for i = 1:size(paramData, 1)
                    nameStr = char(string(paramData{i, 1}));
                    if isempty(strtrim(nameStr))
                        continue;
                    end
                    if ~isvarname(nameStr)
                        paramErrors{end+1} = sprintf('评估器参数名必须是合法 MATLAB 标识符: Row %d: %s', i, nameStr); %#ok<AGROW>
                        continue;
                    end

                    value = paramData{i, 2};
                    if isempty(value) || ~isnumeric(value) || ~isscalar(value)
                        paramErrors{end+1} = sprintf('评估器参数值必须为数值标量: %s', nameStr); %#ok<AGROW>
                        continue;
                    end
                    if isnan(value)
                        paramErrors{end+1} = sprintf('评估器参数值为 NaN: %s', nameStr); %#ok<AGROW>
                    end
                end

                if ~isempty(paramErrors)
                    errors = [errors, paramErrors];
                    valid = false;
                end
            end

            % 仿真器配置
            if isempty(strtrim(app.ModelPathField.Value))
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

            % 映射行完整性检查（名称/路径不能为空）
            if valid
                varData = app.VarMappingTable.Data;
                for i = 1:size(varData, 1)
                    nameStr = char(string(varData{i, 1}));
                    pathStr = char(string(varData{i, 2}));
                    if isempty(strtrim(nameStr)) || isempty(strtrim(pathStr))
                        errors{end+1} = sprintf('变量映射第 %d 行名称/路径不能为空', i);
                        valid = false;
                        break;
                    end
                end
            end
            if valid
                resData = app.ResMappingTable.Data;
                for i = 1:size(resData, 1)
                    nameStr = char(string(resData{i, 1}));
                    pathStr = char(string(resData{i, 2}));
                    if isempty(strtrim(nameStr)) || isempty(strtrim(pathStr))
                        errors{end+1} = sprintf('结果映射第 %d 行名称/路径不能为空', i);
                        valid = false;
                        break;
                    end
                end
            end

            % 变量名合法性 + 与变量映射一致性检查
            % 说明：节点映射最终会写入 struct 字段，因此变量名必须是合法 MATLAB 标识符。
            % 同时，为保证 x 向量与仿真器变量顺序一致，推荐映射 key 与变量名保持一致。
            if valid
                problemVarNames = {};
                varDef = app.VariablesTable.Data;
                for i = 1:size(varDef, 1)
                    varName = char(string(varDef{i, 1}));
                    if isempty(strtrim(varName))
                        errors{end+1} = sprintf('决策变量第 %d 行变量名为空', i);
                        valid = false;
                        break;
                    end
                    if ~isvarname(varName)
                        errors{end+1} = sprintf('决策变量名必须是合法 MATLAB 标识符: %s', varName);
                        valid = false;
                        break;
                    end
                    problemVarNames{end+1} = varName; %#ok<AGROW>
                end
            end

            if valid
                mapNames = {};
                varMapData = app.VarMappingTable.Data;
                for i = 1:size(varMapData, 1)
                    mapNames{end+1} = char(string(varMapData{i, 1})); %#ok<AGROW>
                end

                missing = setdiff(problemVarNames, mapNames);
                if ~isempty(missing)
                    errors{end+1} = sprintf('以下变量缺少节点映射（Tab3 变量映射需与变量名一致）: %s', ...
                        strjoin(missing, ', '));
                    valid = false;
                else
                    extra = setdiff(mapNames, problemVarNames);
                    if ~isempty(extra)
                        logMessage(app, sprintf('提示：发现 %d 个多余的变量映射（将被忽略）：%s', ...
                            numel(extra), strjoin(extra, ', ')));
                    end
                end
            end

            % 检查节点映射名称是否合法（必须为合法 MATLAB 标识符）
            if valid
                invalidVarNames = {};
                varData = app.VarMappingTable.Data;
                for i = 1:size(varData, 1)
                    nameStr = char(string(varData{i, 1}));
                    if isempty(nameStr) || ~isvarname(nameStr)
                        invalidVarNames{end+1} = sprintf('Row %d: %s', i, nameStr); %#ok<AGROW>
                    end
                end

                invalidResNames = {};
                resData = app.ResMappingTable.Data;
                for i = 1:size(resData, 1)
                    nameStr = char(string(resData{i, 1}));
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

        function updateAlgorithmDescription(app)
            %% 更新算法说明

            algType = app.AlgorithmDropDown.Value;

            switch algType
                case 'NSGA-II'
                    desc = { ...
                        'NSGA-II (Non-dominated Sorting Genetic Algorithm II)'; ...
                        ''; ...
                        '快速非支配排序遗传算法，适用于多目标优化问题。'; ...
                        ''; ...
                        '主要特点：'; ...
                        '• 快速非支配排序'; ...
                        '• 拥挤距离保持种群多样性'; ...
                        '• 精英保留策略'; ...
                        '• SBX 交叉和多项式变异'; ...
                        ''; ...
                        '适用场景：多目标优化、需要 Pareto 前沿' ...
                        };

                case 'PSO'
                    desc = { ...
                        'PSO (Particle Swarm Optimization)'; ...
                        ''; ...
                        '粒子群优化算法，模拟鸟群觅食行为。'; ...
                        ''; ...
                        '主要特点：'; ...
                        '• 实现简单，参数少'; ...
                        '• 收敛速度快'; ...
                        '• 全局搜索能力强'; ...
                        '• 适合连续优化问题'; ...
                        ''; ...
                        '适用场景：单目标/多目标优化、连续变量' ...
                        };

                otherwise
                    info = '';
                    if exist('AlgorithmMetadata', 'class') == 8
                        try
                            info = AlgorithmMetadata.getDescription(algType);
                        catch
                            info = '';
                        end
                    end
                    if isempty(info) && exist('AlgorithmFactory', 'class') == 8
                        try
                            info = AlgorithmFactory.getAlgorithmInfo(algType);
                        catch
                            info = '';
                        end
                    end

                    if isempty(info)
                        desc = {sprintf('算法: %s', algType)};
                    else
                        lines = regexp(char(string(info)), '\\r?\\n', 'split');
                        desc = [{sprintf('算法: %s', algType)}; {''}; lines(:)];
                    end
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

                otherwise
                    totalEvals = 0;
                    if exist('AlgorithmMetadata', 'class') == 8
                        try
                            params = AlgorithmMetadata.fromTableData(app.AlgorithmParamsTable.Data);

                            if isfield(params, 'populationSize') && isfield(params, 'maxGenerations')
                                totalEvals = params.populationSize * (params.maxGenerations + 1);
                            elseif isfield(params, 'swarmSize') && isfield(params, 'maxIterations')
                                totalEvals = params.swarmSize * (params.maxIterations + 1);
                            elseif isfield(params, 'populationSize') && isfield(params, 'maxIterations')
                                totalEvals = params.populationSize * (params.maxIterations + 1);
                            end
                        catch
                        end
                    end
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
            if isempty(paramData)
                paramData = cell(0, 2);
            end

            eco = struct();
            for i = 1:size(paramData, 1)
                nameStr = char(string(paramData{i, 1}));
                if isempty(strtrim(nameStr))
                    continue;
                end
                if ~isvarname(nameStr)
                    % 防御：无效字段名将被跳过（运行前会在 validateConfiguration 提示）
                    continue;
                end

                value = paramData{i, 2};
                if ischar(value) || isstring(value)
                    value = str2double(value);
                end
                eco.(nameStr) = value;
            end

            app.guiData.problem.evaluator.economicParameters = eco;

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
                varName = char(string(varMapData{i, 1}));
                nodePath = char(string(varMapData{i, 2}));
                if isvarname(varName)
                    app.guiData.simulator.nodeMapping.variables.(varName) = nodePath;
                end
            end

            % 节点映射 - 结果
            resMapData = app.ResMappingTable.Data;
            app.guiData.simulator.nodeMapping.results = struct();
            for i = 1:size(resMapData, 1)
                resName = char(string(resMapData{i, 1}));
                nodePath = char(string(resMapData{i, 2}));
                if isvarname(resName)
                    app.guiData.simulator.nodeMapping.results.(resName) = nodePath;
                end
            end

            % 算法
            app.guiData.algorithm.type = app.AlgorithmDropDown.Value;
            app.guiData.algorithm.parameters = struct();

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

                otherwise
                    if exist('AlgorithmMetadata', 'class') == 8
                        try
                            app.guiData.algorithm.parameters = AlgorithmMetadata.fromTableData(app.AlgorithmParamsTable.Data);
                        catch
                            app.guiData.algorithm.parameters = struct();
                        end
                    end
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
                else
                    app.EvaluatorParamsTable.Data = cell(0, 2);
                end

                updateEvaluatorInfo(app);
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
                algTypeValue = guiData.algorithm.type;
                try
                    if ~ismember(algTypeValue, app.AlgorithmDropDown.Items)
                        app.AlgorithmDropDown.Items{end+1} = algTypeValue; %#ok<AGROW>
                    end
                catch
                end
                app.AlgorithmDropDown.Value = algTypeValue;

                switch guiData.algorithm.type
                    case 'NSGA-II'
                        app.NSGAIIPanel.Visible = 'on';
                        app.PSOPanel.Visible = 'off';
                        app.GenericAlgorithmPanel.Visible = 'off';

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
                        app.GenericAlgorithmPanel.Visible = 'off';

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

                    otherwise
                        app.NSGAIIPanel.Visible = 'off';
                        app.PSOPanel.Visible = 'off';
                        app.GenericAlgorithmPanel.Visible = 'on';

                        if isfield(guiData.algorithm, 'parameters') && isstruct(guiData.algorithm.parameters) && exist('AlgorithmMetadata', 'class') == 8
                            try
                                app.AlgorithmParamsTable.Data = AlgorithmMetadata.toTableData(guiData.algorithm.parameters);
                            catch
                                app.AlgorithmParamsTable.Data = cell(0, 2);
                            end
                        else
                            app.AlgorithmParamsTable.Data = cell(0, 2);
                        end
                end
            end

            updateAlgorithmDescription(app);
            updateEstimations(app);
        end

        function handleOptimizationDataGUI(app, data)
            %% 处理优化数据（GUI 版本）

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

                        % 可选：输出部分堆栈，帮助定位（限制行数避免刷屏）
                        if isfield(data, 'stack') && ~isempty(data.stack)
                            try
                                st = data.stack;
                                n = min(numel(st), 6);
                                for k = 1:n
                                    logMessage(app, sprintf('  at %s (line %d)', st(k).name, st(k).line));
                                end
                            catch
                            end
                        end

                        % 复位异步状态与按钮
                        app.asyncFuture = [];
                        app.dataQueue = [];
                        app.results = [];

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
                app.results = data.results;
                app.callbacks.onAlgorithmEndCallback(data.results);

                app.asyncFuture = [];
                app.dataQueue = [];

                % 恢复按钮状态
                app.RunButton.Enable = 'on';
                app.StopButton.Enable = 'off';
                app.SaveConfigButton.Enable = 'on';
                app.LoadConfigButton.Enable = 'on';
                app.SaveResultsButton.Enable = 'on';

                logMessage(app, '========================================');
                logMessage(app, '优化完成！');

                promptSaveResults(app);
            else
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
            if ~strcmp(answer, '是')
                return;
            end

            baseDir = uigetdir(pwd, '选择结果保存目录');
            if isequal(baseDir, 0)
                return;
            end

            try
                elapsedTime = NaN;
                if ~isempty(app.optimizationStartTime)
                    elapsedTime = toc(app.optimizationStartTime);
                end

                resultsDir = ResultsSaver.saveAll(app.results, app.config, ...
                    elapsedTime, baseDir, app.configFilePath);

                logMessage(app, sprintf('结果已保存至: %s', resultsDir));
                uialert(app.UIFigure, sprintf('结果已保存至:\n%s', resultsDir), ...
                    '保存成功', 'Icon', 'success');
            catch ME
                logMessage(app, sprintf('保存结果失败: %s', ME.message));
                uialert(app.UIFigure, sprintf('保存失败: %s', ME.message), ...
                    '错误', 'Icon', 'error');
            end
        end

        %% 辅助方法

        function updateStatus(app, message)
            timestamp = datestr(now, 'HH:MM:SS');
            app.StatusLabel.Text = sprintf('状态: %s  [%s]', message, timestamp);
        end

        function logMessage(app, message)
            if isempty(app.LogTextArea) || ~isvalid(app.LogTextArea)
                return;
            end

            timestamp = datestr(now, 'HH:MM:SS');
            logMsg = sprintf('[%s] %s', timestamp, message);

            currentLog = app.LogTextArea.Value;
            if isstring(currentLog)
                currentLog = cellstr(currentLog(:));
            elseif ischar(currentLog)
                currentLog = {currentLog};
            elseif iscell(currentLog)
                currentLog = currentLog(:);
            else
                currentLog = cell(0, 1);
            end

            currentLog(end+1, 1) = {logMsg}; %#ok<AGROW>

            if size(currentLog, 1) > 1000
                currentLog = currentLog(end-999:end, 1);
            end

            app.LogTextArea.Value = currentLog;
            drawnow limitrate;
        end

        function updateConfigStatus(app)
            % 刷新变量映射下拉选项（来自问题配置的变量名）
            try
                refreshVarMappingDropdown(app);
            catch
            end

            % 刷新结果映射下拉选项（来自问题配置的目标名）
            try
                refreshResMappingDropdown(app);
            catch
            end

            % 问题配置
            hasName = ~isempty(strtrim(app.ProblemNameField.Value));
            hasVariables = ~isempty(app.VariablesTable.Data);
            hasObjectives = ~isempty(app.ObjectivesTable.Data);
            problemConfigured = hasName && hasVariables && hasObjectives;

            if problemConfigured
                app.ProblemStatusLabel.Text = '问题: ✓ 已配置';
            else
                app.ProblemStatusLabel.Text = '问题: ✗ 未配置';
            end

            % 评估器配置（仅检查是否填写类型）
            hasEvaluator = ~isempty(strtrim(char(string(app.EvaluatorTypeDropDown.Value))));

            % 仿真器配置
            hasModel = ~isempty(strtrim(app.ModelPathField.Value));
            hasVarMapping = ~isempty(app.VarMappingTable.Data);
            hasResMapping = ~isempty(app.ResMappingTable.Data);
            simConfigured = hasModel && hasVarMapping && hasResMapping;

            if simConfigured
                app.SimulatorStatusLabel.Text = '仿真器: ✓ 已配置';
            else
                app.SimulatorStatusLabel.Text = '仿真器: ✗ 未配置';
            end

            % 算法默认视为已配置
            app.AlgorithmStatusLabel.Text = '算法: ✓ 已配置';

            % 状态栏汇总
            missing = {};
            if ~hasName, missing{end+1} = '问题名称'; end
            if ~hasVariables, missing{end+1} = '变量'; end
            if ~hasObjectives, missing{end+1} = '目标'; end
            if ~hasEvaluator, missing{end+1} = '评估器'; end
            if ~hasModel, missing{end+1} = '模型'; end
            if ~hasVarMapping, missing{end+1} = '变量映射'; end
            if ~hasResMapping, missing{end+1} = '结果映射'; end

            if isempty(missing)
                app.ConfigStatusLabel.Text = '配置: 完成';
                app.ConfigStatusLabel.FontColor = [0.2, 0.8, 0.2];
            else
                app.ConfigStatusLabel.Text = sprintf('配置: 缺少 %s', strjoin(missing, '、'));
                app.ConfigStatusLabel.FontColor = [1, 0.6, 0];
            end
        end

        function varNames = getProblemVariableNames(app)
            %% 获取问题配置中的变量名列表（去空、去重）

            varNames = {};
            if isempty(app) || isempty(app.VariablesTable) || ~isvalid(app.VariablesTable)
                return;
            end

            data = app.VariablesTable.Data;
            if isempty(data)
                return;
            end

            try
                firstCol = data(:, 1);
            catch
                return;
            end

            names = cell(numel(firstCol), 1);
            for i = 1:numel(firstCol)
                try
                    names{i} = strtrim(char(string(firstCol{i})));
                catch
                    names{i} = '';
                end
            end

            names = names(~cellfun(@isempty, names));
            if isempty(names)
                return;
            end

            varNames = unique(names, 'stable');
        end

        function objNames = getProblemObjectiveNames(app)
            %% 获取问题配置中的目标名列表（去空、去重）

            objNames = {};
            if isempty(app) || isempty(app.ObjectivesTable) || ~isvalid(app.ObjectivesTable)
                return;
            end

            data = app.ObjectivesTable.Data;
            if isempty(data)
                return;
            end

            try
                firstCol = data(:, 1);
            catch
                return;
            end

            names = cell(numel(firstCol), 1);
            for i = 1:numel(firstCol)
                try
                    names{i} = strtrim(char(string(firstCol{i})));
                catch
                    names{i} = '';
                end
            end

            names = names(~cellfun(@isempty, names));
            if isempty(names)
                return;
            end

            objNames = unique(names, 'stable');
        end

        function refreshVarMappingDropdown(app)
            %% 将 VarMappingTable 第一列改为问题变量名下拉选项

            if isempty(app) || isempty(app.VarMappingTable) || ~isvalid(app.VarMappingTable)
                return;
            end

            varNames = getProblemVariableNames(app);

            % 为避免已有值不在下拉列表导致显示异常，将现有映射名称也加入候选项
            currentData = app.VarMappingTable.Data;
            existing = {};
            if iscell(currentData) && ~isempty(currentData) && size(currentData, 2) >= 1
                existing = cell(size(currentData, 1), 1);
                for i = 1:size(currentData, 1)
                    existing{i} = strtrim(char(string(currentData{i, 1})));
                end
                existing = existing(~cellfun(@isempty, existing));
            end

            items = unique([varNames(:); existing(:)], 'stable');

            if isempty(items)
                app.VarMappingTable.ColumnFormat = {'char', 'char'};
            else
                app.VarMappingTable.ColumnFormat = {items, 'char'};
            end
        end

        function refreshResMappingDropdown(app)
            %% 将ResMappingTable 第一列改成问题目标名下拉选项

            if isempty(app) || isempty(app.ResMappingTable) || ~isvalid(app.ResMappingTable)
                return;
            end

            objNames = getProblemObjectiveNames(app);

            % 为避免已有值不在下拉列表导致显示异常，将现有映射名称也加入候选项
            currentData = app.ResMappingTable.Data;
            existing = {};
            if iscell(currentData) && ~isempty(currentData) && size(currentData, 2) >= 1
                existing = cell(size(currentData, 1), 1);
                for i = 1:size(currentData, 1)
                    existing{i} = strtrim(char(string(currentData{i, 1})));
                end
                existing = existing(~cellfun(@isempty, existing));
            end

            items = unique([objNames(:); existing(:)], 'stable');

            if isempty(items)
                app.ResMappingTable.ColumnFormat = {'char', 'char'};
            else
                app.ResMappingTable.ColumnFormat = {items, 'char'};
            end
        end

    end
end
