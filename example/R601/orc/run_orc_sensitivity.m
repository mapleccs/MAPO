% run_orc_sensitivity.m - ORC灵敏度分析示例
%
% 描述:
%   演示如何使用灵敏度分析框架进行有机朗肯循环的单变量分析
%   找出各个变量的可行域，为多目标优化提供参考
%
% 作者: MAPO Framework
% 日期: 2024

clear;
clc;
close all;

fprintf('========================================\n');
fprintf('    ORC灵敏度分析示例\n');
fprintf('========================================\n\n');

%% 1. 加载配置
fprintf('1. 加载配置...\n');
% 添加框架路径
addpath(genpath('../../../framework'));

% 获取当前脚本所在目录
currentDir = fileparts(mfilename('fullpath'));

% 加载ORC配置
config = orc_sensitivity_config();

%% 2. 创建优化问题
fprintf('2. 创建优化问题...\n');

% 定义优化变量 (与run_ocr_nsga2_optimization.m一致)
variables = [
    Variable('FLOW_S7', 40, 60, '流量S7 (kmol/hr)');      % S7流量进EV1
    Variable('FLOW_S8', 40, 60, '流量S8 (kmol/hr)');      % S8流量进EV2
    Variable('P_EVAP', 2.0, 5.0, '蒸发压力 (bar)');       % 蒸发压力
    Variable('P_COND', 0.5, 1.5, '冷凝压力 (bar)')        % 冷凝压力
];

% 定义优化目标
objectives = [
    Objective('NetPower', 'maximize', '净功率输出 (kW)'),
    Objective('Efficiency', 'maximize', '系统效率 (%)')
];

% 创建问题实例
problem = OptimizationProblem('ORC_Sensitivity', variables, objectives);

%% 3. 配置仿真器
fprintf('3. 配置仿真器...\n');

% Aspen模型路径 - 使用实际的r601a.bkp文件
modelPath = fullfile(fileparts(currentDir), 'r601a.bkp');

% 检查文件是否存在
if ~exist(modelPath, 'file')
    error('Aspen模型文件不存在: %s', modelPath);
end

% 创建仿真器配置
simConfig = SimulatorConfig('Aspen');
simConfig.set('modelPath', modelPath);
simConfig.set('timeout', 60);           % 仿真超时时间(秒)
simConfig.set('visible', false);        % Aspen不可见（提高性能）
simConfig.set('autoSave', false);       % 不自动保存

% 设置输入变量的节点映射
simConfig.setNodeMapping('FLOW_S7', '\Data\Streams\S7\Input\TOTFLOW\MIXED');
simConfig.setNodeMapping('FLOW_S8', '\Data\Streams\S8\Input\TOTFLOW\MIXED');
simConfig.setNodeMapping('P_EVAP', '\Data\Blocks\PUM\Input\PRES');
simConfig.setNodeMapping('P_COND', '\Data\Blocks\TUR\Input\PRES');

% 设置结果映射（用于计算目标）
simConfig.setResultMapping('W_TUR', '\Data\Blocks\TUR\Output\WORK');
simConfig.setResultMapping('W_PUM', '\Data\Blocks\PUM\Output\WORK');
simConfig.setResultMapping('Q_EV1', '\Data\Blocks\EV1\Output\QCALC');
simConfig.setResultMapping('Q_EV2', '\Data\Blocks\EV2\Output\QCALC');
simConfig.setResultMapping('Q_CON', '\Data\Blocks\CON\Output\QCALC');

% 创建仿真器
simulator = AspenSimulator(simConfig);

% 创建评估器
evaluator = ProblemEvaluator(simulator, problem);

%% 4. 创建灵敏度分析器
fprintf('4. 创建灵敏度分析器...\n');

% 创建分析器
analyzer = BaseSensitivityAnalyzer(problem, evaluator);

% 配置分析器
analyzer.setSimulationMode(config.simulationMode);
analyzer.setNumPoints(config.numPoints);
analyzer.setShowProgress(config.showProgress);
analyzer.setUseCache(config.useCache);

% 设置变化策略
if strcmpi(config.variationStrategy, 'linear')
    strategy = LinearVariationStrategy('RangeExpansion', config.rangeExpansion);
elseif strcmpi(config.variationStrategy, 'logarithmic')
    strategy = LogarithmicVariationStrategy('NumDecades', 2);
else
    strategy = LinearVariationStrategy();  % 默认线性
end
analyzer.setVariationStrategy(strategy);

% 设置收敛评估器
convergenceEvaluator = AspenConvergenceEvaluator(...
    'PenaltyThreshold', config.penaltyThreshold);
analyzer.setConvergenceEvaluator(convergenceEvaluator);

%% 5. 执行灵敏度分析
fprintf('5. 执行灵敏度分析...\n\n');

% 分析指定变量或所有变量
if ~isempty(config.targetVariables)
    % 分析指定的变量
    for i = 1:length(config.targetVariables)
        varName = config.targetVariables{i};
        fprintf('分析变量: %s\n', varName);
        fprintf('----------------------------------------\n');

        result = analyzer.analyzeVariable(varName);

        if ~isempty(result)
            fprintf('  测试点数: %d\n', length(result.testValues));
            fprintf('  收敛率: %.1f%%\n', result.convergenceRate * 100);

            if ~isempty(result.feasibleRange)
                fprintf('  可行域: [%.2f, %.2f]\n', ...
                    result.feasibleRange(1), result.feasibleRange(2));
            else
                fprintf('  可行域: 未找到\n');
            end
        else
            fprintf('  分析失败\n');
        end

        fprintf('\n');
    end
else
    % 分析所有变量
    analyzer.analyzeAll();
end

%% 6. 生成报告
fprintf('6. 生成报告...\n');

% 创建复合报告器
compositeReporter = CompositeReporter();

% 添加控制台报告
if config.generateConsoleReport
    consoleReporter = ConsoleReporter('ShowDetails', true);
    compositeReporter.addReporter(consoleReporter, 'Console');
end

% 添加文件报告
if config.generateFileReport
    fileReporter = FileReporter(...
        'OutputDirectory', config.outputDirectory, ...
        'SaveTextReport', true, ...
        'SaveCSV', true, ...
        'SaveMAT', true);
    compositeReporter.addReporter(fileReporter, 'File');
end

% 添加图形报告
if config.generatePlotReport
    plotReporter = PlotReporter(...
        'OutputDirectory', config.outputDirectory, ...
        'FigureSize', [1200, 600], ...
        'DPI', 300);
    compositeReporter.addReporter(plotReporter, 'Plot');
end

% 生成所有报告
analyzer.report(compositeReporter);

%% 7. 获取可行域
fprintf('7. 获取可行域...\n');
feasibleRanges = analyzer.getFeasibleRanges();

fprintf('\n可行域汇总:\n');
fprintf('========================================\n');
for i = 1:length(variables)
    varName = variables(i).name;
    if isfield(feasibleRanges, varName) && ~isempty(feasibleRanges.(varName))
        range = feasibleRanges.(varName);
        fprintf('%-15s: [%.2f, %.2f]\n', varName, range(1), range(2));
    else
        fprintf('%-15s: 未找到可行域\n', varName);
    end
end
fprintf('========================================\n');

%% 8. 保存结果用于优化
fprintf('\n8. 保存结果用于优化...\n');

% 创建优化建议
optimizationSuggestions = struct();
optimizationSuggestions.feasibleRanges = feasibleRanges;
optimizationSuggestions.analysisDate = datetime('now');
optimizationSuggestions.config = config;

% 更新变量边界建议
for i = 1:length(variables)
    varName = variables(i).name;
    if isfield(feasibleRanges, varName) && ~isempty(feasibleRanges.(varName))
        range = feasibleRanges.(varName);
        optimizationSuggestions.suggestedBounds.(varName) = range;

        % 计算安全边界（留5%余量）
        margin = (range(2) - range(1)) * 0.05;
        optimizationSuggestions.safeBounds.(varName) = ...
            [range(1) + margin, range(2) - margin];
    end
end

% 保存到文件
suggestionsFile = fullfile(config.outputDirectory, 'optimization_suggestions.mat');
save(suggestionsFile, 'optimizationSuggestions');
fprintf('优化建议已保存到: %s\n', suggestionsFile);

%% 9. 清理
fprintf('\n9. 清理资源...\n');
delete(simulator);  % 关闭仿真器

fprintf('\n========================================\n');
fprintf('    灵敏度分析完成\n');
fprintf('========================================\n');

%% 辅助函数
function displayResults(result)
    % 显示分析结果
    fprintf('  变量: %s\n', result.variableName);
    fprintf('  单位: %s\n', result.variableUnit);
    fprintf('  测试范围: [%.2f, %.2f]\n', ...
        min(result.testValues), max(result.testValues));
    fprintf('  收敛率: %.1f%%\n', result.convergenceRate * 100);

    if ~isempty(result.feasibleRange)
        fprintf('  可行域: [%.2f, %.2f]\n', ...
            result.feasibleRange(1), result.feasibleRange(2));
    end

    % 显示输出统计
    if isfield(result, 'metadata') && isfield(result.metadata, 'outputStats')
        stats = result.metadata.outputStats;
        for i = 1:length(stats)
            fprintf('  输出%d - 范围: [%.2f, %.2f]\n', ...
                i, stats(i).min, stats(i).max);
        end
    end
end