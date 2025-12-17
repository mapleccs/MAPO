# MAPOGUI 快速参考

## 文件清单

### 已创建的辅助文件（✓ 完成）

| 文件 | 位置 | 功能 |
|------|------|------|
| **ConfigBuilder.m** | `gui/helpers/` | GUI 数据 ↔ JSON 配置转换 |
| **ConfigValidator.m** | `gui/helpers/` | 配置完整性验证 |
| **AspenNodeTemplates.m** | `gui/helpers/` | Aspen Plus 节点路径模板 |
| **ResultsSaver.m** | `gui/helpers/` | 结果保存（MAT/CSV/PNG/TXT） |
| **handleOptimizationData.m** | `gui/helpers/` | DataQueue 事件处理 |
| **OptimizationCallbacks.m** | `gui/callbacks/` | 优化过程回调（同步模式） |
| **runOptimizationAsync.m** | `gui/` | 异步/同步优化封装 |
| **MAPOGUI_CreationGuide.md** | `gui/` | App Designer 创建详细指南 |
| **MAPOGUI_Callbacks.m** | `gui/` | 所有回调函数代码参考 |
| **launchGUI.m** | 根目录 | GUI 启动脚本 |

### 待创建的文件（需要在 App Designer 中创建）

| 文件 | 位置 | 说明 |
|------|------|------|
| **MAPOGUI.mlapp** | `gui/` | App Designer 主界面文件 |

---

## 快速开始

### 1. 检查依赖

```matlab
launchGUI('check')
```

输出示例：
```
========================================
MAPO 图形用户界面启动器 v2.0
========================================
项目根目录: E:\Project\Chemical Design Competition\MAPO
MATLAB 版本: R2023a

添加路径...
  [OK] Framework 路径已添加
  [OK] GUI 路径已添加

检查依赖文件...
  [OK] ConfigBuilder.m
  [OK] ConfigValidator.m
  [OK] AspenNodeTemplates.m
  [OK] ResultsSaver.m
  [OK] handleOptimizationData.m
  [OK] OptimizationCallbacks.m
  [OK] runOptimizationAsync.m

  [OK] Parallel Computing Toolbox 可用
  [OK] MAPOGUI.mlapp

========================================
依赖检查完成！所有文件就绪。
========================================
```

### 2. 创建 MAPOGUI.mlapp

如果 `MAPOGUI.mlapp` 尚未创建，运行：

```matlab
launchGUI
```

将提示：
```
警告: MAPOGUI.mlapp 未找到！
App Designer 文件尚未创建。

请按以下步骤创建:
1. 打开 App Designer: appdesigner
2. 创建新的 Blank App
3. 按照指南创建界面: gui/MAPOGUI_CreationGuide.md
4. 保存为: gui/MAPOGUI.mlapp

回调函数实现参考: gui/MAPOGUI_Callbacks.m

是否现在打开 App Designer? (y/n):
```

选择 `y` 打开 App Designer，然后按照 `MAPOGUI_CreationGuide.md` 创建界面。

### 3. 实现回调函数

在 App Designer 的 Code View 中：

1. **定义 App 属性**（在 `properties (Access = private)` 区域）：
```matlab
properties (Access = private)
    guiData struct;
    config struct;
    configFilePath char;
    results struct;
    asyncFuture;
    dataQueue;
    callbacks;
    optimizationStartTime;
    varTemplates cell;
    resTemplates cell;
end
```

2. **复制 startupFcn**（从 `MAPOGUI_Callbacks.m` 第 14-59 行）

3. **复制其他回调函数**（从 `MAPOGUI_Callbacks.m` 对应章节）

### 4. 测试 GUI

创建完成后，启动测试：

```matlab
launchGUI
```

---

## 界面结构概览

### Tab 1: 问题配置
- 决策变量表格（添加/删除/编辑）
- 优化目标表格（添加/删除/编辑）
- 约束条件表格（添加/删除/编辑）

### Tab 2: 评估器配置
- 评估器类型（下拉 + 可编辑）与超时设置
- 评估器参数表（写入 `problem.evaluator.economicParameters`）

### Tab 3: 仿真器配置
- 仿真器类型选择（Aspen/MATLAB/Python）
- 模型文件浏览
- 变量节点映射（支持模板）
- 结果节点映射（支持模板）
- 连接测试

### Tab 4: 算法配置
- 算法选择（NSGA-II/PSO）
- 参数配置（滑块 + 数值输入）
- 预估评估次数和运行时间

### Tab 5: 运行与结果
- 运行控制（开始/暂停/停止/保存/加载）
- 进度显示（进度条/时间估算）
- 实时图表（Pareto 前沿/收敛曲线）
- 日志输出
- 结果表格和导出

---

## 关键工作流

### 配置工作流

```
GUI 表格数据
    ↓ collectGUIData()
app.guiData (struct)
    ↓ ConfigBuilder.buildConfig()
config (JSON-ready struct)
    ↓ ConfigValidator.validate()
验证通过
    ↓ ConfigBuilder.toJSON()
case_config.json 文件
```

### 优化工作流

```
case_config.json
    ↓ runOptimizationAsync()
检测 Parallel Toolbox
    ├─ 有 → 异步模式（parfeval）
    │   ↓ Worker 线程执行
    │   ↓ DataQueue 发送数据
    │   ↓ afterEach 接收数据
    │   ↓ handleOptimizationData()
    │   └→ 更新 GUI
    │
    └─ 无 → 同步模式（主线程）
        ↓ OptimizationCallbacks 直接更新 GUI
        └→ 阻塞式执行
```

### 结果保存工作流

```
优化完成（data.isFinal = true）
    ↓ app.results = data.results
    ↓ 询问用户是否保存
    ↓ 用户选择保存位置
    ↓ ResultsSaver.saveAll()
    ├─ optimization_results.mat
    ├─ pareto_solutions.csv
    ├─ all_solutions.csv
    ├─ pareto_front.png
    ├─ optimization_report.txt
    └─ config.json (备份)
```

---

## 常用代码片段

### 添加日志消息

```matlab
logMessage(app, 'This is a log message');
```

### 显示警告对话框

```matlab
uialert(app.UIFigure, 'Warning message', 'Warning Title', 'Icon', 'warning');
```

### 显示成功对话框

```matlab
uialert(app.UIFigure, 'Success message', 'Success', 'Icon', 'success');
```

### 询问用户

```matlab
answer = questdlg('Question?', 'Title', 'Yes', 'No', 'Yes');
if strcmp(answer, 'Yes')
    % 用户选择了 Yes
end
```

### 文件选择对话框

```matlab
[file, path] = uigetfile('*.json', 'Select Config File');
if file ~= 0
    fullPath = fullfile(path, file);
    % 处理文件
end
```

### 文件保存对话框

```matlab
[file, path] = uiputfile('*.json', 'Save Config As', 'default_name.json');
if file ~= 0
    fullPath = fullfile(path, file);
    % 保存文件
end
```

---

## 调试技巧

### 1. 检查 GUI 数据结构

在任何回调函数中添加：
```matlab
disp(app.guiData);
```

### 2. 验证配置

在 RunButton 回调中，在启动优化前添加：
```matlab
[valid, errors, warnings] = ConfigValidator.validate(app.config);
disp(errors);
disp(warnings);
```

### 3. 检查异步任务状态

```matlab
if ~isempty(app.asyncFuture)
    disp(app.asyncFuture.State);  % 'running', 'finished', 'failed'
end
```

### 4. 测试单个辅助函数

在命令窗口测试：
```matlab
% 测试 ConfigBuilder
guiData = struct();
guiData.problem.name = 'TestProblem';
guiData.problem.variables(1).name = 'x1';
% ... 设置其他字段
config = ConfigBuilder.buildConfig(guiData);
disp(config);

% 测试 AspenNodeTemplates
templates = AspenNodeTemplates.getVariableTemplates();
disp(templates.StreamInput);
```

---

## 常见问题

### Q1: GUI 启动失败，提示找不到 MAPOGUI

**A**: 确保：
1. `MAPOGUI.mlapp` 文件存在于 `gui/` 目录
2. 运行 `launchGUI('check')` 检查所有依赖
3. 在 App Designer 中打开 .mlapp 文件检查是否有错误

### Q2: 回调函数报错

**A**:
1. 检查是否复制了所有必需的辅助函数（`methods (Access = private)` 区域）
2. 检查 App 属性是否正确定义
3. 参考 `MAPOGUI_Callbacks.m` 确保回调签名正确

### Q3: 表格数据无法编辑

**A**: 检查表格的 `ColumnEditable` 属性：
```matlab
app.VariablesTable.ColumnEditable = [true, true, true, true, true, true];
```

### Q4: 异步模式不工作

**A**:
1. 检查是否安装了 Parallel Computing Toolbox
2. 运行 `launchGUI('check')` 查看工具箱状态
3. 如果没有工具箱，会自动回退到同步模式

### Q5: 节点模板无法应用

**A**:
1. 确保 `AspenNodeTemplates.m` 在路径中
2. 检查模板下拉框是否正确初始化：
```matlab
app.VarTemplateDropDown.Items = AspenNodeTemplates.getTemplateCategories();
```

---

## 下一步

1. **创建 MAPOGUI.mlapp**
   - 打开 App Designer
   - 按照 `MAPOGUI_CreationGuide.md` 创建界面
   - 复制 `MAPOGUI_Callbacks.m` 中的回调函数

2. **测试基本功能**
   - 添加变量/目标/约束
   - 配置仿真器节点映射
   - 选择算法和参数
   - 测试配置保存/加载

3. **运行完整优化**
   - 加载示例配置（`example/R601/case_config.json`）
   - 点击"开始优化"
   - 观察实时进度和图表
   - 保存优化结果

4. **自定义和扩展**
   - 添加新的评估器类型
   - 扩展节点模板
   - 自定义图表样式
   - 添加更多算法支持

---

## 技术支持

如遇问题，请检查：
1. 创建指南：`gui/MAPOGUI_CreationGuide.md`
2. 回调参考：`gui/MAPOGUI_Callbacks.m`
3. 框架文档：`framework/` 目录下的各个类文件
4. 示例配置：`example/R601/case_config.json`

祝使用顺利！
