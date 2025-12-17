function [future, dataQueue] = runOptimizationAsync(configFilePath, guiCallbacks)
%% runOptimizationAsync - Run optimization asynchronously with GUI updates
%
% Wrapper for running MAPO optimization with async/sync support.
%
% Input:
%   configFilePath - Absolute path to case_config.json
%   guiCallbacks   - OptimizationCallbacks instance (for sync mode)
%
% Output:
%   future      - parfeval Future object (async) or results struct (sync)
%   dataQueue   - parallel.pool.DataQueue (async) or [] (sync)
%
% Usage (Async with automatic handler):
%   [future, queue] = runOptimizationAsync(absPath, callbacks);
%   if isa(future, 'parallel.FevalFuture')
%       % Use helper function to handle both iteration and final data
%       afterEach(queue, @(data) handleOptimizationData(callbacks, data));
%   end
%
% Usage (Sync):
%   [results, ~] = runOptimizationAsync(absPath, callbacks);
%   callbacks.onAlgorithmEndCallback(results);
%
% Helper function for DataQueue (place in your GUI code):
%   function handleOptimizationData(callbacks, data)
%       if isfield(data, 'isFinal') && data.isFinal
%           % Final results - update GUI completion state
%           callbacks.onAlgorithmEndCallback(data.results);
%           % Update button states, etc.
%       else
%           % Iteration data - update progress
%           callbacks.onIterationCallback(data.iteration, data);
%       end
%   end
%
% IMPORTANT DIFFERENCES FROM run_case.m:
%   - configFilePath MUST be absolute path
%   - Model paths in config MUST be absolute paths
%   - Evaluator class must exist in path
%   - This wrapper does NOT create results directories or save files
%   - This wrapper does NOT set simulator log files
%   - GUI is responsible for saving results (MAT/CSV/PNG) as needed
%
% DESIGN RATIONALE:
%   This wrapper focuses solely on optimization execution, leaving file I/O
%   to the GUI layer. This approach:
%   - Allows users to preview results before saving
%   - Avoids file system conflicts in async worker threads
%   - Provides GUI flexibility in save location/format
%   - Supports "temporary run" without disk writes
%
% CONSTRAINT HANDLING:
%   Constraint expressions (e.g., "T1 <= 350") are metadata only.
%   Actual constraint evaluation is performed by the Evaluator class.
%   This matches run_case.m behavior (see line 227-235).
%
% ITERATION DATA:
%   Data structure depends on algorithm implementation:
%   - NSGA-II: iteration, evaluations, bestObjectives, paretoFront,
%              archiveSize, feasibleRatio, objectiveMean, objectiveStd
%   - PSO: Similar structure with swarm-specific data
%   See NSGAII.m line 425-468 for getIterationData() implementation

    %% Validate inputs
    if nargin < 1
        error('runOptimizationAsync:MissingInput', 'configFilePath is required');
    end

    if nargin < 2
        guiCallbacks = [];
    end

    % Ensure absolute path
    if ~isAbsolutePath(configFilePath)
        error('runOptimizationAsync:RelativePath', ...
            'configFilePath must be absolute path, got: %s', configFilePath);
    end

    % Check if file exists
    if ~exist(configFilePath, 'file')
        error('runOptimizationAsync:FileNotFound', ...
            'Config file not found: %s', configFilePath);
    end

    %% Check for Parallel Computing Toolbox
    hasParallelToolbox = license('test', 'Distrib_Computing_Toolbox');

    if hasParallelToolbox
        try
            % Try to get or create parallel pool
            p = gcp('nocreate');
            if isempty(p)
                fprintf('[runOptimizationAsync] Starting parallel pool...\n');
                p = parpool('local');
            end
            fprintf('[runOptimizationAsync] Using parallel pool with %d workers\n', p.NumWorkers);

            % Run in async mode
            [future, dataQueue] = runAsync(configFilePath);
            return;

        catch ME
            warning('runOptimizationAsync:ParallelFailed', ...
                'Failed to use parallel pool: %s. Falling back to synchronous mode.', ME.message);
            hasParallelToolbox = false;
        end
    end

    %% Fallback to synchronous mode
    if ~hasParallelToolbox
        fprintf('[runOptimizationAsync] Parallel Computing Toolbox not available.\n');
        fprintf('[runOptimizationAsync] Running optimization synchronously...\n');

        future = runSync(configFilePath, guiCallbacks);
        dataQueue = [];
    end
end


function [future, dataQueue] = runAsync(configFilePath)
    %% runAsync - Run optimization asynchronously using parfeval

    % Create DataQueue for iteration data
    dataQueue = parallel.pool.DataQueue;

    % Get project root path
    thisFilePath = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(thisFilePath);  % Up from gui/ to project root
    frameworkPath = fullfile(projectRoot, 'framework');

    if ~exist(frameworkPath, 'dir')
        error('runOptimizationAsync:FrameworkNotFound', ...
            'Framework directory not found: %s', frameworkPath);
    end

    % Launch async task
    fprintf('[runAsync] Submitting task to worker...\n');
    fprintf('[runAsync] Config: %s\n', configFilePath);
    fprintf('[runAsync] Framework: %s\n', frameworkPath);

    future = parfeval(@workerOptimizationTask, 1, ...
        configFilePath, frameworkPath, dataQueue);

    fprintf('[runAsync] Task submitted (ID: %s)\n', future.ID);
end


function results = runSync(configFilePath, guiCallbacks)
    %% runSync - Run optimization synchronously in main thread

    % Get project root
    thisFilePath = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(thisFilePath);
    frameworkPath = fullfile(projectRoot, 'framework');

    % Ensure framework in path
    if ~exist(frameworkPath, 'dir')
        error('runOptimizationAsync:FrameworkNotFound', ...
            'Framework directory not found: %s', frameworkPath);
    end
    addpath(genpath(frameworkPath));

    % Load config
    fprintf('[runSync] Loading config: %s\n', configFilePath);
    config = jsondecode(fileread(configFilePath));

    % Build all components
    fprintf('[runSync] Setting up optimization...\n');
    [problem, algorithm, simulator] = buildOptimizationComponents(config);

    % Set callbacks if provided
    if ~isempty(guiCallbacks)
        algorithm.setIterationCallback(@guiCallbacks.onIterationCallback);
        algorithm.setAlgorithmEndCallback(@guiCallbacks.onAlgorithmEndCallback);
        fprintf('[runSync] GUI callbacks registered\n');
    end

    % Run optimization
    fprintf('[runSync] Starting optimization...\n');
    results = algorithm.optimize(problem, config.algorithm.parameters);

    % Cleanup
    if ~isempty(simulator)
        try
            simulator.disconnect();
        catch
        end
    end

    fprintf('[runSync] Optimization completed\n');
end


function results = workerOptimizationTask(configFilePath, frameworkPath, dataQueue)
    %% workerOptimizationTask - Optimization task executed in worker

    simulator = [];

    try
        % Add framework to worker's path
        addpath(genpath(frameworkPath));

        sendLogData(dataQueue, 'INFO', 'Worker 已启动');
        sendLogData(dataQueue, 'INFO', '读取配置: %s', configFilePath);

        % Load config
        config = jsondecode(fileread(configFilePath));

        % Build components (also connects simulator)
        sendLogData(dataQueue, 'INFO', '初始化优化组件...');
        [problem, algorithm, simulator] = buildOptimizationComponents(config, dataQueue, configFilePath);

        % Set DataQueue-based callbacks
        algorithm.setIterationCallback(@(iter, data) sendIterationData(dataQueue, iter, data));
        algorithm.setAlgorithmEndCallback(@(results) sendFinalData(dataQueue, results));

        sendLogData(dataQueue, 'INFO', '开始优化（首次评估可能需要较长时间，请耐心等待）');

        % Run optimization
        results = algorithm.optimize(problem, config.algorithm.parameters);

        % Cleanup
        if ~isempty(simulator)
            try
                simulator.disconnect();
            catch
            end
        end

        sendLogData(dataQueue, 'INFO', '优化任务完成');

    catch ME
        % Best-effort cleanup
        if ~isempty(simulator)
            try
                simulator.disconnect();
            catch
            end
        end

        % Cancellation should not be surfaced as an error toast in GUI
        if isCancellationError(ME)
            return;
        end

        sendErrorData(dataQueue, ME);
        rethrow(ME);
    end
end


function [problem, algorithm, simulator] = buildOptimizationComponents(config, dataQueue, configFilePath)
    %% buildOptimizationComponents - Build problem, algorithm, and simulator
    %
    % Follows the exact structure of run_case.m

    simulator = [];
    simLogger = [];
    algLogger = [];

    if nargin < 2
        dataQueue = [];
    end
    if nargin < 3
        configFilePath = '';
    end

    if ~isempty(dataQueue)
        try
            % 注意：仿真器在每次 evaluate/run 时会输出较多日志。
            % 这里默认回传 INFO+，以便 GUI 能看到“仿真成功/失败”等关键信息。
            simLogger = DataQueueLogger(dataQueue, 'Simulator', Logger.INFO);
            algLogger = DataQueueLogger(dataQueue, 'Algorithm', Logger.INFO);
        catch
            simLogger = [];
            algLogger = [];
        end
    end

    %% Create and configure simulator
    fprintf('  Creating simulator...\n');
    sendLogData(dataQueue, 'INFO', '创建仿真器...');

    % Create SimulatorConfig
    simConfig = SimulatorConfig(config.simulator.type);

    % Set all settings
    settings = config.simulator.settings;
    resolvedModelPath = '';
    resolvedVisible = [];
    settingFields = fieldnames(settings);
    for i = 1:length(settingFields)
        field = settingFields{i};
        value = settings.(field);

        % Resolve relative modelPath (GUI temp config is saved in a different folder)
        if strcmpi(field, 'modelPath') && ~isempty(value)
            modelPath = char(string(value));
            if ~isAbsolutePath(modelPath)
                baseDir = '';
                if isfield(config, 'runtime') && isfield(config.runtime, 'baseDir')
                    baseDir = char(string(config.runtime.baseDir));
                end
                if isempty(baseDir) && ~isempty(configFilePath)
                    baseDir = fileparts(configFilePath);
                end
                if ~isempty(baseDir)
                    candidate = fullfile(baseDir, modelPath);
                    if exist(candidate, 'file')
                        modelPath = candidate;
                    end
                end
            end
            value = modelPath;
            resolvedModelPath = modelPath;
        elseif strcmpi(field, 'visible')
            resolvedVisible = value;
        end

        simConfig.set(field, value);
    end

    % Set node mappings
    if isfield(config.simulator, 'nodeMapping')
        % Variable mappings
        if isfield(config.simulator.nodeMapping, 'variables')
            varMap = config.simulator.nodeMapping.variables;

            % Prefer problem variable order (to match x vector order)
            if isfield(config, 'problem') && isfield(config.problem, 'variables') && ...
               ~isempty(config.problem.variables)
                problemVars = config.problem.variables;
                problemVarNames = cell(1, length(problemVars));
                for i = 1:length(problemVars)
                    problemVarNames{i} = char(string(problemVars(i).name));
                end

                for i = 1:length(problemVarNames)
                    varName = problemVarNames{i};
                    try
                        hasField = isfield(varMap, varName);
                    catch
                        error('runOptimizationAsync:InvalidVariableName', ...
                            'Variable name must be a valid MATLAB identifier (for nodeMapping): %s', varName);
                    end

                    if ~hasField
                        error('runOptimizationAsync:MissingNodeMapping', ...
                            'Missing node mapping for problem variable "%s" (simulator.nodeMapping.variables.%s)', ...
                            varName, varName);
                    end

                    nodePath = varMap.(varName);
                    simConfig.setNodeMapping(varName, nodePath);
                end

                % Warn about extra mappings not in problem variables
                try
                    mapFields = fieldnames(varMap);
                    extra = setdiff(mapFields, problemVarNames);
                    if ~isempty(extra)
                        warning('runOptimizationAsync:ExtraNodeMappings', ...
                            'Ignoring %d extra variable node mappings not in problem.variables: %s', ...
                            numel(extra), strjoin(extra, ', '));
                    end
                catch
                end

            else
                % Fallback: use mapping field order (alphabetical for struct)
                varNames = fieldnames(varMap);
                for i = 1:length(varNames)
                    varName = varNames{i};
                    nodePath = varMap.(varName);
                    simConfig.setNodeMapping(varName, nodePath);
                end
            end
        end

        % Result mappings
        if isfield(config.simulator.nodeMapping, 'results')
            resNames = fieldnames(config.simulator.nodeMapping.results);
            for i = 1:length(resNames)
                resName = resNames{i};
                nodePath = config.simulator.nodeMapping.results.(resName);
                simConfig.setResultMapping(resName, nodePath);
            end
        end
    end

    % Create simulator instance
    switch upper(config.simulator.type)
        case 'ASPEN'
            simulator = AspenPlusSimulator();
        case 'MATLAB'
            simulator = MATLABSimulator();
        case 'PYTHON'
            simulator = PythonSimulator();
        otherwise
            error('Unsupported simulator type: %s', config.simulator.type);
    end

    % Attach logger before connecting so connect() logs show up in GUI
    if ~isempty(simLogger)
        try
            simulator.setLogger(simLogger);
        catch
        end
    end

    sendLogData(dataQueue, 'INFO', '连接仿真器: %s', config.simulator.type);
    if strcmpi(config.simulator.type, 'Aspen') && ~isempty(resolvedModelPath)
        sendLogData(dataQueue, 'INFO', 'Aspen 模型: %s', resolvedModelPath);
        if ~isempty(resolvedVisible)
            sendLogData(dataQueue, 'INFO', 'Aspen 窗口可见: %s', char(string(resolvedVisible)));
        end
    end

    % Connect simulator
    simulator.connect(simConfig);
    fprintf('  Simulator connected: %s\n', config.simulator.type);
    sendLogData(dataQueue, 'INFO', '仿真器已连接: %s', config.simulator.type);

    %% Create evaluator
    fprintf('  Creating evaluator...\n');
    sendLogData(dataQueue, 'INFO', '创建评估器...');

    evaluatorType = config.problem.evaluator.type;
    evaluatorTimeout = 300;

    if isfield(config.problem.evaluator, 'timeout')
        evaluatorTimeout = config.problem.evaluator.timeout;
    end

    % Try to create evaluator instance (supports constructors with or without simulator)
    evaluator = [];
    createErr1 = [];

    try
        evaluator = feval(evaluatorType, simulator);
    catch ME1
        createErr1 = ME1;
        try
            evaluator = feval(evaluatorType);
        catch ME2
            error('runOptimizationAsync:EvaluatorCreationFailed', ...
                ['Failed to create evaluator: %s\n' ...
                 'Tried:\n  1) %s(simulator) -> %s\n  2) %s() -> %s'], ...
                evaluatorType, evaluatorType, createErr1.message, evaluatorType, ME2.message);
        end
    end

    if isprop(evaluator, 'timeout')
        evaluator.timeout = evaluatorTimeout;
    end

    % Set economic parameters if any
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

    fprintf('  Evaluator created: %s\n', evaluatorType);
    sendLogData(dataQueue, 'INFO', '评估器已创建: %s', evaluatorType);

    %% Create optimization problem
    fprintf('  Building problem...\n');
    sendLogData(dataQueue, 'INFO', '构建优化问题...');

    problemName = config.problem.name;
    problemDesc = '';
    if isfield(config.problem, 'description')
        problemDesc = config.problem.description;
    end

    problem = OptimizationProblem(problemName, problemDesc);

    % Add variables (using correct constructor: name, type, [lb, ub])
    for i = 1:length(config.problem.variables)
        var = config.problem.variables(i);
        variable = Variable(var.name, var.type, [var.lowerBound, var.upperBound]);

        if isfield(var, 'unit')
            variable.unit = var.unit;
        end
        if isfield(var, 'description')
            variable.description = var.description;
        end

        problem.addVariable(variable);
    end

    % Add objectives
    for i = 1:length(config.problem.objectives)
        obj = config.problem.objectives(i);

        % Process type (maximize -> minimize internally)
        objType = obj.type;
        if strcmpi(objType, 'maximize')
            objType = 'minimize';
        end

        objective = Objective(obj.name, objType);

        if isfield(obj, 'description')
            objective.description = obj.description;
        end
        if isfield(obj, 'weight')
            objective.weight = obj.weight;
        end

        problem.addObjective(objective);
    end

    % Add constraints (if any)
    if isfield(config.problem, 'constraints') && ~isempty(config.problem.constraints)
        for i = 1:length(config.problem.constraints)
            con = config.problem.constraints(i);

            % Use factory methods to create constraints
            switch con.type
                case 'inequality'
                    if isfield(con, 'expression') && contains(con.expression, '<=')
                        constraint = Constraint.createLessEqual(con.name, 0);
                    else
                        constraint = Constraint.createGreaterEqual(con.name, 0);
                    end
                case 'equality'
                    constraint = Constraint.createEqual(con.name, 0);
                otherwise
                    warning('Unknown constraint type: %s', con.type);
                    continue;
            end

            if isfield(con, 'description')
                constraint.description = con.description;
            end

            problem.addConstraint(constraint);
        end
    end

    % Set problem type
    if problem.getNumberOfObjectives() > 1
        problem.problemType = 'multi-objective';
    else
        problem.problemType = 'single-objective';
    end

    % Set evaluator
    problem.setEvaluator(evaluator);

    % Optional: provide problem to Evaluator-style classes
    if ismethod(evaluator, 'setProblem')
        try
            evaluator.setProblem(problem);
        catch ME
            warning('runOptimizationAsync:SetProblemFailed', ...
                'Failed to set problem on evaluator (%s): %s', evaluatorType, ME.message);
        end
    end

    fprintf('  Problem defined: %d vars, %d objs, %d constraints\n', ...
        problem.getNumberOfVariables(), ...
        problem.getNumberOfObjectives(), ...
        problem.getNumberOfConstraints());
    sendLogData(dataQueue, 'INFO', '问题已定义: %d vars, %d objs, %d constraints', ...
        problem.getNumberOfVariables(), ...
        problem.getNumberOfObjectives(), ...
        problem.getNumberOfConstraints());

    %% Create algorithm
    fprintf('  Initializing algorithm...\n');
    sendLogData(dataQueue, 'INFO', '初始化算法...');

    algType = config.algorithm.type;
    algTypeNorm = upper(strrep(algType, '-', ''));

    switch algTypeNorm
        case 'NSGAII'
            algorithm = NSGAII();
        case 'PSO'
            algorithm = PSO();
        otherwise
            error('Unknown algorithm type: %s', algType);
    end

    fprintf('  Algorithm: %s\n', algType);
    if ~isempty(algLogger)
        try
            algorithm.setLogger(algLogger);
        catch
        end
    end
    sendLogData(dataQueue, 'INFO', '算法: %s', algType);
end


function sendIterationData(dataQueue, iteration, data)
    %% sendIterationData - Send iteration data via DataQueue

    % Ensure data has iteration field
    if ~isstruct(data)
        data = struct('iteration', iteration);
    elseif ~isfield(data, 'iteration')
        data.iteration = iteration;
    end

    % Mark as iteration data
    data.isFinal = false;

    % Send to client thread
    send(dataQueue, data);
end


function sendFinalData(dataQueue, results)
    %% sendFinalData - Send final results via DataQueue

    finalData = struct();
    finalData.isFinal = true;
    finalData.results = results;

    send(dataQueue, finalData);
end


function sendLogData(dataQueue, level, message, varargin)
    %% sendLogData - Send log/status messages via DataQueue (optional)

    if nargin < 1 || isempty(dataQueue)
        return;
    end

    if nargin < 2 || isempty(level)
        level = 'INFO';
    end

    if nargin < 3
        message = '';
    end

    if ~isempty(varargin)
        try
            message = sprintf(message, varargin{:});
        catch
        end
    end

    payload = struct();
    payload.type = 'log';
    payload.level = char(string(level));
    payload.message = char(string(message));
    payload.source = 'Worker';

    try
        send(dataQueue, payload);
    catch
    end
end


function sendErrorData(dataQueue, ME)
    %% sendErrorData - Send error info via DataQueue (optional)

    if nargin < 1 || isempty(dataQueue)
        return;
    end

    payload = struct();
    payload.type = 'error';
    payload.message = ME.message;
    payload.identifier = ME.identifier;

    try
        payload.stack = ME.stack;
    catch
    end

    try
        send(dataQueue, payload);
    catch
    end
end


function tf = isCancellationError(ME)
    %% isCancellationError - Heuristic for Future cancellation exceptions

    tf = false;

    try
        id = lower(ME.identifier);
        if contains(id, 'cancel') || contains(id, 'canceled') || contains(id, 'cancelled')
            tf = true;
            return;
        end
    catch
    end

    try
        msg = lower(ME.message);
        tf = contains(msg, 'cancel') || contains(msg, 'canceled') || contains(msg, 'cancelled');
    catch
    end
end


function tf = isAbsolutePath(path)
    %% isAbsolutePath - Check if path is absolute

    if ispc
        % Windows: C:\... or \\server\...
        tf = ~isempty(regexp(path, '^[A-Za-z]:\\', 'once')) || startsWith(path, '\\');
    else
        % Unix/Mac: /...
        tf = startsWith(path, '/');
    end
end
