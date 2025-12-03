%% MAPO 并行优化示例
% 本脚本演示如何使用MAPO框架的并行计算功能
%
% 功能:
%   - 并行种群评估 (NSGA-II / PSO)
%   - 并行灵敏度分析
%   - 自动Worker管理
%
% 要求:
%   - MATLAB Parallel Computing Toolbox
%   - MAPO Framework
%
% 作者: MAPO Framework
% 日期: 2024

clear; clc; close all;

%% 添加路径
% 获取脚本所在目录
scriptPath = fileparts(mfilename('fullpath'));
frameworkPath = fullfile(scriptPath, '..', '..', 'framework');

% 添加框架路径
addpath(genpath(frameworkPath));

%% 检查并行计算环境
fprintf('========================================\n');
fprintf('MAPO 并行计算环境检查\n');
fprintf('========================================\n');

% 检查Parallel Computing Toolbox
if ParallelConfig.checkToolbox()
    fprintf('Parallel Computing Toolbox 已安装\n');
else
    fprintf('Parallel Computing Toolbox 未安装\n');
    fprintf('将使用顺序计算模式\n');
end

% 获取系统信息
sysInfo = ParallelConfig.getSystemInfo();
fprintf('CPU核心数: %d\n', sysInfo.numCores);
fprintf('逻辑处理器数: %d\n', sysInfo.numLogicalCPUs);

if sysInfo.poolActive
    fprintf('当前并行池: %d workers\n', sysInfo.poolWorkers);
else
    fprintf('当前并行池: 未激活\n');
end

fprintf('========================================\n\n');

%% 定义测试问题
% 使用ZDT1测试函数作为示例
fprintf('创建测试问题 (ZDT1)...\n');

% 创建问题
problem = OptimizationProblem('ZDT1_Parallel_Test');

% 添加变量 (30维)
numVars = 30;
for i = 1:numVars
    problem.addVariable(Variable(sprintf('x%d', i), 'continuous', [0, 1]));
end

% 添加目标函数
problem.addObjective(Objective('f1', 'minimize'));
problem.addObjective(Objective('f2', 'minimize'));

% 创建ZDT1评估器
evaluator = ZDT1Evaluator();
evaluator.setProblem(problem);
problem.evaluator = evaluator;

fprintf('问题维度: %d 变量, %d 目标\n\n', numVars, 2);

%% 配置并行NSGA-II优化
fprintf('========================================\n');
fprintf('配置 NSGA-II 优化 (并行模式)\n');
fprintf('========================================\n');

% 算法配置
config = struct();
config.populationSize = 50;
config.maxGenerations = 20;
config.crossoverRate = 0.9;
config.mutationRate = 1.0;
config.crossoverDistIndex = 20;
config.mutationDistIndex = 20;

% 并行配置
config.enableParallel = true;      % 启用并行评估
config.numWorkers = 0;              % 0 = 自动检测可用核心数

% 或者使用详细的并行配置
% parallelCfg = ParallelConfig(...
%     'EnableParallel', true, ...
%     'NumWorkers', 4, ...           % 指定Worker数量
%     'Verbose', true, ...           % 显示并行详情
%     'FallbackToSequential', true); % 失败时回退到顺序
% config.parallelConfig = parallelCfg;

fprintf('种群大小: %d\n', config.populationSize);
fprintf('最大代数: %d\n', config.maxGenerations);
fprintf('预计评估次数: %d\n', config.populationSize * (config.maxGenerations + 1));
fprintf('并行评估: 已启用\n\n');

%% 运行并行优化
fprintf('========================================\n');
fprintf('开始并行优化...\n');
fprintf('========================================\n');

nsga2 = NSGAII();

tic;
results = nsga2.optimize(problem, config);
parallelTime = toc;

fprintf('\n优化完成!\n');
fprintf('总运行时间: %.2f 秒\n', parallelTime);
fprintf('总评估次数: %d\n', results.evaluations);
fprintf('平均每次评估: %.4f 秒\n', parallelTime / results.evaluations);

%% 运行顺序模式进行对比 (可选)
runComparison = false;  % 设为true以运行对比测试

if runComparison
    fprintf('\n========================================\n');
    fprintf('运行顺序模式进行对比...\n');
    fprintf('========================================\n');

    % 顺序配置
    seqConfig = config;
    seqConfig.enableParallel = false;

    nsga2_seq = NSGAII();

    tic;
    results_seq = nsga2_seq.optimize(problem, seqConfig);
    sequentialTime = toc;

    fprintf('\n顺序模式完成!\n');
    fprintf('顺序运行时间: %.2f 秒\n', sequentialTime);
    fprintf('并行运行时间: %.2f 秒\n', parallelTime);
    fprintf('加速比: %.2fx\n', sequentialTime / parallelTime);
end

%% 提取并显示结果
fprintf('\n========================================\n');
fprintf('优化结果\n');
fprintf('========================================\n');

% 获取Pareto前沿
paretoFront = results.paretoFront;
fprintf('Pareto前沿大小: %d 个解\n', paretoFront.size());

% 提取目标值
frontIndividuals = paretoFront.getAll();
objectives = zeros(length(frontIndividuals), 2);
for i = 1:length(frontIndividuals)
    objectives(i, :) = frontIndividuals(i).getObjectives();
end

% 显示部分结果
fprintf('\n前5个Pareto最优解:\n');
fprintf('%-10s %-15s %-15s\n', '序号', 'f1', 'f2');
fprintf('%s\n', repmat('-', 1, 40));
for i = 1:min(5, size(objectives, 1))
    fprintf('%-10d %-15.6f %-15.6f\n', i, objectives(i, 1), objectives(i, 2));
end

%% 可视化结果
figure('Name', 'MAPO 并行优化结果', 'Position', [100, 100, 800, 600]);

% 绘制Pareto前沿
subplot(2, 2, 1);
scatter(objectives(:, 1), objectives(:, 2), 50, 'b', 'filled');
xlabel('f_1');
ylabel('f_2');
title('Pareto 前沿');
grid on;

% 绘制真实Pareto前沿对比
hold on;
x_true = linspace(0, 1, 100);
y_true = 1 - sqrt(x_true);
plot(x_true, y_true, 'r-', 'LineWidth', 2);
legend('优化结果', '理论前沿', 'Location', 'northeast');
hold off;

% 绘制收敛曲线
subplot(2, 2, 2);
if isfield(results, 'history') && ~isempty(results.history)
    generations = [results.history.iteration];
    if isfield(results.history, 'paretoFrontSize')
        frontSizes = [results.history.paretoFrontSize];
        plot(generations, frontSizes, 'b-o', 'LineWidth', 1.5);
        ylabel('Pareto前沿大小');
    end
end
xlabel('代数');
title('收敛曲线');
grid on;

% 显示性能统计
subplot(2, 2, [3, 4]);
axis off;

statsText = {
    sprintf('\\bf优化性能统计\\rm'), ...
    '', ...
    sprintf('算法: NSGA-II (并行模式)'), ...
    sprintf('问题: ZDT1 (%d维)', numVars), ...
    sprintf('种群大小: %d', config.populationSize), ...
    sprintf('最大代数: %d', config.maxGenerations), ...
    '', ...
    sprintf('总评估次数: %d', results.evaluations), ...
    sprintf('总运行时间: %.2f 秒', parallelTime), ...
    sprintf('平均每次评估: %.4f 秒', parallelTime / results.evaluations), ...
    '', ...
    sprintf('Pareto前沿大小: %d', paretoFront.size())
};

if runComparison
    statsText{end+1} = '';
    statsText{end+1} = sprintf('顺序运行时间: %.2f 秒', sequentialTime);
    statsText{end+1} = sprintf('并行加速比: %.2fx', sequentialTime / parallelTime);
end

text(0.1, 0.9, statsText, 'FontSize', 11, ...
    'VerticalAlignment', 'top', 'FontName', 'FixedWidth');

%% 并行灵敏度分析示例 (可选)
runSensitivity = false;  % 设为true以运行灵敏度分析

if runSensitivity
    fprintf('\n========================================\n');
    fprintf('并行灵敏度分析\n');
    fprintf('========================================\n');

    % 创建灵敏度分析上下文
    context = SensitivityContext(problem);

    % 设置基准点
    baseline = containers.Map();
    for i = 1:numVars
        baseline(sprintf('x%d', i)) = 0.5;
    end
    context.setBaseline(baseline);

    % 创建并行灵敏度分析器
    analyzer = BaseSensitivityAnalyzer(context, ...
        'EnableParallel', true, ...
        'EnableCache', true, ...
        'ProgressDisplay', true);

    % 分析前3个变量
    fprintf('分析变量 x1, x2, x3...\n');
    for i = 1:3
        varName = sprintf('x%d', i);
        result = analyzer.analyzeVariable(varName);
        fprintf('  %s: 收敛率 %.1f%%\n', varName, result.convergenceRate * 100);
    end

    % 生成报告
    analyzer.report();
end

%% 清理
fprintf('\n========================================\n');
fprintf('示例完成!\n');
fprintf('========================================\n');

% 注意：并行池会自动保留，除非手动关闭
% 如需关闭并行池，取消下面的注释：
% delete(gcp('nocreate'));


%% ZDT1评估器类定义 (嵌套在脚本末尾)
% 注意：在实际使用中，这应该是一个单独的.m文件
