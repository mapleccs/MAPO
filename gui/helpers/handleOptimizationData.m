function handleOptimizationData(app, callbacks, data)
%% handleOptimizationData - Handle iteration and final data from DataQueue
%
% Helper function for processing optimization data sent via DataQueue
% in asynchronous mode. Dispatches to appropriate callback based on
% data.isFinal flag.
%
% Input:
%   app       - GUI app instance (for updating button states)
%   callbacks - OptimizationCallbacks instance
%   data      - Data struct from DataQueue
%
% Data struct fields:
%   - isFinal: true for final results, false for iteration data
%   - results: Final optimization results (when isFinal=true)
%   - iteration: Current iteration number (when isFinal=false)
%   - evaluations: Total evaluation count
%   - bestObjectives: Best objective values
%   - paretoFront: Pareto front individuals
%   - archiveSize: Size of Pareto archive
%   - feasibleRatio: Ratio of feasible solutions
%   - objectiveMean: Mean objective values
%   - objectiveStd: Std of objective values
%
% Usage:
%   % In GUI, after calling runOptimizationAsync:
%   [future, queue] = runOptimizationAsync(absPath, callbacks);
%   if isa(future, 'parallel.FevalFuture')
%       afterEach(queue, @(data) handleOptimizationData(app, callbacks, data));
%   end
%
% Saving Results:
%   When isFinal=true, GUI can optionally save results using ResultsSaver:
%
%   if data.isFinal
%       % Update GUI first
%       callbacks.onAlgorithmEndCallback(data.results);
%
%       % Optional: Save results to disk
%       answer = questdlg('Save optimization results?', 'Save Results', ...
%           'Yes', 'No', 'Yes');
%       if strcmp(answer, 'Yes')
%           [file, path] = uiputfile('*.mat', 'Save Results As', ...
%               sprintf('%s_results.mat', app.config.problem.name));
%           if file ~= 0
%               ResultsSaver.saveAll(data.results, app.config, ...
%                   toc(app.optimizationStartTime), path, app.configFilePath);
%           end
%       end
%   end
%
% Example:
%   function RunButtonPushed(app, event)
%       % Prepare config
%       config = ConfigBuilder.buildConfig(app.guiData);
%       absPath = fullfile(pwd, 'temp', 'config.json');
%       ConfigBuilder.toJSON(config, absPath);
%
%       % Save for later use
%       app.config = config;
%       app.configFilePath = absPath;
%       app.optimizationStartTime = tic;
%
%       % Setup callbacks
%       callbacks = OptimizationCallbacks(app);
%       callbacks.setMaxIterations(config.algorithm.parameters.maxGenerations);
%       callbacks.resetStartTime();
%
%       % Start optimization
%       [future, queue] = runOptimizationAsync(absPath, callbacks);
%
%       if isa(future, 'parallel.FevalFuture')
%           % Async mode
%           app.asyncFuture = future;
%           app.RunButton.Enable = 'off';
%           app.StopButton.Enable = 'on';
%           afterEach(queue, @(data) handleOptimizationData(app, callbacks, data));
%       else
%           % Sync mode - already completed
%           callbacks.onAlgorithmEndCallback(future);
%       end
%   end

    % Check if this is final results or iteration data
    if isfield(data, 'isFinal') && data.isFinal
        % Final results - optimization completed
        fprintf('[handleOptimizationData] Optimization completed\n');

        % Call algorithm end callback
        callbacks.onAlgorithmEndCallback(data.results);

        % Update GUI button states (if app handle provided)
        if ~isempty(app) && isvalid(app)
            if isprop(app, 'RunButton')
                app.RunButton.Enable = 'on';
            end
            if isprop(app, 'StopButton')
                app.StopButton.Enable = 'off';
            end
            if isprop(app, 'asyncFuture')
                app.asyncFuture = [];
            end

            % Log completion to GUI
            if isprop(app, 'LogTextArea')
                logMsg = sprintf('[%s] Optimization task completed', datestr(now, 'HH:MM:SS'));
                currentLog = app.LogTextArea.Value;
                if isstring(currentLog)
                    currentLog = cellstr(currentLog(:));
                elseif ischar(currentLog)
                    currentLog = {currentLog};
                elseif iscell(currentLog)
                    currentLog = currentLog(:);
                else
                    currentLog = cell(0, 1);
                end
                currentLog(end+1, 1) = {logMsg};
                app.LogTextArea.Value = currentLog;
            end
        end

    else
        % Iteration data - update progress
        iteration = 0;
        if isfield(data, 'iteration')
            iteration = data.iteration;
        end

        % Call iteration callback
        callbacks.onIterationCallback(iteration, data);
    end
end
