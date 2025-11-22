classdef PlotReporter < IReporter
    % PlotReporter - 图形报告生成器
    %
    % 描述:
    %   生成灵敏度分析的图形报告
    %   为每个变量创建灵敏度曲线图
    %
    % 作者: MAPO Framework
    % 日期: 2024

    properties
        outputDirectory = 'results'    % 输出目录
        figureSize = [1200, 600]      % 图形大小 [宽, 高]
        dpi = 300                      % 分辨率（DPI）
        showUnconverged = true         % 是否显示不收敛的点
        convergedStyle = 'b-o'         % 收敛点的样式
        unconvergedStyle = 'ro'        % 不收敛点的样式
        fontSize = 12                  % 字体大小
        gridOn = true                  % 是否显示网格
    end

    methods
        function obj = PlotReporter(varargin)
            % 构造函数
            %
            % 可选参数（名称-值对）:
            %   'OutputDirectory' - 输出目录
            %   'FigureSize' - 图形大小 [宽, 高]
            %   'DPI' - 分辨率
            %   'ShowUnconverged' - 是否显示不收敛的点
            %   'FontSize' - 字体大小

            if nargin > 0
                p = inputParser;
                addParameter(p, 'OutputDirectory', 'results', @ischar);
                addParameter(p, 'FigureSize', [1200, 600], @(x) length(x) == 2);
                addParameter(p, 'DPI', 300, @(x) x > 0);
                addParameter(p, 'ShowUnconverged', true, @islogical);
                addParameter(p, 'FontSize', 12, @(x) x > 0);
                parse(p, varargin{:});

                obj.outputDirectory = p.Results.OutputDirectory;
                obj.figureSize = p.Results.FigureSize;
                obj.dpi = p.Results.DPI;
                obj.showUnconverged = p.Results.ShowUnconverged;
                obj.fontSize = p.Results.FontSize;
            end
        end

        function generate(obj, context)
            % 生成图形报告
            %
            % 输入:
            %   context - SensitivityContext对象

            % 创建输出目录
            if ~exist(obj.outputDirectory, 'dir')
                mkdir(obj.outputDirectory);
            end

            % 为每个变量生成图形
            variables = context.problem.variables;
            objectives = context.problem.objectives;

            for i = 1:length(variables)
                varName = variables(i).name;
                result = context.getResult(varName);

                if ~isempty(result)
                    obj.plotVariableSensitivity(result, objectives);

                    % 保存图形
                    filename = fullfile(obj.outputDirectory, ...
                        sprintf('sensitivity_%s.png', varName));
                    print(gcf, filename, '-dpng', sprintf('-r%d', obj.dpi));
                    close(gcf);

                    fprintf('  图形已保存: %s\n', filename);
                end
            end

            % 生成综合对比图
            obj.plotComparison(context);
        end
    end

    methods (Access = private)
        function plotVariableSensitivity(obj, result, objectives)
            % 绘制单个变量的灵敏度曲线

            % 创建图形
            fig = figure('Position', [100, 100, obj.figureSize]);
            set(fig, 'Color', 'white');

            % 确定子图数量
            numObjectives = length(objectives);
            if numObjectives == 0 || isempty(result.outputs)
                numObjectives = size(result.outputs, 2);
                if numObjectives == 0
                    numObjectives = 1;
                end
            end

            % 为每个目标创建子图
            for j = 1:numObjectives
                subplot(1, numObjectives, j);
                obj.plotSingleObjective(result, j, objectives);
            end

            % 添加总标题
            sgtitle(sprintf('灵敏度分析: %s', result.variableName), ...
                'FontSize', obj.fontSize + 2, 'Interpreter', 'none');
        end

        function plotSingleObjective(obj, result, objIndex, objectives)
            % 绘制单个目标的灵敏度曲线

            testValues = result.testValues;
            convergency = result.convergency;

            % 获取输出数据
            if ~isempty(result.outputs) && size(result.outputs, 2) >= objIndex
                outputData = result.outputs(:, objIndex);
            else
                outputData = NaN(size(testValues));
            end

            % 分离收敛和不收敛的点
            convergedIdx = find(convergency);
            unconvergedIdx = find(~convergency);

            % 绘制收敛的点
            if ~isempty(convergedIdx)
                plot(testValues(convergedIdx), outputData(convergedIdx), ...
                    obj.convergedStyle, 'LineWidth', 1.5, 'MarkerSize', 6);
                hold on;
            end

            % 绘制不收敛的点
            if obj.showUnconverged && ~isempty(unconvergedIdx)
                plot(testValues(unconvergedIdx), outputData(unconvergedIdx), ...
                    obj.unconvergedStyle, 'MarkerSize', 8, 'LineWidth', 1.5);
            end

            % 设置标签
            xlabel(sprintf('%s (%s)', result.variableName, result.variableUnit), ...
                'FontSize', obj.fontSize, 'Interpreter', 'none');

            if ~isempty(objectives) && length(objectives) >= objIndex
                ylabel(objectives(objIndex).name, ...
                    'FontSize', obj.fontSize, 'Interpreter', 'none');
            else
                ylabel(sprintf('输出 %d', objIndex), ...
                    'FontSize', obj.fontSize);
            end

            % 设置标题
            title(sprintf('收敛率: %.1f%%', result.convergenceRate * 100), ...
                'FontSize', obj.fontSize);

            % 网格
            if obj.gridOn
                grid on;
            end

            % 图例
            if obj.showUnconverged && ~isempty(unconvergedIdx)
                legend('收敛点', '不收敛点', 'Location', 'best');
            end

            % 调整字体
            set(gca, 'FontSize', obj.fontSize - 2);
        end

        function plotComparison(obj, context)
            % 生成综合对比图

            variables = context.problem.variables;
            if isempty(variables)
                return;
            end

            % 创建图形
            fig = figure('Position', [100, 100, 1400, 800]);
            set(fig, 'Color', 'white');

            % 计算子图布局
            numVars = length(variables);
            rows = ceil(sqrt(numVars));
            cols = ceil(numVars / rows);

            for i = 1:numVars
                varName = variables(i).name;
                result = context.getResult(varName);

                if ~isempty(result)
                    subplot(rows, cols, i);
                    obj.plotComparisonSubplot(result);
                end
            end

            % 添加总标题
            sgtitle('灵敏度分析对比', 'FontSize', obj.fontSize + 2);

            % 保存图形
            filename = fullfile(obj.outputDirectory, 'sensitivity_comparison.png');
            print(fig, filename, '-dpng', sprintf('-r%d', obj.dpi));
            close(fig);

            fprintf('  综合对比图: %s\n', filename);
        end

        function plotComparisonSubplot(obj, result)
            % 绘制对比图的子图

            testValues = result.testValues;
            convergency = result.convergency;

            % 创建收敛率条形图
            bar(1, result.convergenceRate * 100, 'FaceColor', [0.3, 0.6, 0.9]);
            hold on;

            % 添加文本标签
            text(1, result.convergenceRate * 100 / 2, ...
                sprintf('%.1f%%', result.convergenceRate * 100), ...
                'HorizontalAlignment', 'center', 'FontSize', obj.fontSize - 2);

            % 设置标题和标签
            title(result.variableName, 'FontSize', obj.fontSize, ...
                'Interpreter', 'none');
            ylabel('收敛率 (%)', 'FontSize', obj.fontSize - 2);
            xlim([0.5, 1.5]);
            ylim([0, 100]);

            % 添加可行域信息
            if ~isempty(result.feasibleRange)
                text(1, -5, sprintf('[%.2f, %.2f]', ...
                    result.feasibleRange(1), result.feasibleRange(2)), ...
                    'HorizontalAlignment', 'center', 'FontSize', obj.fontSize - 3);
            end

            % 隐藏X轴刻度
            set(gca, 'XTick', []);
        end
    end
end