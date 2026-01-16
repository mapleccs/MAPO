%% run_brayton_optimization.m
% 布雷顿循环多目标优化 - NSGA-II
% Brayton Cycle Multi-objective Optimization using NSGA-II
%
% 优化目标:
%   1. 最大化热效率 (thermal_efficiency)
%   2. 最大化净输出功率 (net_power)
%
% 决策变量:
%   1. P_HP_in - 高压透平入口压力 [17-35 MPa]
%   2. T_LP_in - 低压透平入口温度 [500-600 °C]
%   3. split_ratio - 分流比 [0.2-0.5]
%   4. P_LP_in - 低压透平入口压力 [8-16 MPa]
%   5. P_inter - 中间压力 [8-16 MPa]
%   6. T_comp_in - 压缩机入口温度 [32-46 °C]

%% ========================================
%% 环境准备
%% ========================================

clc; clear; close all;

fprintf('========================================\n');
fprintf('布雷顿循环多目标优化\n');
fprintf('Brayton Cycle Multi-objective Optimization\n');
fprintf('========================================\n\n');

% 添加框架路径
fprintf('[1/8] 添加路径...\n');
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(projectRoot, 'framework')));

% 获取当前脚本所在目录
currentDir = fileparts(mfilename('fullpath'));

% 创建结果目录
resultsDir = fullfile(currentDir, 'results_nsga2');
if ~exist(resultsDir, 'dir')
    mkdir(resultsDir);
end
fprintf('  结果目录: %s\n', resultsDir);

%% ========================================
%% 步骤1: 选择运行模式
%% ========================================

fprintf('\n[2/8] 选择运行模式...\n');

% 检查是否有Aspen Plus模型文件
modelPath = fullfile(currentDir, 'brayton_cycle.bkp');
hasAspenModel = exist(modelPath, 'file');

if hasAspenModel
    fprintf('  检测到Aspen Plus模型: %s\n', modelPath);
    useAspen = true;
else
    fprintf('  未检测到Aspen Plus模型，使用简化模型\n');
    fprintf('  提示: 将Aspen模型命名为 brayton_cycle.bkp 并放在当前目录\n');
    useAspen = false;
end

%% ========================================
%% 步骤2: 配置仿真器（如果使用Aspen）
%% ========================================

simulator = [];

if useAspen
    fprintf('\n[3/8] 配置Aspen Plus仿真器...\n');

    % 创建仿真器配置
    simConfig = SimulatorConfig('Aspen');
    simConfig.set('modelPath', modelPath);
    simConfig.set('timeout', 300);
    simConfig.set('visible', false);
    simConfig.set('autoSave', false);

    % 配置节点映射（根据实际Aspen模型调整）
    simConfig.setNodeMapping('P_HP_in', '\Data\Blocks\HP_TURB\Input\PRES');
    simConfig.setNodeMapping('T_LP_in', '\Data\Blocks\LP_TURB\Input\TEMP');
    simConfig.setNodeMapping('split_ratio', '\Data\Blocks\SPLITTER\Input\SPLIT_FRAC');
    simConfig.setNodeMapping('P_LP_in', '\Data\Blocks\LP_TURB\Input\PRES');
    simConfig.setNodeMapping('P_inter', '\Data\Blocks\MIXER\Input\PRES');
    simConfig.setNodeMapping('T_comp_in', '\Data\Blocks\COMPRESSOR\Input\TEMP');

    % 配置结果映射
    simConfig.setResultMapping('W_net', '\Data\Streams\POWER_NET\Output\WORK');
    simConfig.setResultMapping('Q_in', '\Data\Streams\HEAT_IN\Output\HEAT');
    simConfig.setResultMapping('W_turbine', '\Data\Blocks\HP_TURB\Output\WORK');
    simConfig.setResultMapping('W_compressor', '\Data\Blocks\COMPRESSOR\Output\WORK');
    simConfig.setResultMapping('mass_flow', '\Data\Streams\MAIN_FLOW\Output\MASSFLOW');

    % 创建并连接仿真器
    simulator = AspenPlusSimulator();

    % 设置日志文件
    logFolder = fullfile(currentDir, 'logs');
    if ~exist(logFolder, 'dir')
        mkdir(logFolder);
    end
    logFile = fullfile(logFolder, sprintf('optimization_%s.txt', datestr(now, 'yyyymmdd_HHMMSS')));
    simulator.setLogFile(logFile);

    % 连接仿真器
    simulator.connect(simConfig);
    fprintf('  Aspen Plus连接成功\n');
else
    fprintf('\n[3/8] 使用简化模型（跳过仿真器配置）...\n');
end

%% ========================================
%% 步骤3: 创建评估器
%% ========================================

fprintf('\n[4/8] 创建评估器...\n');

evaluator = BraytonCycleEvaluator(simulator);
evaluator.timeout = 300;

% 设置经济参数（可选）
evaluator.interestRate = 0.12;
evaluator.systemLifetime = 20;
evaluator.maintenanceFactor = 0.06;
evaluator.operatingHours = 7200;
evaluator.electricityPrice = 0.1;

fprintf('  评估器创建完成\n');
fprintf('  评估器类型: BraytonCycleEvaluator\n');
if useAspen
    fprintf('  仿真模式: Aspen Plus\n');
else
    fprintf('  仿真模式: 简化模型\n');
end

%% ========================================
%% 步骤4: 定义优化问题
%% ========================================

fprintf('\n[5/8] 定义优化问题...\n');

problem = OptimizationProblem('BraytonCycleOptimization', ...
    '布雷顿循环多目标优化');

% 添加设计变量
problem.addVariable(Variable('P_HP_in', 'continuous', [17, 35]));      % MPa
problem.addVariable(Variable('T_LP_in', 'continuous', [500, 600]));    % °C
problem.addVariable(Variable('split_ratio', 'continuous', [0.2, 0.5])); % -
problem.addVariable(Variable('P_LP_in', 'continuous', [8, 16]));       % MPa
problem.addVariable(Variable('P_inter', 'continuous', [8, 16]));       % MPa
problem.addVariable(Variable('T_comp_in', 'continuous', [32, 46]));    % °C

% 添加目标函数（最大化转为最小化）
problem.addObjective(Objective('thermal_efficiency', 'minimize', ...
    'Description', '负的热效率'));
problem.addObjective(Objective('net_power', 'minimize', ...
    'Description', '负的净输出功率'));

% 设置问题类型和评估器
problem.problemType = 'multi-objective';
problem.evaluator = evaluator;

fprintf('  变量数: %d\n', problem.getNumberOfVariables());
fprintf('    1. P_HP_in (高压透平入口压力): [17, 35] MPa\n');
fprintf('    2. T_LP_in (低压透平入口温度): [500, 600] °C\n');
fprintf('    3. split_ratio (分流比): [0.2, 0.5]\n');
fprintf('    4. P_LP_in (低压透平入口压力): [8, 16] MPa\n');
fprintf('    5. P_inter (中间压力): [8, 16] MPa\n');
fprintf('    6. T_comp_in (压缩机入口温度): [32, 46] °C\n');
fprintf('  目标数: %d\n', problem.getNumberOfObjectives());
fprintf('    1. 最大化 热效率\n');
fprintf('    2. 最大化 净输出功率\n');
fprintf('  问题类型: %s\n', problem.problemType);

%% ========================================
%% 步骤5: 配置NSGA-II算法
%% ========================================

fprintf('\n[6/8] 配置NSGA-II算法...\n');

% 算法参数配置
algoConfig = struct();
algoConfig.populationSize = 50;             % 种群大小
algoConfig.maxGenerations = 30;             % 最大迭代代数
algoConfig.crossoverRate = 0.9;             % 交叉概率
algoConfig.mutationRate = 1.0;              % 变异率(归一化)
algoConfig.crossoverDistIndex = 20;         % SBX分布指数
algoConfig.mutationDistIndex = 20;          % 多项式变异分布指数

fprintf('  种群大小: %d\n', algoConfig.populationSize);
fprintf('  最大代数: %d\n', algoConfig.maxGenerations);
fprintf('  交叉概率: %.2f\n', algoConfig.crossoverRate);
fprintf('  变异率: %.2f\n', algoConfig.mutationRate);
fprintf('  预计评估次数: %d\n', algoConfig.populationSize * algoConfig.maxGenerations);

% 创建NSGA-II算法实例
nsga2 = NSGAII();

%% ========================================
%% 步骤6: 运行优化
%% ========================================

fprintf('\n[7/8] 开始优化...\n');
fprintf('========================================\n');
if useAspen
    fprintf('注意: 每次Aspen仿真可能需要较长时间，请耐心等待...\n');
else
    fprintf('注意: 使用简化模型，运行速度较快\n');
end
fprintf('========================================\n\n');

tic;
results = nsga2.optimize(problem, algoConfig);
elapsedTime = toc;

fprintf('\n========================================\n');
fprintf('优化完成! 总用时: %.2f 秒 (%.2f 分钟)\n', ...
    elapsedTime, elapsedTime/60);
fprintf('评估次数: %d\n', evaluator.getEvaluationCount());

%% ========================================
%% 步骤7: 提取和显示结果
%% ========================================

fprintf('\n[8/8] 提取和显示结果...\n');

if ~isempty(results.population)
    % 获取Pareto前沿
    paretoFront = results.paretoFront;
    numParetoSolutions = paretoFront.size();
    paretoIndividuals = paretoFront.getAll();

    fprintf('\n========================================\n');
    fprintf('优化结果统计\n');
    fprintf('========================================\n');
    fprintf('Pareto最优解数: %d\n', numParetoSolutions);
    fprintf('总评估次数: %d\n', evaluator.getEvaluationCount());
    fprintf('\n');

    fprintf('%-5s | %-10s | %-10s | %-12s | %-10s | %-10s | %-10s | %-15s | %-15s\n', ...
        '序号', 'P_HP_in', 'T_LP_in', 'split_ratio', 'P_LP_in', 'P_inter', 'T_comp_in', '热效率(%)', '净功率(kW)');
    fprintf('%s\n', repmat('-', 1, 140));

    % 提取Pareto前沿解的信息
    paretoVars = [];
    paretoObjs = [];
    for i = 1:numParetoSolutions
        ind = paretoIndividuals(i);
        vars = ind.getVariables();
        objs = ind.getObjectives();

        % 将最小化的负值转换回最大化的正值
        thermal_efficiency = -objs(1);
        net_power = -objs(2);

        fprintf('%-5d | %-10.2f | %-10.2f | %-12.3f | %-10.2f | %-10.2f | %-10.2f | %-15.2f | %-15.2f\n', ...
            i, vars(1), vars(2), vars(3), vars(4), vars(5), vars(6), thermal_efficiency, net_power);

        paretoVars = [paretoVars; vars];
        paretoObjs = [paretoObjs; thermal_efficiency, net_power];
    end

    %% ========================================
    %% 步骤8: 可视化和保存结果
    %% ========================================

    fprintf('\n========================================\n');
    fprintf('可视化和保存结果\n');
    fprintf('========================================\n');

    % 绘制Pareto前沿
    figure('Name', '布雷顿循环优化 - Pareto前沿', 'Position', [100, 100, 1000, 600]);

    % 绘制Pareto前沿解
    plot(paretoObjs(:, 1), paretoObjs(:, 2), 'or', ...
        'MarkerSize', 10, 'MarkerFaceColor', 'r', 'LineWidth', 1.5);
    hold on;

    % 绘制Pareto前沿连线
    [sortedEff, idx] = sort(paretoObjs(:, 1));
    sortedPower = paretoObjs(idx, 2);
    plot(sortedEff, sortedPower, '-b', 'LineWidth', 1.5);

    xlabel('热效率 (%)', 'FontSize', 12);
    ylabel('净输出功率 (kW)', 'FontSize', 12);
    title('布雷顿循环优化 - Pareto前沿', 'FontSize', 14, 'FontWeight', 'bold');
    legend('Pareto最优解', 'Pareto前沿', 'Location', 'best');
    grid on;
    hold off;

    % 保存图片
    figPath = fullfile(resultsDir, 'pareto_front.png');
    saveas(gcf, figPath);
    fprintf('  图片已保存: %s\n', figPath);

    % 保存数据
    matPath = fullfile(resultsDir, 'optimization_results.mat');
    save(matPath, 'results', 'paretoVars', 'paretoObjs', 'algoConfig', 'elapsedTime');
    fprintf('  优化结果已保存: %s\n', matPath);

    % 保存Pareto前沿数据为CSV
    paretoData = [paretoVars, paretoObjs];
    paretoTable = array2table(paretoData, ...
        'VariableNames', {'P_HP_in', 'T_LP_in', 'split_ratio', 'P_LP_in', 'P_inter', 'T_comp_in', ...
                          'thermal_efficiency', 'net_power'});
    csvPath = fullfile(resultsDir, 'pareto_solutions.csv');
    writetable(paretoTable, csvPath);
    fprintf('  Pareto前沿解已保存: %s\n', csvPath);

else
    fprintf('\n警告: 未找到Pareto最优解\n');
end

%% ========================================
%% 清理资源
%% ========================================

if useAspen && ~isempty(simulator)
    fprintf('\n========================================\n');
    fprintf('清理资源\n');
    fprintf('========================================\n');

    simulator.disconnect();
    fprintf('  Aspen Plus已断开\n');
end

%% ========================================
%% 总结
%% ========================================

fprintf('\n========================================\n');
fprintf('优化任务完成\n');
fprintf('========================================\n');
fprintf('总用时: %.2f 秒 (%.2f 分钟)\n', elapsedTime, elapsedTime/60);
fprintf('评估次数: %d\n', evaluator.getEvaluationCount());
if ~isempty(results.paretoFront)
    fprintf('Pareto解数量: %d\n', results.paretoFront.size());
    fprintf('\n所有结果已保存至: %s\n', resultsDir);
end
fprintf('========================================\n\n');
