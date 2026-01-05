# MAPO - MATLAB-Aspen Process Optimizer

[![MATLAB](https://img.shields.io/badge/MATLAB-R2020a%2B-orange)](https://www.mathworks.com/products/matlab.html)
[![Aspen Plus](https://img.shields.io/badge/Aspen%20Plus-V11%2B-blue)](https://www.aspentech.com/en/products/engineering/aspen-plus)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-2.1-brightgreen)](CHANGELOG.md)

## 📌 简介

MAPO (MATLAB-Aspen Process Optimizer) 是一个集成了MATLAB优化算法与Aspen Plus过程仿真的化工流程优化框架。该框架提供了模块化、可扩展的架构，支持单目标和多目标优化问题。

**🎉 版本 2.1 更新内容**:
- 🖥️ 新增图形用户界面(GUI)，提供可视化操作体验
- ⚡ 支持并行计算，大幅提升优化效率
- 📈 新增灵敏度分析模块
- 📝 优化日志系统，支持队列式日志记录
- 🔧 改进Aspen Plus连接稳定性
- 🧠 新增 ANN-NSGA-II 代理辅助多目标算法（可选 TOPSIS 折中解与精确回代验证）
- 🧩 GUI 算法列表/参数面板改为 metadata 驱动（`framework/algorithm/**/algorithm_meta.json`）
- 🧪 新增通用算法冒烟测试脚本 `run_smoke_algorithm`（不依赖 Aspen/COM）

### 主要特性

- 🎯 **多种优化算法**: NSGA-II (多目标)、ANN-NSGA-II (代理辅助)、PSO (粒子群优化)
- 🧩 **低耦合算法集成**: `AlgorithmFactory`/GUI 自动扫描 `algorithm_meta.json`，新增算法无需改 GUI 代码
- 🖥️ **图形用户界面**: 全新GUI支持，无需编写代码即可完成优化配置
- ⚡ **并行计算支持**: 多核并行评估，显著加速优化过程
- 🔧 **多仿真器支持**: Aspen Plus、MATLAB函数、Python脚本
- 📦 **模块化设计**: 易于扩展新算法、评估器和仿真器
- 📈 **灵敏度分析**: 内置参数灵敏度分析工具
- 📊 **结果可视化**: Pareto前沿、收敛曲线、优化历史
- ⚙️ **灵活配置**: JSON配置文件，参数化管理
- 📝 **详细日志**: 完整的优化过程记录
- ✨ **模板系统**: 通用运行脚本，最小化代码编写

## 🚀 快速开始

### 系统要求

- MATLAB R2020a 或更高版本 (推荐 R2021a+)
- Aspen Plus V11 或更高版本
- Windows 操作系统 (支持COM接口)
- Parallel Computing Toolbox (可选，用于并行计算)

### 📥 安装

1. 克隆或下载项目:
```bash
git clone https://github.com/mapleccs/MAPO.git
cd MAPO
```

2. 在MATLAB中添加路径:
```matlab
addpath(genpath('framework'));
addpath(genpath('gui'));
addpath(genpath(fullfile('example','_template'))); % 可选：模板脚本 & 冒烟测试脚本
```

### 🧪 冒烟测试（推荐）

如果你在开发/集成新算法，建议先跑一个不依赖 Aspen/COM 的冒烟测试：

```matlab
addpath(genpath(fullfile('example','_template')));
out = run_smoke_algorithm('all', ...
    'Problem', 'zdt1', ...
    'PopulationSize', 20, ...
    'Iterations', 5, ...
    'ThrowOnFailure', true);
```

### 💻 使用方式

#### 方式一: 图形用户界面 (推荐新手使用) 🖥️

```matlab
% 启动GUI
launchGUI()

% 或加载测试配置
launchGUI('test')

% 仅检查依赖
launchGUI('check')
```

GUI提供以下功能:
- 可视化配置优化问题
- 实时监控优化进度
- 交互式结果分析
- 一键导出结果

#### 方式二: 使用模板系统 (推荐有经验用户) ✨

1. **复制模板目录**:
```matlab
copyfile('example/_template', 'my_optimization', 'f');
cd('my_optimization');
```

2. **修改配置文件** (`case_config.json`):
```json
{
  "problem": {
    "name": "MyProcess",
    "variables": [...],
    "objectives": [...]
  },
  "simulator": {
    "modelPath": "my_model.bkp",
    "nodeMapping": {...}
  },
  "algorithm": {
    "type": "NSGA-II",
    "parameters": {...}
  }
}
```

3. **运行优化**:
```matlab
results = run_case('case_config.json');
```

#### 方式三: 使用预置示例

```matlab
% ADN生产工艺优化
cd('example/ADN');
run_adn_nsga2_optimization;

% ORC系统优化
cd('example/R601');
run_ocr_nsga2_optimization;

% ASPL示例
cd('example/ASPL');
ASPL;
```

## 📁 项目结构

```
MAPO/
├── framework/                    # 核心框架
│   ├── algorithm/               # 优化算法
│   │   ├── ann_nsga2/          # ANN-NSGA-II（代理辅助）
│   │   │   ├── ANNNSGAII.m
│   │   │   └── algorithm_meta.json
│   │   ├── nsga2/              # NSGA-II算法
│   │   │   ├── NSGAII.m
│   │   │   ├── GeneticOperators.m
│   │   │   └── algorithm_meta.json
│   │   ├── pso/                # 粒子群算法
│   │   │   ├── PSO.m
│   │   │   └── algorithm_meta.json
│   │   ├── AlgorithmBase.m     # 算法基类
│   │   ├── AlgorithmFactory.m  # 算法工厂
│   │   ├── Individual.m        # 个体类
│   │   ├── Population.m        # 种群类
│   │   └── IOptimizer.m        # 优化器接口
│   │
│   ├── problem/                 # 问题定义
│   │   ├── evaluator/          # 评估器
│   │   │   ├── EvaluatorFactory.m
│   │   │   ├── ADNProductionEvaluator.m
│   │   │   ├── ASPLProductionEvaluator.m
│   │   │   ├── DistillationEvaluator.m
│   │   │   ├── ORCEvaluator.m
│   │   │   ├── MyCaseEvaluator.m
│   │   │   └── ZDT1Evaluator.m
│   │   ├── Variable.m          # 变量定义
│   │   ├── VariableSet.m       # 变量集合
│   │   ├── Objective.m         # 目标函数
│   │   ├── Constraint.m        # 约束条件
│   │   ├── Evaluator.m         # 评估器基类
│   │   ├── ProblemFactory.m    # 问题工厂
│   │   └── OptimizationProblem.m
│   │
│   ├── simulator/               # 仿真器适配器
│   │   ├── aspen/              # Aspen Plus适配器
│   │   │   └── AspenPlusSimulator.m
│   │   ├── matlab/             # MATLAB函数适配器
│   │   ├── python/             # Python脚本适配器
│   │   ├── ISimulator.m        # 仿真器接口
│   │   ├── SimulatorBase.m     # 仿真器基类
│   │   ├── SimulatorFactory.m  # 仿真器工厂
│   │   └── SimulatorConfig.m   # 仿真器配置
│   │
│   ├── analysis/                # 分析模块
│   │   └── sensitivity/        # 灵敏度分析
│   │       ├── core/
│   │       ├── evaluators/
│   │       ├── reporters/
│   │       ├── strategies/
│   │       └── scan_feasible_regions.m
│   │
│   ├── core/                    # 核心组件
│   │   ├── Config.m            # 配置管理
│   │   ├── Logger.m            # 日志系统
│   │   ├── DataQueueLogger.m   # 队列日志
│   │   ├── ParallelConfig.m    # 并行配置
│   │   └── ParallelEvaluationManager.m
│   │
│   └── module/                  # 扩展模块
│       ├── builtin/            # 内置模块
│       ├── custom/             # 自定义模块
│       └── template/           # 模块模板
│
├── gui/                         # 图形用户界面
│   ├── MAPOGUI.m               # 主GUI类
│   ├── MAPOGUI_Callbacks.m     # 回调函数
│   ├── runOptimizationAsync.m  # 异步优化运行器
│   ├── helpers/                # GUI辅助函数
│   │   ├── ConfigBuilder.m
│   │   ├── ConfigValidator.m
│   │   ├── AlgorithmMetadata.m
│   │   ├── AspenNodeTemplates.m
│   │   └── ResultsSaver.m
│   └── callbacks/              # 回调处理器
│
├── example/                     # 示例案例
│   ├── _template/              # 通用模板
│   │   ├── run_case.m
│   │   ├── run_parallel_optimization.m
│   │   ├── run_smoke_algorithm.m
│   │   ├── run_smoke_all_algorithms.m
│   │   ├── run_smoke_ann_nsga2.m
│   │   └── case_config.json
│   ├── ADN/                    # ADN生产优化
│   ├── R601/                   # ORC系统优化
│   └── ASPL/                   # ASPL示例
│
├── config/                      # 全局配置文件
│   ├── algorithm_config.json   # 算法配置
│   ├── simulator_config.json   # 仿真器配置
│   └── problem_config.json     # 问题配置
│
├── docs/                        # 文档
│   ├── user_guide.md           # 用户指南
│   └── GUI_使用指南.md          # GUI使用指南
│
├── launchGUI.m                  # GUI启动器
├── CLAUDE.md                    # AI辅助开发指南
└── README.md                    # 本文档
```

## ⚙️ 配置说明

### 算法配置（case_config.json）

在 `case_config.json` 中选择算法类型并填写参数：

```json
{
  "algorithm": {
    "type": "ANN-NSGA-II",
    "parameters": {
      "populationSize": 50,
      "maxGenerations": 20,
      "training": { "samples": 100, "samplingMethod": "lhs" },
      "surrogate": { "type": "poly2" },
      "verification": { "enabled": true, "verifyTOPSIS": true }
    }
  }
}
```

可选算法类型示例：`NSGA-II` / `ANN-NSGA-II` / `PSO`。GUI 默认参数来自 `framework/algorithm/**/algorithm_meta.json`。

### 仿真器配置

```json
{
  "simulator": {
    "type": "Aspen",
    "settings": {
      "modelPath": "path/to/model.bkp",
      "timeout": 300,
      "visible": false,
      "maxRetries": 3,
      "retryDelay": 2
    },
    "nodeMapping": {
      "variables": {
        "FEED_FLOW": "\\Data\\Streams\\FEED\\Input\\TOTFLOW"
      },
      "results": {
        "PRODUCT_PURITY": "\\Data\\Streams\\PRODUCT\\Output\\MASSFRAC"
      }
    }
  }
}
```

### 问题配置

```json
{
  "problem": {
    "name": "Process_Optimization",
    "variables": [
      {
        "name": "VAR1",
        "type": "continuous",
        "lowerBound": 10,
        "upperBound": 100,
        "initialValue": 50
      },
      {
        "name": "VAR2",
        "type": "integer",
        "lowerBound": 1,
        "upperBound": 20
      }
    ],
    "objectives": [
      {"name": "COST", "type": "minimize"},
      {"name": "EFFICIENCY", "type": "maximize"}
    ],
    "constraints": [
      {"name": "PURITY", "type": "inequality", "expression": "PURITY >= 0.99"}
    ],
    "evaluator": {"type": "MyCaseEvaluator", "timeout": 300}
  }
}
```

## 📋 变量类型

MAPO支持四种变量类型:

| 类型 | 说明 | 示例 |
|------|------|------|
| continuous | 连续变量 | 温度、压力、流量 |
| integer | 整数变量 | 塔板数、进料位置 |
| discrete | 离散变量 | 预定义的离散值集合 |
| categorical | 分类变量 | 工质类型、设备型号 |

```matlab
% 连续变量
var1 = Variable('temperature', 'continuous', [300, 500]);

% 整数变量
var2 = Variable('stages', 'integer', [10, 50]);

% 离散变量
var3 = Variable('pressure', 'discrete', [1.0, 1.5, 2.0, 2.5, 3.0]);

% 分类变量
var4 = Variable('solvent', 'categorical', {'water', 'ethanol', 'methanol'});
```

## ⚡ 并行计算

启用并行计算可显著加速优化过程:

```matlab
% 配置并行计算
parallelConfig = ParallelConfig();
parallelConfig.enableParallel = true;
parallelConfig.numWorkers = 4;  % 0表示自动检测

% 应用到算法
nsga2.setParallelConfig(parallelConfig);
```

或在JSON配置中:

```json
{
  "parallel": {
    "enabled": true,
    "numWorkers": 0,
    "chunkSize": 0,
    "timeout": 300
  }
}
```

## 📈 灵敏度分析

MAPO提供内置的灵敏度分析工具:

```matlab
% 创建分析上下文
context = SensitivityContext(problem);

% 创建分析器
analyzer = BaseSensitivityAnalyzer(context, ...
    'EnableParallel', true, ...
    'EnableCache', true);

% 分析变量
strategy = LinearVariationStrategy();
result = analyzer.analyzeVariable('temperature', strategy);

% 生成报告
analyzer.report();
analyzer.plotResults();
```

## 🎯 典型应用案例

### 1. 精馏塔优化
- 目标: 最小化年度总成本(TAC)，最大化产品纯度
- 变量: 回流比、进料位置、塔板数

### 2. 反应器优化
- 目标: 最大化转化率，最大化选择性，最小化能耗
- 变量: 温度、压力、停留时间

### 3. 换热网络优化
- 目标: 最小化公用工程消耗，最小化投资成本
- 变量: 换热器配置、流股分配

### 4. ORC余热回收优化
- 目标: 最大化系统利润，最大化热效率
- 变量: 工质流量、蒸发压力、冷凝温度

### 5. 轻烯烃分离系统优化
- 目标: 最小化年总能耗(ATE)，最大化年产品收益(APR)
- 变量: 馏出流量、回流比

## 📊 结果输出

优化完成后，结果保存在指定目录:

```
results/
├── [项目名]_[时间戳]/
│   ├── config.json           # 优化配置
│   ├── pareto_front.csv      # Pareto前沿解
│   ├── objectives.csv        # 目标函数值
│   ├── convergence.csv       # 收敛历史
│   ├── optimization.log      # 优化日志
│   ├── pareto_front_2d.fig   # 2D Pareto图
│   └── pareto_front_3d.fig   # 3D Pareto图
```

## 🔌 扩展开发

### 添加新算法（自动出现在 GUI）

1) 在 `framework/algorithm/<your_alg>/` 新建算法类（继承 `AlgorithmBase`），实现 `optimize`：

```matlab
classdef MyAlgorithm < AlgorithmBase
    methods
        function results = optimize(obj, problem, config)
            obj.initialize(problem, config);

            while ~obj.shouldStop()
                % TODO: 生成新解 -> 评估 -> 选择/更新
                % 例如：population.evaluate(problem.evaluator);
                %      obj.incrementEvaluationCount(population.size());
            end

            results = obj.finalizeResults();
        end
    end
end
```

2) 同目录放置 `algorithm_meta.json`（`AlgorithmFactory`/GUI 会自动扫描）：

```json
{
  "type": "MY-ALG",
  "class": "MyAlgorithm",
  "displayName": "My Algorithm",
  "description": "My custom optimization algorithm.",
  "aliases": ["MYALG"],
  "defaultParameters": { "populationSize": 50, "maxGenerations": 20 }
}
```

3) 在 MATLAB 会话里刷新注册（或重启 GUI）：

```matlab
AlgorithmFactory.refreshFromMetadata();
```

4) 用冒烟测试快速验证（不依赖 Aspen/COM）：

```matlab
out = run_smoke_algorithm('MY-ALG', 'Problem', 'zdt1', 'PopulationSize', 20, 'Iterations', 5, 'ThrowOnFailure', true);
```

### 添加新评估器

继承`Evaluator`类:

```matlab
classdef MyEvaluator < Evaluator
    properties
        simulator
    end

    methods
        function obj = MyEvaluator(simulator)
            obj@Evaluator();
            obj.simulator = simulator;
        end

        function result = evaluate(obj, x)
            % 设置变量
            obj.simulator.setVariables(x);

            % 运行仿真
            success = obj.simulator.run();

            % 获取结果
            if success
                objectives = obj.calculateObjectives();
                constraints = obj.calculateConstraints(); % g(x) <= 0
                result = obj.createSuccessResult(objectives, constraints);
            else
                result = obj.createErrorResult('Simulation failed');
            end
        end
    end
end
```

## ⚠️ 已知问题

- Windows系统下Aspen Plus COM接口偶发RPC错误，已实现自动重试机制
- 大规模种群(>500)时非支配排序效率较低，建议使用较小种群配合更多代数

## 📜 版本历史

### v2.1 (当前版本)
- 新增图形用户界面(GUI)
- 支持并行计算
- 新增灵敏度分析模块
- 优化日志系统
- 改进Aspen Plus连接稳定性
- 新增 ANN-NSGA-II（代理辅助多目标优化）
- GUI 算法/参数接入改为 metadata 驱动（`algorithm_meta.json`）
- 新增通用算法冒烟测试脚本（`run_smoke_algorithm` / `run_smoke_all_algorithms`）
- 新增ASPL示例

### v2.0
- 引入统一模板系统
- JSON配置文件支持
- 模块化架构重构
- 多仿真器支持

### v1.0
- 初始版本
- NSGA-II算法实现
- Aspen Plus集成

## 🤝 贡献指南

欢迎贡献代码、报告问题或提出建议!

1. Fork项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'feat: add some amazing feature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启Pull Request

提交信息请遵循[Conventional Commits](https://www.conventionalcommits.org/)规范。

## 📄 许可证

本项目采用MIT许可证 - 详见[LICENSE](LICENSE)文件

## 📮 联系方式

项目维护者: 若羌

Email: mapleccs@outlook.com

项目链接: [https://github.com/mapleccs/MAPO](https://github.com/mapleccs/MAPO)

## 🙏 致谢

- Aspen Technology - Aspen Plus软件
- MathWorks - MATLAB平台
- Deb et al. - NSGA-II算法原始论文
- Kennedy & Eberhart - PSO算法原始论文

## 📚 参考文献

1. Deb, K., et al. (2002). A fast and elitist multiobjective genetic algorithm: NSGA-II. IEEE Transactions on Evolutionary Computation, 6(2), 182-197.
2. Kennedy, J., & Eberhart, R. (1995). Particle swarm optimization. Proceedings of ICNN'95.
3. Yang, L., et al. (2024). An efficient and invertible machine learning-driven multi-objective optimization architecture for light olefins separation system. Chemical Engineering Science, 285, 119553.

---
**注意**: 使用本框架前，请确保您拥有合法的Aspen Plus和MATLAB许可证。
