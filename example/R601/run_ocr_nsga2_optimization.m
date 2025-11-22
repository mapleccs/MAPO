%% run_orc_nsga2_optimization.m
% ORC余热回收多目标优化 - NSGA-II
% ORC Waste Heat Recovery Multi-objective Optimization using NSGA-II
%
% 优化目标:
%   1. 最大化 ORC系统利润 (PROFIT)
%   2. 最大化 ORC热力学效率 (EFF)
%
% 设计变量:
%   1. FLOW_EV1 - 进入EV1的工质流量 (kmol/hr 或 kg/hr)
%   2. FLOW_EV2 - 进入EV2的工质流量 (kmol/hr 或 kg/hr)
%   3. P_TUR_OUT - 透平出口压力 (bar)
%   4. P_PUM_OUT - 泵出口压力 (bar)
%   5. T_CON_OUT - 冷凝器出口温度 (C)

%% ========================================
%% 环境准备
%% ========================================

clc; clear; close all;

fprintf('========================================\n');
fprintf('ORC余热回收多目标优化\n');
fprintf('Aspen Plus + NSGA-II\n');
fprintf('========================================\n\n');

% 添加框架路径
fprintf('[1/10] 添加路径...\n');
addpath(genpath('framework'));

% 获取当前脚本所在目录
currentDir = fileparts(mfilename('fullpath'));

% 创建结果目录
resultsDir = fullfile(currentDir, 'results_orc_nsga2');
if ~exist(resultsDir, 'dir')
    mkdir(resultsDir);
end
fprintf('  结果目录: %s\n', resultsDir);

%% ========================================
%% 步骤1: 可行域扫描（可选）
%% ========================================

fprintf('\n[2/10] 可行域扫描...\n');

% 询问用户是否执行可行域扫描
performScan = input('是否执行可行域扫描？(y/n，默认n): ', 's');
if isempty(performScan)
    performScan = 'n';
end

useFeasibleRanges = false;
feasibleRanges = struct();

if strcmpi(performScan, 'y')
    fprintf('\n执行可行域扫描...\n');

    % 检查是否有已保存的扫描结果
    sensitivityWorkspace = fullfile(currentDir, 'orc', 'results', 'sensitivity', 'sensitivity_workspace.mat');

    if exist(sensitivityWorkspace, 'file')
        loadExisting = input('发现已有扫描结果，是否加载？(y/n，默认y): ', 's');
        if isempty(loadExisting)
            loadExisting = 'y';
        end

        if strcmpi(loadExisting, 'y')
            fprintf('加载已有扫描结果...\n');
            load(sensitivityWorkspace, 'feasibleRanges', 'scanResults');
            fprintf('扫描结果已加载\n');
            useFeasibleRanges = true;
        else
            fprintf('将执行新的扫描...\n');
            % 这里可以调用扫描脚本
            fprintf('请先运行 orc/run_all_sensitivity.m 执行扫描，然后重新运行本脚本\n');
            error('请先执行可行域扫描');
        end
    else
        fprintf('未找到已有扫描结果\n');
        fprintf('请先运行 orc/run_all_sensitivity.m 执行扫描，然后重新运行本脚本\n');
        error('请先执行可行域扫描');
    end
else
    fprintf('跳过可行域扫描，使用默认变量范围\n');
end

%% ========================================
%% 步骤2: 配置Aspen Plus仿真器
%% ========================================

fprintf('\n[3/10] 配置Aspen Plus仿真器...\n');

% Aspen模型路径
modelPath = fullfile(currentDir, 'r601a.bkp');

% 检查文件是否存在
if ~exist(modelPath, 'file')
    error('Aspen模型文件不存在: %s\n请修改modelPath为您的实际文件名', modelPath);
end

% 创建仿真器配置
simConfig = SimulatorConfig('Aspen');
simConfig.set('modelPath', modelPath);
simConfig.set('timeout', 300);           % 仿真超时时间(秒)
simConfig.set('visible', true);          % Aspen可见（调试时设为true）
simConfig.set('autoSave', false);        % 不自动保存

% ★ 配置输入变量的节点映射 ★
% 使用4个控制变量（S7和S8是输入流）
simConfig.setNodeMapping('FLOW_S7',     '\Data\Streams\S7\Input\TOTFLOW\MIXED');    % S7流量（进EV1）
simConfig.setNodeMapping('FLOW_S8',     '\Data\Streams\S8\Input\TOTFLOW\MIXED');    % S8流量（进EV2）
simConfig.setNodeMapping('P_EVAP',      '\Data\Blocks\PUM\Input\PRES');             % 蒸发压力(泵出口压力)
simConfig.setNodeMapping('P_COND',      '\Data\Blocks\TUR\Input\PRES');             % 冷凝压力(透平出口压力)


% ★ 配置计算目标所需的中间结果映射 ★
simConfig.setResultMapping('W_TUR', '\Data\Blocks\TUR\Output\WNET');      % 透平净功
simConfig.setResultMapping('W_PUM', '\Data\Blocks\PUM\Output\WNET');      % 泵净功
simConfig.setResultMapping('Q_CON', '\Data\Blocks\CON\Output\QCALC');     % CON热负荷

% ★ 配置焓值映射（用于计算热力学效率）★
simConfig.setResultMapping('H_1', '\Data\Streams\IN-T\Output\HMX\MIXED');   % 透平入口焓值
simConfig.setResultMapping('H_2', '\Data\Streams\OUT-T\Output\HMX\MIXED');  % 透平出口焓值
simConfig.setResultMapping('H_3', '\Data\Streams\IN-P\Output\HMX\MIXED');   % 泵入口焓值
simConfig.setResultMapping('H_4', '\Data\Streams\S13\Output\HMX\MIXED');    % 泵出口焓值

fprintf('  模型路径: %s\n', modelPath);
fprintf('  超时时间: %d 秒\n', 300);
fprintf('  Aspen可见性: %s\n', simConfig.get('visible'));

% 创建并连接仿真器
simulator = AspenPlusSimulator();

% 设置日志文件
logFolder = fullfile(currentDir, 'logs');
if ~exist(logFolder, 'dir')
    mkdir(logFolder);
end
logFile = fullfile(logFolder, sprintf('optimization_%s.txt', datestr(now, 'yyyymmdd_HHMMSS')));
simulator.setLogFile(logFile);
fprintf('  日志文件: %s\n', logFile);

% 连接仿真器
simulator.connect(simConfig);
fprintf('  Aspen Plus连接成功\n');

%% ========================================
%% 步骤3: 创建评估器
%% ========================================

fprintf('\n[4/10] 创建评估器...\n');

evaluator = ORCEvaluator(simulator);
evaluator.timeout = 300;  % 超时时间

% 设置经济参数（可根据实际情况调整）
evaluator.electricityPrice = 0.1;      % 电价 ($/kWh)
evaluator.operatingHours = 8000;       % 年运行小时数 (hr/year)
evaluator.coolingWaterCost = 0.354;    % 冷却水成本 ($/GJ)

fprintf('  评估器创建完成\n');
fprintf('  评估器类型: ORCEvaluator\n');
fprintf('  经济参数:\n');
fprintf('    电价: %.3f $/kWh\n', evaluator.electricityPrice);
fprintf('    年运行时间: %d hr/year\n', evaluator.operatingHours);
fprintf('    冷却水成本: %.3f $/GJ\n', evaluator.coolingWaterCost);

%% ========================================
%% 步骤4: 定义优化问题和变量范围
%% ========================================

fprintf('\n[5/10] 定义优化问题...\n');

problem = OptimizationProblem('ORC_Optimization', 'ORC余热回收多目标优化');

% 定义默认变量范围
defaultRanges = struct();
defaultRanges.FLOW_S7 = [40, 60];
defaultRanges.FLOW_S8 = [40, 60];
defaultRanges.P_EVAP = [2.0, 5.0];
defaultRanges.P_COND = [0.5, 1.5];

% 如果使用可行域，则显示并确认
if useFeasibleRanges
    fprintf('\n可行域扫描结果:\n');
    fprintf('========================================\n');
    fprintf('%-15s | %-20s | %-20s\n', '变量', '默认范围', '可行域');
    fprintf('%s\n', repmat('-', 1, 60));

    varNames = fieldnames(defaultRanges);
    for i = 1:length(varNames)
        varName = varNames{i};
        defaultRange = defaultRanges.(varName);

        if isfield(feasibleRanges, varName) && ~isnan(feasibleRanges.(varName)(1))
            feasRange = feasibleRanges.(varName);
            fprintf('%-15s | [%.2f, %.2f] | [%.4f, %.4f]\n', ...
                varName, defaultRange(1), defaultRange(2), feasRange(1), feasRange(2));
        else
            fprintf('%-15s | [%.2f, %.2f] | 未找到可行域\n', ...
                varName, defaultRange(1), defaultRange(2));
        end
    end
    fprintf('========================================\n\n');

    % 询问用户是否使用可行域范围
    useConfirm = input('是否使用扫描得到的可行域作为优化范围？(y/n，默认n): ', 's');
    if isempty(useConfirm)
        useConfirm = 'n';
    end

    if strcmpi(useConfirm, 'y')
        fprintf('使用可行域范围\n');
        % 更新范围，添加10%%安全余量
        for i = 1:length(varNames)
            varName = varNames{i};
            if isfield(feasibleRanges, varName) && ~isnan(feasibleRanges.(varName)(1))
                feasRange = feasibleRanges.(varName);
                range = feasRange(2) - feasRange(1);
                margin = range * 0.1;

                % 确保在默认范围内
                newLower = max(defaultRanges.(varName)(1), feasRange(1) + margin);
                newUpper = min(defaultRanges.(varName)(2), feasRange(2) - margin);

                if newLower < newUpper
                    defaultRanges.(varName) = [newLower, newUpper];
                    fprintf('  %s: [%.4f, %.4f]\n', varName, newLower, newUpper);
                end
            end
        end
    else
        fprintf('使用默认范围\n');
    end
end

% ★ 添加ORC设计变量 ★
% S7和S8是独立输入流，可分别控制
problem.addVariable(Variable('FLOW_S7', 'continuous', defaultRanges.FLOW_S7));    % S7流量进EV1 (kmol/hr)
problem.addVariable(Variable('FLOW_S8', 'continuous', defaultRanges.FLOW_S8));    % S8流量进EV2 (kmol/hr)
problem.addVariable(Variable('P_EVAP', 'continuous', defaultRanges.P_EVAP));      % 蒸发压力 (bar)
problem.addVariable(Variable('P_COND', 'continuous', defaultRanges.P_COND));      % 冷凝压力 (bar)


% ★ 添加2个目标函数 ★（最大化转为最小化）
problem.addObjective(Objective('PROFIT', 'minimize', 'Description', '负的ORC系统利润'));
problem.addObjective(Objective('EFF', 'minimize', 'Description', '负的ORC热力学效率'));

% 设置问题类型和评估器
problem.problemType = 'multi-objective';
problem.evaluator = evaluator;

fprintf('  变量数: %d\n', problem.getNumberOfVariables());
fprintf('    1. FLOW_S7 (S7流量进EV1): [%.2f, %.2f] kmol/hr\n', defaultRanges.FLOW_S7(1), defaultRanges.FLOW_S7(2));
fprintf('    2. FLOW_S8 (S8流量进EV2): [%.2f, %.2f] kmol/hr\n', defaultRanges.FLOW_S8(1), defaultRanges.FLOW_S8(2));
fprintf('    3. P_EVAP (蒸发压力): [%.2f, %.2f] bar\n', defaultRanges.P_EVAP(1), defaultRanges.P_EVAP(2));
fprintf('    4. P_COND (冷凝压力): [%.2f, %.2f] bar\n', defaultRanges.P_COND(1), defaultRanges.P_COND(2));

fprintf('  目标数: %d\n', problem.getNumberOfObjectives());
fprintf('    1. 最大化 ORC系统利润 ($/year)\n');
fprintf('    2. 最大化 ORC热力学效率 (%%)\n');
fprintf('  问题类型: %s\n', problem.problemType);

%% ========================================
%% 步骤5: 配置NSGA-II算法
%% ========================================

fprintf('\n[6/10] 配置NSGA-II算法...\n');

% 算法参数配置
algoConfig = struct();
algoConfig.populationSize = 20;             % 种群大小（建议10-50）
algoConfig.maxGenerations = 10;             % 最大迭代代数（建议5-30）
algoConfig.crossoverRate = 0.9;             % 交叉概率
algoConfig.mutationRate = 1.0;              % 变异率(归一化)
algoConfig.crossoverDistIndex = 20;         % SBX分布指数
algoConfig.mutationDistIndex = 20;          % 多项式变异分布指数

fprintf('  种群大小: %d\n', algoConfig.populationSize);
fprintf('  最大代数: %d\n', algoConfig.maxGenerations);
fprintf('  交叉概率: %.2f\n', algoConfig.crossoverRate);
fprintf('  变异率: %.2f\n', algoConfig.mutationRate);
fprintf('  交叉分布指数: %d\n', algoConfig.crossoverDistIndex);
fprintf('  变异分布指数: %d\n', algoConfig.mutationDistIndex);

% 创建NSGA-II算法实例
nsga2 = NSGAII();

%% ========================================
%% 步骤6: 运行优化
%% ========================================

fprintf('\n[7/10] 开始优化...\n');
fprintf('========================================\n');
fprintf('注意: 每次仿真可能需要较长时间，请耐心等待...\n');
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

fprintf('\n[8/10] 提取和显示结果...\n');

% 提取所有解和Pareto前沿
if ~isempty(results.population)
    % 获取最终种群
    population = results.population;
    finalPopIndividuals = population.getAll();
    finalPopSize = length(finalPopIndividuals);

    % 获取所有评估过的解（包括历史）
    if isfield(results, 'allEvaluatedIndividuals')
        allIndividuals = results.allEvaluatedIndividuals;
        totalSolutions = length(allIndividuals);
        fprintf('\n========================================\n');
        fprintf('优化结果统计（完整历史记录）\n');
        fprintf('========================================\n');
        fprintf('总评估解数: %d\n', totalSolutions);
        fprintf('最终种群大小: %d\n', finalPopSize);
    else
        % 兼容旧版本（没有allEvaluatedIndividuals字段）
        allIndividuals = finalPopIndividuals;
        totalSolutions = finalPopSize;
        fprintf('\n========================================\n');
        fprintf('优化结果统计（仅最终种群）\n');
        fprintf('========================================\n');
        fprintf('最终种群大小: %d\n', totalSolutions);
    end

    % 获取Pareto前沿
    paretoFront = results.paretoFront;
    numParetoSolutions = paretoFront.size();
    paretoIndividuals = paretoFront.getAll();

    fprintf('Pareto最优解数: %d\n', numParetoSolutions);
    fprintf('总评估次数: %d\n', evaluator.getEvaluationCount());
    fprintf('非Pareto解数: %d\n\n', totalSolutions - numParetoSolutions);

    fprintf('%-5s | %-10s | %-10s | %-10s | %-10s | %-18s | %-15s\n', ...
        '序号', 'FLOW_S7', 'FLOW_S8', 'P_EVAP', 'P_COND', 'ORC利润($/yr)', 'ORC效率(%)');
    fprintf('%s\n', repmat('-', 1, 125));

    % 提取Pareto前沿解的信息
    paretoVars = [];
    paretoObjs = [];
    for i = 1:numParetoSolutions
        ind = paretoIndividuals(i);
        vars = ind.getVariables();
        objs = ind.getObjectives();

        % 将最小化的负值转换回最大化的正值
        PROFIT = -objs(1);
        EFF    = -objs(2);

        fprintf('%-5d | %-10.4f | %-10.4f | %-10.4f | %-10.2f | %-18.2f | %-15.4f\n', ...
            i, vars(1), vars(2), vars(3), vars(4), PROFIT, EFF);

        paretoVars = [paretoVars; vars];
        paretoObjs = [paretoObjs; PROFIT, EFF];
    end

    % 提取所有解的目标值（用于绘图）
    allObjs = [];
    validIndices = [];  % 记录有效解的索引
    for i = 1:totalSolutions
        ind = allIndividuals(i);
        objs = ind.getObjectives();
        % 转换为最大化目标
        PROFIT = -objs(1);
        EFF    = -objs(2);

        % 过滤掉失败的解（惩罚值会变成负的大数）
        % 失败的解：objectives = [1e8, 1e8]，取负后变成[-1e8, -1e8]
        if PROFIT > -1e7 && EFF > -1e7  % 只保留有效解
            allObjs = [allObjs; PROFIT, EFF];
            validIndices = [validIndices; i];
        end
    end

    fprintf('  有效解数量: %d / %d\n', length(validIndices), totalSolutions);
    fprintf('  失败解数量: %d\n', totalSolutions - length(validIndices));

    %% ========================================
    %% 步骤8: 可视化和保存结果
    %% ========================================

    fprintf('\n[9/10] 可视化和保存结果...\n');
    fprintf('========================================\n');

    % 绘制所有解和Pareto前沿
    if isfield(results, 'allEvaluatedIndividuals')
        figTitle = 'ORC优化 - 所有评估解与Pareto前沿';
    else
        figTitle = 'ORC优化 - 最终种群与Pareto前沿';
    end
    figure('Name', figTitle, 'Position', [100, 100, 1000, 600]);

    % 找出非Pareto前沿的解
    % 创建一个逻辑数组标记哪些是Pareto解
    numValidSolutions = size(allObjs, 1);
    isParetoSolution = false(numValidSolutions, 1);
    for i = 1:numValidSolutions
        for j = 1:numParetoSolutions
            % 比较目标值（使用容差判断相等）
            if all(abs(allObjs(i, :) - paretoObjs(j, :)) < 1e-6)
                isParetoSolution(i) = true;
                break;
            end
        end
    end

    % 分离Pareto和非Pareto解
    nonParetoObjs = allObjs(~isParetoSolution, :);

    % 绘制非Pareto前沿解（黑色点）
    if ~isempty(nonParetoObjs)
        plot(nonParetoObjs(:, 1), nonParetoObjs(:, 2), 'ok', ...
            'MarkerSize', 8, 'MarkerFaceColor', 'k');
        hold on;
    end

    % 绘制Pareto前沿解（红色点）
    plot(paretoObjs(:, 1), paretoObjs(:, 2), 'or', ...
        'MarkerSize', 10, 'MarkerFaceColor', 'r', 'LineWidth', 1.5);

    % 绘制Pareto前沿连线
    [sortedProfit, idx] = sort(paretoObjs(:, 1));
    sortedEff = paretoObjs(idx, 2);
    plot(sortedProfit, sortedEff, '-b', 'LineWidth', 1.5);

    xlabel('ORC利润 ($/year)', 'FontSize', 12);
    ylabel('ORC热力学效率 (%)', 'FontSize', 12);
    title(figTitle, 'FontSize', 14, 'FontWeight', 'bold');

    % 根据是否有非Pareto解来设置图例
    if isfield(results, 'allEvaluatedIndividuals')
        % 显示所有评估解（过滤掉失败的）
        if ~isempty(nonParetoObjs)
            legendText = sprintf('非Pareto解（%d个有效解）', numValidSolutions - numParetoSolutions);
            legend(legendText, 'Pareto前沿解', 'Pareto前沿连线', 'Location', 'best');
        else
            legend('Pareto前沿解', 'Pareto前沿连线', 'Location', 'best');
        end
    else
        % 仅显示最终种群
        if ~isempty(nonParetoObjs)
            legend('非Pareto解（最终种群）', 'Pareto前沿解', 'Pareto前沿连线', 'Location', 'best');
        else
            legend('Pareto前沿解', 'Pareto前沿连线', 'Location', 'best');
        end
    end

    grid on;
    hold off;

    % 保存图片
    figPath = fullfile(resultsDir, 'pareto_front.png');
    saveas(gcf, figPath);
    fprintf('  图片已保存: %s\n', figPath);

    % 保存数据
    matPath = fullfile(resultsDir, 'optimization_results.mat');
    save(matPath, 'results', 'paretoVars', 'paretoObjs', 'allObjs', 'algoConfig', 'elapsedTime');
    fprintf('  优化结果已保存: %s\n', matPath);

    % 保存Pareto前沿数据为CSV
    paretoData = [paretoVars, paretoObjs];
    paretoTable = array2table(paretoData, ...
        'VariableNames', {'FLOW_S7', 'FLOW_S8', 'P_EVAP', 'P_COND', 'PROFIT', 'EFF'});
    csvPath = fullfile(resultsDir, 'pareto_solutions.csv');
    writetable(paretoTable, csvPath);
    fprintf('  Pareto前沿解已保存: %s\n', csvPath);

    % 保存所有解的数据为CSV
    allData = [];
    for i = 1:totalSolutions
        ind = allIndividuals(i);
        vars = ind.getVariables();
        objs = ind.getObjectives();
        allData = [allData; vars, -objs(1), -objs(2)];
    end
    allSolutionsTable = array2table(allData, ...
        'VariableNames', {'FLOW_S7', 'FLOW_S8', 'P_EVAP', 'P_COND', 'PROFIT', 'EFF'});
    allCsvPath = fullfile(resultsDir, 'all_solutions.csv');
    writetable(allSolutionsTable, allCsvPath);
    if isfield(results, 'allEvaluatedIndividuals')
        fprintf('  所有评估解已保存（%d个）: %s\n', totalSolutions, allCsvPath);
    else
        fprintf('  最终种群解已保存（%d个）: %s\n', totalSolutions, allCsvPath);
    end

else
    fprintf('\n警告: 未找到Pareto最优解\n');
end

%% ========================================
%% 步骤9: 清理资源
%% ========================================

fprintf('\n[10/10] 清理资源...\n');
fprintf('========================================\n');

% 使用 try/finally 确保一定断开连接
try
    simulator.disconnect();
    fprintf('  Aspen Plus已断开\n');
catch ME
    warning('断开Aspen Plus时出错: %s', ME.message);
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
