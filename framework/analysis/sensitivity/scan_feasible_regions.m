function [feasibleRanges, scanResults] = scan_feasible_regions(problem, simConfig, options)
% scan_feasible_regions 单变量可行域扫描
%
% 描述:
%   对优化问题中的每个变量进行单变量扫描，确定 Aspen Plus 可收敛的可行区间
%   固定其他变量为基准值，逐个变量线性或对数扫描
%
% 输入:
%   problem - OptimizationProblem对象，包含变量定义
%   simConfig - SimulatorConfig对象，包含仿真器配置
%   options - (可选) 扫描选项结构体
%     .numPoints - 每个变量的采样点数（默认20）
%     .useLogScale - 对数尺度变量名列表（cell array）
%     .baselineValues - 基准值（结构体），如未提供则使用中值
%     .timeout - 单次仿真超时时间（秒，默认120）
%     .outputDir - 输出目录（默认'sensitivity_results'）
%     .enablePlot - 是否生成图形（默认true）
%     .enableExport - 是否导出CSV/JSON（默认true）
%     .retryOnFailure - 失败时是否重试（默认true）
%
% 输出:
%   feasibleRanges - 各变量的可行域（结构体）
%   scanResults - 详细扫描结果（结构体数组）
%
% 示例:
%   problem = OptimizationProblem.fromConfig('problem_config.json');
%   simConfig = SimulatorConfig.fromFile('simulator_config.json');
%   options.numPoints = 30;
%   options.timeout = 120;
%   options.useLogScale = {'P_EVAP', 'P_COND'};
%   [feasibleRanges, results] = scan_feasible_regions(problem, simConfig, options);
%
% 作者: MAPO Framework
% 日期: 2024

    %% 参数验证和默认值
    if nargin < 2
        error('scan_feasible_regions:InsufficientArgs', ...
            '至少需要 problem 和 simConfig 两个参数');
    end

    if nargin < 3
        options = struct();
    end

    % 设置默认选项
    if ~isfield(options, 'numPoints')
        options.numPoints = 20;
    end
    if ~isfield(options, 'useLogScale')
        options.useLogScale = {};
    end
    if ~isfield(options, 'baselineValues')
        options.baselineValues = struct();
    end
    if ~isfield(options, 'timeout')
        options.timeout = 120;
    end
    if ~isfield(options, 'outputDir')
        options.outputDir = 'sensitivity_results';
    end
    if ~isfield(options, 'enablePlot')
        options.enablePlot = true;
    end
    if ~isfield(options, 'enableExport')
        options.enableExport = true;
    end
    if ~isfield(options, 'retryOnFailure')
        options.retryOnFailure = true;
    end

    %% 获取变量信息
    varSet = problem.getVariableSet();
    numVars = varSet.size();

    if numVars == 0
        error('scan_feasible_regions:NoVariables', ...
            '优化问题中没有定义变量');
    end

    % 获取所有变量
    variables = cell(numVars, 1);
    for i = 1:numVars
        variables{i} = varSet.getVariableByIndex(i);
    end

    fprintf('\n========================================\n');
    fprintf('单变量可行域扫描\n');
    fprintf('========================================\n');
    fprintf('问题名称: %s\n', problem.name);
    fprintf('变量数量: %d\n', numVars);
    fprintf('每变量采样点: %d\n', options.numPoints);
    fprintf('超时时间: %d 秒\n', options.timeout);
    fprintf('========================================\n\n');

    %% 计算基准值
    baselineValues = struct();
    for i = 1:numVars
        var = variables{i};
        varName = var.name;

        % 检查是否提供了基准值
        if isfield(options.baselineValues, varName)
            baselineValues.(varName) = options.baselineValues.(varName);
        else
            % 使用中值作为基准
            bounds = var.getBounds();
            baselineValues.(varName) = (bounds(1) + bounds(2)) / 2;
        end
    end

    %% 创建输出目录
    if options.enableExport || options.enablePlot
        if ~exist(options.outputDir, 'dir')
            mkdir(options.outputDir);
        end
    end

    %% 连接仿真器
    fprintf('[步骤 1/%d] 连接Aspen Plus仿真器...\n', numVars + 2);

    try
        simulator = AspenPlusSimulator();
        simulator.connect(simConfig);
        fprintf('  Aspen Plus连接成功\n\n');
    catch ME
        error('scan_feasible_regions:SimulatorConnectionFailed', ...
            '无法连接仿真器: %s', ME.message);
    end

    % 确保断开时清理资源
    cleanupObj = onCleanup(@() cleanupSimulator(simulator));

    %% 逐变量扫描
    scanResults = struct();
    feasibleRanges = struct();

    for varIdx = 1:numVars
        var = variables{varIdx};
        varName = var.name;
        bounds = var.getBounds();

        fprintf('[步骤 %d/%d] 扫描变量: %s\n', varIdx + 1, numVars + 2, varName);
        fprintf('  原始范围: [%.4f, %.4f]\n', bounds(1), bounds(2));

        % 生成测试点
        if ismember(varName, options.useLogScale)
            % 对数尺度
            testValues = logspace(log10(bounds(1)), log10(bounds(2)), options.numPoints);
            fprintf('  采样方式: 对数尺度\n');
        else
            % 线性尺度
            testValues = linspace(bounds(1), bounds(2), options.numPoints);
            fprintf('  采样方式: 线性尺度\n');
        end

        % 初始化结果存储
        convergency = false(options.numPoints, 1);
        resultData = cell(options.numPoints, 1);

        % 逐点仿真
        fprintf('  测试进度: ');
        for i = 1:options.numPoints
            if mod(i, 5) == 0 || i == 1 || i == options.numPoints
                fprintf('%d/%d ', i, options.numPoints);
            end

            % 构建输入向量：固定其他变量为基准值
            inputValues = zeros(numVars, 1);
            for j = 1:numVars
                if j == varIdx
                    inputValues(j) = testValues(i);
                else
                    inputValues(j) = baselineValues.(variables{j}.name);
                end
            end

            % 调用仿真器
            try
                % 设置变量
                simulator.setVariables(inputValues);

                % 运行仿真
                success = simulator.run(options.timeout);

                % 检查收敛性
                if success
                    convergency(i) = true;
                    % 获取结果数据（如果需要）
                    resultData{i} = struct('success', true);
                else
                    % 如果启用重试
                    if options.retryOnFailure
                        pause(1);  % 等待1秒后重试
                        simulator.setVariables(inputValues);
                        success = simulator.run(options.timeout);
                        if success
                            convergency(i) = true;
                            resultData{i} = struct('success', true);
                        else
                            convergency(i) = false;
                            resultData{i} = struct('success', false, 'reason', '未收敛');
                        end
                    else
                        convergency(i) = false;
                        resultData{i} = struct('success', false, 'reason', '未收敛');
                    end
                end

            catch ME
                % 仿真失败
                convergency(i) = false;
                resultData{i} = struct('success', false, 'error', ME.message);

                % 重试一次
                if options.retryOnFailure
                    try
                        pause(1);  % 等待1秒后重试
                        simulator.setVariables(inputValues);
                        success = simulator.run(options.timeout);
                        if success
                            convergency(i) = true;
                            resultData{i} = struct('success', true);
                        end
                    catch
                        % 重试失败，保持失败状态
                    end
                end
            end
        end
        fprintf('\n');

        % 分析收敛性
        numConverged = sum(convergency);
        convergenceRate = numConverged / options.numPoints * 100;
        fprintf('  收敛率: %.1f%% (%d/%d)\n', convergenceRate, numConverged, options.numPoints);

        % 确定可行域
        validIndices = find(convergency);
        if ~isempty(validIndices)
            feasibleMin = testValues(validIndices(1));
            feasibleMax = testValues(validIndices(end));

            % 查找所有连续的可行区间
            feasibleIntervals = findContinuousFeasibleIntervals(testValues, convergency);

            fprintf('  可行域: [%.4f, %.4f]\n', feasibleMin, feasibleMax);
            if size(feasibleIntervals, 1) > 1
                fprintf('  警告: 发现 %d 个不连续的可行区间\n', size(feasibleIntervals, 1));
            end

            feasibleRanges.(varName) = [feasibleMin, feasibleMax];
        else
            fprintf('  警告: 没有找到收敛点！\n');
            feasibleRanges.(varName) = [NaN, NaN];
            feasibleIntervals = [];
        end

        % 保存扫描结果
        scanResults.(varName) = struct(...
            'testValues', testValues, ...
            'convergency', convergency, ...
            'convergenceRate', convergenceRate, ...
            'feasibleRange', feasibleRanges.(varName), ...
            'feasibleIntervals', feasibleIntervals, ...
            'resultData', {resultData});

        % 导出结果
        if options.enableExport
            exportVariableResults(varName, scanResults.(varName), options.outputDir);
        end

        % 绘制图形
        if options.enablePlot
            plotVariableResults(varName, var, scanResults.(varName), options.outputDir);
        end

        fprintf('\n');
    end

    %% 生成综合报告
    fprintf('[步骤 %d/%d] 生成综合报告...\n', numVars + 2, numVars + 2);

    if options.enableExport
        exportSummaryReport(feasibleRanges, scanResults, options.outputDir);
    end

    if options.enablePlot
        plotSummaryFigure(variables, scanResults, options.outputDir);
    end

    fprintf('\n========================================\n');
    fprintf('可行域扫描完成\n');
    fprintf('========================================\n');
    displayFeasibleRangesSummary(variables, feasibleRanges);
    fprintf('========================================\n\n');

end

%% 辅助函数

function intervals = findContinuousFeasibleIntervals(testValues, convergency)
    % 查找所有连续的可行区间

    intervals = [];

    validIndices = find(convergency);
    if isempty(validIndices)
        return;
    end

    % 检测不连续点
    gaps = find(diff(validIndices) > 1);

    if isempty(gaps)
        % 只有一个连续区间
        intervals = [testValues(validIndices(1)), testValues(validIndices(end))];
    else
        % 有多个不连续区间
        numIntervals = length(gaps) + 1;
        intervals = zeros(numIntervals, 2);

        startIdx = 1;
        for i = 1:length(gaps)
            endIdx = gaps(i);
            intervals(i, :) = [testValues(validIndices(startIdx)), testValues(validIndices(endIdx))];
            startIdx = endIdx + 1;
        end
        % 最后一个区间
        intervals(end, :) = [testValues(validIndices(startIdx)), testValues(validIndices(end))];
    end
end

function exportVariableResults(varName, scanResult, outputDir)
    % 导出单个变量的结果到CSV和JSON

    % CSV导出
    csvFilename = fullfile(outputDir, sprintf('%s_feasibility.csv', varName));

    % 构建表格数据
    data = [scanResult.testValues', double(scanResult.convergency)];
    headers = {varName, 'Converged'};

    % 写入CSV
    fid = fopen(csvFilename, 'w');
    fprintf(fid, '%s,%s\n', headers{:});
    for i = 1:size(data, 1)
        fprintf(fid, '%.6f,%d\n', data(i, 1), data(i, 2));
    end
    fclose(fid);

    % JSON导出
    jsonFilename = fullfile(outputDir, sprintf('%s_feasibility.json', varName));

    jsonData = struct();
    jsonData.variableName = varName;
    jsonData.testValues = scanResult.testValues;
    jsonData.convergency = scanResult.convergency;
    jsonData.convergenceRate = scanResult.convergenceRate;
    jsonData.feasibleRange = scanResult.feasibleRange;
    if ~isempty(scanResult.feasibleIntervals)
        jsonData.feasibleIntervals = scanResult.feasibleIntervals;
    end

    % 写入JSON
    jsonStr = jsonencode(jsonData);
    fid = fopen(jsonFilename, 'w');
    fprintf(fid, '%s', jsonStr);
    fclose(fid);
end

function plotVariableResults(varName, variable, scanResult, outputDir)
    % 绘制单个变量的可行性图

    figure('Visible', 'off', 'Position', [100, 100, 800, 400]);

    testValues = scanResult.testValues;
    convergency = scanResult.convergency;

    % 绘制收敛点（绿色圆圈）
    validIdx = find(convergency);
    if ~isempty(validIdx)
        plot(testValues(validIdx), ones(length(validIdx), 1), 'go', ...
            'MarkerSize', 8, 'MarkerFaceColor', 'g', 'LineWidth', 1.5);
        hold on;
    end

    % 绘制失败点（红色叉）
    failIdx = find(~convergency);
    if ~isempty(failIdx)
        plot(testValues(failIdx), zeros(length(failIdx), 1), 'rx', ...
            'MarkerSize', 10, 'LineWidth', 2);
        hold on;
    end

    % 标记可行域
    if ~isnan(scanResult.feasibleRange(1))
        ylim([-0.5, 1.5]);
        % 绘制可行域区间
        fill([scanResult.feasibleRange(1), scanResult.feasibleRange(2), ...
              scanResult.feasibleRange(2), scanResult.feasibleRange(1)], ...
             [-0.5, -0.5, 1.5, 1.5], 'g', 'FaceAlpha', 0.1, 'EdgeColor', 'none');
    end

    xlabel(varName, 'FontSize', 12);
    ylabel('收敛状态', 'FontSize', 12);
    title(sprintf('%s 可行域扫描 (收敛率: %.1f%%)', varName, scanResult.convergenceRate), ...
        'FontSize', 14, 'FontWeight', 'bold');

    set(gca, 'YTick', [0, 1], 'YTickLabel', {'失败', '收敛'});
    grid on;
    legend('收敛', '失败', 'Location', 'best');

    % 保存图形
    pngFilename = fullfile(outputDir, sprintf('%s_feasibility.png', varName));
    saveas(gcf, pngFilename);
    close(gcf);
end

function exportSummaryReport(feasibleRanges, scanResults, outputDir)
    % 导出综合报告

    varNames = fieldnames(feasibleRanges);

    % CSV报告
    csvFilename = fullfile(outputDir, 'feasibility_summary.csv');
    fid = fopen(csvFilename, 'w');
    fprintf(fid, 'Variable,FeasibleMin,FeasibleMax,ConvergenceRate\n');

    for i = 1:length(varNames)
        varName = varNames{i};
        range = feasibleRanges.(varName);
        convRate = scanResults.(varName).convergenceRate;

        fprintf(fid, '%s,%.6f,%.6f,%.2f\n', ...
            varName, range(1), range(2), convRate);
    end
    fclose(fid);

    % JSON报告
    jsonFilename = fullfile(outputDir, 'feasibility_summary.json');

    summaryData = struct();
    summaryData.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    summaryData.feasibleRanges = feasibleRanges;

    % 简化的扫描结果（不包含详细数据）
    simplifiedResults = struct();
    for i = 1:length(varNames)
        varName = varNames{i};
        simplifiedResults.(varName) = struct(...
            'convergenceRate', scanResults.(varName).convergenceRate, ...
            'feasibleRange', scanResults.(varName).feasibleRange);
    end
    summaryData.scanResults = simplifiedResults;

    jsonStr = jsonencode(summaryData);
    fid = fopen(jsonFilename, 'w');
    fprintf(fid, '%s', jsonStr);
    fclose(fid);
end

function plotSummaryFigure(variables, scanResults, outputDir)
    % 绘制所有变量的综合图

    numVars = length(variables);

    figure('Visible', 'off', 'Position', [100, 100, 1200, 800]);

    for i = 1:numVars
        var = variables{i};
        varName = var.name;
        result = scanResults.(varName);

        subplot(ceil(numVars/2), 2, i);

        % 绘制收敛点
        validIdx = find(result.convergency);
        if ~isempty(validIdx)
            plot(result.testValues(validIdx), ones(length(validIdx), 1), 'go', ...
                'MarkerSize', 6, 'MarkerFaceColor', 'g');
            hold on;
        end

        % 绘制失败点
        failIdx = find(~result.convergency);
        if ~isempty(failIdx)
            plot(result.testValues(failIdx), zeros(length(failIdx), 1), 'rx', ...
                'MarkerSize', 8, 'LineWidth', 1.5);
        end

        ylim([-0.5, 1.5]);
        set(gca, 'YTick', [0, 1], 'YTickLabel', {'失败', '收敛'});
        xlabel(varName);
        title(sprintf('%s (%.1f%%)', varName, result.convergenceRate), 'FontSize', 10);
        grid on;
    end

    sgtitle('所有变量可行域扫描综合结果', 'FontSize', 14, 'FontWeight', 'bold');

    % 保存图形
    pngFilename = fullfile(outputDir, 'all_variables_feasibility.png');
    saveas(gcf, pngFilename);
    close(gcf);
end

function displayFeasibleRangesSummary(variables, feasibleRanges)
    % 在控制台显示可行域汇总

    fprintf('\n可行域汇总:\n');
    fprintf('%-15s | %-20s | %-20s\n', '变量', '原始范围', '可行域');
    fprintf('%s\n', repmat('-', 1, 60));

    for i = 1:length(variables)
        var = variables{i};
        varName = var.name;
        bounds = var.getBounds();

        if isfield(feasibleRanges, varName)
            feasRange = feasibleRanges.(varName);
            if ~isnan(feasRange(1))
                fprintf('%-15s | [%.4f, %.4f] | [%.4f, %.4f]\n', ...
                    varName, bounds(1), bounds(2), feasRange(1), feasRange(2));
            else
                fprintf('%-15s | [%.4f, %.4f] | 未找到可行域\n', ...
                    varName, bounds(1), bounds(2));
            end
        end
    end
end

function cleanupSimulator(simulator)
    % 清理仿真器资源
    try
        if ~isempty(simulator)
            simulator.disconnect();
            fprintf('\n仿真器已断开连接\n');
        end
    catch ME
        warning('scan_feasible_regions:CleanupFailed', ...
            '清理仿真器时出错: %s', ME.message);
    end
end
