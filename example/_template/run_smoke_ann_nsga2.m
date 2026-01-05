function results = run_smoke_ann_nsga2()
%% run_smoke_ann_nsga2 - ANN-NSGA-II 冒烟测试（不依赖 Aspen/COM）
%
% 目的:
%   - 快速验证新算法类是否可创建、可运行、可产出 Pareto 结果
%   - 使用内置 ZDT1 测试函数，避免仿真器依赖
%
% 用法:
%   results = run_smoke_ann_nsga2();
%
% 输出:
%   results.nsga2      - NSGA-II 结果结构体
%   results.ann_nsga2  - ANN-NSGA-II 结果结构体

    clc;
    fprintf('========================================\n');
    fprintf('MAPO - ANN-NSGA-II Smoke Test\n');
    fprintf('========================================\n');

    %% 添加框架路径
    thisDir = fileparts(mfilename('fullpath'));          % .../example/_template
    projectRoot = fileparts(fileparts(thisDir));         % .../ (project root)
    frameworkPath = fullfile(projectRoot, 'framework');
    addpath(genpath(frameworkPath));

    %% 构建一个简单多目标测试问题（ZDT1）
    problem = OptimizationProblem('ZDT1_Smoke', 'ZDT1 smoke test (2 objectives, no constraints)');

    nVars = 10;
    for i = 1:nVars
        problem.addVariable(Variable(sprintf('x%d', i), 'continuous', [0, 1]));
    end
    problem.addObjective(Objective('f1', 'minimize'));
    problem.addObjective(Objective('f2', 'minimize'));

    evaluator = ZDT1Evaluator();
    problem.setEvaluator(evaluator);
    try
        evaluator.setProblem(problem);
    catch
    end

    %% 运行 NSGA-II（基线）
    nsga2 = AlgorithmFactory.create('NSGA-II');
    nsga2.setVerbose(true);

    paramsNSGA = struct();
    paramsNSGA.populationSize = 40;
    paramsNSGA.maxGenerations = 20;
    paramsNSGA.crossoverRate = 0.9;
    paramsNSGA.mutationRate = 1.0;
    paramsNSGA.crossoverDistIndex = 20;
    paramsNSGA.mutationDistIndex = 20;

    fprintf('\n[1/2] Running NSGA-II...\n');
    results.nsga2 = nsga2.optimize(problem, paramsNSGA);
    reportPareto(results.nsga2, 'NSGA-II');

    %% 运行 ANN-NSGA-II
    ann = AlgorithmFactory.create('ANN-NSGA-II');
    ann.setVerbose(true);

    paramsANN = struct();
    paramsANN.populationSize = 40;
    paramsANN.maxGenerations = 20;
    paramsANN.crossoverRate = 0.9;
    paramsANN.mutationRate = 1.0;

    paramsANN.training = struct();
    paramsANN.training.samples = 100;
    paramsANN.training.maxAttempts = 500;
    paramsANN.training.samplingMethod = 'lhs';
    paramsANN.training.requireSuccess = true;
    paramsANN.training.requireFeasible = false;

    paramsANN.surrogate = struct();
    paramsANN.surrogate.type = 'poly2';
    paramsANN.surrogate.ridgeLambda = 1e-6;

    paramsANN.operators = struct();
    paramsANN.operators.useDynamicOperators = true;

    paramsANN.verification = struct();
    paramsANN.verification.enabled = true;
    paramsANN.verification.verifyParetoFront = false;
    paramsANN.verification.verifyTOPSIS = true;

    fprintf('\n[2/2] Running ANN-NSGA-II...\n');
    results.ann_nsga2 = ann.optimize(problem, paramsANN);
    reportPareto(results.ann_nsga2, 'ANN-NSGA-II');

    fprintf('\nSmoke test completed.\n');
end


function reportPareto(results, name)
    if ~isstruct(results) || ~isfield(results, 'paretoFront') || isempty(results.paretoFront)
        error('SmokeTest:InvalidResults', '%s results missing paretoFront', name);
    end

    try
        frontSize = results.paretoFront.size();
    catch
        frontSize = -1;
    end

    fprintf('%s | evaluations=%d | paretoSize=%d\n', name, results.evaluations, frontSize);

    if isfield(results, 'topsis') && isstruct(results.topsis) && isfield(results.topsis, 'objectives')
        try
            fprintf('%s | TOPSIS objectives: [%s]\n', name, num2str(results.topsis.objectives, '%.6g '));
        catch
        end
    end
end

