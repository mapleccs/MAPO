%% run_all_sensitivity.m
% 批量运行所有变量的灵敏度分析
%
% 描述:
%   对ORC系统的所有设计变量进行单变量灵敏度分析
%   使用 scan_feasible_regions 函数找出每个变量的可行域和对系统性能的影响
%
% 作者: MAPO Framework
% 日期: 2024

clear;
clc;
close all;

fprintf('========================================\n');
fprintf('    ORC全变量灵敏度分析\n');
fprintf('========================================\n\n');

%% 1. 基本设置
fprintf('[1/5] 基本设置...\n');

% 获取当前脚本所在目录
currentDir = fileparts(mfilename('fullpath'));
parentDir = fileparts(currentDir);

% 添加必要的路径
addpath(genpath(fullfile(parentDir, '..', '..', 'framework')));
addpath(genpath(fullfile(parentDir, '..', '..', 'utils')));

% Aspen模型路径
modelPath = fullfile(parentDir, 'r601a.bkp');

% 检查文件是否存在
if ~exist(modelPath, 'file')
    error('Aspen模型文件不存在: %s', modelPath);
end

% 创建结果目录
resultsDir = fullfile(currentDir, 'results', 'sensitivity');
if ~exist(resultsDir, 'dir')
    mkdir(resultsDir);
end

fprintf('  模型文件: %s\n', modelPath);
fprintf('  结果目录: %s\n', resultsDir);

%% 2. 创建优化问题定义
fprintf('\n[2/5] 定义优化问题...\n');

problem = OptimizationProblem('ORC_Sensitivity', 'ORC系统单变量灵敏度分析');

% 添加设计变量（与优化问题保持一致）
problem.addVariable(Variable('FLOW_S7', 'continuous', [40, 60]));    % S7流量进EV1 (kmol/hr)
problem.addVariable(Variable('FLOW_S8', 'continuous', [40, 60]));    % S8流量进EV2 (kmol/hr)
problem.addVariable(Variable('P_EVAP', 'continuous', [2.0, 5.0]));   % 蒸发压力 (bar)
problem.addVariable(Variable('P_COND', 'continuous', [0.5, 1.5]));   % 冷凝压力 (bar)

fprintf('  变量数: %d\n', problem.getNumberOfVariables());
fprintf('    1. FLOW_S7 (S7流量): [40, 60] kmol/hr\n');
fprintf('    2. FLOW_S8 (S8流量): [40, 60] kmol/hr\n');
fprintf('    3. P_EVAP (蒸发压力): [2.0, 5.0] bar\n');
fprintf('    4. P_COND (冷凝压力): [0.5, 1.5] bar\n');

%% 3. 配置仿真器
fprintf('\n[3/5] 配置Aspen Plus仿真器...\n');

simConfig = SimulatorConfig('Aspen');
simConfig.set('modelPath', modelPath);
simConfig.set('timeout', 180);           % 单次仿真超时时间(秒)
simConfig.set('visible', true);         % Aspen不可见（加快速度）
simConfig.set('autoSave', false);

% 配置输入变量的节点映射
simConfig.setNodeMapping('FLOW_S7', '\Data\Streams\S7\Input\TOTFLOW\MIXED');
simConfig.setNodeMapping('FLOW_S8', '\Data\Streams\S8\Input\TOTFLOW\MIXED');
simConfig.setNodeMapping('P_EVAP', '\Data\Blocks\PUM\Input\PRES');
simConfig.setNodeMapping('P_COND', '\Data\Blocks\TUR\Input\PRES');

% 配置结果映射
simConfig.setResultMapping('W_TUR', '\Data\Blocks\TUR\Output\WNET');      % 透平净功
simConfig.setResultMapping('W_PUM', '\Data\Blocks\PUM\Output\WNET');      % 泵净功
simConfig.setResultMapping('Q_CON', '\Data\Blocks\CON\Output\QCALC');     % CON热负荷

% 配置焓值映射（用于计算热力学效率）
simConfig.setResultMapping('H_1', '\Data\Streams\IN-T\Output\HMX\MIXED');   % 透平入口焓值
simConfig.setResultMapping('H_2', '\Data\Streams\OUT-T\Output\HMX\MIXED');  % 透平出口焓值
simConfig.setResultMapping('H_3', '\Data\Streams\IN-P\Output\HMX\MIXED');   % 泵入口焓值
simConfig.setResultMapping('H_4', '\Data\Streams\S13\Output\HMX\MIXED');    % 泵出口焓值

fprintf('  仿真器类型: Aspen Plus\n');
fprintf('  超时时间: %d 秒\n', 180);
fprintf('  可见性: 隐藏\n');

%% 4. 创建评估器
fprintf('\n[4/5] 创建评估器...\n');

% 为了兼容 scan_feasible_regions，创建一个简单的评估器
% 这里我们使用 ORCEvaluator 但它需要先连接仿真器

% 创建临时仿真器来设置评估器
tempSimulator = AspenPlusSimulator();
tempSimulator.connect(simConfig);

evaluator = ORCEvaluator(tempSimulator);
evaluator.timeout = 180;

% 设置经济参数
evaluator.electricityPrice = 0.1;
evaluator.operatingHours = 8000;
evaluator.coolingWaterCost = 0.354;

problem.setEvaluator(evaluator);

fprintf('  评估器类型: ORCEvaluator\n');

%% 5. 配置扫描选项
fprintf('\n[5/5] 配置扫描选项...\n');

options = struct();
options.numPoints = 20;                      % 每个变量采样20个点
options.useLogScale = {};                    % 不使用对数尺度
options.timeout = 180;                       % 单次仿真超时180秒
options.outputDir = resultsDir;              % 输出目录
options.enablePlot = true;                   % 生成图形
options.enableExport = true;                 % 导出CSV/JSON
options.retryOnFailure = true;               % 失败时重试

% 设置基准值（使用中值）
options.baselineValues = struct();
options.baselineValues.FLOW_S7 = 50;
options.baselineValues.FLOW_S8 = 50;
options.baselineValues.P_EVAP = 3.5;
options.baselineValues.P_COND = 1.0;

fprintf('  每变量采样点数: %d\n', options.numPoints);
fprintf('  超时时间: %d 秒\n', options.timeout);
fprintf('  基准值:\n');
fprintf('    FLOW_S7 = %.1f kmol/hr\n', options.baselineValues.FLOW_S7);
fprintf('    FLOW_S8 = %.1f kmol/hr\n', options.baselineValues.FLOW_S8);
fprintf('    P_EVAP = %.2f bar\n', options.baselineValues.P_EVAP);
fprintf('    P_COND = %.2f bar\n', options.baselineValues.P_COND);

%% 执行可行域扫描
fprintf('\n========================================\n');
fprintf('开始单变量可行域扫描\n');
fprintf('========================================\n\n');

try
    % 调用核心扫描函数
    [feasibleRanges, scanResults] = scan_feasible_regions(problem, simConfig, options);

    fprintf('\n========================================\n');
    fprintf('扫描完成\n');
    fprintf('========================================\n\n');

    %% 显示优化建议
    fprintf('优化建议:\n');
    fprintf('----------------------------------------\n');
    fprintf('基于灵敏度分析结果，建议在多目标优化中:\n\n');

    varNames = fieldnames(feasibleRanges);
    for i = 1:length(varNames)
        varName = varNames{i};
        var = problem.getVariableSet().getVariable(varName);
        bounds = var.getBounds();
        feasRange = feasibleRanges.(varName);

        if ~isnan(feasRange(1))
            % 计算安全边界（留10%余量）
            range = feasRange(2) - feasRange(1);
            margin = range * 0.1;
            safeLower = max(bounds(1), feasRange(1) + margin);
            safeUpper = min(bounds(2), feasRange(2) - margin);

            fprintf('%s:\n', varName);
            fprintf('  原始范围: [%.4f, %.4f]\n', bounds(1), bounds(2));
            fprintf('  可行域: [%.4f, %.4f]\n', feasRange(1), feasRange(2));
            fprintf('  建议范围: [%.4f, %.4f] (留10%%安全余量)\n\n', safeLower, safeUpper);
        else
            fprintf('%s:\n', varName);
            fprintf('  警告: 未找到可行域，建议检查模型或调整初值\n\n');
        end
    end

    fprintf('注意: 以上是单变量分析结果，实际优化时变量间可能存在相互作用。\n');
    fprintf('========================================\n');

    %% 保存工作空间（供后续使用）
    matFilename = fullfile(resultsDir, 'sensitivity_workspace.mat');
    save(matFilename, 'feasibleRanges', 'scanResults', 'problem', 'simConfig', 'options');
    fprintf('\n工作空间已保存: %s\n', matFilename);

catch ME
    fprintf('\n错误: 扫描过程中出现异常\n');
    fprintf('错误信息: %s\n', ME.message);
    fprintf('错误位置: %s (行 %d)\n', ME.stack(1).name, ME.stack(1).line);

    % 清理
    try
        if exist('tempSimulator', 'var') && ~isempty(tempSimulator)
            tempSimulator.disconnect();
        end
    catch
        % 忽略清理错误
    end

    rethrow(ME);
end

%% 清理资源
try
    if exist('tempSimulator', 'var') && ~isempty(tempSimulator)
        tempSimulator.disconnect();
        fprintf('仿真器已断开连接\n');
    end
catch ME
    warning('清理时出错: %s', ME.message);
end

fprintf('\n========================================\n');
fprintf('    全变量灵敏度分析完成\n');
fprintf('========================================\n\n');
