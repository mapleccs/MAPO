classdef ANNNSGAII < AlgorithmBase
    % ANNNSGAII
    % Surrogate-assisted NSGA-II with optional dynamic SBX/polynomial mutation.

    properties (Access = private)
        populationSize
        maxGenerations
        crossoverRate
        mutationRate

        useDynamicOperators
        crossoverDistIndex
        mutationDistIndex
        crossoverDistIndexStart
        crossoverDistIndexEnd
        mutationDistIndexStart
        mutationDistIndexEnd

        lowerBounds
        upperBounds
        currentGeneration

        randomSeed

        trainingSamples
        trainingMaxAttempts
        samplingMethod
        requireSuccess
        requireFeasible

        surrogateType
        ridgeLambda

        annHiddenLayers
        annTrainFcn
        annMaxEpochs
        annTrainRatio
        annValRatio
        annTestRatio

        verificationEnabled
        verifyParetoFront
        verifyParetoLimit
        verifyTOPSIS
        topsisWeights

        exactEvaluator
        surrogateEvaluator
        surrogateModel

        surrogateParetoFront
        exactParetoFront
        topsisResult

        trainingInfo
        verificationInfo
    end

    methods
        function obj = ANNNSGAII()
            obj@AlgorithmBase();

            obj.populationSize = 100;
            obj.maxGenerations = 250;
            obj.crossoverRate = 0.9;
            obj.mutationRate = 1.0;

            obj.useDynamicOperators = true;
            obj.crossoverDistIndex = 20;
            obj.mutationDistIndex = 20;
            obj.crossoverDistIndexStart = 5;
            obj.crossoverDistIndexEnd = 30;
            obj.mutationDistIndexStart = 5;
            obj.mutationDistIndexEnd = 30;

            obj.lowerBounds = [];
            obj.upperBounds = [];
            obj.currentGeneration = 0;

            obj.randomSeed = [];

            obj.trainingSamples = 200;
            obj.trainingMaxAttempts = 2000;
            obj.samplingMethod = 'lhs';
            obj.requireSuccess = true;
            obj.requireFeasible = false;

            obj.surrogateType = 'poly2';
            obj.ridgeLambda = 1e-6;

            obj.annHiddenLayers = [25, 25];
            obj.annTrainFcn = 'trainscg';
            obj.annMaxEpochs = 500;
            obj.annTrainRatio = 0.7;
            obj.annValRatio = 0.2;
            obj.annTestRatio = 0.1;

            obj.verificationEnabled = true;
            obj.verifyParetoFront = false;
            obj.verifyParetoLimit = 0;
            obj.verifyTOPSIS = true;
            obj.topsisWeights = [];

            obj.exactEvaluator = [];
            obj.surrogateEvaluator = [];
            obj.surrogateModel = [];

            obj.surrogateParetoFront = [];
            obj.exactParetoFront = [];
            obj.topsisResult = struct();

            obj.trainingInfo = struct();
            obj.verificationInfo = struct();
        end

        function results = optimize(obj, problem, config)
            obj.initialize(problem, config);
            obj.loadConfig(config);
            obj.validateProblem();
            obj.getBounds();

            if ~isempty(obj.randomSeed)
                try
                    rng(obj.randomSeed, 'twister');
                catch
                    rng(obj.randomSeed);
                end
            end

            obj.exactEvaluator = obj.problem.evaluator;
            obj.currentGeneration = 0;

            obj.logMessage('INFO', 'ANN-NSGA-II: collecting training samples...');
            [trainX, trainY, trainInfo] = obj.collectTrainingData();
            obj.trainingInfo = trainInfo;

            obj.logMessage('INFO', 'ANN-NSGA-II: training surrogate (%s)...', obj.surrogateType);
            obj.surrogateModel = obj.trainSurrogate(trainX, trainY);
            obj.surrogateEvaluator = SurrogateEvaluator(obj.surrogateModel);

            obj.problem.evaluator = obj.surrogateEvaluator;

            obj.initializePopulation();

            obj.logMessage('INFO', 'ANN-NSGA-II: starting evolution...');
            while ~obj.shouldStop()
                obj.currentGeneration = obj.currentGeneration + 1;

                etaC = obj.getCurrentCrossoverEta();
                etaM = obj.getCurrentMutationEta();

                offspring = obj.generateOffspring(etaC, etaM);
                offspring.evaluate(obj.problem.evaluator);
                obj.incrementEvaluationCount(offspring.size());

                combinedPop = obj.population.merge(offspring);
                combinedPop.fastNonDominatedSort();
                combinedPop.calculateCrowdingDistance();
                obj.population = obj.environmentalSelection(combinedPop);

                iterData = obj.getIterationData(obj.currentGeneration);
                obj.logIteration(obj.currentGeneration, iterData);

                if mod(obj.currentGeneration, 10) == 0 || obj.shouldStop()
                    obj.logProgress();
                end
            end

            obj.problem.evaluator = obj.exactEvaluator;

            obj.surrogateParetoFront = obj.population.getParetoFront();
            obj.verificationInfo = struct();
            obj.exactParetoFront = [];

            if obj.verificationEnabled
                [obj.exactParetoFront, obj.verificationInfo] = obj.verifySolutions();
            end

            results = obj.finalizeResults();
        end
    end

    methods (Access = protected)
        function validateProblem(obj)
            validateProblem@AlgorithmBase(obj);

            if obj.problem.getNumberOfObjectives() == 0
                error('ANNNSGAII:InvalidProblem', 'Problem must have at least one objective.');
            end
        end

        function results = finalizeResults(obj)
            results = finalizeResults@AlgorithmBase(obj);

            results.trainingInfo = obj.trainingInfo;
            results.verificationInfo = obj.verificationInfo;
            results.topsis = obj.topsisResult;

            results.surrogateModel = obj.surrogateModel;
            results.surrogateParetoFront = obj.surrogateParetoFront;

            if obj.verificationEnabled && ~isempty(obj.exactParetoFront)
                results.exactParetoFront = obj.exactParetoFront;
                results.paretoFront = obj.exactParetoFront;
            else
                results.exactParetoFront = [];
            end
        end
    end

    methods (Access = private)
        function loadConfig(obj, config)
            if ~isstruct(config)
                return;
            end

            if isfield(config, 'populationSize')
                obj.populationSize = config.populationSize;
            end
            if isfield(config, 'maxGenerations')
                obj.maxGenerations = config.maxGenerations;
            end
            obj.maxEvaluations = obj.populationSize * (obj.maxGenerations + 1);

            if isfield(config, 'crossoverRate')
                obj.crossoverRate = config.crossoverRate;
            end
            if isfield(config, 'mutationRate')
                obj.mutationRate = config.mutationRate;
            end

            if isfield(config, 'operators')
                ops = config.operators;
                if isfield(ops, 'useDynamicOperators')
                    obj.useDynamicOperators = ops.useDynamicOperators;
                end
                if isfield(ops, 'crossoverDistIndex')
                    obj.crossoverDistIndex = ops.crossoverDistIndex;
                end
                if isfield(ops, 'mutationDistIndex')
                    obj.mutationDistIndex = ops.mutationDistIndex;
                end
                if isfield(ops, 'crossoverDistIndexStart')
                    obj.crossoverDistIndexStart = ops.crossoverDistIndexStart;
                end
                if isfield(ops, 'crossoverDistIndexEnd')
                    obj.crossoverDistIndexEnd = ops.crossoverDistIndexEnd;
                end
                if isfield(ops, 'mutationDistIndexStart')
                    obj.mutationDistIndexStart = ops.mutationDistIndexStart;
                end
                if isfield(ops, 'mutationDistIndexEnd')
                    obj.mutationDistIndexEnd = ops.mutationDistIndexEnd;
                end
            else
                if isfield(config, 'useDynamicOperators')
                    obj.useDynamicOperators = config.useDynamicOperators;
                end
                if isfield(config, 'crossoverDistIndex')
                    obj.crossoverDistIndex = config.crossoverDistIndex;
                end
                if isfield(config, 'mutationDistIndex')
                    obj.mutationDistIndex = config.mutationDistIndex;
                end
                if isfield(config, 'crossoverDistIndexStart')
                    obj.crossoverDistIndexStart = config.crossoverDistIndexStart;
                end
                if isfield(config, 'crossoverDistIndexEnd')
                    obj.crossoverDistIndexEnd = config.crossoverDistIndexEnd;
                end
                if isfield(config, 'mutationDistIndexStart')
                    obj.mutationDistIndexStart = config.mutationDistIndexStart;
                end
                if isfield(config, 'mutationDistIndexEnd')
                    obj.mutationDistIndexEnd = config.mutationDistIndexEnd;
                end
            end

            if isfield(config, 'training')
                t = config.training;
                if isfield(t, 'samples')
                    obj.trainingSamples = t.samples;
                end
                if isfield(t, 'maxAttempts')
                    obj.trainingMaxAttempts = t.maxAttempts;
                end
                if isfield(t, 'samplingMethod')
                    obj.samplingMethod = t.samplingMethod;
                end
                if isfield(t, 'requireSuccess')
                    obj.requireSuccess = t.requireSuccess;
                end
                if isfield(t, 'requireFeasible')
                    obj.requireFeasible = t.requireFeasible;
                end
                if isfield(t, 'randomSeed')
                    obj.randomSeed = t.randomSeed;
                end
            else
                if isfield(config, 'trainingSamples')
                    obj.trainingSamples = config.trainingSamples;
                end
                if isfield(config, 'trainingMaxAttempts')
                    obj.trainingMaxAttempts = config.trainingMaxAttempts;
                end
                if isfield(config, 'samplingMethod')
                    obj.samplingMethod = config.samplingMethod;
                end
                if isfield(config, 'randomSeed')
                    obj.randomSeed = config.randomSeed;
                end
            end

            if isfield(config, 'surrogate')
                s = config.surrogate;
                if isfield(s, 'type')
                    obj.surrogateType = s.type;
                end
                if isfield(s, 'ridgeLambda')
                    obj.ridgeLambda = s.ridgeLambda;
                end
                if isfield(s, 'annHiddenLayers')
                    obj.annHiddenLayers = s.annHiddenLayers;
                end
                if isfield(s, 'annTrainFcn')
                    obj.annTrainFcn = s.annTrainFcn;
                end
                if isfield(s, 'annMaxEpochs')
                    obj.annMaxEpochs = s.annMaxEpochs;
                end
                if isfield(s, 'annTrainRatio')
                    obj.annTrainRatio = s.annTrainRatio;
                end
                if isfield(s, 'annValRatio')
                    obj.annValRatio = s.annValRatio;
                end
                if isfield(s, 'annTestRatio')
                    obj.annTestRatio = s.annTestRatio;
                end
            end

            if isfield(config, 'verification')
                v = config.verification;
                if isfield(v, 'enabled')
                    obj.verificationEnabled = v.enabled;
                end
                if isfield(v, 'verifyParetoFront')
                    obj.verifyParetoFront = v.verifyParetoFront;
                end
                if isfield(v, 'verifyParetoLimit')
                    obj.verifyParetoLimit = v.verifyParetoLimit;
                end
                if isfield(v, 'verifyTOPSIS')
                    obj.verifyTOPSIS = v.verifyTOPSIS;
                end
                if isfield(v, 'topsisWeights')
                    obj.topsisWeights = v.topsisWeights;
                end
            end
        end

        function getBounds(obj)
            bounds = obj.problem.getBounds();
            obj.lowerBounds = bounds(:, 1)';
            obj.upperBounds = bounds(:, 2)';
        end

        function initializePopulation(obj)
            numVars = obj.problem.getNumberOfVariables();
            obj.logMessage('INFO', 'Initializing population (N=%d, dim=%d)', obj.populationSize, numVars);

            obj.population = Population.random(obj.populationSize, numVars, obj.lowerBounds, obj.upperBounds);
            obj.population.evaluate(obj.problem.evaluator);
            obj.incrementEvaluationCount(obj.populationSize);

            obj.population.fastNonDominatedSort();
            obj.population.calculateCrowdingDistance();
        end

        function offspring = generateOffspring(obj, etaC, etaM)
            numVars = obj.problem.getNumberOfVariables();
            offspring = Population();

            individuals = obj.population.getAll();

            for i = 1:obj.populationSize
                parent1 = AnnNsga2Operators.binaryTournament(individuals);
                parent2 = AnnNsga2Operators.binaryTournament(individuals);

                if rand() < obj.crossoverRate
                    [child1Vars, child2Vars] = AnnNsga2Operators.sbxCrossover( ...
                        parent1.getVariables(), parent2.getVariables(), ...
                        obj.lowerBounds, obj.upperBounds, etaC);

                    if rand() < 0.5
                        childVars = child1Vars;
                    else
                        childVars = child2Vars;
                    end
                else
                    if rand() < 0.5
                        childVars = parent1.getVariables();
                    else
                        childVars = parent2.getVariables();
                    end
                end

                childVars = AnnNsga2Operators.polynomialMutation(childVars, ...
                    obj.lowerBounds, obj.upperBounds, obj.mutationRate, etaM);

                child = Individual(childVars);
                offspring.add(child);
            end
        end

        function selectedPop = environmentalSelection(obj, combinedPop)
            selectedPop = Population();
            individuals = combinedPop.getAll();

            [~, sortIdx] = sort(arrayfun(@(ind) ind.rank * 1e6 - ind.crowdingDistance, individuals));
            for i = 1:min(obj.populationSize, length(sortIdx))
                selectedPop.add(individuals(sortIdx(i)).clone());
            end
        end

        function eta = getCurrentCrossoverEta(obj)
            if obj.useDynamicOperators
                eta = obj.interpolateEta(obj.crossoverDistIndexStart, obj.crossoverDistIndexEnd);
            else
                eta = obj.crossoverDistIndex;
            end
        end

        function eta = getCurrentMutationEta(obj)
            if obj.useDynamicOperators
                eta = obj.interpolateEta(obj.mutationDistIndexStart, obj.mutationDistIndexEnd);
            else
                eta = obj.mutationDistIndex;
            end
        end

        function eta = interpolateEta(obj, etaStart, etaEnd)
            if obj.maxGenerations <= 1
                eta = etaEnd;
                return;
            end
            t = (obj.currentGeneration - 1) / (obj.maxGenerations - 1);
            eta = etaStart + (etaEnd - etaStart) * t;
        end

        function [X, Y, info] = collectTrainingData(obj)
            numVars = obj.problem.getNumberOfVariables();
            nObj = obj.problem.getNumberOfObjectives();
            nCon = obj.problem.getNumberOfConstraints();
            nOut = nObj + nCon;

            X = zeros(obj.trainingSamples, numVars);
            Y = zeros(obj.trainingSamples, nOut);

            accepted = 0;
            attempts = 0;

            candidates = obj.generateCandidateMatrix(obj.trainingMaxAttempts, numVars);

            while accepted < obj.trainingSamples && attempts < obj.trainingMaxAttempts
                attempts = attempts + 1;
                x = candidates(attempts, :);

                result = obj.exactEvaluator.evaluate(x);

                if ~isfield(result, 'objectives') || isempty(result.objectives)
                    continue;
                end

                objectives = result.objectives(:)';
                if length(objectives) ~= nObj
                    continue;
                end

                if isfield(result, 'constraints') && ~isempty(result.constraints)
                    constraints = result.constraints(:)';
                else
                    constraints = zeros(1, nCon);
                end

                if obj.requireSuccess && isfield(result, 'success') && ~result.success
                    continue;
                end

                if obj.requireFeasible && any(constraints > 0)
                    continue;
                end

                out = [objectives, constraints];
                if any(~isfinite(out))
                    continue;
                end

                accepted = accepted + 1;
                X(accepted, :) = x;
                Y(accepted, :) = out;
            end

            if accepted < obj.trainingSamples
                X = X(1:accepted, :);
                Y = Y(1:accepted, :);
            end

            info = struct();
            info.requestedSamples = obj.trainingSamples;
            info.acceptedSamples = accepted;
            info.attempts = attempts;
            info.samplingMethod = obj.samplingMethod;
        end

        function candidates = generateCandidateMatrix(obj, n, numVars)
            lb = obj.lowerBounds;
            ub = obj.upperBounds;

            switch lower(obj.samplingMethod)
                case 'lhs'
                    u = obj.lhsUnit(n, numVars);
                otherwise
                    u = rand(n, numVars);
            end

            candidates = lb + u .* (ub - lb);
        end

        function u = lhsUnit(obj, n, d)
            u = zeros(n, d);
            for j = 1:d
                perm = randperm(n);
                u(:, j) = (perm' - rand(n, 1)) / n;
            end
        end

        function model = trainSurrogate(obj, X, Y)
            nObj = obj.problem.getNumberOfObjectives();
            nCon = obj.problem.getNumberOfConstraints();
            nOut = nObj + nCon;

            inputMean = mean(X, 1);
            inputStd = std(X, 0, 1);
            inputStd(inputStd == 0) = 1;
            Xz = (X - inputMean) ./ inputStd;

            outputMean = mean(Y, 1);
            outputStd = std(Y, 0, 1);
            outputStd(outputStd == 0) = 1;
            Yz = (Y - outputMean) ./ outputStd;

            model = struct();
            model.type = obj.surrogateType;
            model.nObjectives = nObj;
            model.nConstraints = nCon;
            model.inputMean = inputMean;
            model.inputStd = inputStd;
            model.outputMean = outputMean;
            model.outputStd = outputStd;
            model.penaltyValue = 1e12;

            if nOut == 0 || isempty(Xz) || isempty(Yz)
                model.W = [];
                return;
            end

            switch lower(obj.surrogateType)
                case 'poly2'
                    Phi = SurrogateEvaluator.buildPoly2FeatureMatrix(Xz);
                    p = size(Phi, 2);
                    A = Phi' * Phi + obj.ridgeLambda * eye(p);
                    B = Phi' * Yz;
                    model.W = A \ B;

                case 'ann'
                    if exist('feedforwardnet', 'file') ~= 2
                        error('ANNNSGAII:MissingToolbox', ...
                            'feedforwardnet not found. Install Deep Learning Toolbox or use surrogate.type=poly2.');
                    end

                    net = feedforwardnet(obj.annHiddenLayers, obj.annTrainFcn);
                    net.inputs{1}.processFcns = {};
                    net.outputs{end}.processFcns = {};

                    for i = 1:length(obj.annHiddenLayers)
                        net.layers{i}.transferFcn = 'poslin';
                    end
                    net.layers{length(obj.annHiddenLayers) + 1}.transferFcn = 'purelin';

                    net.divideFcn = 'dividerand';
                    net.divideParam.trainRatio = obj.annTrainRatio;
                    net.divideParam.valRatio = obj.annValRatio;
                    net.divideParam.testRatio = obj.annTestRatio;

                    net.trainParam.epochs = obj.annMaxEpochs;

                    net = train(net, Xz', Yz');
                    model.net = net;
                    model.W = [];

                otherwise
                    error('ANNNSGAII:InvalidSurrogateType', 'Unknown surrogate type: %s', obj.surrogateType);
            end
        end

        function [exactFront, info] = verifySolutions(obj)
            info = struct();
            info.enabled = true;
            info.verifyParetoFront = obj.verifyParetoFront;
            info.verifyTOPSIS = obj.verifyTOPSIS;

            surrogateFront = obj.surrogateParetoFront;
            exactFront = [];

            if isempty(surrogateFront) || surrogateFront.isEmpty()
                return;
            end

            if obj.verifyParetoFront
                inds = surrogateFront.getAll();
                n = length(inds);

                limit = obj.verifyParetoLimit;
                if isempty(limit) || limit <= 0 || limit > n
                    limit = n;
                end

                exactPop = Population();
                for i = 1:limit
                    ind = obj.evaluateExact(inds(i));
                    exactPop.add(ind);
                end

                exactPop.fastNonDominatedSort();
                exactPop.calculateCrowdingDistance();
                exactFront = exactPop.getParetoFront();
                info.verifiedParetoCount = limit;
            else
                info.verifiedParetoCount = 0;
            end

            sourceForTopsis = surrogateFront;
            if ~isempty(exactFront) && ~exactFront.isEmpty()
                sourceForTopsis = exactFront;
            end

            if isempty(obj.topsisWeights)
                nObj = obj.problem.getNumberOfObjectives();
                obj.topsisWeights = ones(1, nObj) / max(1, nObj);
            end

            [bestInd, bestIdx, scores] = obj.selectByTOPSIS(sourceForTopsis, obj.topsisWeights);
            obj.topsisResult = struct();
            obj.topsisResult.index = bestIdx;
            obj.topsisResult.score = [];
            if ~isempty(scores) && bestIdx > 0
                obj.topsisResult.score = scores(bestIdx);
            end
            if ~isempty(bestInd)
                obj.topsisResult.variables = bestInd.getVariables();
                obj.topsisResult.objectives = bestInd.getObjectives();
                obj.topsisResult.isFeasible = bestInd.isFeasible();
            end

            if obj.verifyTOPSIS && isempty(exactFront)
                if ~isempty(bestInd)
                    verifiedBest = obj.evaluateExact(bestInd);
                    obj.topsisResult.exactObjectives = verifiedBest.getObjectives();
                    obj.topsisResult.exactConstraints = verifiedBest.getConstraints();
                    obj.topsisResult.exactFeasible = verifiedBest.isFeasible();
                end
            end
        end

        function indOut = evaluateExact(obj, indIn)
            x = indIn.getVariables();
            result = obj.exactEvaluator.evaluate(x);

            indOut = Individual(x);
            if isfield(result, 'objectives')
                indOut.setObjectives(result.objectives);
            end
            if isfield(result, 'constraints')
                indOut.setConstraints(result.constraints);
            end
        end

        function [bestInd, bestIdx, scores] = selectByTOPSIS(obj, pop, weights)
            bestInd = [];
            bestIdx = 0;
            scores = [];

            if isempty(pop) || pop.isEmpty()
                return;
            end

            inds = pop.getAll();
            n = length(inds);
            nObj = obj.problem.getNumberOfObjectives();

            F = nan(n, nObj);
            feasible = false(n, 1);
            for i = 1:n
                try
                    F(i, :) = inds(i).getObjectives();
                    feasible(i) = inds(i).isFeasible();
                catch
                end
            end

            valid = all(isfinite(F), 2);
            if any(feasible)
                valid = valid & feasible;
            end

            validIdx = find(valid);
            if isempty(validIdx)
                return;
            end

            Fv = F(validIdx, :);
            w = weights(:)' / sum(weights);

            denom = sqrt(sum(Fv .^ 2, 1));
            denom(denom == 0) = 1;
            R = Fv ./ denom;
            V = R .* w;

            idealBest = min(V, [], 1);
            idealWorst = max(V, [], 1);

            Splus = sqrt(sum((V - idealBest) .^ 2, 2));
            Sminus = sqrt(sum((V - idealWorst) .^ 2, 2));
            C = Sminus ./ (Splus + Sminus + eps);

            [~, localIdx] = max(C);
            bestIdx = validIdx(localIdx);
            bestInd = inds(bestIdx);

            scores = nan(n, 1);
            scores(validIdx) = C;
        end

        function logProgress(obj)
            paretoFront = obj.population.getParetoFront();
            paretoSize = paretoFront.size();

            obj.logMessage('INFO', 'Gen: %d/%d, Evals: %d, Pareto: %d', ...
                obj.currentGeneration, obj.maxGenerations, obj.evaluationCount, paretoSize);
        end

        function data = getIterationData(obj, iteration)
            data = struct();
            data.iteration = iteration;
            data.evaluations = obj.evaluationCount;
            data.bestObjectives = [];
            data.paretoFront = [];
            data.populationObjectives = [];
            data.archiveSize = 0;

            if isempty(obj.population)
                return;
            end

            inds = obj.population.getAll();
            if isempty(inds)
                return;
            end

            frontInds = Individual.empty(0, 0);
            try
                for i = 1:length(inds)
                    if inds(i).getRank() == 1
                        frontInds(end + 1) = inds(i); %#ok<AGROW>
                    end
                end
            catch
                frontInds = Individual.empty(0, 0);
            end

            if isempty(frontInds)
                frontInds = inds;
            end

            nSolutions = length(frontInds);
            if nSolutions == 0
                return;
            end

            try
                nObj = length(frontInds(1).getObjectives());
            catch
                nObj = 0;
            end
            if nObj <= 0
                return;
            end

            allObjValues = nan(length(inds), nObj);
            for i = 1:length(inds)
                try
                    allObjValues(i, :) = inds(i).getObjectives();
                catch
                end
            end
            validAll = ~all(isnan(allObjValues), 2);
            allObjValues = allObjValues(validAll, :);
            data.populationObjectives = allObjValues;

            objValues = nan(nSolutions, nObj);
            for i = 1:nSolutions
                try
                    objValues(i, :) = frontInds(i).getObjectives();
                catch
                end
            end
            validRow = ~all(isnan(objValues), 2);
            objValues = objValues(validRow, :);

            data.paretoFront = objValues;
            data.archiveSize = size(objValues, 1);

            best = nan(1, nObj);
            if ~isempty(allObjValues)
                for j = 1:nObj
                    col = allObjValues(:, j);
                    col = col(isfinite(col));
                    if ~isempty(col)
                        best(j) = min(col);
                    end
                end
            end
            data.bestObjectives = best;
        end
    end
end
