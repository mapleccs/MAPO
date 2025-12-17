classdef OptimizationCallbacks < handle
    %% OptimizationCallbacks - GUI optimization callback handler
    %
    % Thread-safe callback handler for optimization algorithms.
    % Supports both synchronous (direct GUI update) and asynchronous
    % (parfeval with DataQueue) execution modes.
    %
    % IMPORTANT: This class is designed for SYNCHRONOUS mode only.
    % For parfeval async execution, do NOT set callbacks in the worker.
    % Instead, use afterEach or poll results from the Future object.
    %
    % Usage (Synchronous):
    %   callbacks = OptimizationCallbacks(guiHandle);
    %   callbacks.setMaxIterations(config.algorithm.parameters.maxGenerations);
    %   callbacks.resetStartTime();
    %   algorithm.setIterationCallback(@callbacks.onIterationCallback);
    %   algorithm.setAlgorithmEndCallback(@callbacks.onAlgorithmEndCallback);
    %   results = algorithm.optimize(problem, config);  % Run in main thread
    %
    % Usage (Asynchronous with DataQueue):
    %   See runOptimizationAsync.m wrapper for proper async implementation.
    %   Workers cannot directly update GUI - data must be sent via DataQueue.
    %
    % Key Features:
    %   - Rate-limited GUI updates (avoids freezing)
    %   - Defensive programming for missing data fields
    %   - Pareto front visualization
    %   - Convergence curve plotting
    %   - Progress estimation and display
    %   - Log message output (compatible with all MATLAB versions)

    properties (Access = private)
        guiHandle;              % Handle to GUI app (MAPOGUI instance)
        lastUpdateTime;         % Last GUI update timestamp (for rate limiting)
        updateInterval;         % Minimum interval between updates (seconds)
        startTime;              % Optimization start time
        maxIterations;          % Maximum iterations/generations (MUST be set!)
        iterationHistory;       % History of iteration data
        enableRateLimiting;     % Whether to apply rate limiting
    end

    methods
        function obj = OptimizationCallbacks(guiHandle, varargin)
            %% Constructor
            %
            % Input:
            %   guiHandle - GUI app instance handle
            %   varargin  - Optional parameters:
            %               'UpdateInterval', value (default: 0.5 seconds)
            %               'EnableRateLimiting', true/false (default: true)
            %
            % IMPORTANT: After construction, MUST call setMaxIterations()
            %            before starting optimization, otherwise progress
            %            bar will show 0%.
            %
            % Example:
            %   callbacks = OptimizationCallbacks(app, 'UpdateInterval', 1.0);
            %   callbacks.setMaxIterations(30);  % REQUIRED!

            obj.guiHandle = guiHandle;
            obj.lastUpdateTime = 0;
            obj.updateInterval = 0.5;  % Default: 0.5 seconds
            obj.startTime = tic;
            obj.maxIterations = 0;     % MUST be set via setMaxIterations()!
            obj.iterationHistory = struct([]);
            obj.enableRateLimiting = true;

            % Parse optional parameters
            for i = 1:2:length(varargin)
                switch lower(varargin{i})
                    case 'updateinterval'
                        obj.updateInterval = varargin{i+1};
                    case 'enableratelimiting'
                        obj.enableRateLimiting = varargin{i+1};
                end
            end
        end

        function onIterationCallback(obj, iteration, data)
            %% onIterationCallback - Iteration completion callback
            %
            % Input:
            %   iteration - Current iteration/generation number
            %   data      - Iteration data struct (from algorithm)
            %
            % Expected data fields (all optional, defensive handling):
            %   - iteration: current iteration number
            %   - evaluations: total evaluation count
            %   - bestObjectives: best objective values (1 x nObj)
            %   - feasibleRatio: ratio of feasible solutions (0-1)
            %   - objectiveMean: mean objective values
            %   - objectiveStd: std of objective values
            %   - archiveSize: size of Pareto archive (multi-objective)
            %   - paretoFront: Pareto front individuals (optional)
            %
            % WARNING: This method runs in the same thread as the algorithm.
            %          For parfeval workers, this will FAIL (cannot access GUI).
            %          Use DataQueue instead for async execution.

            % Check if rate limiting allows update
            if obj.enableRateLimiting
                currentTime = toc(obj.startTime);
                if (currentTime - obj.lastUpdateTime) < obj.updateInterval && ...
                   (obj.maxIterations == 0 || iteration ~= obj.maxIterations)
                    % Skip update unless it's the last iteration
                    return;
                end
                obj.lastUpdateTime = currentTime;
            end

            % Store iteration data (avoid storing large payloads such as Pareto fronts)
            if isstruct(data) && ~isempty(data)
                dataToStore = data;

                % Ensure bestObjectives exists for convergence curve (derive from matrices if needed)
                if ~isfield(dataToStore, 'bestObjectives') || isempty(dataToStore.bestObjectives)
                    best = [];
                    if isfield(data, 'populationObjectives') && isnumeric(data.populationObjectives) && ~isempty(data.populationObjectives)
                        best = obj.computeBestObjectivesFromMatrix(data.populationObjectives);
                    elseif isfield(data, 'paretoFront') && isnumeric(data.paretoFront) && ~isempty(data.paretoFront)
                        best = obj.computeBestObjectivesFromMatrix(data.paretoFront);
                    end
                    if ~isempty(best)
                        dataToStore.bestObjectives = best;
                    end
                end

                if isfield(dataToStore, 'paretoFront')
                    dataToStore.paretoFront = [];
                end
                if isfield(dataToStore, 'populationObjectives')
                    dataToStore.populationObjectives = [];
                end
                obj.iterationHistory(end+1) = dataToStore;
            end

            % Try to update GUI (may fail if GUI handle invalid or closed)
            try
                % Update progress bar and status text
                obj.updateProgress(iteration, data);

                % Update charts (Pareto front, convergence curves)
                obj.updateCharts(iteration, data);

                % Update log output
                obj.updateLog(iteration, data);

                % Force GUI refresh with rate limiting
                drawnow limitrate;

            catch ME
                % GUI update failed - likely GUI was closed or invalid handle
                warning('OptimizationCallbacks:GUIUpdateFailed', ...
                    'GUI update failed at iteration %d: %s', iteration, ME.message);
            end
        end

        function onAlgorithmEndCallback(obj, results)
            %% onAlgorithmEndCallback - Algorithm completion callback
            %
            % Input:
            %   results - Final optimization results struct
            %
            % Expected results fields (all optional):
            %   - evaluations: total evaluation count
            %   - iterations: total iterations
            %   - elapsedTime: total elapsed time (seconds)
            %   - population: final population
            %   - paretoFront: Pareto front solutions
            %   - bestObjectives: best objective values
            %   - convergenceData: convergence history

            try
                % Update final status
                obj.updateFinalStatus(results);

                % Update final charts
                obj.updateFinalCharts(results);

                % Update results table
                obj.updateResultsTable(results);

                % Log completion message
                obj.logCompletion(results);

                % Force final GUI refresh
                drawnow;

            catch ME
                warning('OptimizationCallbacks:FinalUpdateFailed', ...
                    'Final GUI update failed: %s', ME.message);
            end
        end

        function setMaxIterations(obj, maxIter)
            %% setMaxIterations - Set maximum iterations for progress calculation
            %
            % IMPORTANT: MUST be called before starting optimization!
            %
            % Input:
            %   maxIter - Maximum generations/iterations from algorithm config
            %
            % Example:
            %   callbacks.setMaxIterations(config.algorithm.parameters.maxGenerations);

            if maxIter <= 0
                warning('OptimizationCallbacks:InvalidMaxIterations', ...
                    'maxIterations must be positive, got %d. Progress bar will show 0%%.', maxIter);
            end
            obj.maxIterations = maxIter;
        end

        function resetStartTime(obj)
            %% resetStartTime - Reset start time counter
            %
            % Call this immediately before starting optimization to ensure
            % accurate time tracking.

            obj.startTime = tic;
            obj.lastUpdateTime = 0;
            obj.iterationHistory = struct([]);
        end
    end

    methods (Access = private)

        function updateProgress(obj, iteration, data)
            %% updateProgress - Update progress bar and status text

            % Skip if GUI handle invalid
            if isempty(obj.guiHandle) || ~isvalid(obj.guiHandle)
                return;
            end

            % Calculate progress percentage
            if obj.maxIterations > 0
                progressPercent = iteration / obj.maxIterations;
            else
                progressPercent = 0;
                % Warn once if maxIterations not set
                if iteration == 1
                    warning('OptimizationCallbacks:MaxIterationsNotSet', ...
                        'maxIterations is 0, progress bar will not update. Call setMaxIterations() first!');
                end
            end

            % Update progress bar (if exists)
            if isprop(obj.guiHandle, 'ProgressBar')
                obj.guiHandle.ProgressBar.Value = progressPercent * 100;
            end

            % Calculate elapsed and remaining time
            elapsedTime = toc(obj.startTime);
            if progressPercent > 0
                totalEstimatedTime = elapsedTime / progressPercent;
                remainingTime = totalEstimatedTime - elapsedTime;
            else
                remainingTime = 0;
            end

            % Extract evaluation count (defensive)
            evalCount = 0;
            if isstruct(data) && isfield(data, 'evaluations')
                evalCount = data.evaluations;
            end

            % Format status text
            statusText = sprintf('Running - Generation %d/%d | Evaluations: %d | Elapsed: %s | Remaining: ~%s', ...
                iteration, obj.maxIterations, evalCount, ...
                obj.formatTime(elapsedTime), obj.formatTime(remainingTime));

            % Update status label (if exists)
            if isprop(obj.guiHandle, 'StatusLabel')
                obj.guiHandle.StatusLabel.Text = statusText;
            end
        end

        function updateCharts(obj, iteration, data)
            %% updateCharts - Update Pareto front and convergence charts

            % Skip if GUI handle invalid
            if isempty(obj.guiHandle) || ~isvalid(obj.guiHandle)
                return;
            end

            % Update Pareto front plot (support plotting non-Pareto solutions as black dots)
            if isprop(obj.guiHandle, 'ParetoAxes') && isstruct(data)
                if isfield(data, 'populationObjectives') && ~isempty(data.populationObjectives)
                    pareto = [];
                    if isfield(data, 'paretoFront')
                        pareto = data.paretoFront;
                    end
                    obj.plotParetoScatter(data.populationObjectives, pareto);
                elseif isfield(data, 'paretoFront') && ~isempty(data.paretoFront)
                    obj.plotParetoFront(data.paretoFront);
                end
            end

            % Update convergence curve (if history available)
            if isprop(obj.guiHandle, 'ConvergenceAxes') && ~isempty(obj.iterationHistory)
                obj.plotConvergenceCurve();
            end
        end

        function plotParetoFront(obj, paretoFront)
            %% plotParetoFront - Plot Pareto front on GUI axes

            if isempty(paretoFront)
                return;
            end

            % Support both numeric objective matrices and Individual arrays
            objValues = [];
            nObj = 0;

            if isa(paretoFront, 'Population')
                try
                    paretoFront = paretoFront.getAll();
                catch
                    return;
                end
            end

            if isnumeric(paretoFront)
                if isvector(paretoFront)
                    objValues = paretoFront(:);
                else
                    objValues = paretoFront;
                end
                nObj = size(objValues, 2);
            else
                % Assume array of Individuals with getObjectives()
                nSolutions = length(paretoFront);
                if nSolutions == 0
                    return;
                end
                try
                    objectives = paretoFront(1).getObjectives();
                    nObj = length(objectives);
                catch
                    return;  % Failed to get objectives
                end
                objValues = zeros(nSolutions, nObj);
                for i = 1:nSolutions
                    try
                        objValues(i, :) = paretoFront(i).getObjectives();
                    catch
                    end
                end
            end

            if isempty(objValues) || nObj == 0
                return;
            end

            % Plot based on number of objectives
            axes(obj.guiHandle.ParetoAxes);
            cla(obj.guiHandle.ParetoAxes);
            hold(obj.guiHandle.ParetoAxes, 'on');

            if nObj == 1
                plot(obj.guiHandle.ParetoAxes, 1:size(objValues, 1), objValues(:, 1), ...
                    'ro', 'MarkerSize', 6, 'MarkerFaceColor', 'r');
                xlabel(obj.guiHandle.ParetoAxes, 'Solution');
                ylabel(obj.guiHandle.ParetoAxes, 'Objective');
                title(obj.guiHandle.ParetoAxes, 'Objective Values');
                grid(obj.guiHandle.ParetoAxes, 'on');

            elseif nObj == 2
                % 2D plot
                plot(obj.guiHandle.ParetoAxes, objValues(:, 1), objValues(:, 2), ...
                    'ro', 'MarkerSize', 6, 'MarkerFaceColor', 'r');
                xlabel(obj.guiHandle.ParetoAxes, 'Objective 1');
                ylabel(obj.guiHandle.ParetoAxes, 'Objective 2');
                title(obj.guiHandle.ParetoAxes, 'Pareto Front');
                grid(obj.guiHandle.ParetoAxes, 'on');

            elseif nObj == 3
                % 3D plot
                plot3(obj.guiHandle.ParetoAxes, ...
                    objValues(:, 1), objValues(:, 2), objValues(:, 3), ...
                    'ro', 'MarkerSize', 6, 'MarkerFaceColor', 'r');
                xlabel(obj.guiHandle.ParetoAxes, 'Objective 1');
                ylabel(obj.guiHandle.ParetoAxes, 'Objective 2');
                zlabel(obj.guiHandle.ParetoAxes, 'Objective 3');
                title(obj.guiHandle.ParetoAxes, 'Pareto Front');
                grid(obj.guiHandle.ParetoAxes, 'on');
                view(obj.guiHandle.ParetoAxes, 3);

            else
                % Multi-objective (>3): plot first 2 objectives
                plot(obj.guiHandle.ParetoAxes, objValues(:, 1), objValues(:, 2), ...
                    'ro', 'MarkerSize', 6, 'MarkerFaceColor', 'r');
                xlabel(obj.guiHandle.ParetoAxes, 'Objective 1');
                ylabel(obj.guiHandle.ParetoAxes, 'Objective 2');
                title(obj.guiHandle.ParetoAxes, sprintf('Pareto Front (showing 2/%d objectives)', nObj));
                grid(obj.guiHandle.ParetoAxes, 'on');
            end

            hold(obj.guiHandle.ParetoAxes, 'off');
        end

        function best = computeBestObjectivesFromMatrix(~, objValues)
            %% computeBestObjectivesFromMatrix - Best values per objective (min, omit NaN/Inf)

            best = [];

            if isempty(objValues) || ~isnumeric(objValues)
                return;
            end

            if isvector(objValues)
                objValues = objValues(:);
            end

            if size(objValues, 2) == 0
                return;
            end

            nObj = size(objValues, 2);
            bestVec = nan(1, nObj);

            for j = 1:nObj
                col = objValues(:, j);
                col = col(isfinite(col));
                if ~isempty(col)
                    bestVec(j) = min(col);
                end
            end

            if ~all(isnan(bestVec))
                best = bestVec;
            end
        end

        function objValues = extractObjectiveMatrix(~, solutions)
            %% extractObjectiveMatrix - Convert Population/Individuals/numeric to objective matrix

            objValues = [];
            if isempty(solutions)
                return;
            end

            if isa(solutions, 'Population')
                try
                    solutions = solutions.getAll();
                catch
                    objValues = [];
                    return;
                end
            end

            if isnumeric(solutions)
                if isvector(solutions)
                    objValues = solutions(:);
                else
                    objValues = solutions;
                end
            else
                try
                    nSolutions = length(solutions);
                catch
                    objValues = [];
                    return;
                end

                if nSolutions == 0
                    objValues = [];
                    return;
                end

                try
                    nObj = length(solutions(1).getObjectives());
                catch
                    objValues = [];
                    return;
                end

                if nObj <= 0
                    objValues = [];
                    return;
                end

                objValues = nan(nSolutions, nObj);
                for i = 1:nSolutions
                    try
                        objValues(i, :) = solutions(i).getObjectives();
                    catch
                    end
                end
            end

            % Drop invalid rows (NaN/Inf) defensively
            if isempty(objValues)
                return;
            end

            if isvector(objValues)
                objValues = objValues(:);
            end

            validRow = all(isfinite(objValues), 2);
            objValues = objValues(validRow, :);
        end

        function plotParetoScatter(obj, allSolutions, paretoSolutions)
            %% plotParetoScatter - Plot all solutions (black) + Pareto (red)

            allObj = obj.extractObjectiveMatrix(allSolutions);
            paretoObj = obj.extractObjectiveMatrix(paretoSolutions);

            if isempty(allObj) && isempty(paretoObj)
                return;
            end

            if ~isempty(paretoObj)
                nObj = size(paretoObj, 2);
            else
                nObj = size(allObj, 2);
            end

            if nObj <= 0
                return;
            end

            ax = obj.guiHandle.ParetoAxes;
            nAll = size(allObj, 1);
            nPareto = size(paretoObj, 1);

            % Detect "penalty" outliers for axis focusing and diagnostics
            outlierMaskAll = false(0, 1);
            outlierMaskPareto = false(0, 1);
            try
                if ~isempty(allObj)
                    outlierMaskAll = obj.detectObjectiveOutliers(allObj);
                end
                if ~isempty(paretoObj)
                    outlierMaskPareto = obj.detectObjectiveOutliers(paretoObj);
                end
            catch
                outlierMaskAll = false(size(allObj, 1), 1);
                outlierMaskPareto = false(size(paretoObj, 1), 1);
            end
            nOutliers = sum(outlierMaskAll);

            axes(ax);
            cla(ax);
            hold(ax, 'on');

            % Plot all solutions (black)
            if ~isempty(allObj)
                if nObj == 1
                    plot(ax, 1:size(allObj, 1), allObj(:, 1), ...
                        'ko', 'MarkerSize', 4, 'MarkerFaceColor', 'k', ...
                        'DisplayName', 'All Solutions');
                    xlabel(ax, 'Solution');
                    ylabel(ax, 'Objective');
                    title(ax, sprintf('Objective Values (All: %d, Pareto: %d, Outliers: %d)', ...
                        nAll, nPareto, nOutliers));
                elseif nObj == 2
                    plot(ax, allObj(:, 1), allObj(:, 2), ...
                        'ko', 'MarkerSize', 4, 'MarkerFaceColor', 'k', ...
                        'DisplayName', 'All Solutions');
                    xlabel(ax, 'Objective 1');
                    ylabel(ax, 'Objective 2');
                    title(ax, sprintf('Objective Space (All: %d, Pareto: %d, Outliers: %d)', ...
                        nAll, nPareto, nOutliers));
                elseif nObj == 3
                    plot3(ax, allObj(:, 1), allObj(:, 2), allObj(:, 3), ...
                        'ko', 'MarkerSize', 4, 'MarkerFaceColor', 'k', ...
                        'DisplayName', 'All Solutions');
                    xlabel(ax, 'Objective 1');
                    ylabel(ax, 'Objective 2');
                    zlabel(ax, 'Objective 3');
                    title(ax, sprintf('Objective Space (All: %d, Pareto: %d, Outliers: %d)', ...
                        nAll, nPareto, nOutliers));
                    view(ax, 3);
                else
                    plot(ax, allObj(:, 1), allObj(:, 2), ...
                        'ko', 'MarkerSize', 4, 'MarkerFaceColor', 'k', ...
                        'DisplayName', 'All Solutions');
                    xlabel(ax, 'Objective 1');
                    ylabel(ax, 'Objective 2');
                    title(ax, sprintf('Objective Space (All: %d, Pareto: %d, Outliers: %d; showing 2/%d objectives)', ...
                        nAll, nPareto, nOutliers, nObj));
                end
            else
                % Still set labels/titles even if only Pareto is available
                if nObj == 1
                    xlabel(ax, 'Solution');
                    ylabel(ax, 'Objective');
                    title(ax, sprintf('Objective Values (All: %d, Pareto: %d, Outliers: %d)', ...
                        nAll, nPareto, nOutliers));
                elseif nObj == 2
                    xlabel(ax, 'Objective 1');
                    ylabel(ax, 'Objective 2');
                    title(ax, sprintf('Objective Space (All: %d, Pareto: %d, Outliers: %d)', ...
                        nAll, nPareto, nOutliers));
                elseif nObj == 3
                    xlabel(ax, 'Objective 1');
                    ylabel(ax, 'Objective 2');
                    zlabel(ax, 'Objective 3');
                    title(ax, sprintf('Objective Space (All: %d, Pareto: %d, Outliers: %d)', ...
                        nAll, nPareto, nOutliers));
                    view(ax, 3);
                else
                    xlabel(ax, 'Objective 1');
                    ylabel(ax, 'Objective 2');
                    title(ax, sprintf('Objective Space (All: %d, Pareto: %d, Outliers: %d; showing 2/%d objectives)', ...
                        nAll, nPareto, nOutliers, nObj));
                end
            end

            % Plot Pareto (red) on top
            if ~isempty(paretoObj)
                if nObj == 1
                    plot(ax, 1:size(paretoObj, 1), paretoObj(:, 1), ...
                        'ro', 'MarkerSize', 6, 'MarkerFaceColor', 'r', ...
                        'DisplayName', 'Pareto');
                elseif nObj == 2
                    plot(ax, paretoObj(:, 1), paretoObj(:, 2), ...
                        'ro', 'MarkerSize', 6, 'MarkerFaceColor', 'r', ...
                        'DisplayName', 'Pareto');
                elseif nObj == 3
                    plot3(ax, paretoObj(:, 1), paretoObj(:, 2), paretoObj(:, 3), ...
                        'ro', 'MarkerSize', 6, 'MarkerFaceColor', 'r', ...
                        'DisplayName', 'Pareto');
                else
                    plot(ax, paretoObj(:, 1), paretoObj(:, 2), ...
                        'ro', 'MarkerSize', 6, 'MarkerFaceColor', 'r', ...
                        'DisplayName', 'Pareto');
                end
            end

            % Auto-focus axis to avoid "penalty outliers" collapsing Pareto points to one dot
            try
                plottedObj = [];
                if ~isempty(allObj)
                    plottedObj = allObj;
                elseif ~isempty(paretoObj)
                    plottedObj = paretoObj;
                end

                if ~isempty(plottedObj) && size(plottedObj, 2) >= 2
                    % Focus uses inlier points (drop outliers by robust magnitude threshold)
                    inlierObj = plottedObj;
                    if ~isempty(allObj) && ~isempty(outlierMaskAll) && length(outlierMaskAll) == size(allObj, 1)
                        inlierObj = allObj(~outlierMaskAll, :);
                        if isempty(inlierObj)
                            inlierObj = allObj;
                        end
                    end

                    paretoForFocus = paretoObj;
                    if ~isempty(paretoObj) && ~isempty(outlierMaskPareto) && length(outlierMaskPareto) == size(paretoObj, 1)
                        paretoInlier = paretoObj(~outlierMaskPareto, :);
                        if ~isempty(paretoInlier)
                            paretoForFocus = paretoInlier;
                        end
                    end

                    % Clamp focus range relative to Pareto range to keep Pareto points visually separated
                    clampFactor = 50;
                    for dim = 1:min(3, size(inlierObj, 2))
                        baseObj = inlierObj;
                        if ~isempty(paretoForFocus)
                            baseObj = paretoForFocus;
                        end

                        pMin = min(baseObj(:, dim));
                        pMax = max(baseObj(:, dim));
                        pRange = pMax - pMin;
                        if ~isfinite(pRange) || pRange <= 0
                            pRange = max(1, abs(pMin)) * 0.05;
                        end

                        fMin = min(inlierObj(:, dim));
                        fMax = max(inlierObj(:, dim));
                        fRange = fMax - fMin;

                        if isfinite(fRange) && isfinite(pRange) && fRange > clampFactor * pRange
                            pMid = (pMin + pMax) / 2;
                            half = (clampFactor * pRange) / 2;
                            fMin = pMid - half;
                            fMax = pMid + half;
                        end

                        margin = 0.10 * (fMax - fMin);
                        if ~isfinite(margin) || margin <= 0
                            margin = max(1, abs(fMin)) * 0.05;
                        end

                        lim = [fMin - margin, fMax + margin];
                        if dim == 1
                            xlim(ax, lim);
                        elseif dim == 2
                            ylim(ax, lim);
                        elseif dim == 3
                            zlim(ax, lim);
                        end
                    end

                    % Ensure UIAxes doesn't auto-expand back
                    try
                        ax.XLimMode = 'manual';
                        ax.YLimMode = 'manual';
                    catch
                    end
                end
            catch
            end

            grid(ax, 'on');
            try
                legend(ax, 'Location', 'best');
            catch
            end

            hold(ax, 'off');
        end

        function outlierMask = detectObjectiveOutliers(~, objMatrix)
            %% detectObjectiveOutliers - Robustly detect "penalty" objective rows for plotting focus

            outlierMask = false(0, 1);
            if isempty(objMatrix) || ~isnumeric(objMatrix)
                return;
            end

            try
                maxAbs = max(abs(objMatrix), [], 2);
            catch
                outlierMask = false(size(objMatrix, 1), 1);
                return;
            end

            maxAbsFinite = maxAbs(isfinite(maxAbs));
            if isempty(maxAbsFinite)
                outlierMask = false(size(objMatrix, 1), 1);
                return;
            end

            medAbs = median(maxAbsFinite);
            if ~isfinite(medAbs)
                medAbs = 0;
            end

            % Threshold adapts to typical objective scale; catches common 1e6~1e8 penalties
            absThreshold = max(1e6, 1000 * medAbs);
            outlierMask = maxAbs > absThreshold;
        end

        function plotConvergenceCurve(obj)
            %% plotConvergenceCurve - Plot convergence curve from history

            if isempty(obj.iterationHistory)
                return;
            end

            % Extract best objective values over iterations (defensive)
            nIter = length(obj.iterationHistory);
            iterations = zeros(nIter, 1);
            bestObjs = [];

            for i = 1:nIter
                % Extract iteration number
                if isfield(obj.iterationHistory(i), 'iteration')
                    iterations(i) = obj.iterationHistory(i).iteration;
                else
                    iterations(i) = i;  % Fallback: use index
                end

                % Extract best objectives
                if isfield(obj.iterationHistory(i), 'bestObjectives') && ...
                   ~isempty(obj.iterationHistory(i).bestObjectives)
                    if isempty(bestObjs)
                        nObj = length(obj.iterationHistory(i).bestObjectives);
                        bestObjs = nan(nIter, nObj);
                    end
                    bestObjs(i, :) = obj.iterationHistory(i).bestObjectives;
                end
            end

            % Plot if we have objective data
            if ~isempty(bestObjs)
                axes(obj.guiHandle.ConvergenceAxes);
                cla(obj.guiHandle.ConvergenceAxes);
                hold(obj.guiHandle.ConvergenceAxes, 'on');

                nObj = size(bestObjs, 2);
                colors = lines(nObj);

                hasLine = false;
                for i = 1:nObj
                    y = bestObjs(:, i);
                    x = iterations;
                    mask = isfinite(y);
                    if ~any(mask)
                        continue;
                    end
                    plot(obj.guiHandle.ConvergenceAxes, x(mask), y(mask), ...
                        '-o', 'Color', colors(i, :), 'LineWidth', 1.5, ...
                        'DisplayName', sprintf('Obj %d', i));
                    hasLine = true;
                end

                xlabel(obj.guiHandle.ConvergenceAxes, 'Generation');
                ylabel(obj.guiHandle.ConvergenceAxes, 'Best Objective Value');
                title(obj.guiHandle.ConvergenceAxes, 'Convergence Curve');
                if hasLine
                    legend(obj.guiHandle.ConvergenceAxes, 'Location', 'best');
                end
                grid(obj.guiHandle.ConvergenceAxes, 'on');
                hold(obj.guiHandle.ConvergenceAxes, 'off');
            end
        end

        function updateLog(obj, iteration, data)
            %% updateLog - Append log message to log area

            % Skip if GUI handle invalid
            if isempty(obj.guiHandle) || ~isvalid(obj.guiHandle)
                return;
            end

            % Skip if no log area
            if ~isprop(obj.guiHandle, 'LogTextArea')
                return;
            end

            % Extract data fields (defensive)
            evalCount = 0;
            paretoSize = 0;

            if isstruct(data)
                if isfield(data, 'evaluations')
                    evalCount = data.evaluations;
                end

                if isfield(data, 'archiveSize')
                    paretoSize = data.archiveSize;
                elseif isfield(data, 'paretoFront')
                    if isnumeric(data.paretoFront)
                        paretoSize = size(data.paretoFront, 1);
                    else
                        paretoSize = length(data.paretoFront);
                    end
                end
            end

            % Format log message
            timestamp = datestr(now, 'HH:MM:SS');
            logMsg = sprintf('[%s] Generation %d: Evaluations=%d, Pareto Solutions=%d', ...
                timestamp, iteration, evalCount, paretoSize);

            % Append best objective if available
            if isstruct(data) && isfield(data, 'bestObjectives') && ~isempty(data.bestObjectives)
                objStr = sprintf('%.4f ', data.bestObjectives);
                logMsg = sprintf('%s, Best=[%s]', logMsg, objStr);
            end

            % Append to log area
            currentLog = obj.guiHandle.LogTextArea.Value;
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

            % Limit log length to last 1000 lines
            if size(currentLog, 1) > 1000
                currentLog = currentLog(end-999:end, 1);
            end

            obj.guiHandle.LogTextArea.Value = currentLog;

            % Note: scroll() method not available in all MATLAB versions
            % GUI should handle auto-scrolling via its own mechanism
        end

        function updateFinalStatus(obj, results)
            %% updateFinalStatus - Update final completion status

            % Skip if GUI handle invalid
            if isempty(obj.guiHandle) || ~isvalid(obj.guiHandle)
                return;
            end

            % Update progress bar to 100%
            if isprop(obj.guiHandle, 'ProgressBar')
                obj.guiHandle.ProgressBar.Value = 100;
            end

            % Extract results fields (defensive)
            elapsedTime = 0;
            evalCount = 0;
            iterations = 0;

            if isstruct(results)
                if isfield(results, 'elapsedTime')
                    elapsedTime = results.elapsedTime;
                end
                if isfield(results, 'evaluations')
                    evalCount = results.evaluations;
                end
                if isfield(results, 'iterations')
                    iterations = results.iterations;
                end
            end

            % Format final status text
            statusText = sprintf('Completed - %d Generations | %d Evaluations | Total Time: %s', ...
                iterations, evalCount, obj.formatTime(elapsedTime));

            % Update status label
            if isprop(obj.guiHandle, 'StatusLabel')
                obj.guiHandle.StatusLabel.Text = statusText;
            end
        end

        function updateFinalCharts(obj, results)
            %% updateFinalCharts - Update charts with final results

            % Skip if GUI handle invalid
            if isempty(obj.guiHandle) || ~isvalid(obj.guiHandle)
                return;
            end

            % Update Pareto front with final data (defensive)
            if isprop(obj.guiHandle, 'ParetoAxes') && isstruct(results) && ...
               isfield(results, 'paretoFront') && ~isempty(results.paretoFront)
                allSolutions = [];
                if isfield(results, 'allEvaluatedIndividuals') && ~isempty(results.allEvaluatedIndividuals)
                    allSolutions = results.allEvaluatedIndividuals;
                elseif isfield(results, 'population') && ~isempty(results.population)
                    allSolutions = results.population;
                end

                if ~isempty(allSolutions)
                    obj.plotParetoScatter(allSolutions, results.paretoFront);
                else
                    obj.plotParetoFront(results.paretoFront);
                end
            end

            % Final convergence curve
            if isprop(obj.guiHandle, 'ConvergenceAxes')
                % Fallback: if async mode skipped storing history, use algorithm results.history
                if isempty(obj.iterationHistory) && isstruct(results) && ...
                   isfield(results, 'history') && ~isempty(results.history)
                    try
                        obj.iterationHistory = results.history;
                        for k = 1:length(obj.iterationHistory)
                            if isfield(obj.iterationHistory(k), 'paretoFront')
                                obj.iterationHistory(k).paretoFront = [];
                            end
                            if isfield(obj.iterationHistory(k), 'populationObjectives')
                                obj.iterationHistory(k).populationObjectives = [];
                            end
                        end
                    catch
                    end
                end

                if ~isempty(obj.iterationHistory)
                    obj.plotConvergenceCurve();
                end
            end
        end

        function updateResultsTable(obj, results)
            %% updateResultsTable - Populate results table with Pareto solutions

            % Skip if GUI handle invalid or no table
            if isempty(obj.guiHandle) || ~isvalid(obj.guiHandle)
                return;
            end

            if ~isprop(obj.guiHandle, 'ResultsTable')
                return;
            end

            % Extract Pareto front (defensive)
            if ~isstruct(results) || ~isfield(results, 'paretoFront') || ...
               isempty(results.paretoFront)
                return;
            end

            paretoFront = results.paretoFront;
            if isa(paretoFront, 'Population')
                try
                    paretoFront = paretoFront.getAll();
                catch
                    return;
                end
            end

            nSolutions = length(paretoFront);
            if nSolutions == 0
                return;
            end

            % Build table data
            tableData = cell(nSolutions, 0);
            columnNames = {};

            % Extract variables and objectives
            for i = 1:nSolutions
                try
                    ind = paretoFront(i);
                    vars = ind.getVariables();
                    objs = ind.getObjectives();

                    if i == 1
                        % Initialize columns
                        nVars = length(vars);
                        nObjs = length(objs);

                        for j = 1:nVars
                            columnNames{end+1} = sprintf('Var%d', j);
                        end
                        for j = 1:nObjs
                            columnNames{end+1} = sprintf('Obj%d', j);
                        end

                        tableData = cell(nSolutions, nVars + nObjs);
                    end

                    % Fill row
                    for j = 1:length(vars)
                        tableData{i, j} = vars(j);
                    end
                    for j = 1:length(objs)
                        tableData{i, length(vars) + j} = objs(j);
                    end
                catch
                    % Skip invalid individual
                end
            end

            % Update GUI table
            if ~isempty(tableData)
                obj.guiHandle.ResultsTable.Data = tableData;
                obj.guiHandle.ResultsTable.ColumnName = columnNames;
            end
        end

        function logCompletion(obj, results)
            %% logCompletion - Log optimization completion message

            % Skip if GUI handle invalid
            if isempty(obj.guiHandle) || ~isvalid(obj.guiHandle)
                return;
            end

            if ~isprop(obj.guiHandle, 'LogTextArea')
                return;
            end

            % Extract results fields (defensive)
            elapsedTime = 0;
            evalCount = 0;
            iterations = 0;

            if isstruct(results)
                if isfield(results, 'elapsedTime')
                    elapsedTime = results.elapsedTime;
                end
                if isfield(results, 'evaluations')
                    evalCount = results.evaluations;
                end
                if isfield(results, 'iterations')
                    iterations = results.iterations;
                end
            end

            % Format completion message
            timestamp = datestr(now, 'HH:MM:SS');
            logMsg = sprintf('[%s] ==== OPTIMIZATION COMPLETED ====', timestamp);
            logMsg2 = sprintf('[%s] Total Generations: %d | Evaluations: %d | Time: %s', ...
                timestamp, iterations, evalCount, obj.formatTime(elapsedTime));

            % Append to log
            currentLog = obj.guiHandle.LogTextArea.Value;
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
            currentLog(end+1, 1) = {logMsg2};

            % Add Pareto front size (defensive)
            if isstruct(results) && isfield(results, 'paretoFront') && ~isempty(results.paretoFront)
                paretoFront = results.paretoFront;
                if isa(paretoFront, 'Population')
                    try
                        paretoSize = paretoFront.size();
                    catch
                        paretoSize = 0;
                    end
                elseif isnumeric(paretoFront)
                    paretoSize = size(paretoFront, 1);
                else
                    paretoSize = length(paretoFront);
                end
                logMsg3 = sprintf('[%s] Pareto Solutions Found: %d', timestamp, paretoSize);
                currentLog(end+1, 1) = {logMsg3};
            end

            obj.guiHandle.LogTextArea.Value = currentLog;
        end

        function timeStr = formatTime(~, seconds)
            %% formatTime - Format seconds to HH:MM:SS string

            if isnan(seconds) || isinf(seconds) || seconds < 0
                timeStr = '--:--:--';
                return;
            end

            hours = floor(seconds / 3600);
            minutes = floor(mod(seconds, 3600) / 60);
            secs = floor(mod(seconds, 60));

            timeStr = sprintf('%02d:%02d:%02d', hours, minutes, secs);
        end
    end
end
