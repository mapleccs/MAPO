# MAPO - MATLAB-Aspen Process Optimizer

[![MATLAB](https://img.shields.io/badge/MATLAB-R2020a%2B-orange)](https://www.mathworks.com/products/matlab.html)
[![Aspen Plus](https://img.shields.io/badge/Aspen%20Plus-V11%2B-blue)](https://www.aspentech.com/en/products/engineering/aspen-plus)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-2.0-brightgreen)](CHANGELOG.md)

## 📌 简介

MAPO (MATLAB-Aspen Process Optimizer) 是一个集成了MATLAB优化算法与Aspen Plus过程仿真的化工流程优化框架。该框架提供了模块化、可扩展的架构，支持单目标和多目标优化问题。

**🎉 新版本 2.0 特性**：引入了统一模板系统，只需修改JSON配置文件即可完成优化任务，大大简化了使用流程！

### 主要特性

- 🎯 **多种优化算法**：NSGA-II（多目标）、PSO（粒子群）、遗传算法等
- 🔧 **多仿真器支持**：Aspen Plus、MATLAB函数、Python脚本
- 📦 **模块化设计**：易于扩展新算法、评估器和仿真器
- 📊 **结果可视化**：Pareto前沿、收敛曲线、优化历史
- ⚙️ **灵活配置**：JSON配置文件，参数化管理
- 📝 **详细日志**：完整的优化过程记录
- ✨ **模板系统**：通用运行脚本，最小化代码编写

## 🚀 快速开始

### 系统要求

- MATLAB R2020a 或更高版本
- Aspen Plus V11 或更高版本
- Windows操作系统（支持COM接口）

### 安装

1. 克隆或下载项目：
```bash
git clone https://github.com/yourusername/MAPO.git
cd MAPO
```

2. 在MATLAB中添加路径：
```matlab
addpath(genpath('framework'));
addpath('utils');
```

### 基本使用（推荐方式 - 使用模板系统）

#### 方式一：使用新的模板系统（推荐）✨

1. **复制模板目录**：
```matlab
% 复制 example/_template 目录到您的工作目录
copyfile('example/_template', 'my_optimization', 'f');
cd('my_optimization');
```

2. **修改配置文件**：
编辑 `case_config.json`，设置您的：
- 优化变量及范围
- 目标函数
- Aspen模型路径和节点映射
- 算法参数

3. **运行优化**：
```matlab
% 使用通用运行脚本
results = run_case('case_config.json');
```

#### 方式二：使用预置示例

##### 示例1：ORC系统优化

```matlab
% 方法A：使用新模板系统
cd('example/R601');
results = run_case('case_config.json');

% 方法B：使用原始脚本（仍然支持）
run_ocr_nsga2_optimization;
```

##### 示例2：ADN生产工艺优化

```matlab
% 方法A：使用新模板系统
cd('example/ADN');
results = run_case('case_config.json');

% 方法B：使用原始脚本（仍然支持）
run_adn_nsga2_optimization;
```

### 创建自定义优化任务（3步完成）

1. **复制模板**：
```bash
cp -r example/_template my_project
```

2. **修改配置**（`case_config.json`）：
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

3. **运行优化**：
```matlab
results = run_case('case_config.json');
```

就这么简单！无需编写复杂的脚本。

## 📁 项目结构

```
MAPO/
├── framework/                 # 核心框架
│   ├── algorithm/            # 优化算法
│   │   ├── nsga2/           # NSGA-II算法
│   │   ├── pso/             # 粒子群算法
│   │   ├── AlgorithmBase.m  # 算法基类
│   │   └── AlgorithmFactory.m
│   ├── simulator/            # 仿真器适配器
│   │   ├── aspen/           # Aspen Plus适配器
│   │   ├── matlab/          # MATLAB函数适配器
│   │   └── python/          # Python脚本适配器
│   ├── problem/              # 问题定义
│   │   ├── evaluator/       # 评估器
│   │   │   ├── EvaluatorFactory.m    # 🆕 评估器工厂
│   │   │   ├── MyCaseEvaluator.m     # 🆕 评估器模板
│   │   │   ├── ORCEvaluator.m        # ORC评估器
│   │   │   └── ADNProductionEvaluator.m
│   │   ├── Variable.m       # 变量定义
│   │   ├── Objective.m      # 目标函数
│   │   └── OptimizationProblem.m
│   ├── module/               # 扩展模块
│   │   ├── builtin/         # 内置模块
│   │   └── custom/          # 自定义模块
│   └── core/                 # 核心组件
│       ├── Config.m          # 配置管理
│       └── Logger.m          # 日志系统
├── example/                  # 示例案例
│   ├── _template/            # 🆕 通用模板（推荐起点）
│   │   ├── run_case.m       # 统一运行脚本
│   │   └── case_config.json # 配置模板
│   ├── ADN/                 # ADN生产优化
│   │   ├── case_config.json # 🆕 ADN配置
│   │   └── run_adn_nsga2_optimization.m
│   └── R601/                # ORC系统优化
│       ├── case_config.json # 🆕 ORC配置
│       └── run_ocr_nsga2_optimization.m
├── config/                   # 全局配置文件
│   ├── algorithm_config.json
│   ├── simulator_config.json
│   └── problem_config.json
├── utils/                    # 工具函数
│   └── loadConfig.m
├── docs/                     # 文档
│   ├── user_guide.md        # 用户指南
│   └── api_reference.md     # API参考
└── README.md                 # 本文档
```

## 🔧 配置说明

### 算法配置 (algorithm_config.json)

```json
{
  "algorithm": {
    "type": "NSGA-II",
    "parameters": {
      "populationSize": 50,
      "maxGenerations": 20,
      "crossoverRate": 0.9,
      "mutationRate": 1.0
    }
  }
}
```

### 仿真器配置 (simulator_config.json)

```json
{
  "aspen": {
    "settings": {
      "modelPath": "path/to/model.bkp",
      "timeout": 300,
      "visible": false
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

### 问题配置 (problem_config.json)

```json
{
  "problem": {
    "name": "ORC_Optimization",
    "variables": [
      {
        "name": "FLOW_EV1",
        "type": "continuous",
        "lowerBound": 10,
        "upperBound": 100
      }
    ],
    "objectives": [
      {
        "name": "PROFIT",
        "type": "maximize"
      }
    ]
  }
}
```

## 📚 使用指南

### 创建新的优化问题

1. **定义评估器**：
```matlab
classdef MyEvaluator < handle
    methods
        function result = evaluate(obj, x)
            % 设置Aspen变量
            simulator.setVariables(x);
            % 运行仿真
            simulator.run();
            % 计算目标函数
            result.objectives = calculateObjectives();
        end
    end
end
```

2. **配置优化问题**：
```matlab
% 创建问题实例
problem = OptimizationProblem('MyProblem', '问题描述');

% 添加变量
problem.addVariable(Variable('VAR1', 'continuous', [0, 100]));

% 添加目标
problem.addObjective(Objective('OBJ1', 'minimize'));

% 设置评估器
problem.evaluator = MyEvaluator(simulator);
```

3. **运行优化**：
```matlab
% 配置算法
config.populationSize = 50;
config.maxGenerations = 20;

% 创建算法实例
nsga2 = NSGAII();

% 运行优化
results = nsga2.optimize(problem, config);
```

### 扩展新算法

继承`AlgorithmBase`类并实现`optimize`方法：

```matlab
classdef MyAlgorithm < AlgorithmBase
    methods
        function results = optimize(obj, problem, config)
            % 初始化
            obj.initialize(problem, config);

            % 优化主循环
            while ~obj.shouldStop()
                % 算法逻辑
                population = generateNewSolution();
                evaluate(population);
                updateBest();
            end

            % 返回结果
            results = obj.finalizeResults();
        end
    end
end
```

## 🎯 典型应用案例

### 1. 精馏塔优化
- 目标：最小化年度总成本(TAC)，最大化产品纯度
- 变量：回流比、进料位置、塔板数

### 2. 反应器优化
- 目标：最大化转化率，最大化选择性，最小化能耗
- 变量：温度、压力、停留时间

### 3. 换热网络优化
- 目标：最小化公用工程消耗，最小化投资成本
- 变量：换热器配置、流股分配

### 4. ORC余热回收优化
- 目标：最大化系统利润，最大化热效率
- 变量：工质流量、压力、温度

## 📊 结果分析

优化完成后，结果保存在`results`目录：

- `pareto_front.png` - Pareto前沿可视化
- `pareto_solutions.csv` - Pareto最优解数据
- `all_solutions.csv` - 所有评估解数据
- `optimization_results.mat` - MATLAB数据文件

## 🤝 贡献指南

欢迎贡献代码、报告问题或提出建议！

1. Fork项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启Pull Request

## 📄 许可证

本项目采用MIT许可证 - 详见[LICENSE](LICENSE)文件

## 📮 联系方式

项目维护者：若羌

Email: mapleccs@outlook.com

项目链接：[https://github.com/mapleccs/MAPO](https://github.com/mapleccs/MAPO)

## 🙏 致谢

- Aspen Technology - Aspen Plus软件
- MathWorks - MATLAB平台
- Deb et al. - NSGA-II算法原始论文

---
**注意**：使用本框架前，请确保您拥有合法的Aspen Plus和MATLAB许可证。