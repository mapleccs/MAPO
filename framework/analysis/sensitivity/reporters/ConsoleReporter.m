classdef ConsoleReporter < IReporter
    % ConsoleReporter - 控制台报告生成器
    %
    % 描述:
    %   在MATLAB控制台输出灵敏度分析报告
    %
    % 作者: MAPO Framework
    % 日期: 2024

    properties
        showDetails = true      % 是否显示详细信息
        columnWidth = 20        % 列宽度
        precision = 4           % 数值精度
    end

    methods
        function obj = ConsoleReporter(varargin)
            % 构造函数
            %
            % 可选参数（名称-值对）:
            %   'ShowDetails' - 是否显示详细信息
            %   'ColumnWidth' - 列宽度
            %   'Precision' - 数值精度

            if nargin > 0
                p = inputParser;
                addParameter(p, 'ShowDetails', true, @islogical);
                addParameter(p, 'ColumnWidth', 20, @(x) x > 5);
                addParameter(p, 'Precision', 4, @(x) x >= 0);
                parse(p, varargin{:});

                obj.showDetails = p.Results.ShowDetails;
                obj.columnWidth = p.Results.ColumnWidth;
                obj.precision = p.Results.Precision;
            end
        end

        function generate(obj, context)
            % 生成控制台报告
            %
            % 输入:
            %   context - SensitivityContext对象

            obj.printHeader(context);
            obj.printSummary(context);
            obj.printResults(context);
            obj.printFooter(context);
        end
    end

    methods (Access = private)
        function printHeader(obj, context)
            % 打印报告头
            fprintf('\n');
            fprintf('========================================\n');
            fprintf('        灵敏度分析报告\n');
            fprintf('========================================\n');
            fprintf('生成时间: %s\n', char(datetime('now')));
            fprintf('问题名称: %s\n', context.problem.name);
            fprintf('\n');
        end

        function printSummary(obj, context)
            % 打印摘要信息
            summary = context.getSummary();

            fprintf('分析摘要\n');
            fprintf('----------------------------------------\n');
            fprintf('总变量数: %d\n', summary.totalVariables);
            fprintf('已完成: %d\n', summary.completedAnalyses);
            fprintf('待完成: %d\n', summary.pendingAnalyses);
            fprintf('\n');
        end

        function printResults(obj, context)
            % 打印分析结果
            fprintf('分析结果\n');
            fprintf('----------------------------------------\n');

            % 创建表头
            headers = {'变量名称', '测试范围', '收敛率', '可行域'};
            formatStr = '';
            for i = 1:length(headers)
                formatStr = [formatStr, sprintf('%%-%ds | ', obj.columnWidth)];
            end
            formatStr = [formatStr(1:end-3), '\n'];  % 移除最后的 ' | '

            % 打印表头
            fprintf(formatStr, headers{:});
            fprintf('%s\n', repmat('-', 1, (obj.columnWidth + 3) * length(headers) - 3));

            % 打印每个变量的结果
            variables = context.problem.variables;
            for i = 1:length(variables)
                varName = variables(i).name;
                result = context.getResult(varName);

                if ~isempty(result)
                    obj.printVariableResult(varName, result, formatStr);
                else
                    obj.printEmptyResult(varName, formatStr);
                end
            end
            fprintf('\n');

            % 如果需要，打印详细信息
            if obj.showDetails
                obj.printDetailedResults(context);
            end
        end

        function printVariableResult(obj, varName, result, formatStr)
            % 打印单个变量的结果

            % 测试范围
            testRange = sprintf('[%.2f, %.2f]', ...
                min(result.testValues), max(result.testValues));

            % 收敛率
            convRate = sprintf('%.1f%%', result.convergenceRate * 100);

            % 可行域
            if ~isempty(result.feasibleRange)
                feasRange = sprintf('[%.2f, %.2f]', ...
                    result.feasibleRange(1), result.feasibleRange(2));
            else
                feasRange = 'N/A';
            end

            fprintf(formatStr, varName, testRange, convRate, feasRange);
        end

        function printEmptyResult(obj, varName, formatStr)
            % 打印空结果
            fprintf(formatStr, varName, 'N/A', 'N/A', 'N/A');
        end

        function printDetailedResults(obj, context)
            % 打印详细结果
            fprintf('详细结果\n');
            fprintf('----------------------------------------\n');

            variables = context.problem.variables;
            for i = 1:length(variables)
                varName = variables(i).name;
                result = context.getResult(varName);

                if ~isempty(result)
                    fprintf('\n变量: %s\n', varName);
                    fprintf('  测试点数: %d\n', length(result.testValues));
                    fprintf('  收敛点数: %d\n', sum(result.convergency));

                    if isfield(result.metadata, 'outputStats') && ~isempty(result.metadata.outputStats)
                        fprintf('  输出统计:\n');
                        for j = 1:length(result.metadata.outputStats)
                            stats = result.metadata.outputStats(j);
                            fprintf('    输出%d - 均值:%.4f, 标准差:%.4f, 范围:[%.4f, %.4f]\n', ...
                                j, stats.mean, stats.std, stats.min, stats.max);
                        end
                    end
                end
            end
            fprintf('\n');
        end

        function printFooter(obj, context)
            % 打印报告尾
            fprintf('========================================\n');
            fprintf('报告生成完成\n');
            fprintf('========================================\n\n');
        end
    end
end