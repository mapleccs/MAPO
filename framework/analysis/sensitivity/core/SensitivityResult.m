classdef SensitivityResult < handle
    % SensitivityResult - 灵敏度分析结果类
    %
    % 描述:
    %   存储单个变量的灵敏度分析结果
    %   提供结果查询、可行域计算和数据导出功能
    %
    % 作者: MAPO Framework
    % 日期: 2024

    properties
        variableName        % 变量名称
        variableDisplayName % 显示名称
        variableUnit        % 单位
        testValues          % 测试值数组
        convergency         % 收敛性数组（布尔）
        outputs             % 原始输出矩阵
        metrics             % 计算后的指标结构体
        feasibleRange       % 可行域 [min, max]
        convergenceRate     % 收敛率
        timestamp           % 分析时间戳
        metadata            % 额外元数据
    end

    methods
        function obj = SensitivityResult()
            % 构造函数
            obj.timestamp = datetime('now');
            obj.metadata = struct();
        end

        function calculateMetrics(obj)
            % 计算性能指标和统计信息

            if isempty(obj.convergency)
                return;
            end

            % 计算收敛率
            obj.convergenceRate = sum(obj.convergency) / length(obj.convergency);

            % 计算可行域（默认阈值为0，即任何收敛点）
            obj.feasibleRange = obj.getFeasibleRange(0);

            % 存储额外统计信息
            obj.metadata.totalTests = length(obj.testValues);
            obj.metadata.convergedCount = sum(obj.convergency);
            obj.metadata.failedCount = sum(~obj.convergency);

            % 如果有输出数据，计算统计指标
            if ~isempty(obj.outputs)
                convergedIdx = find(obj.convergency);
                if ~isempty(convergedIdx)
                    convergedOutputs = obj.outputs(convergedIdx, :);

                    % 对每个输出列计算统计
                    numOutputs = size(obj.outputs, 2);
                    for i = 1:numOutputs
                        colData = convergedOutputs(:, i);
                        obj.metadata.outputStats(i) = struct(...
                            'mean', mean(colData, 'omitnan'), ...
                            'std', std(colData, 'omitnan'), ...
                            'min', min(colData), ...
                            'max', max(colData), ...
                            'range', max(colData) - min(colData));
                    end
                end
            end
        end

        function [minVal, maxVal] = getFeasibleRange(obj, threshold)
            % 获取可行域
            %
            % 输入:
            %   threshold - 收敛率阈值，默认0.7 (70%)
            %
            % 输出:
            %   minVal - 可行域最小值
            %   maxVal - 可行域最大值

            if nargin < 2
                threshold = 0.7;
            end

            % 如果收敛率低于阈值，返回空
            if obj.convergenceRate < threshold
                minVal = [];
                maxVal = [];
                return;
            end

            % 找到收敛的点
            convergedIdx = find(obj.convergency);

            if isempty(convergedIdx)
                minVal = [];
                maxVal = [];
            else
                % 找到连续收敛区间
                minVal = obj.testValues(convergedIdx(1));
                maxVal = obj.testValues(convergedIdx(end));

                % 检查是否有断点（不连续的收敛区间）
                if length(convergedIdx) > 1
                    diffs = diff(convergedIdx);
                    if any(diffs > 1)
                        % 存在不连续区间，找最长的连续区间
                        [minVal, maxVal] = obj.findLongestContinuousRange(convergedIdx);
                    end
                end
            end
        end

        function saveToFile(obj, filepath)
            % 保存到MAT文件
            %
            % 输入:
            %   filepath - 文件路径

            if nargin < 2
                filepath = sprintf('%s_sensitivity.mat', obj.variableName);
            end

            % 创建保存结构体
            saveData = struct();
            saveData.variableName = obj.variableName;
            saveData.variableDisplayName = obj.variableDisplayName;
            saveData.variableUnit = obj.variableUnit;
            saveData.testValues = obj.testValues;
            saveData.convergency = obj.convergency;
            saveData.outputs = obj.outputs;
            saveData.metrics = obj.metrics;
            saveData.feasibleRange = obj.feasibleRange;
            saveData.convergenceRate = obj.convergenceRate;
            saveData.timestamp = obj.timestamp;
            saveData.metadata = obj.metadata;

            save(filepath, 'saveData', '-v7.3');
        end

        function report = generateTextReport(obj)
            % 生成文本报告
            %
            % 输出:
            %   report - 文本报告字符串

            report = sprintf('灵敏度分析报告 - %s\n', obj.variableName);
            report = [report, sprintf('=' * ones(1, 50)), '\n'];
            report = [report, sprintf('分析时间: %s\n', char(obj.timestamp))];
            report = [report, sprintf('变量单位: %s\n', obj.variableUnit)];
            report = [report, sprintf('测试范围: [%.4f, %.4f]\n', ...
                min(obj.testValues), max(obj.testValues))];
            report = [report, sprintf('测试点数: %d\n', length(obj.testValues))];
            report = [report, sprintf('收敛点数: %d\n', sum(obj.convergency))];
            report = [report, sprintf('收敛率: %.2f%%\n', obj.convergenceRate * 100)];

            if ~isempty(obj.feasibleRange)
                report = [report, sprintf('可行域: [%.4f, %.4f]\n', ...
                    obj.feasibleRange(1), obj.feasibleRange(2))];
            else
                report = [report, sprintf('可行域: 无法确定\n')];
            end

            % 添加输出统计信息
            if isfield(obj.metadata, 'outputStats') && ~isempty(obj.metadata.outputStats)
                report = [report, sprintf('\n输出统计:\n')];
                for i = 1:length(obj.metadata.outputStats)
                    stats = obj.metadata.outputStats(i);
                    report = [report, sprintf('  输出 %d:\n', i)];
                    report = [report, sprintf('    均值: %.4f\n', stats.mean)];
                    report = [report, sprintf('    标准差: %.4f\n', stats.std)];
                    report = [report, sprintf('    范围: [%.4f, %.4f]\n', ...
                        stats.min, stats.max)];
                end
            end
        end

        function exportToCSV(obj, filepath)
            % 导出到CSV文件
            %
            % 输入:
            %   filepath - CSV文件路径

            if nargin < 2
                filepath = sprintf('%s_sensitivity.csv', obj.variableName);
            end

            % 创建表格
            T = table();
            T.TestValue = obj.testValues(:);
            T.Converged = obj.convergency(:);

            % 添加输出列
            if ~isempty(obj.outputs)
                numOutputs = size(obj.outputs, 2);
                for i = 1:numOutputs
                    colName = sprintf('Output%d', i);
                    T.(colName) = obj.outputs(:, i);
                end
            end

            % 写入CSV
            writetable(T, filepath);
        end
    end

    methods (Access = private)
        function [minVal, maxVal] = findLongestContinuousRange(obj, convergedIdx)
            % 找到最长的连续收敛区间
            %
            % 输入:
            %   convergedIdx - 收敛点的索引
            %
            % 输出:
            %   minVal - 最长区间的最小值
            %   maxVal - 最长区间的最大值

            % 找到所有连续段
            segments = {};
            currentSegment = convergedIdx(1);

            for i = 2:length(convergedIdx)
                if convergedIdx(i) == convergedIdx(i-1) + 1
                    % 连续
                    currentSegment = [currentSegment, convergedIdx(i)];
                else
                    % 断开，保存当前段并开始新段
                    segments{end+1} = currentSegment;
                    currentSegment = convergedIdx(i);
                end
            end
            segments{end+1} = currentSegment;

            % 找最长的段
            maxLength = 0;
            longestSegment = [];
            for i = 1:length(segments)
                if length(segments{i}) > maxLength
                    maxLength = length(segments{i});
                    longestSegment = segments{i};
                end
            end

            if ~isempty(longestSegment)
                minVal = obj.testValues(longestSegment(1));
                maxVal = obj.testValues(longestSegment(end));
            else
                minVal = [];
                maxVal = [];
            end
        end
    end
end