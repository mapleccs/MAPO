classdef FileReporter < IReporter
    % FileReporter - 文件报告生成器
    %
    % 描述:
    %   将灵敏度分析结果保存到文件（文本和CSV格式）
    %
    % 作者: MAPO Framework
    % 日期: 2024

    properties
        outputDirectory = 'results'    % 输出目录
        filePrefix = 'sensitivity'     % 文件前缀
        saveTextReport = true          % 是否保存文本报告
        saveCSV = true                 % 是否保存CSV文件
        saveMAT = true                 % 是否保存MAT文件
    end

    methods
        function obj = FileReporter(varargin)
            % 构造函数
            %
            % 可选参数（名称-值对）:
            %   'OutputDirectory' - 输出目录
            %   'FilePrefix' - 文件前缀
            %   'SaveTextReport' - 是否保存文本报告
            %   'SaveCSV' - 是否保存CSV文件
            %   'SaveMAT' - 是否保存MAT文件

            if nargin > 0
                p = inputParser;
                addParameter(p, 'OutputDirectory', 'results', @ischar);
                addParameter(p, 'FilePrefix', 'sensitivity', @ischar);
                addParameter(p, 'SaveTextReport', true, @islogical);
                addParameter(p, 'SaveCSV', true, @islogical);
                addParameter(p, 'SaveMAT', true, @islogical);
                parse(p, varargin{:});

                obj.outputDirectory = p.Results.OutputDirectory;
                obj.filePrefix = p.Results.FilePrefix;
                obj.saveTextReport = p.Results.SaveTextReport;
                obj.saveCSV = p.Results.SaveCSV;
                obj.saveMAT = p.Results.SaveMAT;
            end
        end

        function generate(obj, context)
            % 生成文件报告
            %
            % 输入:
            %   context - SensitivityContext对象

            % 创建输出目录
            if ~exist(obj.outputDirectory, 'dir')
                mkdir(obj.outputDirectory);
            end

            % 保存文本报告
            if obj.saveTextReport
                obj.saveTextReportToFile(context);
            end

            % 保存CSV文件
            if obj.saveCSV
                obj.saveResultsToCSV(context);
            end

            % 保存MAT文件
            if obj.saveMAT
                obj.saveResultsToMAT(context);
            end

            fprintf('文件报告已保存到: %s\n', obj.outputDirectory);
        end
    end

    methods (Access = private)
        function saveTextReportToFile(obj, context)
            % 保存文本报告
            filename = fullfile(obj.outputDirectory, ...
                sprintf('%s_report.txt', obj.filePrefix));

            fid = fopen(filename, 'w');
            if fid == -1
                warning('FileReporter:FileError', ...
                    '无法创建文本报告文件: %s', filename);
                return;
            end

            % 写入报告内容
            obj.writeHeader(fid, context);
            obj.writeSummary(fid, context);
            obj.writeResults(fid, context);
            obj.writeFooter(fid, context);

            fclose(fid);
            fprintf('  文本报告: %s\n', filename);
        end

        function writeHeader(obj, fid, context)
            % 写入报告头
            fprintf(fid, '灵敏度分析报告\n');
            fprintf(fid, '========================================\n');
            fprintf(fid, '生成时间: %s\n', char(datetime('now')));
            fprintf(fid, '问题名称: %s\n', context.problem.name);
            fprintf(fid, '\n');
        end

        function writeSummary(obj, fid, context)
            % 写入摘要
            summary = context.getSummary();

            fprintf(fid, '分析摘要\n');
            fprintf(fid, '----------------------------------------\n');
            fprintf(fid, '总变量数: %d\n', summary.totalVariables);
            fprintf(fid, '已完成: %d\n', summary.completedAnalyses);
            fprintf(fid, '待完成: %d\n', summary.pendingAnalyses);
            fprintf(fid, '\n');
        end

        function writeResults(obj, fid, context)
            % 写入结果表格
            fprintf(fid, '分析结果\n');
            fprintf(fid, '----------------------------------------\n');
            fprintf(fid, '%-20s | %-20s | %-12s | %-20s\n', ...
                '变量名称', '测试范围', '收敛率', '可行域');
            fprintf(fid, '%s\n', repmat('-', 1, 80));

            variables = context.problem.variables;
            for i = 1:length(variables)
                varName = variables(i).name;
                result = context.getResult(varName);

                if ~isempty(result)
                    testRange = sprintf('[%.4f, %.4f]', ...
                        min(result.testValues), max(result.testValues));
                    convRate = sprintf('%.2f%%', result.convergenceRate * 100);

                    if ~isempty(result.feasibleRange)
                        feasRange = sprintf('[%.4f, %.4f]', ...
                            result.feasibleRange(1), result.feasibleRange(2));
                    else
                        feasRange = 'N/A';
                    end

                    fprintf(fid, '%-20s | %-20s | %-12s | %-20s\n', ...
                        varName, testRange, convRate, feasRange);
                else
                    fprintf(fid, '%-20s | %-20s | %-12s | %-20s\n', ...
                        varName, 'N/A', 'N/A', 'N/A');
                end
            end
            fprintf(fid, '\n');
        end

        function writeFooter(obj, fid, context)
            % 写入报告尾
            fprintf(fid, '========================================\n');
            fprintf(fid, '报告生成时间: %s\n', char(datetime('now')));
            fprintf(fid, '========================================\n');
        end

        function saveResultsToCSV(obj, context)
            % 保存结果到CSV文件

            variables = context.problem.variables;
            for i = 1:length(variables)
                varName = variables(i).name;
                result = context.getResult(varName);

                if ~isempty(result)
                    filename = fullfile(obj.outputDirectory, ...
                        sprintf('%s_%s.csv', obj.filePrefix, varName));

                    % 创建数据表
                    T = table();
                    T.TestValue = result.testValues(:);
                    T.Converged = double(result.convergency(:));

                    % 添加输出列
                    if ~isempty(result.outputs)
                        numOutputs = size(result.outputs, 2);
                        for j = 1:numOutputs
                            colName = sprintf('Output%d', j);
                            T.(colName) = result.outputs(:, j);
                        end
                    end

                    % 写入CSV
                    writetable(T, filename);
                    fprintf('  CSV文件: %s\n', filename);
                end
            end
        end

        function saveResultsToMAT(obj, context)
            % 保存所有结果到MAT文件
            filename = fullfile(obj.outputDirectory, ...
                sprintf('%s_data.mat', obj.filePrefix));

            % 收集所有数据
            sensitivityData = struct();
            sensitivityData.context = context;
            sensitivityData.problem = context.problem;
            sensitivityData.timestamp = datetime('now');

            % 保存每个变量的结果
            variables = context.problem.variables;
            for i = 1:length(variables)
                varName = variables(i).name;
                result = context.getResult(varName);
                if ~isempty(result)
                    sensitivityData.results.(varName) = result;
                end
            end

            % 保存到MAT文件
            save(filename, 'sensitivityData', '-v7.3');
            fprintf('  MAT文件: %s\n', filename);
        end
    end
end