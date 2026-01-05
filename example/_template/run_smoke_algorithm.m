function out = run_smoke_algorithm(algorithmTypes, varargin)
%% run_smoke_algorithm - 通用算法冒烟测试（不依赖 Aspen/COM）
%
% 目标:
%   - 快速验证某个/多个算法类型是否可创建、可运行、可产出结果
%   - 默认使用 ZDT1（多目标、无约束）作为测试问题
%
% 用法示例:
%   out = run_smoke_algorithm('ANN-NSGA-II');
%   out = run_smoke_algorithm({'NSGA-II', 'ANN-NSGA-II', 'PSO'}, ...
%       'Problem', 'zdt1', 'PopulationSize', 40, 'Iterations', 20);
%
%   out = run_smoke_algorithm('all', 'PopulationSize', 20, 'Iterations', 5);
%   out = run_smoke_algorithm({'NSGA-II','PSO'}, 'Problem', 'sphere_c');
%   out = run_smoke_algorithm('ANN-NSGA-II', 'Problem', 'zdt1c', 'RequireFeasible', false);
%
% Key options:
%   - 'ValidateResults' (true)   basic structural checks on results
%   - 'ThrowOnFailure'  (false)  throw error if any run fails
%   - 'AlgorithmParameters'      struct/cell/containers.Map overrides
%       * struct mapping fields: 'ALL', 'NSGAII', 'PSO', 'ANNNSGAII', ...
% 返回:
%   out.problem     - 问题信息
%   out.settings    - 冒烟测试设置
%   out.runs        - 每个算法的运行结果（结构体数组）
%
% 说明:
%   - 本测试只验证“可用性”（能否跑通），不代表算法性能优劣
%   - 若要测试约束处理，可改用 MATLABFunctionEvaluator 自定义带约束函数

    if nargin < 1 || isempty(algorithmTypes)
        algorithmTypes = {'NSGA-II'};
    end

    if ischar(algorithmTypes) || isstring(algorithmTypes)
        algorithmTypes = {char(string(algorithmTypes))};
    end

    p = inputParser;
    addParameter(p, 'Problem', 'zdt1', @(x) ischar(x) || isstring(x));
    addParameter(p, 'NumVars', 10, @(x) isnumeric(x) && isscalar(x) && x >= 1);
    addParameter(p, 'PopulationSize', 40, @(x) isnumeric(x) && isscalar(x) && x >= 2);
    addParameter(p, 'Iterations', 20, @(x) isnumeric(x) && isscalar(x) && x >= 1);
    addParameter(p, 'Seed', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
    addParameter(p, 'Verbose', true, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'ValidateResults', true, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'RequireFeasible', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'ThrowOnFailure', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'AlgorithmParameters', [], @(x) isempty(x) || isstruct(x) || iscell(x) || isa(x, 'containers.Map'));
    parse(p, varargin{:});

    settings = p.Results;
    settings.problem = char(string(settings.Problem));

    %% 添加框架路径（以及刷新 metadata）
    thisDir = fileparts(mfilename('fullpath'));          % .../example/_template
    projectRoot = fileparts(fileparts(thisDir));         % .../ (project root)
    frameworkPath = fullfile(projectRoot, 'framework');
    addpath(genpath(frameworkPath));

    if exist('AlgorithmFactory', 'class') == 8
        try
            AlgorithmFactory.refreshFromMetadata();
        catch
        end
    end

    % Expand special token: 'all' => discover from metadata files
    if length(algorithmTypes) == 1
        try
            token = lower(strtrim(char(string(algorithmTypes{1}))));
        catch
            token = '';
        end

        if strcmp(token, 'all')
            algorithmTypes = discoverAlgorithmTypesFromMetadata(projectRoot);
            if isempty(algorithmTypes)
                error('SmokeTest:NoAlgorithmsDiscovered', ...
                    'No algorithms discovered from metadata. Expected `framework/algorithm/**/algorithm_meta.json`.');
            end
        end
    end

    %% 构建测试问题
    [problem, problemInfo] = buildTestProblem(settings.problem, settings.NumVars);

    %% 设置随机数种子（可复现）
    if ~isempty(settings.Seed)
        try
            rng(settings.Seed, 'twister');
        catch
            rng(settings.Seed);
        end
    end

    fprintf('========================================\n');
    fprintf('MAPO - Algorithm Smoke Test\n');
    fprintf('Problem: %s | dim=%d\n', problemInfo.name, problemInfo.numVars);
    fprintf('Algorithms: %s\n', strjoin(algorithmTypes, ', '));
    fprintf('Budget: N=%d | Iter=%d\n', settings.PopulationSize, settings.Iterations);
    fprintf('========================================\n');

    %% 运行每个算法
    runs = struct('type', {}, 'success', {}, 'message', {}, 'params', {}, 'results', {}, 'summary', {});
    for i = 1:length(algorithmTypes)
        algType = char(string(algorithmTypes{i}));

        runEntry = struct();
        runEntry.type = algType;
        runEntry.success = false;
        runEntry.message = '';
        runEntry.params = struct();
        runEntry.results = [];
        runEntry.summary = struct();

        try
            algorithm = AlgorithmFactory.create(algType);
            if settings.Verbose && ismethod(algorithm, 'setVerbose')
                algorithm.setVerbose(true);
            elseif ismethod(algorithm, 'setVerbose')
                algorithm.setVerbose(false);
            end

            params = buildSmokeParameters(algType, settings);
            params = applyOverrides(params, settings.AlgorithmParameters, algType, i);

            fprintf('\n[%d/%d] Running %s ...\n', i, length(algorithmTypes), algType);
            res = algorithm.optimize(problem, params);

            runEntry.params = params;
            runEntry.results = res;
            [runEntry.success, runEntry.message, runEntry.summary] = validateAndSummarize(res, problem, problemInfo, settings);

            printSummary(runEntry.summary, algType);

        catch ME
            runEntry.success = false;
            runEntry.message = ME.message;
            fprintf('FAILED: %s\n', ME.message);
        end

        runs(end + 1) = runEntry; %#ok<AGROW>
    end

    out = struct();
    out.problem = problemInfo;
    out.settings = settings;
    out.runs = runs;

    try
        out.ok = all([runs.success]);
        out.failedTypes = {runs(~[runs.success]).type};
    catch
        out.ok = false;
        out.failedTypes = {};
    end

    fprintf('\n========================================\n');
    fprintf('Smoke Test Summary: %d/%d passed\n', sum([runs.success]), length(runs));
    fprintf('========================================\n');

    if settings.ThrowOnFailure && ~out.ok
        error('SmokeTest:Failed', 'Smoke test failed for: %s', strjoin(out.failedTypes, ', '));
    end
end


function [problem, info] = buildTestProblem(problemType, numVars)
    problemType = lower(strtrim(char(string(problemType))));

    switch problemType
        case 'zdt1'
            info = struct();
            info.name = 'ZDT1';
            info.numVars = numVars;
            info.numObjectives = 2;
            info.numConstraints = 0;

            problem = OptimizationProblem('ZDT1_Smoke', 'ZDT1 smoke test (2 objectives, no constraints)');
            for i = 1:numVars
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

        case {'zdt1c', 'zdt1_c', 'zdt1-constrained'}
            info = struct();
            info.name = 'ZDT1 (constrained)';
            info.numVars = max(2, numVars);
            info.numObjectives = 2;
            info.numConstraints = 1;

            problem = OptimizationProblem('ZDT1C_Smoke', 'ZDT1 + 1 inequality constraint');
            for i = 1:info.numVars
                problem.addVariable(Variable(sprintf('x%d', i), 'continuous', [0, 1]));
            end
            problem.addObjective(Objective('f1', 'minimize'));
            problem.addObjective(Objective('f2', 'minimize'));
            problem.addConstraint(Constraint.createLessEqual('g1', 0));

            evaluator = MATLABFunctionEvaluator(@zdt1Objectives, @zdt1Constraints);
            problem.setEvaluator(evaluator);
            try
                evaluator.setProblem(problem);
            catch
            end

        case 'sphere'
            info = struct();
            info.name = 'Sphere';
            info.numVars = numVars;
            info.numObjectives = 1;
            info.numConstraints = 0;

            problem = OptimizationProblem('Sphere_Smoke', 'Sphere function (single objective, no constraints)');
            for i = 1:numVars
                problem.addVariable(Variable(sprintf('x%d', i), 'continuous', [-5, 5]));
            end
            problem.addObjective(Objective('f', 'minimize'));

            evaluator = MATLABFunctionEvaluator(@(x) sum(x(:)'.^2));
            problem.setEvaluator(evaluator);
            try
                evaluator.setProblem(problem);
            catch
            end

        case {'sphere_c', 'sphere-c', 'constrained_sphere'}
            info = struct();
            info.name = 'Sphere (constrained)';
            info.numVars = numVars;
            info.numObjectives = 1;
            info.numConstraints = 1;

            problem = OptimizationProblem('SphereC_Smoke', 'Sphere + 1 inequality constraint');
            for i = 1:numVars
                problem.addVariable(Variable(sprintf('x%d', i), 'continuous', [-5, 5]));
            end
            problem.addObjective(Objective('f', 'minimize'));
            problem.addConstraint(Constraint.createLessEqual('g1', 0));

            evaluator = MATLABFunctionEvaluator(@sphereObjective, @sphereConstraint);
            problem.setEvaluator(evaluator);
            try
                evaluator.setProblem(problem);
            catch
            end

        otherwise
            error('SmokeTest:UnknownProblem', ...
                'Unknown problem type: %s (supported: zdt1, zdt1c, sphere, sphere_c)', problemType);
    end
end


function params = buildSmokeParameters(algType, settings)
    n = settings.PopulationSize;
    iter = settings.Iterations;

    params = struct();

    % 通用：同时提供两套字段，最大化兼容不同算法实现
    params.populationSize = n;
    params.maxGenerations = iter;
    params.swarmSize = n;
    params.maxIterations = iter;

    % NSGA/GA 类默认
    params.crossoverRate = 0.9;
    params.mutationRate = 1.0;
    params.crossoverDistIndex = 20;
    params.mutationDistIndex = 20;

    % ANN-NSGA-II（若算法不使用，会被忽略）
    params.training = struct();
    params.training.samples = min(200, max(20, n * 2));
    params.training.maxAttempts = max(params.training.samples * 5, 200);
    params.training.samplingMethod = 'lhs';
    params.training.requireSuccess = true;
    params.training.requireFeasible = false;
    if ~isempty(settings.Seed)
        params.training.randomSeed = settings.Seed;
    end

    params.surrogate = struct();
    params.surrogate.type = 'poly2';
    params.surrogate.ridgeLambda = 1e-6;

    params.operators = struct();
    params.operators.useDynamicOperators = true;
    params.operators.crossoverDistIndex = params.crossoverDistIndex;
    params.operators.mutationDistIndex = params.mutationDistIndex;

    params.verification = struct();
    params.verification.enabled = true;
    params.verification.verifyParetoFront = false;
    params.verification.verifyParetoLimit = 0;
    params.verification.verifyTOPSIS = true;

    % 按类型做少量优化（避免误传）
    if contains(upper(regexprep(algType, '[-_\\s]', '')), 'PSO')
        % PSO 不需要交叉/变异参数，保留也不会影响（多数实现会忽略）
    end
end


function params = applyOverrides(params, override, algType, index)
    if nargin < 2 || isempty(override)
        return;
    end

    algKey = normalizeAlgKey(algType);

    if isa(override, 'containers.Map')
        try
            if override.isKey(algKey)
                value = override(algKey);
                if isstruct(value)
                    params = mergeStruct(params, value);
                end
            elseif override.isKey('ALL')
                value = override('ALL');
                if isstruct(value)
                    params = mergeStruct(params, value);
                end
            end
        catch
        end
        return;
    end

    if isstruct(override)
        isMapping = false;
        if isfield(override, 'all') && isstruct(override.all)
            isMapping = true;
        end
        if isfield(override, 'ALL') && isstruct(override.ALL)
            isMapping = true;
        end
        if ~isempty(algKey) && isfield(override, algKey) && isstruct(override.(algKey))
            isMapping = true;
        end

        if isMapping
            if isfield(override, 'all') && isstruct(override.all)
                params = mergeStruct(params, override.all);
            elseif isfield(override, 'ALL') && isstruct(override.ALL)
                params = mergeStruct(params, override.ALL);
            end

            if ~isempty(algKey) && isfield(override, algKey) && isstruct(override.(algKey))
                params = mergeStruct(params, override.(algKey));
            end
        else
            params = mergeStruct(params, override);
        end
        return;
    end

    if iscell(override)
        if index <= length(override) && isstruct(override{index})
            params = mergeStruct(params, override{index});
        end
        return;
    end
end


function out = mergeStruct(base, override)
    out = base;
    if isempty(override) || ~isstruct(override)
        return;
    end

    fields = fieldnames(override);
    for i = 1:length(fields)
        name = fields{i};
        val = override.(name);

        if isstruct(val) && isfield(out, name) && isstruct(out.(name))
            out.(name) = mergeStruct(out.(name), val);
        else
            out.(name) = val;
        end
    end
end


function [ok, message, summary] = validateAndSummarize(results, problem, problemInfo, settings)
    ok = true;
    message = '';
    summary = summarizeResults(results, problem, problemInfo);

    if ~settings.ValidateResults
        return;
    end

    [ok, message] = validateResults(results, problem, summary, settings);
    summary.validationOk = ok;
    summary.validationMessage = message;
end


function summary = summarizeResults(results, problem, problemInfo)
    summary = struct();
    summary.evaluations = [];
    summary.iterations = [];
    summary.elapsedTime = [];
    summary.paretoSize = [];
    summary.bestObjectives = [];
    summary.topsisObjectives = [];
    summary.feasibleRatio = [];
    summary.paretoFeasibleRatio = [];
    summary.igd = [];
    summary.validationOk = [];
    summary.validationMessage = '';

    try
        summary.problem = problemInfo.name;
    catch
        summary.problem = '';
    end

    if ~isstruct(results)
        return;
    end

    if isfield(results, 'evaluations')
        summary.evaluations = results.evaluations;
    end
    if isfield(results, 'iterations')
        summary.iterations = results.iterations;
    end
    if isfield(results, 'elapsedTime')
        summary.elapsedTime = results.elapsedTime;
    end

    try
        if isfield(results, 'population') && isa(results.population, 'Population')
            summary.feasibleRatio = computeFeasibleRatio(results.population);
        end
    catch
    end

    try
        if isfield(results, 'paretoFront') && isa(results.paretoFront, 'Population')
            summary.paretoSize = results.paretoFront.size();
            summary.paretoFeasibleRatio = computeFeasibleRatio(results.paretoFront);

            if isstruct(problemInfo) && isfield(problemInfo, 'name')
                name = char(string(problemInfo.name));
            else
                name = '';
            end

            if contains(upper(name), 'ZDT1') && exist('ZDT1Evaluator', 'class') == 8
                objs = extractObjectives(results.paretoFront);
                if ~isempty(objs) && size(objs, 2) == 2
                    summary.igd = ZDT1Evaluator.calculateIGD(objs, 100);
                end
            end
        end
    catch
    end

    if isfield(results, 'bestObjectives')
        summary.bestObjectives = results.bestObjectives;
    end

    if isfield(results, 'topsis') && isstruct(results.topsis) && isfield(results.topsis, 'objectives')
        summary.topsisObjectives = results.topsis.objectives;
    end
end


function [ok, message] = validateResults(results, problem, summary, settings)
    ok = true;
    message = '';

    if ~isstruct(results)
        ok = false;
        message = 'optimize() did not return a struct';
        return;
    end

    requiredFields = {'evaluations', 'iterations', 'elapsedTime', 'population'};
    for i = 1:length(requiredFields)
        if ~isfield(results, requiredFields{i})
            ok = false;
            message = sprintf('missing field: %s', requiredFields{i});
            return;
        end
    end

    if ~isnumeric(results.evaluations) || ~isscalar(results.evaluations)
        ok = false;
        message = 'invalid evaluations field';
        return;
    end

    if ~isnumeric(results.iterations) || ~isscalar(results.iterations)
        ok = false;
        message = 'invalid iterations field';
        return;
    end

    if ~isnumeric(results.elapsedTime) || ~isscalar(results.elapsedTime)
        ok = false;
        message = 'invalid elapsedTime field';
        return;
    end

    if isempty(results.population) || ~isa(results.population, 'Population')
        ok = false;
        message = 'missing/invalid population in results';
        return;
    end

    try
        if results.population.size() <= 0
            ok = false;
            message = 'population is empty';
            return;
        end
    catch
    end

    try
        if isfield(results, 'bestObjectives') && ~isempty(results.bestObjectives) && ~isempty(problem) && isa(problem, 'OptimizationProblem')
            if length(results.bestObjectives) ~= problem.getNumberOfObjectives()
                ok = false;
                message = 'bestObjectives size mismatch';
                return;
            end
            if any(~isfinite(results.bestObjectives))
                ok = false;
                message = 'bestObjectives contains non-finite values';
                return;
            end
        end
    catch
    end

    try
        if ~isempty(problem) && isa(problem, 'OptimizationProblem') && problem.getNumberOfConstraints() > 0
            if settings.RequireFeasible && ~isempty(summary.feasibleRatio) && summary.feasibleRatio <= 0
                ok = false;
                message = 'no feasible solution found (RequireFeasible=true)';
                return;
            end
        end
    catch
    end
end


function printSummary(summary, algType)
    evalStr = '?';
    iterStr = '?';
    paretoStr = '?';
    timeStr = '';
    feasStr = '';
    igdStr = '';

    try
        if ~isempty(summary.evaluations)
            evalStr = num2str(summary.evaluations);
        end
        if ~isempty(summary.iterations)
            iterStr = num2str(summary.iterations);
        end
        if ~isempty(summary.paretoSize)
            paretoStr = num2str(summary.paretoSize);
        end
        if ~isempty(summary.feasibleRatio)
            feasStr = sprintf(' | feas=%.0f%%', 100 * summary.feasibleRatio);
        end
        if ~isempty(summary.igd)
            igdStr = sprintf(' | IGD=%.4g', summary.igd);
        end
        if ~isempty(summary.elapsedTime)
            timeStr = sprintf(' | time=%.2fs', summary.elapsedTime);
        end
    catch
    end

    fprintf('%s | evals=%s | iters=%s | pareto=%s%s%s%s\n', ...
        algType, evalStr, iterStr, paretoStr, feasStr, igdStr, timeStr);

    if isstruct(summary) && isfield(summary, 'validationOk') && isequal(summary.validationOk, false)
        try
            fprintf('%s | VALIDATION FAILED: %s\n', algType, summary.validationMessage);
        catch
        end
    end

    try
        if ~isempty(summary.topsisObjectives)
            fprintf('%s | TOPSIS objectives: [%s]\n', algType, num2str(summary.topsisObjectives, '%.6g '));
        end
    catch
    end
end


function key = normalizeAlgKey(type)
    try
        type = char(string(type));
    catch
        type = '';
    end
    key = upper(regexprep(type, '[-_\\s]', ''));
end


function types = discoverAlgorithmTypesFromMetadata(projectRoot)
    types = {};

    algRoot = fullfile(projectRoot, 'framework', 'algorithm');
    if ~exist(algRoot, 'dir')
        return;
    end

    dirs = strsplit(genpath(algRoot), pathsep);
    for i = 1:length(dirs)
        dirPath = dirs{i};
        if isempty(dirPath)
            continue;
        end

        metaPath = fullfile(dirPath, 'algorithm_meta.json');
        if ~exist(metaPath, 'file')
            continue;
        end

        try
            meta = jsondecode(fileread(metaPath));
        catch
            continue;
        end

        if ~isstruct(meta) || ~isfield(meta, 'type')
            continue;
        end

        try
            typeStr = char(string(meta.type));
        catch
            continue;
        end

        if isempty(strtrim(typeStr))
            continue;
        end

        types{end+1} = typeStr; %#ok<AGROW>
    end

    if isempty(types)
        return;
    end

    keys = cellfun(@normalizeAlgKey, types, 'UniformOutput', false);
    [~, keepIdx] = unique(keys, 'stable');
    types = types(sort(keepIdx));
end


function objs = extractObjectives(pop)
    objs = [];
    if isempty(pop) || ~isa(pop, 'Population')
        return;
    end

    try
        inds = pop.getAll();
    catch
        return;
    end

    if isempty(inds)
        return;
    end

    try
        m = length(inds(1).getObjectives());
    catch
        m = 0;
    end

    if m <= 0
        return;
    end

    objs = nan(length(inds), m);
    for i = 1:length(inds)
        try
            row = inds(i).getObjectives();
            if iscolumn(row)
                row = row';
            end
            objs(i, :) = row;
        catch
        end
    end

    finiteRow = all(isfinite(objs), 2);
    objs = objs(finiteRow, :);
end


function r = computeFeasibleRatio(pop)
    r = [];
    if isempty(pop) || ~isa(pop, 'Population')
        return;
    end

    try
        inds = pop.getAll();
    catch
        return;
    end

    if isempty(inds)
        r = 0;
        return;
    end

    feasible = false(length(inds), 1);
    for i = 1:length(inds)
        try
            feasible(i) = inds(i).isFeasible();
        catch
            feasible(i) = false;
        end
    end
    r = mean(feasible);
end


function f = zdt1Objectives(x)
    x = x(:)';
    n = length(x);
    f1 = x(1);

    if n > 1
        g = 1 + 9 * sum(x(2:end)) / (n - 1);
    else
        g = 1;
    end

    f2 = g * (1 - sqrt(f1 / g));
    f = [f1, f2];
end


function g = zdt1Constraints(x)
    x = x(:)';
    if length(x) >= 2
        g1 = x(1) + x(2) - 1;
    else
        g1 = x(1) - 1;
    end
    g = g1;
end


function f = sphereObjective(x)
    f = sum(x(:)'.^2);
end


function g = sphereConstraint(x)
    g = sum(x(:)') - 1;
end
