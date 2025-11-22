function results = run_case(configFile)
%% run_case - 通用优化运行脚本
% 通过单一JSON配置文件运行优化任务
%
% 输入:
%   configFile - 配置文件路径 (默认: 'case_config.json')
%
% 输出:
%   results - 优化结果结构体
%
% 示例:
%   results = run_case('case_config.json');
%   results = run_case('my_custom_config.json');


    %% 参数处理
    if nargin < 1
        configFile = 'case_config.json';
    end

    %% 初始化
    clc;
    fprintf('========================================\n');
    fprintf('MAPO 通用优化框架 v2.0\n');
    fprintf('========================================\n\n');

    % 记录开始时间
    startTime = tic;

    % 初始化变量
    simulator = [];
    results = [];

    try
        %% Step 1: 加载配置文件
        fprintf('[1/8] 加载配置文件...\n');
        if ~exist(configFile, 'file')
            error('配置文件不存在: %s', configFile);
        end

        % 读取JSON配置
        configText = fileread(configFile);
        config = jsondecode(configText);
        fprintf('  配置文件: %s\n', configFile);
        fprintf('  项目名称: %s\n', config.problem.name);

        %% Step 2: 初始化环境
        fprintf('\n[2/8] 初始化环境...\n');

        % 添加框架路径
        frameworkPath = fullfile(fileparts(fileparts(mfilename('fullpath'))), '..', 'framework');
        addpath(genpath(frameworkPath));
        fprintf('  框架路径已添加\n');

        % 创建结果目录
        timestamp = datestr(now, 'yyyymmdd_HHMMSS');
        resultsDir = fullfile(pwd, 'results', sprintf('%s_%s', config.problem.name, timestamp));
        if ~exist(resultsDir, 'dir')
            mkdir(resultsDir);
        end
        fprintf('  结果目录: %s\n', resultsDir);

        % 创建日志目录
        logDir = fullfile(pwd, 'logs');
        if ~exist(logDir, 'dir')
            mkdir(logDir);
        end
        logFile = fullfile(logDir, sprintf('%s_%s.log', config.problem.name, timestamp));
        fprintf('  日志文件: %s\n', logFile);

        %% Step 3: 创建仿真器
        fprintf('\n[3/8] 配置仿真器...\n');

        % 创建仿真器配置
        simConfig = SimulatorConfig(config.simulator.type);

        % 设置基本参数
        settings = config.simulator.settings;
        settingFields = fieldnames(settings);
        for i = 1:length(settingFields)
            field = settingFields{i};
            simConfig.set(field, settings.(field));
        end

        % 设置节点映射
        if isfield(config.simulator, 'nodeMapping')
            % 设置变量映射
            if isfield(config.simulator.nodeMapping, 'variables')
                varNames = fieldnames(config.simulator.nodeMapping.variables);
                for i = 1:length(varNames)
                    varName = varNames{i};
                    nodePath = config.simulator.nodeMapping.variables.(varName);
                    simConfig.setNodeMapping(varName, nodePath);
                end
            end

            % 设置结果映射
            if isfield(config.simulator.nodeMapping, 'results')
                resNames = fieldnames(config.simulator.nodeMapping.results);
                for i = 1:length(resNames)
                    resName = resNames{i};
                    nodePath = config.simulator.nodeMapping.results.(resName);
                    simConfig.setResultMapping(resName, nodePath);
                end
            end
        end

        % 创建仿真器实例
        switch upper(config.simulator.type)
            case 'ASPEN'
                simulator = AspenPlusSimulator();
            case 'MATLAB'
                simulator = MATLABSimulator();
            case 'PYTHON'
                simulator = PythonSimulator();
            otherwise
                error('不支持的仿真器类型: %s', config.simulator.type);
        end

        % 设置日志文件
        simulator.setLogFile(logFile);

        % 连接仿真器
        simulator.connect(simConfig);
        fprintf('  仿真器类型: %s\n', config.simulator.type);
        fprintf('  仿真器连接成功\n');

        %% Step 4: 创建评估器
        fprintf('\n[4/8] 创建评估器...\n');

        evaluatorType = config.problem.evaluator.type;
        evaluatorTimeout = 300;  % 默认超时时间

        if isfield(config.problem.evaluator, 'timeout')
            evaluatorTimeout = config.problem.evaluator.timeout;
        end

        % 使用评估器工厂创建实例
        try
            evaluator = EvaluatorFactory.create(evaluatorType, simulator, evaluatorTimeout);
        catch ME
            % 如果工厂不存在或失败，尝试直接创建
            fprintf('  警告: EvaluatorFactory未找到，尝试直接创建评估器\n');
            switch evaluatorType
                case 'ORCEvaluator'
                    evaluator = ORCEvaluator(simulator);
                case 'ADNProductionEvaluator'
                    evaluator = ADNProductionEvaluator(simulator);
                case 'MyCaseEvaluator'
                    evaluator = MyCaseEvaluator(simulator);
                otherwise
                    error('未知的评估器类型: %s', evaluatorType);
            end
            evaluator.timeout = evaluatorTimeout;
        end

        % 设置经济参数（如果存在）
        if isfield(config.problem.evaluator, 'economicParameters')
            ecoParams = config.problem.evaluator.economicParameters;
            ecoFields = fieldnames(ecoParams);
            for i = 1:length(ecoFields)
                field = ecoFields{i};
                if isprop(evaluator, field)
                    evaluator.(field) = ecoParams.(field);
                end
            end
        end

        fprintf('  评估器类型: %s\n', evaluatorType);
        fprintf('  评估器超时: %d 秒\n', evaluatorTimeout);

        %% Step 5: 定义优化问题
        fprintf('\n[5/8] 定义优化问题...\n');

        problemName = config.problem.name;
        problemDesc = '';
        if isfield(config.problem, 'description')
            problemDesc = config.problem.description;
        end

        problem = OptimizationProblem(problemName, problemDesc);

        % 添加变量
        for i = 1:length(config.problem.variables)
            var = config.problem.variables(i);
            variable = Variable(var.name, var.type, [var.lowerBound, var.upperBound]);

            % 设置可选属性
            if isfield(var, 'unit')
                variable.unit = var.unit;
            end
            if isfield(var, 'description')
                variable.description = var.description;
            end

            problem.addVariable(variable);
        end

        % 添加目标
        for i = 1:length(config.problem.objectives)
            obj = config.problem.objectives(i);

            % 处理类型（maximize转为minimize）
            objType = obj.type;
            if strcmpi(objType, 'maximize')
                objType = 'minimize';  % 内部统一为最小化
            end

            objective = Objective(obj.name, objType);

            % 设置可选属性
            if isfield(obj, 'description')
                objective.description = obj.description;
            end
            if isfield(obj, 'weight')
                objective.weight = obj.weight;
            end

            problem.addObjective(objective);
        end

        % 添加约束（如果存在）
        if isfield(config.problem, 'constraints')
            for i = 1:length(config.problem.constraints)
                con = config.problem.constraints(i);

                switch con.type
                    case 'inequality'
                        if contains(con.expression, '<=')
                            constraint = Constraint.createLessEqual(con.name, 0);
                        else
                            constraint = Constraint.createGreaterEqual(con.name, 0);
                        end
                    case 'equality'
                        constraint = Constraint.createEqual(con.name, 0);
                    otherwise
                        warning('未知的约束类型: %s', con.type);
                        continue;
                end

                if isfield(con, 'description')
                    constraint.description = con.description;
                end

                problem.addConstraint(constraint);
            end
        end

        % 设置问题类型
        if length(config.problem.objectives) > 1
            problem.problemType = 'multi-objective';
        else
            problem.problemType = 'single-objective';
        end

        % 设置评估器
        problem.evaluator = evaluator;

        fprintf('  问题名称: %s\n', problemName);
        fprintf('  变量数: %d\n', problem.getNumberOfVariables());
        fprintf('  目标数: %d\n', problem.getNumberOfObjectives());
        fprintf('  问题类型: %s\n', problem.problemType);

        %% Step 6: 配置优化算法
        fprintf('\n[6/8] 配置优化算法...\n');

        algorithmType = config.algorithm.type;
        algorithmParams = config.algorithm.parameters;

        % 创建算法实例
        switch upper(algorithmType)
            case 'NSGA-II'
                algorithm = NSGAII();
            case 'NSGAII'
                algorithm = NSGAII();
            case 'PSO'
                algorithm = PSO();
            otherwise
                % 尝试使用算法工厂
                try
                    algorithm = AlgorithmFactory.create(algorithmType);
                catch
                    error('不支持的算法类型: %s', algorithmType);
                end
        end

        fprintf('  算法类型: %s\n', algorithmType);
        fprintf('  种群大小: %d\n', algorithmParams.populationSize);
        fprintf('  最大代数: %d\n', algorithmParams.maxGenerations);

        %% Step 7: 运行优化
        fprintf('\n[7/8] 运行优化...\n');
        fprintf('========================================\n');
        fprintf('注意: 每次仿真可能需要较长时间，请耐心等待...\n');
        fprintf('========================================\n\n');

        % 运行优化
        optStartTime = tic;
        results = algorithm.optimize(problem, algorithmParams);
        optElapsedTime = toc(optStartTime);

        fprintf('\n========================================\n');
        fprintf('优化完成！\n');
        fprintf('  总用时: %.2f 秒 (%.2f 分钟)\n', optElapsedTime, optElapsedTime/60);
        fprintf('  评估次数: %d\n', evaluator.getEvaluationCount());
        fprintf('========================================\n');

        %% Step 8: 保存结果
        fprintf('\n[8/8] 保存结果...\n');

        % 保存MATLAB数据
        matFile = fullfile(resultsDir, 'optimization_results.mat');
        save(matFile, 'results', 'config', 'optElapsedTime');
        fprintf('  MATLAB数据: %s\n', matFile);

        % 处理Pareto前沿（多目标优化）
        if strcmpi(problem.problemType, 'multi-objective') && ...
           isfield(results, 'paretoFront') && ~isempty(results.paretoFront)

            % 提取Pareto解
            paretoIndividuals = results.paretoFront.getAll();
            numParetoSolutions = length(paretoIndividuals);

            if numParetoSolutions > 0
                % 提取变量和目标值
                paretoVars = [];
                paretoObjs = [];

                for i = 1:numParetoSolutions
                    ind = paretoIndividuals(i);
                    vars = ind.getVariables();
                    objs = ind.getObjectives();

                    % 处理最大化目标（转换回正值）
                    for j = 1:length(config.problem.objectives)
                        if strcmpi(config.problem.objectives(j).type, 'maximize')
                            objs(j) = -objs(j);
                        end
                    end

                    paretoVars = [paretoVars; vars];
                    paretoObjs = [paretoObjs; objs];
                end

                % 保存Pareto解为CSV
                paretoData = [paretoVars, paretoObjs];

                % 创建列名
                varNames = cell(1, length(config.problem.variables));
                for i = 1:length(config.problem.variables)
                    varNames{i} = config.problem.variables(i).name;
                end

                objNames = cell(1, length(config.problem.objectives));
                for i = 1:length(config.problem.objectives)
                    objNames{i} = config.problem.objectives(i).name;
                end

                columnNames = [varNames, objNames];

                % 创建表格并保存
                paretoTable = array2table(paretoData, 'VariableNames', columnNames);
                csvFile = fullfile(resultsDir, 'pareto_solutions.csv');
                writetable(paretoTable, csvFile);
                fprintf('  Pareto解CSV: %s\n', csvFile);

                % 绘制Pareto前沿（仅限2目标）
                if size(paretoObjs, 2) == 2
                    figure('Position', [100, 100, 800, 600]);
                    plot(paretoObjs(:, 1), paretoObjs(:, 2), 'ro-', ...
                         'MarkerSize', 8, 'MarkerFaceColor', 'r', 'LineWidth', 1.5);
                    xlabel(objNames{1}, 'FontSize', 12);
                    ylabel(objNames{2}, 'FontSize', 12);
                    title('Pareto前沿', 'FontSize', 14, 'FontWeight', 'bold');
                    grid on;

                    pngFile = fullfile(resultsDir, 'pareto_front.png');
                    saveas(gcf, pngFile);
                    close(gcf);
                    fprintf('  Pareto图像: %s\n', pngFile);
                end
            end
        end

        % 保存所有评估过的解
        if isfield(results, 'allEvaluatedIndividuals')
            allIndividuals = results.allEvaluatedIndividuals;
        elseif isfield(results, 'population')
            allIndividuals = results.population.getAll();
        else
            allIndividuals = [];
        end

        if ~isempty(allIndividuals)
            allData = [];
            for i = 1:length(allIndividuals)
                ind = allIndividuals(i);
                vars = ind.getVariables();
                objs = ind.getObjectives();

                % 处理最大化目标
                for j = 1:length(config.problem.objectives)
                    if strcmpi(config.problem.objectives(j).type, 'maximize')
                        objs(j) = -objs(j);
                    end
                end

                allData = [allData; vars, objs];
            end

            % 创建列名
            varNames = cell(1, length(config.problem.variables));
            for i = 1:length(config.problem.variables)
                varNames{i} = config.problem.variables(i).name;
            end

            objNames = cell(1, length(config.problem.objectives));
            for i = 1:length(config.problem.objectives)
                objNames{i} = config.problem.objectives(i).name;
            end

            columnNames = [varNames, objNames];

            % 保存所有解
            allTable = array2table(allData, 'VariableNames', columnNames);
            allCsvFile = fullfile(resultsDir, 'all_solutions.csv');
            writetable(allTable, allCsvFile);
            fprintf('  所有解CSV: %s\n', allCsvFile);
        end

        % 生成报告
        reportFile = fullfile(resultsDir, 'optimization_report.txt');
        generateReport(reportFile, config, results, optElapsedTime, evaluator);
        fprintf('  优化报告: %s\n', reportFile);

        % 保存配置文件副本
        configCopy = fullfile(resultsDir, 'config.json');
        copyfile(configFile, configCopy);
        fprintf('  配置备份: %s\n', configCopy);

        %% 完成
        totalTime = toc(startTime);
        fprintf('\n========================================\n');
        fprintf('任务完成！\n');
        fprintf('  总耗时: %.2f 秒 (%.2f 分钟)\n', totalTime, totalTime/60);
        fprintf('  结果目录: %s\n', resultsDir);
        fprintf('========================================\n\n');

    catch ME
        % 错误处理
        fprintf('\n========================================\n');
        fprintf('错误发生！\n');
        fprintf('  错误信息: %s\n', ME.message);
        fprintf('  错误位置: %s (第 %d 行)\n', ...
                ME.stack(1).file, ME.stack(1).line);
        fprintf('========================================\n\n');

        % 保存错误信息
        if exist('resultsDir', 'var')
            errorFile = fullfile(resultsDir, 'error.txt');
            fid = fopen(errorFile, 'w');
            fprintf(fid, '错误信息: %s\n\n', ME.message);
            fprintf(fid, '调用栈:\n');
            for i = 1:length(ME.stack)
                fprintf(fid, '  %s (第 %d 行)\n', ...
                        ME.stack(i).file, ME.stack(i).line);
            end
            fclose(fid);
        end

        rethrow(ME);

    finally
        % 清理资源
        if ~isempty(simulator) && isvalid(simulator)
            try
                fprintf('\n清理资源...\n');
                simulator.disconnect();
                fprintf('  仿真器已断开\n');
            catch
                % 忽略清理错误
            end
        end
    end
end

%% 辅助函数：生成报告
function generateReport(reportFile, config, results, elapsedTime, evaluator)
    fid = fopen(reportFile, 'w');

    fprintf(fid, '========================================\n');
    fprintf(fid, 'MAPO 优化结果报告\n');
    fprintf(fid, '========================================\n\n');

    fprintf(fid, '项目信息:\n');
    fprintf(fid, '  名称: %s\n', config.problem.name);
    if isfield(config.problem, 'description')
        fprintf(fid, '  描述: %s\n', config.problem.description);
    end
    fprintf(fid, '  生成时间: %s\n\n', datestr(now));

    fprintf(fid, '优化配置:\n');
    fprintf(fid, '  算法: %s\n', config.algorithm.type);
    fprintf(fid, '  种群大小: %d\n', config.algorithm.parameters.populationSize);
    fprintf(fid, '  最大代数: %d\n', config.algorithm.parameters.maxGenerations);
    fprintf(fid, '  变量数: %d\n', length(config.problem.variables));
    fprintf(fid, '  目标数: %d\n\n', length(config.problem.objectives));

    fprintf(fid, '运行统计:\n');
    fprintf(fid, '  总用时: %.2f 秒 (%.2f 分钟)\n', elapsedTime, elapsedTime/60);
    fprintf(fid, '  评估次数: %d\n', evaluator.getEvaluationCount());

    if isfield(results, 'generations')
        fprintf(fid, '  实际运行代数: %d\n', results.generations);
    end

    if isfield(results, 'population')
        fprintf(fid, '  最终种群大小: %d\n', results.population.size());
    end

    if isfield(results, 'paretoFront') && ~isempty(results.paretoFront)
        fprintf(fid, '  Pareto最优解数: %d\n', results.paretoFront.size());
    end

    fprintf(fid, '\n变量范围:\n');
    for i = 1:length(config.problem.variables)
        var = config.problem.variables(i);
        fprintf(fid, '  %s: [%.4f, %.4f]', var.name, var.lowerBound, var.upperBound);
        if isfield(var, 'unit')
            fprintf(fid, ' %s', var.unit);
        end
        fprintf(fid, '\n');
    end

    fprintf(fid, '\n优化目标:\n');
    for i = 1:length(config.problem.objectives)
        obj = config.problem.objectives(i);
        fprintf(fid, '  %s (%s)', obj.name, obj.type);
        if isfield(obj, 'description')
            fprintf(fid, ' - %s', obj.description);
        end
        fprintf(fid, '\n');
    end

    fclose(fid);
end