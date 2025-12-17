classdef ResultsSaver < handle
    %% ResultsSaver - 优化结果保存辅助类
    %
    % 提供与 run_case.m 一致的结果保存功能，供 GUI 调用。
    % GUI 在收到最终结果后，可选择性地调用此类保存文件。
    %
    % 功能：
    %   - 创建结果目录
    %   - 保存 MAT 文件（完整结果）
    %   - 保存 Pareto 解为 CSV
    %   - 保存所有评估解为 CSV
    %   - 绘制并保存 Pareto 前沿图（PNG）
    %   - 生成优化报告（TXT）
    %   - 备份配置文件
    %
    % 用法：
    %   % 方式 1: 保存全部
    %   resultsDir = ResultsSaver.saveAll(results, config, elapsedTime, baseDir);
    %
    %   % 方式 2: 分步保存
    %   saver = ResultsSaver(results, config, elapsedTime);
    %   saver.createDirectory(baseDir);
    %   saver.saveMATFile();
    %   saver.saveParetoCSV();
    %   saver.savePlot();
    %   saver.saveReport();
    %
    % 示例：
    %   % 在 GUI 的 handleOptimizationData 中：
    %   if data.isFinal
    %       results = data.results;
    %       [file, path] = uiputfile('*.mat', 'Save Results As');
    %       if file ~= 0
    %           baseDir = path;
    %           ResultsSaver.saveAll(results, app.config, elapsedTime, baseDir);
    %       end
    %   end

    properties (Access = private)
        results;        % 优化结果结构体
        config;         % 配置结构体
        elapsedTime;    % 优化用时（秒）
        resultsDir;     % 结果目录路径
    end

    methods
        function obj = ResultsSaver(results, config, elapsedTime)
            %% ResultsSaver - 构造函数
            %
            % Input:
            %   results     - 优化结果结构体
            %   config      - 配置结构体（从 ConfigBuilder 生成）
            %   elapsedTime - 优化耗时（秒）

            obj.results = results;
            obj.config = config;
            obj.elapsedTime = elapsedTime;
            obj.resultsDir = '';
        end

        function createDirectory(obj, baseDir)
            %% createDirectory - 创建结果目录
            %
            % Input:
            %   baseDir - 基础目录（默认为 pwd）
            %
            % 目录命名格式：{problemName}_{timestamp}

            if nargin < 2
                baseDir = pwd;
            end

            timestamp = datestr(now, 'yyyymmdd_HHMMSS');
            dirName = sprintf('%s_%s', obj.config.problem.name, timestamp);
            obj.resultsDir = fullfile(baseDir, 'results', dirName);

            if ~exist(obj.resultsDir, 'dir')
                mkdir(obj.resultsDir);
            end

            fprintf('[ResultsSaver] Results directory: %s\n', obj.resultsDir);
        end

        function filePath = saveMATFile(obj)
            %% saveMATFile - 保存 MATLAB 数据文件
            %
            % Output:
            %   filePath - 保存的 MAT 文件路径

            if isempty(obj.resultsDir)
                error('ResultsSaver:NoDirectory', 'Call createDirectory() first');
            end

            results = obj.results;
            config = obj.config;
            elapsedTime = obj.elapsedTime;

            filePath = fullfile(obj.resultsDir, 'optimization_results.mat');
            save(filePath, 'results', 'config', 'elapsedTime');

            fprintf('[ResultsSaver] MAT file saved: %s\n', filePath);
        end

        function filePath = saveParetoCSV(obj)
            %% saveParetoCSV - 保存 Pareto 解为 CSV
            %
            % Output:
            %   filePath - 保存的 CSV 文件路径（多目标时）或 [] （单目标时）

            filePath = [];

            if isempty(obj.resultsDir)
                error('ResultsSaver:NoDirectory', 'Call createDirectory() first');
            end

            % 判断是否为多目标优化
            isMultiObjective = false;
            if isfield(obj.config, 'problem')
                % 方法 1: 通过 problemType 字段判断
                if isfield(obj.config.problem, 'problemType') && ...
                   strcmpi(obj.config.problem.problemType, 'multi-objective')
                    isMultiObjective = true;
                % 方法 2: 通过目标数量判断
                elseif isfield(obj.config.problem, 'objectives') && ...
                       length(obj.config.problem.objectives) > 1
                    isMultiObjective = true;
                end
            end

            % 仅多目标优化且存在 Pareto 前沿时保存
            if ~isMultiObjective || ...
               ~isfield(obj.results, 'paretoFront') || ...
               isempty(obj.results.paretoFront)
                return;
            end

            % 提取 Pareto 解
            if isa(obj.results.paretoFront, 'Population')
                paretoIndividuals = obj.results.paretoFront.getAll();
            else
                paretoIndividuals = obj.results.paretoFront;
            end

            numParetoSolutions = length(paretoIndividuals);

            if numParetoSolutions == 0
                return;
            end

            % 提取变量和目标值
            paretoVars = [];
            paretoObjs = [];

            for i = 1:numParetoSolutions
                ind = paretoIndividuals(i);
                vars = ind.getVariables();
                objs = ind.getObjectives();

                % 处理最大化目标（转换回正值）
                for j = 1:length(obj.config.problem.objectives)
                    if strcmpi(obj.config.problem.objectives(j).type, 'maximize')
                        objs(j) = -objs(j);
                    end
                end

                paretoVars = [paretoVars; vars];
                paretoObjs = [paretoObjs; objs];
            end

            % 创建列名
            varNames = cell(1, length(obj.config.problem.variables));
            for i = 1:length(obj.config.problem.variables)
                varNames{i} = obj.config.problem.variables(i).name;
            end

            objNames = cell(1, length(obj.config.problem.objectives));
            for i = 1:length(obj.config.problem.objectives)
                objNames{i} = obj.config.problem.objectives(i).name;
            end

            columnNames = [varNames, objNames];
            paretoData = [paretoVars, paretoObjs];

            % 保存 CSV
            paretoTable = array2table(paretoData, 'VariableNames', columnNames);
            filePath = fullfile(obj.resultsDir, 'pareto_solutions.csv');
            writetable(paretoTable, filePath);

            fprintf('[ResultsSaver] Pareto CSV saved: %s\n', filePath);
        end

        function filePath = saveAllSolutionsCSV(obj)
            %% saveAllSolutionsCSV - 保存所有评估过的解为 CSV
            %
            % Output:
            %   filePath - 保存的 CSV 文件路径或 []

            filePath = [];

            if isempty(obj.resultsDir)
                error('ResultsSaver:NoDirectory', 'Call createDirectory() first');
            end

            % 获取所有个体
            if isfield(obj.results, 'allEvaluatedIndividuals')
                allIndividuals = obj.results.allEvaluatedIndividuals;
            elseif isfield(obj.results, 'population')
                if isa(obj.results.population, 'Population')
                    allIndividuals = obj.results.population.getAll();
                else
                    allIndividuals = obj.results.population;
                end
            else
                return;
            end

            if isempty(allIndividuals)
                return;
            end

            % 提取数据
            allData = [];
            for i = 1:length(allIndividuals)
                ind = allIndividuals(i);
                vars = ind.getVariables();
                objs = ind.getObjectives();

                % 处理最大化目标
                for j = 1:length(obj.config.problem.objectives)
                    if strcmpi(obj.config.problem.objectives(j).type, 'maximize')
                        objs(j) = -objs(j);
                    end
                end

                allData = [allData; vars, objs];
            end

            % 创建列名
            varNames = cell(1, length(obj.config.problem.variables));
            for i = 1:length(obj.config.problem.variables)
                varNames{i} = obj.config.problem.variables(i).name;
            end

            objNames = cell(1, length(obj.config.problem.objectives));
            for i = 1:length(obj.config.problem.objectives)
                objNames{i} = obj.config.problem.objectives(i).name;
            end

            columnNames = [varNames, objNames];

            % 保存 CSV
            allTable = array2table(allData, 'VariableNames', columnNames);
            filePath = fullfile(obj.resultsDir, 'all_solutions.csv');
            writetable(allTable, filePath);

            fprintf('[ResultsSaver] All solutions CSV saved: %s\n', filePath);
        end

        function filePath = savePlot(obj)
            %% savePlot - 绘制并保存 Pareto 前沿图
            %
            % Output:
            %   filePath - 保存的 PNG 文件路径或 []
            %
            % 仅支持 2 目标优化

            filePath = [];

            if isempty(obj.resultsDir)
                error('ResultsSaver:NoDirectory', 'Call createDirectory() first');
            end

            % 检查是否为多目标且存在 Pareto 前沿
            if ~isfield(obj.results, 'paretoFront') || ...
               isempty(obj.results.paretoFront)
                return;
            end

            % 提取 Pareto 解
            if isa(obj.results.paretoFront, 'Population')
                paretoIndividuals = obj.results.paretoFront.getAll();
            else
                paretoIndividuals = obj.results.paretoFront;
            end

            if isempty(paretoIndividuals)
                return;
            end

            % 提取目标值
            paretoObjs = [];
            for i = 1:length(paretoIndividuals)
                ind = paretoIndividuals(i);
                objs = ind.getObjectives();

                % 处理最大化目标
                for j = 1:length(obj.config.problem.objectives)
                    if strcmpi(obj.config.problem.objectives(j).type, 'maximize')
                        objs(j) = -objs(j);
                    end
                end

                paretoObjs = [paretoObjs; objs];
            end

            % 仅绘制 2 目标
            if size(paretoObjs, 2) ~= 2
                fprintf('[ResultsSaver] Plot not saved (only 2-objective supported)\n');
                return;
            end

            % 获取目标名称
            objNames = cell(1, length(obj.config.problem.objectives));
            for i = 1:length(obj.config.problem.objectives)
                objNames{i} = obj.config.problem.objectives(i).name;
            end

            % 绘图
            fig = figure('Position', [100, 100, 800, 600], 'Visible', 'off');
            plot(paretoObjs(:, 1), paretoObjs(:, 2), 'ro-', ...
                 'MarkerSize', 8, 'MarkerFaceColor', 'r', 'LineWidth', 1.5);
            xlabel(objNames{1}, 'FontSize', 12);
            ylabel(objNames{2}, 'FontSize', 12);
            title('Pareto Front', 'FontSize', 14, 'FontWeight', 'bold');
            grid on;

            % 保存
            filePath = fullfile(obj.resultsDir, 'pareto_front.png');
            saveas(fig, filePath);
            close(fig);

            fprintf('[ResultsSaver] Pareto plot saved: %s\n', filePath);
        end

        function filePath = saveReport(obj)
            %% saveReport - 生成优化报告
            %
            % Output:
            %   filePath - 保存的报告文件路径

            if isempty(obj.resultsDir)
                error('ResultsSaver:NoDirectory', 'Call createDirectory() first');
            end

            filePath = fullfile(obj.resultsDir, 'optimization_report.txt');
            fid = fopen(filePath, 'w');

            fprintf(fid, '========================================\n');
            fprintf(fid, 'MAPO Optimization Results Report\n');
            fprintf(fid, '========================================\n\n');

            fprintf(fid, 'Project Information:\n');
            fprintf(fid, '  Name: %s\n', obj.config.problem.name);
            if isfield(obj.config.problem, 'description')
                fprintf(fid, '  Description: %s\n', obj.config.problem.description);
            end
            fprintf(fid, '  Generated: %s\n\n', datestr(now));

            fprintf(fid, 'Optimization Configuration:\n');
            fprintf(fid, '  Algorithm: %s\n', obj.config.algorithm.type);
            fprintf(fid, '  Population Size: %d\n', obj.config.algorithm.parameters.populationSize);
            fprintf(fid, '  Max Generations: %d\n', obj.config.algorithm.parameters.maxGenerations);
            fprintf(fid, '  Number of Variables: %d\n', length(obj.config.problem.variables));
            fprintf(fid, '  Number of Objectives: %d\n\n', length(obj.config.problem.objectives));

            fprintf(fid, 'Execution Statistics:\n');
            fprintf(fid, '  Total Time: %.2f seconds (%.2f minutes)\n', obj.elapsedTime, obj.elapsedTime/60);
            if isfield(obj.results, 'evaluations')
                fprintf(fid, '  Evaluations: %d\n', obj.results.evaluations);
            end
            if isfield(obj.results, 'iterations')
                fprintf(fid, '  Iterations: %d\n', obj.results.iterations);
            end
            if isfield(obj.results, 'paretoFront') && ~isempty(obj.results.paretoFront)
                if isa(obj.results.paretoFront, 'Population')
                    fprintf(fid, '  Pareto Solutions: %d\n', obj.results.paretoFront.size());
                else
                    fprintf(fid, '  Pareto Solutions: %d\n', length(obj.results.paretoFront));
                end
            end

            fprintf(fid, '\nVariable Ranges:\n');
            for i = 1:length(obj.config.problem.variables)
                var = obj.config.problem.variables(i);
                fprintf(fid, '  %s: [%.4f, %.4f]', var.name, var.lowerBound, var.upperBound);
                if isfield(var, 'unit')
                    fprintf(fid, ' %s', var.unit);
                end
                fprintf(fid, '\n');
            end

            fprintf(fid, '\nOptimization Objectives:\n');
            for i = 1:length(obj.config.problem.objectives)
                obj_item = obj.config.problem.objectives(i);
                fprintf(fid, '  %s (%s)', obj_item.name, obj_item.type);
                if isfield(obj_item, 'description')
                    fprintf(fid, ' - %s', obj_item.description);
                end
                fprintf(fid, '\n');
            end

            fclose(fid);

            fprintf('[ResultsSaver] Report saved: %s\n', filePath);
        end

        function copyConfig(obj, configFilePath)
            %% copyConfig - 备份配置文件到结果目录
            %
            % Input:
            %   configFilePath - 原始配置文件路径

            if isempty(obj.resultsDir)
                error('ResultsSaver:NoDirectory', 'Call createDirectory() first');
            end

            if ~exist(configFilePath, 'file')
                warning('ResultsSaver:ConfigNotFound', 'Config file not found: %s', configFilePath);
                return;
            end

            configCopy = fullfile(obj.resultsDir, 'config.json');
            copyfile(configFilePath, configCopy);

            fprintf('[ResultsSaver] Config backup saved: %s\n', configCopy);
        end
    end

    methods (Static)
        function resultsDir = saveAll(results, config, elapsedTime, baseDir, configFilePath)
            %% saveAll - 保存所有结果（静态方法）
            %
            % Input:
            %   results        - 优化结果结构体
            %   config         - 配置结构体
            %   elapsedTime    - 优化耗时（秒）
            %   baseDir        - 基础目录（可选，默认为 pwd）
            %   configFilePath - 配置文件路径（可选，用于备份）
            %
            % Output:
            %   resultsDir - 结果目录路径
            %
            % 示例:
            %   resultsDir = ResultsSaver.saveAll(results, config, 1234.5);
            %   resultsDir = ResultsSaver.saveAll(results, config, 1234.5, 'D:\MyResults');
            %   resultsDir = ResultsSaver.saveAll(results, config, 1234.5, pwd, 'config.json');

            if nargin < 4
                baseDir = pwd;
            end

            saver = ResultsSaver(results, config, elapsedTime);
            saver.createDirectory(baseDir);
            saver.saveMATFile();
            saver.saveParetoCSV();
            saver.saveAllSolutionsCSV();
            saver.savePlot();
            saver.saveReport();

            if nargin >= 5 && ~isempty(configFilePath)
                saver.copyConfig(configFilePath);
            end

            resultsDir = saver.resultsDir;

            fprintf('[ResultsSaver] All results saved to: %s\n', resultsDir);
        end
    end
end
