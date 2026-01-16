classdef ExpressionEvaluator < Evaluator
    % ExpressionEvaluator - Evaluate objectives/constraints from expressions.

    properties
        timeout = 300;
        constraintPenalty = 1e8;
    end

    properties (Access = private)
        simulator;
        config;
        compiled;
        compiledExpressions;
        variableNames;
        variableUnits;
        resultUnits;
        paramValues;
        paramUnits;
        resultNames;
        derivedDefs;
        objectiveDefs;
        constraintDefs;
    end

    methods
        function obj = ExpressionEvaluator(simulator, config)
            obj@Evaluator();
            if nargin >= 1
                obj.simulator = simulator;
            else
                obj.simulator = [];
            end
            if nargin >= 2
                obj.config = config;
            else
                obj.config = struct();
            end
            obj.compiled = false;
            obj.compiledExpressions = struct();
            obj.variableNames = {};
            obj.variableUnits = struct();
            obj.resultUnits = struct();
            obj.paramValues = struct();
            obj.paramUnits = struct();
            obj.resultNames = {};
            obj.derivedDefs = struct([]);
            obj.objectiveDefs = struct([]);
            obj.constraintDefs = struct([]);

            obj.applyConfigDefaults();
        end

        function setProblem(obj, problem)
            setProblem@Evaluator(obj, problem);
            obj.compiled = false;
        end

        function result = evaluate(obj, x)
            obj.evaluationCounter = obj.evaluationCounter + 1;

            try
                obj.ensureCompiled();

                % Run simulator if provided
                simResults = struct();
                if ~isempty(obj.simulator)
                    obj.simulator.setVariables(x);
                    success = obj.simulator.run(obj.timeout);
                    if ~success
                        result = obj.createPenaltyResult('Simulation failed or did not converge');
                        return;
                    end
                    simResults = obj.fetchResults();
                end

                % Build lookup context
                ctx = obj.buildContext(x, simResults);

                % Evaluate derived values
                ctx = obj.evaluateDerived(ctx);

                % Evaluate objectives and constraints
                objectives = obj.evaluateObjectives(ctx);
                constraints = obj.evaluateConstraints(ctx);

                result = obj.createSuccessResult(objectives, constraints, '');
            catch ME
                result = obj.createPenaltyResult(ME.message);
            end
        end
    end

    methods (Access = private)
        function applyConfigDefaults(obj)
            if isfield(obj.config, 'problem') && isfield(obj.config.problem, 'evaluator')
                evalCfg = obj.config.problem.evaluator;
                if isfield(evalCfg, 'timeout')
                    obj.timeout = evalCfg.timeout;
                end
                if isfield(evalCfg, 'constraintPenalty')
                    obj.constraintPenalty = evalCfg.constraintPenalty;
                elseif isfield(evalCfg, 'economicParameters') && isfield(evalCfg.economicParameters, 'constraintPenalty')
                    obj.constraintPenalty = evalCfg.economicParameters.constraintPenalty;
                end
            end
        end

        function ensureCompiled(obj)
            if obj.compiled
                return;
            end
            if ~isfield(obj.config, 'problem')
                error('ExpressionEvaluator:MissingConfig', 'Missing problem configuration.');
            end

            problem = obj.config.problem;

            % Variable metadata
            obj.variableNames = {};
            obj.variableUnits = struct();
            if isfield(problem, 'variables') && ~isempty(problem.variables)
                for i = 1:length(problem.variables)
                    v = problem.variables(i);
                    name = char(string(v.name));
                    obj.variableNames{end+1} = name; %#ok<AGROW>
                    if isfield(v, 'unit')
                        obj.variableUnits.(name) = char(string(v.unit));
                    else
                        obj.variableUnits.(name) = '';
                    end
                end
            end

            % Result units (from simulator node mapping)
            obj.resultUnits = struct();
            if isfield(obj.config, 'simulator') && isfield(obj.config.simulator, 'nodeMapping')
                nm = obj.config.simulator.nodeMapping;
                if isfield(nm, 'resultUnits') && isstruct(nm.resultUnits)
                    obj.resultUnits = nm.resultUnits;
                end
            end

            % Parameters
            obj.paramValues = struct();
            obj.paramUnits = struct();
            if isfield(problem, 'evaluator')
                evalCfg = problem.evaluator;
                if isfield(evalCfg, 'economicParameters') && isstruct(evalCfg.economicParameters)
                    obj.paramValues = evalCfg.economicParameters;
                end
                metaUnits = obj.lookupEvaluatorMetaUnits(evalCfg);
                obj.paramUnits = metaUnits;
                if isfield(evalCfg, 'parameterUnits') && isstruct(evalCfg.parameterUnits)
                    fields = fieldnames(evalCfg.parameterUnits);
                    for i = 1:length(fields)
                        name = fields{i};
                        unitStr = evalCfg.parameterUnits.(name);
                        if isempty(unitStr)
                            continue;
                        end
                        obj.paramUnits.(name) = char(string(unitStr));
                    end
                end
            end

            % Derived expressions
            obj.derivedDefs = obj.buildDerivedDefs(problem);

            % Objectives
            obj.objectiveDefs = obj.buildObjectiveDefs(problem);

            % Constraints
            obj.constraintDefs = obj.buildConstraintDefs(problem);

            % Collect result names from expressions
            obj.resultNames = obj.collectResultNames();

            obj.compiled = true;
        end

        function defs = buildDerivedDefs(obj, problem)
            defs = struct([]);
            if ~isfield(problem, 'derived') || isempty(problem.derived)
                return;
            end
            derived = problem.derived;
            for i = 1:length(derived)
                d = derived(i);
                name = char(string(d.name));
                expr = char(string(d.expression));
                unit = '';
                if isfield(d, 'unit')
                    unit = char(string(d.unit));
                end
                compiled = ExpressionEngine.compile(expr);
                obj.validateIdentifiers(compiled, sprintf('Derived "%s"', name));
                defs(i).name = name; %#ok<AGROW>
                defs(i).expression = expr;
                defs(i).unit = unit;
                defs(i).compiled = compiled;
            end
        end

        function defs = buildObjectiveDefs(obj, problem)
            defs = struct([]);
            if ~isfield(problem, 'objectives') || isempty(problem.objectives)
                return;
            end
            objs = problem.objectives;
            for i = 1:length(objs)
                o = objs(i);
                name = char(string(o.name));
                objType = 'minimize';
                if isfield(o, 'type')
                    objType = char(lower(string(o.type)));
                end
                expr = '';
                if isfield(o, 'expression')
                    expr = char(string(o.expression));
                end
                if isempty(expr)
                    expr = ['result.' name];
                end
                unit = '';
                if isfield(o, 'unit')
                    unit = char(string(o.unit));
                end
                compiled = ExpressionEngine.compile(expr);
                obj.validateIdentifiers(compiled, sprintf('Objective "%s"', name));
                defs(i).name = name; %#ok<AGROW>
                defs(i).type = objType;
                defs(i).expression = expr;
                defs(i).unit = unit;
                defs(i).compiled = compiled;
            end
        end

        function defs = buildConstraintDefs(obj, problem)
            defs = struct([]);
            if ~isfield(problem, 'constraints') || isempty(problem.constraints)
                return;
            end
            cons = problem.constraints;
            for i = 1:length(cons)
                c = cons(i);
                name = char(string(c.name));
                conType = 'inequality';
                if isfield(c, 'type')
                    conType = char(lower(string(c.type)));
                end
                expr = '';
                if isfield(c, 'expression')
                    expr = char(string(c.expression));
                end
                unit = '';
                if isfield(c, 'unit')
                    unit = char(string(c.unit));
                end
                tol = [];
                if isfield(c, 'tolerance')
                    tol = c.tolerance;
                end

                parsed = obj.parseConstraintExpression(expr);
                defs(i).name = name; %#ok<AGROW>
                defs(i).type = conType;
                defs(i).expression = expr;
                defs(i).unit = unit;
                defs(i).tolerance = tol;
                defs(i).parsed = parsed;
                if ~isempty(parsed.lhs)
                    defs(i).lhs = ExpressionEngine.compile(parsed.lhs);
                    obj.validateIdentifiers(defs(i).lhs, sprintf('Constraint "%s" (lhs)', name));
                else
                    defs(i).lhs = [];
                end
                if ~isempty(parsed.rhs)
                    defs(i).rhs = ExpressionEngine.compile(parsed.rhs);
                    obj.validateIdentifiers(defs(i).rhs, sprintf('Constraint "%s" (rhs)', name));
                else
                    defs(i).rhs = [];
                end
            end
        end

        function parsed = parseConstraintExpression(~, expr)
            parsed = struct('lhs', '', 'rhs', '', 'op', '');
            expr = strtrim(char(string(expr)));
            if isempty(expr)
                return;
            end
            tokens = regexp(expr, '^\s*(?<lhs>.+?)\s*(?<op><=|>=|==|=|<|>)\s*(?<rhs>.+)\s*$', 'names');
            if isempty(tokens)
                parsed.lhs = expr;
                parsed.rhs = '';
                parsed.op = '';
                return;
            end
            parsed.lhs = strtrim(tokens.lhs);
            parsed.rhs = strtrim(tokens.rhs);
            parsed.op = tokens.op;
        end

        function resultNames = collectResultNames(obj)
            resultNames = {};
            for i = 1:length(obj.derivedDefs)
                resultNames = [resultNames, obj.extractResultNames(obj.derivedDefs(i).compiled)]; %#ok<AGROW>
            end
            for i = 1:length(obj.objectiveDefs)
                resultNames = [resultNames, obj.extractResultNames(obj.objectiveDefs(i).compiled)]; %#ok<AGROW>
            end
            for i = 1:length(obj.constraintDefs)
                c = obj.constraintDefs(i);
                if ~isempty(c.lhs)
                    resultNames = [resultNames, obj.extractResultNames(c.lhs)]; %#ok<AGROW>
                end
                if ~isempty(c.rhs)
                    resultNames = [resultNames, obj.extractResultNames(c.rhs)]; %#ok<AGROW>
                end
            end
            resultNames = unique(resultNames);
        end

        function simResults = fetchResults(obj)
            simResults = struct();
            if isempty(obj.resultNames)
                return;
            end
            try
                simResults = obj.simulator.getResults(obj.resultNames);
            catch ME
                error('ExpressionEvaluator:ResultFetchFailed', 'Failed to fetch results: %s', ME.message);
            end
        end

        function ctx = buildContext(obj, x, simResults)
            valueMap = containers.Map('KeyType', 'char', 'ValueType', 'any');

            % Variables
            if length(x) ~= length(obj.variableNames)
                error('ExpressionEvaluator:SizeMismatch', 'Variable count mismatch.');
            end
            for i = 1:length(obj.variableNames)
                name = obj.variableNames{i};
                unitStr = '';
                if isfield(obj.variableUnits, name)
                    unitStr = obj.variableUnits.(name);
                end
                u = UnitRegistry.parseUnit(unitStr);
                valueMap(['x.' name]) = struct('value', x(i) * u.scale, 'dims', u.dims);
            end

            % Parameters
            paramFields = fieldnames(obj.paramValues);
            for i = 1:length(paramFields)
                name = paramFields{i};
                unitStr = '';
                if isfield(obj.paramUnits, name)
                    unitStr = obj.paramUnits.(name);
                end
                u = UnitRegistry.parseUnit(unitStr);
                valueMap(['param.' name]) = struct('value', obj.paramValues.(name) * u.scale, 'dims', u.dims);
            end

            % Results
            for i = 1:length(obj.resultNames)
                key = obj.resultNames{i};
                if ~isfield(simResults, key)
                    error('ExpressionEvaluator:MissingResult', 'Missing result value: %s', key);
                end
                unitStr = '';
                if isfield(obj.resultUnits, key)
                    unitStr = obj.resultUnits.(key);
                end
                u = UnitRegistry.parseUnit(unitStr);
                valueMap(['result.' key]) = struct('value', simResults.(key) * u.scale, 'dims', u.dims);
            end

            ctx.lookup = @(name) ExpressionEvaluator.lookupValue(valueMap, name);
            ctx.valueMap = valueMap;
        end

        function ctx = evaluateDerived(obj, ctx)
            for i = 1:length(obj.derivedDefs)
                d = obj.derivedDefs(i);
                [val, dims] = ExpressionEngine.evaluate(d.compiled, ctx);
                if ~isempty(d.unit)
                    u = UnitRegistry.parseUnit(d.unit);
                    if ~UnitRegistry.sameDims(dims, u.dims)
                        error('ExpressionEvaluator:UnitMismatch', ...
                            'Derived "%s" unit mismatch: %s', d.name, d.unit);
                    end
                end
                ctx.valueMap(['derived.' d.name]) = struct('value', val, 'dims', dims);
            end
        end

        function objectives = evaluateObjectives(obj, ctx)
            n = length(obj.objectiveDefs);
            objectives = zeros(1, n);
            for i = 1:n
                o = obj.objectiveDefs(i);
                [val, dims] = ExpressionEngine.evaluate(o.compiled, ctx);
                if ~isempty(o.unit)
                    u = UnitRegistry.parseUnit(o.unit);
                    if ~UnitRegistry.sameDims(dims, u.dims)
                        error('ExpressionEvaluator:UnitMismatch', ...
                            'Objective "%s" unit mismatch: %s', o.name, o.unit);
                    end
                    val = val / u.scale;
                end
                if strcmpi(o.type, 'maximize')
                    val = -val;
                end
                objectives(i) = val;
            end
        end

        function constraints = evaluateConstraints(obj, ctx)
            n = length(obj.constraintDefs);
            if n == 0
                constraints = [];
                return;
            end
            constraints = zeros(1, n);
            for i = 1:n
                c = obj.constraintDefs(i);
                g = obj.evaluateConstraintValue(c, ctx);
                constraints(i) = g;
            end
        end

        function g = evaluateConstraintValue(obj, c, ctx)
            if isempty(c.parsed.op)
                if isempty(c.lhs)
                    g = 0;
                    return;
                end
                [val, dims] = ExpressionEngine.evaluate(c.lhs, ctx);
                g = obj.finalizeConstraintValue(val, dims, c);
                return;
            end

            [lhsVal, lhsDims] = ExpressionEngine.evaluate(c.lhs, ctx);
            [rhsVal, rhsDims] = ExpressionEngine.evaluate(c.rhs, ctx);
            if ~UnitRegistry.sameDims(lhsDims, rhsDims)
                error('ExpressionEvaluator:UnitMismatch', ...
                    'Constraint "%s" sides have mismatched units.', c.name);
            end

            switch c.parsed.op
                case {'<=', '<'}
                    val = lhsVal - rhsVal;
                case {'>=', '>'}
                    val = rhsVal - lhsVal;
                case {'=', '=='}
                    val = abs(lhsVal - rhsVal);
                otherwise
                    val = lhsVal - rhsVal;
            end

            g = obj.finalizeConstraintValue(val, lhsDims, c);
        end

        function g = finalizeConstraintValue(obj, val, dims, c)
            if strcmpi(c.type, 'equality')
                tol = 0;
                if ~isempty(c.tolerance)
                    tol = c.tolerance;
                end
                g = val - tol;
            else
                g = val;
            end

            if ~isempty(c.unit)
                u = UnitRegistry.parseUnit(c.unit);
                if ~UnitRegistry.sameDims(dims, u.dims)
                    error('ExpressionEvaluator:UnitMismatch', ...
                        'Constraint "%s" unit mismatch: %s', c.name, c.unit);
                end
                g = g / u.scale;
            end
        end

        function result = createPenaltyResult(obj, message)
            nObj = obj.getProblemObjectiveCount();
            nCon = obj.getProblemConstraintCount();
            if nObj <= 0
                nObj = 1;
            end
            result = struct();
            result.objectives = obj.constraintPenalty * ones(1, nObj);
            result.constraints = obj.constraintPenalty * ones(1, nCon);
            result.success = false;
            result.message = message;
        end

        function n = getProblemObjectiveCount(obj)
            n = 0;
            if ~isempty(obj.problem) && isa(obj.problem, 'OptimizationProblem')
                n = obj.problem.getNumberOfObjectives();
            elseif isfield(obj.config, 'problem') && isfield(obj.config.problem, 'objectives')
                n = length(obj.config.problem.objectives);
            end
        end

        function n = getProblemConstraintCount(obj)
            n = 0;
            if ~isempty(obj.problem) && isa(obj.problem, 'OptimizationProblem')
                n = obj.problem.getNumberOfConstraints();
            elseif isfield(obj.config, 'problem') && isfield(obj.config.problem, 'constraints')
                n = length(obj.config.problem.constraints);
            end
        end

        function units = lookupEvaluatorMetaUnits(obj, evaluatorConfig)
            units = struct();
            if ~isstruct(evaluatorConfig) || ~isfield(evaluatorConfig, 'type')
                return;
            end
            evalType = char(string(evaluatorConfig.type));
            thisFile = mfilename('fullpath');
            frameworkRoot = fileparts(fileparts(fileparts(thisFile)));
            metaPath = fullfile(frameworkRoot, 'problem', 'evaluator', 'evaluator_meta.json');
            if ~exist(metaPath, 'file')
                return;
            end
            try
                meta = jsondecode(fileread(metaPath));
            catch
                return;
            end
            for i = 1:length(meta)
                if strcmpi(meta(i).type, evalType)
                    params = meta(i).parameters;
                    for j = 1:length(params)
                        if isfield(params(j), 'name') && isfield(params(j), 'unit')
                            units.(params(j).name) = params(j).unit;
                        end
                    end
                    return;
                end
            end
        end

        function validateIdentifiers(~, compiled, label)
            allowed = {'x.', 'param.', 'result.', 'derived.'};
            ids = compiled.identifiers;
            for i = 1:length(ids)
                name = ids{i};
                ok = false;
                for j = 1:numel(allowed)
                    if startsWith(name, allowed{j})
                        ok = true;
                        break;
                    end
                end
                if ~ok
                    error('ExpressionEvaluator:InvalidIdentifier', ...
                        '%s uses invalid symbol "%s". Use result./x./param./derived. prefixes.', label, name);
                end
            end
        end

        function names = extractResultNames(~, compiled)
            names = {};
            if isempty(compiled) || ~isfield(compiled, 'identifiers')
                return;
            end
            ids = compiled.identifiers;
            for j = 1:length(ids)
                name = ids{j};
                if startsWith(name, 'result.')
                    names{end+1} = name(8:end); %#ok<AGROW>
                end
            end
        end
    end

    methods (Static, Access = private)
        function item = lookupValue(map, name)
            if isKey(map, name)
                item = map(name);
                return;
            end
            error('ExpressionEvaluator:UnknownSymbol', 'Unknown symbol: %s', name);
        end
    end
end
