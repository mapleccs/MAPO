%% run_aspl_nsga2_optimization.m
% 阿司匹林生产工艺多目标优化 - NSGA-II
% ASPL Production Process Multi-objective Optimization using NSGA-II
%
% 优化目标:
%   1. 最大化水杨酸(C7H6O3)质量分率
%   2. 最大化水杨酸(C7H6O3)质量流量（产量）
%
% 设计变量:
%   1. R101_FEED_TEMP - 反应釜进料温度 [80, 150] ℃
%   2. R101_FEED_PRES - 反应釜进料压力 [0.5, 3.0] MPa

%% ========================================
%% 环境准备
%% ========================================

clc; clear; close all;

fprintf('========================================\n');
fprintf('阿司匹林生产工艺多目标优化\n');
fprintf('Aspen Plus + NSGA-II\n');
fprintf('========================================\n\n');

% 添加框架路径
fprintf('[1/8] 添加路径...\n');
addpath(genpath('framework'));

% 获取当前脚本所在目录
currentDir = fileparts(mfilename('fullpath'));

% 创建结果目录
resultsDir = fullfile(currentDir, 'results_nsga2');
if ~exist(resultsDir, 'dir')
    mkdir(resultsDir);
end
fprintf('  结果目录: %s\n', resultsDir);

%% ========================================
%% 步骤1: 配置Aspen Plus仿真器
%% ========================================

fprintf('\n[2/8] 配置Aspen Plus仿真器...\n');

% Aspen模型路径
modelPath = fullfile(currentDir, '阿司匹林.bkp');

% 检查文件是否存在
if ~exist(modelPath, 'file')
    error('Aspen模型文件不存在: %s', modelPath);
end

% 创建仿真器配置
simConfig = SimulatorConfig('Aspen');
simConfig.set('modelPath', modelPath);
simConfig.set('timeout', 300);           % 仿真超时时间(秒)
simConfig.set('visible', true);          % Aspen可见（调试时设为true）
simConfig.set('autoSave', false);        % 不自动保存

% 配置节点映射
simConfig.setNodeMapping('R101_FEED_TEMP', '\Data\Blocks\R101\Input\TEMP');
simConfig.setNodeMapping('R101_FEED_PRES', '\Data\Blocks\R101\Input\PRES');

% 配置结果映射（水杨酸 C7H6O3）
% 注意: 需要根据实际Aspen模型中的流股名称和组分名称调整
simConfig.setResultMapping('SA_FRAC', '\Data\Streams\0106\Output\MASSFRAC\MIXED\C7H6O3');
simConfig.setResultMapping('SA_FLOW', '\Data\Streams\0106\Output\MASSFLOW\MIXED\C7H6O3');

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
%% 步骤2: 创建评估器
%% ========================================

fprintf('\n[3/8] 创建评估器...\n');

% 使用阿司匹林生产专用评估器
evaluator = ASPLProductionEvaluator(simulator);
evaluator.timeout = 300;  % 超时时间

fprintf('  评估器创建完成\n');
fprintf('  评估器类型: ASPLProductionEvaluator\n');

%% ========================================
%% 步骤3: 定义优化问题
%% ========================================

fprintf('\n[4/8] 定义优化问题...\n');

problem = OptimizationProblem('ASPLProductionOptimization', ...
    '阿司匹林生产工艺多目标优化');

% 添加设计变量
problem.addVariable(Variable('R101_FEED_TEMP', 'continuous', [80, 150]));    % 进料温度 (℃)
problem.addVariable(Variable('R101_FEED_PRES', 'continuous', [0.5, 3.0]));   % 进料压力 (MPa)

% 添加目标函数（最大化转为最小化）
problem.addObjective(Objective('SA_FRAC', 'minimize', 'Description', '负的水杨酸质量分率'));
problem.addObjective(Objective('SA_FLOW', 'minimize', 'Description', '负的水杨酸质量流量'));

% 设置问题类型和评估器
problem.problemType = 'multi-objective';  % 多目标优化
problem.evaluator = evaluator;

fprintf('  变量数: %d\n', problem.getNumberOfVariables());
fprintf('    1. R101_FEED_TEMP (进料温度): [80, 150] ℃\n');
fprintf('    2. R101_FEED_PRES (进料压力): [0.5, 3.0] MPa\n');
fprintf('  目标数: %d\n', problem.getNumberOfObjectives());
fprintf('    1. 最大化 水杨酸质量分率\n');
fprintf('    2. 最大化 水杨酸质量流量（产量）\n');
fprintf('  问题类型: %s\n', problem.problemType);

%% ========================================
%% 步骤4: 配置NSGA-II算法
%% ========================================

fprintf('\n[5/8] 配置NSGA-II算法...\n');

% 算法参数配置
algoConfig = struct();
algoConfig.populationSize = 10;             % 种群大小
algoConfig.maxGenerations = 5;              % 最大迭代代数
algoConfig.crossoverRate = 0.9;             % 交叉概率
algoConfig.mutationRate = 1.0;              % 变异率(归一化)
algoConfig.crossoverDistIndex = 20;         % SBX分布指数
algoConfig.mutationDistIndex = 20;          % 多项式变异分布指数

fprintf('  种群大小: %d\n', algoConfig.populationSize);
fprintf('  最大代数: %d\n', algoConfig.maxGenerations);
fprintf('  交叉概率: %.2f\n', algoConfig.crossoverRate);
fprintf('  变异率: %.2f\n', algoConfig.mutationRate);

% 创建NSGA-II算法实例
nsga2 = NSGAII();

%% ========================================
%% 步骤5: 运行优化
%% ========================================

fprintf('\n[6/8] 开始优化...\n');
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
%% 步骤6: 提取和显示结果
%% ========================================

fprintf('\n[7/8] 提取和显示结果...\n');

% 提取所有解和Pareto前沿（对于单目标问题，就是最优解）
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

    % 获取最优解（单目标）或Pareto前沿（多目标）
    if strcmp(problem.problemType, 'single-objective')
        % 单目标优化：找到最优解
        bestInd = finalPopIndividuals(1);
        bestObj = inf;
        for i = 1:finalPopSize
            ind = finalPopIndividuals(i);
            objs = ind.getObjectives();
            if objs(1) < bestObj
                bestObj = objs(1);
                bestInd = ind;
            end
        end

        bestVars = bestInd.getVariables();
        bestObjVal = -bestInd.getObjectives(1);  % 转换回最大化

        fprintf('最优解:\n');
        fprintf('  进料温度: %.2f ℃\n', bestVars(1));
        fprintf('  进料压力: %.2f MPa\n', bestVars(2));
        fprintf('  水杨酸质量分率: %.6f\n', bestObjVal);

        % 保存最优解
        bestResult = struct('temperature', bestVars(1), 'pressure', bestVars(2), 'fraction', bestObjVal);

    else
        % 多目标优化：获取Pareto前沿
        paretoFront = results.paretoFront;
        numParetoSolutions = paretoFront.size();
        paretoIndividuals = paretoFront.getAll();

        fprintf('Pareto最优解数: %d\n', numParetoSolutions);
        fprintf('总评估次数: %d\n', evaluator.getEvaluationCount());
        fprintf('非Pareto解数: %d\n\n', totalSolutions - numParetoSolutions);

        fprintf('%-5s | %-15s | %-15s | %-20s | %-20s\n', ...
            '序号', 'TEMP(℃)', 'PRES(MPa)', '水杨酸分率', '水杨酸产量(kg/hr)');
        fprintf('%s\n', repmat('-', 1, 90));

        % 提取Pareto前沿解的信息
        paretoVars = [];
        paretoObjs = [];
        for i = 1:numParetoSolutions
            ind = paretoIndividuals(i);
            vars = ind.getVariables();
            objs = ind.getObjectives();

            % 将最小化的负值转换回最大化的正值
            SA_FRAC = -objs(1);
            SA_FLOW = -objs(2);

            fprintf('%-5d | %-15.2f | %-15.2f | %-20.6f | %-20.4f\n', ...
                i, vars(1), vars(2), SA_FRAC, SA_FLOW);

            paretoVars = [paretoVars; vars];
            paretoObjs = [paretoObjs; SA_FRAC, SA_FLOW];
        end

        % 提取所有解的目标值（用于绘图）
        allObjs = [];
        validIndices = [];  % 记录有效解的索引
        for i = 1:totalSolutions
            ind = allIndividuals(i);
            objs = ind.getObjectives();
            % 转换为最大化目标
            SA_FRAC = -objs(1);
            SA_FLOW = -objs(2);

            % 过滤掉失败的解（惩罚值会变成负的大数）
            % 失败的解：objectives = [1e8, 1e8]，取负后变成[-1e8, -1e8]
            if SA_FRAC > -1e7 && SA_FLOW > -1e7  % 只保留有效解
                allObjs = [allObjs; SA_FRAC, SA_FLOW];
                validIndices = [validIndices; i];
            end
        end

        fprintf('  有效解数量: %d / %d\n', length(validIndices), totalSolutions);
        fprintf('  失败解数量: %d\n', totalSolutions - length(validIndices));
    end

    %% ========================================
    %% 步骤7: 可视化和保存结果
    %% ========================================

    fprintf('\n[8/8] 可视化和保存结果...\n');
    fprintf('========================================\n');

    % 保存数据
    matPath = fullfile(resultsDir, 'optimization_results.mat');
    if strcmp(problem.problemType, 'single-objective')
        save(matPath, 'results', 'bestResult', 'algoConfig', 'elapsedTime');
        fprintf('  最优解已保存: %s\n', matPath);

        % 保存为CSV
        bestTable = struct2table(bestResult);
        csvPath = fullfile(resultsDir, 'best_solution.csv');
        writetable(bestTable, csvPath);
        fprintf('  最优解CSV已保存: %s\n', csvPath);

    else
        % 多目标：保存Pareto前沿
        save(matPath, 'results', 'paretoVars', 'paretoObjs', 'allObjs', 'algoConfig', 'elapsedTime');
        fprintf('  优化结果已保存: %s\n', matPath);

        % 保存Pareto前沿数据为CSV
        paretoData = [paretoVars, paretoObjs];
        paretoTable = array2table(paretoData, ...
            'VariableNames', {'R101_FEED_TEMP', 'R101_FEED_PRES', 'SA_FRAC', 'SA_FLOW'});
        csvPath = fullfile(resultsDir, 'pareto_solutions.csv');
        writetable(paretoTable, csvPath);
        fprintf('  Pareto前沿解已保存: %s\n', csvPath);

        % 绘制所有解和Pareto前沿
        if isfield(results, 'allEvaluatedIndividuals')
            figTitle = '阿司匹林生产优化 - 所有评估解与Pareto前沿';
        else
            figTitle = '阿司匹林生产优化 - 最终种群与Pareto前沿';
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
        [sortedFrac, idx] = sort(paretoObjs(:, 1));
        sortedFlow = paretoObjs(idx, 2);
        plot(sortedFrac, sortedFlow, '-b', 'LineWidth', 1.5);

        xlabel('水杨酸质量分率', 'FontSize', 12);
        ylabel('水杨酸产量 (kg/hr)', 'FontSize', 12);
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
    end

    % 保存所有解的数据为CSV
    allData = [];
    for i = 1:totalSolutions
        ind = allIndividuals(i);
        vars = ind.getVariables();
        objs = ind.getObjectives();
        % 对于多目标，转换两个目标值；对于单目标，只转换一个
        if strcmp(problem.problemType, 'multi-objective')
            allData = [allData; vars, -objs(1), -objs(2)];
        else
            allData = [allData; vars, -objs(1)];
        end
    end

    if strcmp(problem.problemType, 'multi-objective')
        allSolutionsTable = array2table(allData, ...
            'VariableNames', {'R101_FEED_TEMP', 'R101_FEED_PRES', 'SA_FRAC', 'SA_FLOW'});
    else
        allSolutionsTable = array2table(allData, ...
            'VariableNames', {'R101_FEED_TEMP', 'R101_FEED_PRES', 'SA_FRAC'});
    end
    allCsvPath = fullfile(resultsDir, 'all_solutions.csv');
    writetable(allSolutionsTable, allCsvPath);
    fprintf('  所有评估解已保存（%d个）: %s\n', totalSolutions, allCsvPath);

else
    fprintf('\n警告: 未找到最优解\n');
end

%% ========================================
%% 清理资源
%% ========================================

fprintf('\n========================================\n');
fprintf('清理资源\n');
fprintf('========================================\n');

simulator.disconnect();
fprintf('  Aspen Plus已断开\n');

%% ========================================
%% 总结
%% ========================================

fprintf('\n========================================\n');
fprintf('优化任务完成\n');
fprintf('========================================\n');
fprintf('总用时: %.2f 秒 (%.2f 分钟)\n', elapsedTime, elapsedTime/60);
fprintf('评估次数: %d\n', evaluator.getEvaluationCount());
if strcmp(problem.problemType, 'single-objective')
    fprintf('最优解已保存至: %s\n', resultsDir);
else
    if ~isempty(results.paretoFront)
        fprintf('Pareto解数量: %d\n', results.paretoFront.size());
    end
    fprintf('\n所有结果已保存至: %s\n', resultsDir);
end
fprintf('========================================\n\n');
