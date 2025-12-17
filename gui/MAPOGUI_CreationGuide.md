# MAPOGUI 创建指南

## 概述

本指南详细说明如何在 MATLAB App Designer 中创建 MAPOGUI 交互式界面。

---

## 第一步：创建新 App

1. 打开 MATLAB
2. 在命令窗口输入：`appdesigner`
3. 选择 "Blank App"
4. 设置 App 名称为 `MAPOGUI`

---

## 第二步：主窗口配置

### UIFigure 属性设置

| 属性 | 值 |
|------|-----|
| Name | MAPO - MATLAB-Aspen Process Optimizer |
| Position | [100, 100, 1200, 800] |
| Resize | on |

---

## 第三步：布局结构

### 整体布局（Grid Layout）

创建主 Grid Layout：
- 行高：['1x', 'fit'] （内容区 + 状态栏）
- 列宽：['1x']

### 标签页组（Tab Group）

在 Grid Layout 的第一行放置 Tab Group：
- 创建 5 个 Tab
- Tab 1: 问题配置 (ProblemTab)
- Tab 2: 评估器配置 (EvaluatorTab)
- Tab 3: 仿真器配置 (SimulatorTab)
- Tab 4: 算法配置 (AlgorithmTab)
- Tab 5: 运行与结果 (RunResultsTab)

### 状态栏（Panel）

在 Grid Layout 的第二行放置 Panel：
- 高度：30 像素
- 包含状态标签

---

## 第四步：Tab 1 - 问题配置

### 布局
- 使用 Grid Layout，分为 4 个主要区域（Panel）

### Panel 1: 基本信息
**位置**：第 1 行

**控件**：
| 控件类型 | 名称 | 标签 | 位置 |
|---------|------|------|------|
| Label | - | 问题名称: | (10, 10) |
| EditField | ProblemNameField | - | (100, 10, 300) |
| Label | - | 问题描述: | (10, 40) |
| TextArea | ProblemDescArea | - | (100, 40, 300, 60) |

### Panel 2: 决策变量
**位置**：第 2 行

**控件**：
| 控件类型 | 名称 | 标签 | 回调 |
|---------|------|------|------|
| Label | - | 决策变量配置 | - |
| Table | VariablesTable | - | CellEditCallback |
| Button | AddVariableButton | 添加变量 | ButtonPushed |
| Button | DeleteVariableButton | 删除变量 | ButtonPushed |

**Table 列配置**：
```matlab
VariablesTable.ColumnName = {'变量名', '类型', '下界', '上界', '单位', '描述'};
VariablesTable.ColumnEditable = [true, true, true, true, true, true];
VariablesTable.ColumnFormat = {'char', {'continuous', 'integer', 'discrete'}, 'numeric', 'numeric', 'char', 'char'};
VariablesTable.ColumnWidth = {100, 100, 80, 80, 60, 200};
```

### Panel 3: 优化目标
**位置**：第 3 行

**控件**：
| 控件类型 | 名称 | 标签 | 回调 |
|---------|------|------|------|
| Label | - | 优化目标配置 | - |
| Table | ObjectivesTable | - | CellEditCallback |
| Button | AddObjectiveButton | 添加目标 | ButtonPushed |
| Button | DeleteObjectiveButton | 删除目标 | ButtonPushed |

**Table 列配置**：
```matlab
ObjectivesTable.ColumnName = {'目标名', '类型', '权重', '描述'};
ObjectivesTable.ColumnEditable = [true, true, true, true];
ObjectivesTable.ColumnFormat = {'char', {'minimize', 'maximize'}, 'numeric', 'char'};
ObjectivesTable.ColumnWidth = {120, 100, 80, 200};
```

### Panel 4: 约束条件
**位置**：第 4 行

**控件**：
| 控件类型 | 名称 | 标签 | 回调 |
|---------|------|------|------|
| Label | - | 约束条件配置 | - |
| Table | ConstraintsTable | - | CellEditCallback |
| Button | AddConstraintButton | 添加约束 | ButtonPushed |
| Button | DeleteConstraintButton | 删除约束 | ButtonPushed |

**Table 列配置**：
```matlab
ConstraintsTable.ColumnName = {'约束名', '类型', '表达式', '描述'};
ConstraintsTable.ColumnEditable = [true, true, true, true];
ConstraintsTable.ColumnFormat = {'char', {'inequality', 'equality'}, 'char', 'char'};
ConstraintsTable.ColumnWidth = {120, 100, 150, 200};
```

---

## 第五步：Tab 2 - 评估器配置

### 布局
- 独立评估器配置标签页

**控件**：
| 控件类型 | 名称 | 标签 | 默认值 |
|---------|------|------|--------|
| Label | - | 评估器配置 | - |
| Label | - | 评估器类型: | - |
| DropDown | EvaluatorTypeDropDown | 评估器类型: | 'ORCEvaluator'（可编辑） |
| Button | EvaluatorRefreshButton | 刷新 | - |
| Spinner | EvaluatorTimeoutSpinner | 超时时间(秒): | 300 |
| Table | EvaluatorParamsTable | 评估器参数表 | 2列：参数名/值 |
| Button | AddEvaluatorParamButton | + 添加 | - |
| Button | DeleteEvaluatorParamButton | 删除 | - |
| Button | AutoFillEvaluatorParamsButton | 推荐填充 | - |
| TextArea | EvaluatorInfoArea | 说明/状态 | - |

---

## 第六步：Tab 3 - 仿真器配置

### 布局
- 上半部分：基本配置
- 下半部分：节点映射表格

### Panel 1: 仿真器类型和设置
**位置**：顶部

**控件**：
| 控件类型 | 名称 | 标签 | 选项/默认值 |
|---------|------|------|------------|
| DropDown | SimulatorTypeDropDown | 仿真器类型: | {'Aspen', 'MATLAB', 'Python'} |
| Label | - | 模型文件路径: | - |
| EditField | ModelPathField | - | '' |
| Button | BrowseModelButton | 浏览... | ButtonPushed |
| Spinner | SimTimeoutSpinner | 超时(秒): | 300 |
| Spinner | MaxRetriesSpinner | 最大重试: | 3 |
| Spinner | RetryDelaySpinner | 重试延迟(秒): | 5 |
| CheckBox | VisibleCheckBox | 可见运行 | false |
| CheckBox | SuppressWarningsCheckBox | 抑制警告 | true |

### Panel 2: 变量节点映射
**位置**：中部左侧

**控件**：
| 控件类型 | 名称 | 标签 | 回调 |
|---------|------|------|------|
| Label | - | 变量节点映射 | - |
| DropDown | VarTemplateDropDown | 模板: | ValueChanged |
| Table | VarMappingTable | - | CellEditCallback |
| Button | AddVarMappingButton | 添加映射 | ButtonPushed |
| Button | DeleteVarMappingButton | 删除映射 | ButtonPushed |
| Button | ApplyVarTemplateButton | 应用模板 | ButtonPushed |

**Table 列配置**：
```matlab
VarMappingTable.ColumnName = {'变量名', 'Aspen节点路径'};
VarMappingTable.ColumnEditable = [false, true];
VarMappingTable.ColumnFormat = {'char', 'char'};
VarMappingTable.ColumnWidth = {120, 400};
```

**DropDown 配置**：
```matlab
VarTemplateDropDown.Items = AspenNodeTemplates.getTemplateCategories();
```

### Panel 3: 结果节点映射
**位置**：中部右侧

**控件**：
| 控件类型 | 名称 | 标签 | 回调 |
|---------|------|------|------|
| Label | - | 结果节点映射 | - |
| DropDown | ResTemplateDropDown | 模板: | ValueChanged |
| Table | ResMappingTable | - | CellEditCallback |
| Button | AddResMappingButton | 添加映射 | ButtonPushed |
| Button | DeleteResMappingButton | 删除映射 | ButtonPushed |
| Button | ApplyResTemplateButton | 应用模板 | ButtonPushed |

**Table 列配置**：同变量映射

### Panel 4: 测试和验证
**位置**：底部

**控件**：
| 控件类型 | 名称 | 标签 | 回调 |
|---------|------|------|------|
| Button | TestConnectionButton | 测试连接 | ButtonPushed |
| Button | ValidatePathsButton | 验证路径 | ButtonPushed |
| Label | ConnectionStatusLabel | 状态: 未连接 | - |

---

## 第七步：Tab 4 - 算法配置

### 布局
- 左侧：算法选择和说明
- 右侧：参数配置面板

### Panel 1: 算法选择
**位置**：顶部

**控件**：
| 控件类型 | 名称 | 标签 | 选项 |
|---------|------|------|------|
| DropDown | AlgorithmDropDown | 算法类型: | {'NSGA-II', 'PSO'} |
| Label | AlgorithmDescLabel | 算法说明: | - |
| TextArea | AlgorithmDescArea | - | (只读) |

### Panel 2: NSGA-II 参数
**位置**：右侧（初始可见）
**组件名称**：NSGAIIPanel

**控件**：
| 控件类型 | 名称 | 标签 | 范围/默认值 |
|---------|------|------|-----------|
| Label | - | 种群大小: | - |
| Spinner | PopSizeSpinner_NSGAII | - | [10, 1000], 100 |
| Label | - | 最大代数: | - |
| Spinner | MaxGenSpinner_NSGAII | - | [1, 1000], 250 |
| Label | - | 交叉概率: | - |
| Slider | CrossoverSlider_NSGAII | - | [0, 1], 0.9 |
| Label | CrossoverValueLabel_NSGAII | 0.90 | - |
| Label | - | 变异概率: | - |
| Slider | MutationSlider_NSGAII | - | [0, 2], 1.0 |
| Label | MutationValueLabel_NSGAII | 1.00 | - |
| Label | - | 交叉分布指数: | - |
| Spinner | CrossoverDistSpinner_NSGAII | - | [1, 50], 20 |
| Label | - | 变异分布指数: | - |
| Spinner | MutationDistSpinner_NSGAII | - | [1, 50], 20 |

### Panel 3: PSO 参数
**位置**：右侧（初始隐藏）
**组件名称**：PSOPanel

**控件**：
| 控件类型 | 名称 | 标签 | 范围/默认值 |
|---------|------|------|-----------|
| Label | - | 粒子数: | - |
| Spinner | SwarmSizeSpinner_PSO | - | [10, 1000], 50 |
| Label | - | 最大迭代数: | - |
| Spinner | MaxIterSpinner_PSO | - | [1, 1000], 200 |
| Label | - | 惯性权重: | - |
| Slider | InertiaSlider_PSO | - | [0, 1], 0.7 |
| Label | InertiaValueLabel_PSO | 0.70 | - |
| Label | - | 认知系数: | - |
| Slider | CognitiveSlider_PSO | - | [0, 4], 1.5 |
| Label | CognitiveValueLabel_PSO | 1.50 | - |
| Label | - | 社会系数: | - |
| Slider | SocialSlider_PSO | - | [0, 4], 1.5 |
| Label | SocialValueLabel_PSO | 1.50 | - |
| Label | - | 最大速度比例: | - |
| Slider | MaxVelSlider_PSO | - | [0.1, 1], 0.2 |
| Label | MaxVelValueLabel_PSO | 0.20 | - |

### Panel 4: 预估信息
**位置**：底部

**控件**：
| 控件类型 | 名称 | 标签 |
|---------|------|------|
| Label | TotalEvalsLabel | 预估总评估次数: 0 |
| Label | EstTimeLabel | 预估运行时间: -- |

---

## 第八步：Tab 5 - 运行与结果

### 布局
- 顶部：控制按钮和状态
- 中部：图表（左右分栏）
- 底部：日志和结果表格

### Panel 1: 运行控制
**位置**：顶部

**控件**：
| 控件类型 | 名称 | 标签 | Icon | 回调 |
|---------|------|------|------|------|
| Button | RunButton | 开始优化 | play | ButtonPushed |
| Button | PauseButton | 暂停 | pause | ButtonPushed |
| Button | StopButton | 停止 | stop | ButtonPushed |
| Button | SaveConfigButton | 保存配置 | save | ButtonPushed |
| Button | LoadConfigButton | 加载配置 | upload | ButtonPushed |
| Button | SaveResultsButton | 保存结果 | export | ButtonPushed |

**初始状态**：
```matlab
RunButton.Enable = 'on';
PauseButton.Enable = 'off';
StopButton.Enable = 'off';
SaveResultsButton.Enable = 'off';
```

### Panel 2: 配置状态
**位置**：顶部右侧

**控件**：
| 控件类型 | 名称 | 内容 |
|---------|------|------|
| Label | ProblemStatusLabel | 问题: ❌ 未配置 |
| Label | SimulatorStatusLabel | 仿真器: ❌ 未配置 |
| Label | AlgorithmStatusLabel | 算法: ✓ 已配置 |

### Panel 3: 进度显示
**位置**：控制按钮下方

**控件**：
| 控件类型 | 名称 | 标签 |
|---------|------|------|
| Gauge | ProgressGauge | 优化进度 |
| Label | ProgressLabel | 代数: 0/0 | 评估: 0 |
| Label | TimeLabel | 已用: 00:00:00 | 剩余: -- |

### Panel 4: 实时图表
**位置**：中部，左右分栏

**左侧**：
- UIAxes: ParetoAxes
- Title: "Pareto 前沿"
- XLabel: "目标 1"
- YLabel: "目标 2"

**右侧**：
- UIAxes: ConvergenceAxes
- Title: "收敛曲线"
- XLabel: "代数"
- YLabel: "最优目标值"

### Panel 5: 日志输出
**位置**：底部左侧

**控件**：
| 控件类型 | 名称 | 属性 |
|---------|------|------|
| Label | - | 运行日志 |
| TextArea | LogTextArea | FontName='Courier New', Editable=false |
| Button | ClearLogButton | 清除日志 | ButtonPushed |

### Panel 6: 结果表格
**位置**：底部右侧

**控件**：
| 控件类型 | 名称 | 属性 |
|---------|------|------|
| Label | - | Pareto 解 |
| Table | ResultsTable | - |
| Button | ExportResultsButton | 导出CSV | ButtonPushed |

---

## 第八步：App 属性定义

在 Code View 中，定义以下 properties：

```matlab
properties (Access = private)
    % GUI 数据结构
    guiData struct;

    % 配置和结果
    config struct;
    configFilePath char;
    results struct;

    % 优化控制
    asyncFuture;
    dataQueue;
    callbacks;
    optimizationStartTime;

    % 模板缓存
    varTemplates cell;
    resTemplates cell;
end
```

---

## 第九步：初始化代码

在 `startupFcn` 中添加：

```matlab
function startupFcn(app)
    % 初始化 GUI 数据结构
    app.guiData = struct();
    app.guiData.problem = struct();
    app.guiData.simulator = struct();
    app.guiData.algorithm = struct();

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

    % 添加框架路径
    addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', 'framework')));

    % 记录日志
    logMessage(app, 'MAPO GUI 已启动');
end
```

---

## 第十步：回调函数

所有回调函数的详细实现请参考 `MAPOGUI_Callbacks.m` 文件。

主要回调包括：
1. **Tab 1**: AddVariableButton, DeleteVariableButton, AddObjectiveButton, DeleteObjectiveButton, AddConstraintButton, DeleteConstraintButton
2. **Tab 2**: EvaluatorTypeDropDown ValueChanged, EvaluatorRefreshButton, Add/Delete/AutoFill 参数按钮
3. **Tab 3**: BrowseModelButton, ApplyVarTemplateButton, ApplyResTemplateButton, TestConnectionButton
4. **Tab 4**: AlgorithmDropDown ValueChanged, Slider ValueChanged (更新标签)
5. **Tab 5**: RunButton, StopButton, SaveConfigButton, LoadConfigButton, SaveResultsButton

---

## 第十一步：辅助函数

在 Code View 的 `methods (Access = private)` 区域添加辅助函数：

```matlab
methods (Access = private)

    function updateConfigStatus(app)
        % 更新配置状态显示
    end

    function valid = validateConfiguration(app)
        % 验证当前配置
    end

    function logMessage(app, message)
        % 添加日志消息
    end

    function updateAlgorithmDescription(app)
        % 更新算法说明
    end

    function collectGUIData(app)
        % 从 GUI 控件收集数据到 app.guiData
    end

    function loadGUIData(app, data)
        % 从数据加载到 GUI 控件
    end
end
```

详细实现请参考 `MAPOGUI_Callbacks.m` 文件。

---

## 第十二步：保存和测试

1. 保存 App：`Ctrl+S`
2. 文件名：`MAPOGUI.mlapp`
3. 保存位置：`E:\Project\Chemical Design Competition\MAPO\gui\`
4. 点击 "Run" 测试

---

## 创建清单

### 必需控件清单

#### Tab 1 - 问题配置
- [x] ProblemNameField
- [x] ProblemDescArea
- [x] VariablesTable
- [x] AddVariableButton, DeleteVariableButton
- [x] ObjectivesTable
- [x] AddObjectiveButton, DeleteObjectiveButton
- [x] ConstraintsTable
- [x] AddConstraintButton, DeleteConstraintButton

#### Tab 2 - 评估器配置
- [x] EvaluatorTypeDropDown, EvaluatorRefreshButton
- [x] EvaluatorTimeoutSpinner
- [x] EvaluatorParamsTable
- [x] AddEvaluatorParamButton, DeleteEvaluatorParamButton, AutoFillEvaluatorParamsButton
- [x] EvaluatorInfoArea

#### Tab 3 - 仿真器配置
- [x] SimulatorTypeDropDown
- [x] ModelPathField, BrowseModelButton
- [x] SimTimeoutSpinner, MaxRetriesSpinner, RetryDelaySpinner
- [x] VisibleCheckBox, SuppressWarningsCheckBox
- [x] VarTemplateDropDown, VarMappingTable
- [x] AddVarMappingButton, DeleteVarMappingButton, ApplyVarTemplateButton
- [x] ResTemplateDropDown, ResMappingTable
- [x] AddResMappingButton, DeleteResMappingButton, ApplyResTemplateButton
- [x] TestConnectionButton, ValidatePathsButton
- [x] ConnectionStatusLabel

#### Tab 4 - 算法配置
- [x] AlgorithmDropDown
- [x] AlgorithmDescArea
- [x] NSGAIIPanel (所有子控件)
- [x] PSOPanel (所有子控件)
- [x] TotalEvalsLabel, EstTimeLabel

#### Tab 5 - 运行与结果
- [x] RunButton, PauseButton, StopButton
- [x] SaveConfigButton, LoadConfigButton, SaveResultsButton
- [x] ProblemStatusLabel, SimulatorStatusLabel, AlgorithmStatusLabel
- [x] ProgressGauge, ProgressLabel, TimeLabel
- [x] ParetoAxes, ConvergenceAxes
- [x] LogTextArea, ClearLogButton
- [x] ResultsTable, ExportResultsButton

---

## 下一步

创建完成后：
1. 运行 `launchGUI.m` 启动应用
2. 测试各个功能模块
3. 使用示例配置文件验证完整流程

如遇问题，请参考：
- `MAPOGUI_Callbacks.m` - 所有回调函数实现
- `MAPOGUI_TestScript.m` - 测试脚本
- `example/R601/case_config.json` - 示例配置
