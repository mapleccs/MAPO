classdef ConfigValidator
    %% ConfigValidator - 配置验证器
    %
    % 验证配置的完整性和正确性，确保配置可以被 run_case.m 正常使用。
    %
    % 用法:
    %   [valid, errors, warnings] = ConfigValidator.validate(config);
    %   [valid, errors] = ConfigValidator.validateProblem(problem);
    %   [valid, errors] = ConfigValidator.validateSimulator(simulator);
    %   [valid, errors] = ConfigValidator.validateAlgorithm(algorithm);

    methods (Static)

        function [valid, errors, warnings] = validate(config)
            %% validate - 验证完整配置
            %
            % 输入:
            %   config - 配置结构体（从 ConfigBuilder.buildConfig 生成）
            %
            % 返回:
            %   valid    - 是否通过验证
            %   errors   - 错误列表（元胞数组）
            %   warnings - 警告列表（元胞数组）

            errors = {};
            warnings = {};

            % 检查顶层结构
            if ~isstruct(config)
                errors{end+1} = 'Config must be a struct';
                valid = false;
                return;
            end

            if ~isfield(config, 'problem')
                errors{end+1} = 'Missing required field: problem';
            end
            if ~isfield(config, 'simulator')
                errors{end+1} = 'Missing required field: simulator';
            end
            if ~isfield(config, 'algorithm')
                errors{end+1} = 'Missing required field: algorithm';
            end

            if ~isempty(errors)
                valid = false;
                return;
            end

            % 验证各部分
            [validProb, errProb, warnProb] = ConfigValidator.validateProblem(config.problem);
            [validSim, errSim, warnSim] = ConfigValidator.validateSimulator(config.simulator);
            [validAlg, errAlg, warnAlg] = ConfigValidator.validateAlgorithm(config.algorithm);

            % 合并结果
            errors = [errProb, errSim, errAlg];
            warnings = [warnProb, warnSim, warnAlg];
            valid = validProb && validSim && validAlg;
        end

        function [valid, errors, warnings] = validateProblem(problem)
            %% validateProblem - 验证问题配置
            %
            % 输入:
            %   problem - 问题配置结构体
            %
            % 返回:
            %   valid    - 是否通过验证
            %   errors   - 错误列表
            %   warnings - 警告列表

            errors = {};
            warnings = {};

            % 检查基本字段
            if ~isfield(problem, 'name') || isempty(problem.name)
                errors{end+1} = 'Problem name is required';
            end

            % 检查变量
            if ~isfield(problem, 'variables') || isempty(problem.variables)
                errors{end+1} = 'At least one variable is required';
            else
                [validVar, errVar, warnVar] = ConfigValidator.validateVariables(problem.variables);
                errors = [errors, errVar];
                warnings = [warnings, warnVar];
            end

            % 检查目标
            if ~isfield(problem, 'objectives') || isempty(problem.objectives)
                errors{end+1} = 'At least one objective is required';
            else
                [validObj, errObj, warnObj] = ConfigValidator.validateObjectives(problem.objectives);
                errors = [errors, errObj];
                warnings = [warnings, warnObj];
            end

            % 检查约束（可选）
            if isfield(problem, 'constraints') && ~isempty(problem.constraints)
                [validCon, errCon, warnCon] = ConfigValidator.validateConstraints(problem.constraints);
                errors = [errors, errCon];
                warnings = [warnings, warnCon];
            end

            % 检查评估器
            if ~isfield(problem, 'evaluator')
                errors{end+1} = 'Evaluator configuration is required';
            else
                [validEval, errEval, warnEval] = ConfigValidator.validateEvaluator(problem.evaluator);
                errors = [errors, errEval];
                warnings = [warnings, warnEval];
            end

            valid = isempty(errors);
        end

        function [valid, errors, warnings] = validateVariables(variables)
            %% validateVariables - 验证变量配置
            errors = {};
            warnings = {};

            for i = 1:length(variables)
                var = variables(i);
                prefix = sprintf('Variable #%d', i);

                % 检查必填字段
                if ~isfield(var, 'name') || isempty(var.name)
                    errors{end+1} = sprintf('%s: name is required', prefix);
                end

                if ~isfield(var, 'type') || isempty(var.type)
                    errors{end+1} = sprintf('%s: type is required', prefix);
                elseif ~ismember(var.type, {'continuous', 'integer', 'discrete'})
                    errors{end+1} = sprintf('%s: invalid type "%s"', prefix, var.type);
                end

                % 检查边界
                if ~isfield(var, 'lowerBound')
                    errors{end+1} = sprintf('%s (%s): lowerBound is required', prefix, var.name);
                elseif isnan(var.lowerBound)
                    errors{end+1} = sprintf('%s (%s): lowerBound is NaN (invalid numeric input)', prefix, var.name);
                end

                if ~isfield(var, 'upperBound')
                    errors{end+1} = sprintf('%s (%s): upperBound is required', prefix, var.name);
                elseif isnan(var.upperBound)
                    errors{end+1} = sprintf('%s (%s): upperBound is NaN (invalid numeric input)', prefix, var.name);
                end

                % 检查边界合理性
                if isfield(var, 'lowerBound') && isfield(var, 'upperBound') && ...
                   ~isnan(var.lowerBound) && ~isnan(var.upperBound)
                    if var.lowerBound >= var.upperBound
                        errors{end+1} = sprintf('%s (%s): lowerBound (%.4f) must be < upperBound (%.4f)', ...
                            prefix, var.name, var.lowerBound, var.upperBound);
                    end
                end

                % 检查初始值
                if isfield(var, 'initialValue') && ~isnan(var.initialValue)
                    if isfield(var, 'lowerBound') && isfield(var, 'upperBound')
                        if var.initialValue < var.lowerBound || var.initialValue > var.upperBound
                            warnings{end+1} = sprintf('%s (%s): initialValue (%.4f) outside bounds [%.4f, %.4f]', ...
                                prefix, var.name, var.initialValue, var.lowerBound, var.upperBound);
                        end
                    end
                end
            end

            valid = isempty(errors);
        end

        function [valid, errors, warnings] = validateObjectives(objectives)
            %% validateObjectives - 验证目标配置
            errors = {};
            warnings = {};

            for i = 1:length(objectives)
                obj = objectives(i);
                prefix = sprintf('Objective #%d', i);

                % 检查必填字段
                if ~isfield(obj, 'name') || isempty(obj.name)
                    errors{end+1} = sprintf('%s: name is required', prefix);
                end

                if ~isfield(obj, 'type') || isempty(obj.type)
                    errors{end+1} = sprintf('%s: type is required', prefix);
                elseif ~ismember(obj.type, {'minimize', 'maximize'})
                    errors{end+1} = sprintf('%s: invalid type "%s"', prefix, obj.type);
                end

                % 检查权重
                if isfield(obj, 'weight')
                    if isnan(obj.weight)
                        errors{end+1} = sprintf('%s (%s): weight is NaN (invalid numeric input)', prefix, obj.name);
                    elseif obj.weight <= 0
                        warnings{end+1} = sprintf('%s (%s): weight (%.4f) should be positive', ...
                            prefix, obj.name, obj.weight);
                    end
                end
            end

            valid = isempty(errors);
        end

        function [valid, errors, warnings] = validateConstraints(constraints)
            %% validateConstraints - 验证约束配置
            errors = {};
            warnings = {};

            for i = 1:length(constraints)
                con = constraints(i);
                prefix = sprintf('Constraint #%d', i);

                % 检查必填字段
                if ~isfield(con, 'name') || isempty(con.name)
                    errors{end+1} = sprintf('%s: name is required', prefix);
                end

                if ~isfield(con, 'type') || isempty(con.type)
                    errors{end+1} = sprintf('%s: type is required', prefix);
                elseif ~ismember(con.type, {'inequality', 'equality'})
                    errors{end+1} = sprintf('%s: invalid type "%s"', prefix, con.type);
                end

                if ~isfield(con, 'expression') || isempty(con.expression)
                    warnings{end+1} = sprintf('%s (%s): expression is empty', prefix, con.name);
                end
            end

            valid = isempty(errors);
        end

        function [valid, errors, warnings] = validateEvaluator(evaluator)
            %% validateEvaluator - 验证评估器配置
            errors = {};
            warnings = {};

            % 检查必填字段
            if ~isfield(evaluator, 'type') || isempty(evaluator.type)
                errors{end+1} = 'Evaluator type is required';
            end

            % 检查超时时间
            if isfield(evaluator, 'timeout')
                if isnan(evaluator.timeout)
                    errors{end+1} = 'Evaluator timeout is NaN (invalid numeric input)';
                elseif evaluator.timeout <= 0
                    errors{end+1} = sprintf('Evaluator timeout (%.0f) must be positive', evaluator.timeout);
                elseif evaluator.timeout < 30
                    warnings{end+1} = sprintf('Evaluator timeout (%.0f s) may be too short for Aspen simulation', ...
                        evaluator.timeout);
                end
            end

            % 检查经济参数（如果存在）
            if isfield(evaluator, 'economicParameters') && isstruct(evaluator.economicParameters)
                fields = fieldnames(evaluator.economicParameters);
                for i = 1:length(fields)
                    fieldName = fields{i};
                    value = evaluator.economicParameters.(fieldName);
                    if ~isnumeric(value) || isempty(value) || ~isscalar(value)
                        errors{end+1} = sprintf('Economic parameter "%s" must be a numeric scalar', fieldName);
                    elseif isnan(value)
                        errors{end+1} = sprintf('Economic parameter "%s" is NaN (invalid numeric input)', fieldName);
                    end
                end
            end

            valid = isempty(errors);
        end

        function [valid, errors, warnings] = validateSimulator(simulator)
            %% validateSimulator - 验证仿真器配置
            errors = {};
            warnings = {};

            % 检查仿真器类型
            if ~isfield(simulator, 'type') || isempty(simulator.type)
                errors{end+1} = 'Simulator type is required';
            elseif ~ismember(simulator.type, {'Aspen', 'MATLAB', 'Python'})
                warnings{end+1} = sprintf('Unknown simulator type: %s', simulator.type);
            end

            % 检查设置
            if ~isfield(simulator, 'settings')
                errors{end+1} = 'Simulator settings are required';
            else
                [validSet, errSet, warnSet] = ConfigValidator.validateSimulatorSettings(simulator.settings, simulator.type);
                errors = [errors, errSet];
                warnings = [warnings, warnSet];
            end

            % 检查节点映射
            if ~isfield(simulator, 'nodeMapping')
                errors{end+1} = 'Simulator nodeMapping is required';
            else
                [validMap, errMap, warnMap] = ConfigValidator.validateNodeMapping(simulator.nodeMapping);
                errors = [errors, errMap];
                warnings = [warnings, warnMap];
            end

            valid = isempty(errors);
        end

        function [valid, errors, warnings] = validateSimulatorSettings(settings, simType)
            %% validateSimulatorSettings - 验证仿真器设置
            errors = {};
            warnings = {};

            % 检查模型路径（Aspen 必需）
            if strcmpi(simType, 'Aspen')
                if ~isfield(settings, 'modelPath') || isempty(settings.modelPath)
                    errors{end+1} = 'Aspen model path is required';
                elseif ~exist(settings.modelPath, 'file')
                    errors{end+1} = sprintf('Aspen model file not found: %s', settings.modelPath);
                elseif ~endsWith(lower(settings.modelPath), '.bkp')
                    warnings{end+1} = sprintf('Aspen model file should have .bkp extension: %s', settings.modelPath);
                end
            end

            % 检查超时时间
            if isfield(settings, 'timeout')
                if isnan(settings.timeout)
                    errors{end+1} = 'Simulator timeout is NaN (invalid numeric input)';
                elseif settings.timeout <= 0
                    errors{end+1} = sprintf('Simulator timeout (%.0f) must be positive', settings.timeout);
                elseif settings.timeout < 60
                    warnings{end+1} = sprintf('Simulator timeout (%.0f s) may be too short', settings.timeout);
                end
            end

            % 检查重试次数
            if isfield(settings, 'maxRetries')
                if isnan(settings.maxRetries)
                    errors{end+1} = 'maxRetries is NaN (invalid numeric input)';
                elseif settings.maxRetries < 0
                    errors{end+1} = sprintf('maxRetries (%d) cannot be negative', settings.maxRetries);
                end
            end

            % 检查重试延迟
            if isfield(settings, 'retryDelay')
                if isnan(settings.retryDelay)
                    errors{end+1} = 'retryDelay is NaN (invalid numeric input)';
                elseif settings.retryDelay < 0
                    errors{end+1} = sprintf('retryDelay (%.1f) cannot be negative', settings.retryDelay);
                end
            end

            valid = isempty(errors);
        end

        function [valid, errors, warnings] = validateNodeMapping(nodeMapping)
            %% validateNodeMapping - 验证节点映射
            errors = {};
            warnings = {};

            % 检查变量映射
            if ~isfield(nodeMapping, 'variables')
                errors{end+1} = 'Node mapping for variables is required';
            elseif ~isstruct(nodeMapping.variables)
                errors{end+1} = 'Variable node mapping must be a struct';
            elseif isempty(fieldnames(nodeMapping.variables))
                warnings{end+1} = 'Variable node mapping is empty (no variables mapped to simulator)';
            end

            % 检查结果映射
            if ~isfield(nodeMapping, 'results')
                errors{end+1} = 'Node mapping for results is required';
            elseif ~isstruct(nodeMapping.results)
                errors{end+1} = 'Result node mapping must be a struct';
            elseif isempty(fieldnames(nodeMapping.results))
                warnings{end+1} = 'Result node mapping is empty (no results mapped from simulator)';
            end

            % 检查节点路径格式（针对 Aspen）
            if isfield(nodeMapping, 'variables') && isstruct(nodeMapping.variables)
                varNames = fieldnames(nodeMapping.variables);
                for i = 1:length(varNames)
                    path = nodeMapping.variables.(varNames{i});
                    pathForCheck = ConfigValidator.normalizeAspenNodePathForCheck(path);
                    if ~ischar(path) || isempty(path)
                        warnings{end+1} = sprintf('Variable "%s" has empty or invalid node path', varNames{i});
                    elseif ~startsWith(pathForCheck, '\Data\')
                        warnings{end+1} = sprintf('Variable "%s" node path should start with \\Data\\: %s', ...
                            varNames{i}, path);
                    end
                end
            end

            if isfield(nodeMapping, 'results') && isstruct(nodeMapping.results)
                resNames = fieldnames(nodeMapping.results);
                for i = 1:length(resNames)
                    path = nodeMapping.results.(resNames{i});
                    pathForCheck = ConfigValidator.normalizeAspenNodePathForCheck(path);
                    if ~ischar(path) || isempty(path)
                        warnings{end+1} = sprintf('Result "%s" has empty or invalid node path', resNames{i});
                    elseif ~startsWith(pathForCheck, '\Data\')
                        warnings{end+1} = sprintf('Result "%s" node path should start with \\Data\\: %s', ...
                            resNames{i}, path);
                    end
                end
            end

            valid = isempty(errors);
        end

        function path = normalizeAspenNodePathForCheck(path)
            try
                if ischar(path)
                    path = path;
                elseif isstring(path) && isscalar(path)
                    path = char(path);
                else
                    path = char(string(path));
                end
            catch
                path = '';
                return;
            end

            path = strtrim(path);
            if isempty(path)
                return;
            end

            path = strrep(path, '/', '\');
            while contains(path, '\\')
                path = strrep(path, '\\', '\');
            end
            if startsWith(path, 'Data\')
                path = ['\' path];
            end
        end

        function [valid, errors, warnings] = validateAlgorithm(algorithm)
            %% validateAlgorithm - 验证算法配置
            errors = {};
            warnings = {};

            % 检查算法类型
            if ~isfield(algorithm, 'type') || isempty(algorithm.type)
                errors{end+1} = 'Algorithm type is required';
            end

            % 检查参数
            if ~isfield(algorithm, 'parameters')
                errors{end+1} = 'Algorithm parameters are required';
            else
                algType = '';
                if isfield(algorithm, 'type')
                    algType = algorithm.type;
                end
                [validParam, errParam, warnParam] = ConfigValidator.validateAlgorithmParameters(...
                    algorithm.parameters, algType);
                errors = [errors, errParam];
                warnings = [warnings, warnParam];
            end

            valid = isempty(errors);
        end

        function [valid, errors, warnings] = validateAlgorithmParameters(params, algType)
            %% validateAlgorithmParameters - 验证算法参数
            errors = {};
            warnings = {};

            % 检查通用参数
            if ~isfield(params, 'populationSize')
                errors{end+1} = 'populationSize is required';
            elseif isnan(params.populationSize)
                errors{end+1} = 'populationSize is NaN (invalid numeric input)';
            elseif params.populationSize < 2
                errors{end+1} = sprintf('populationSize (%d) must be at least 2', params.populationSize);
            elseif params.populationSize > 1000
                warnings{end+1} = sprintf('populationSize (%d) is very large, may be slow', params.populationSize);
            end

            if ~isfield(params, 'maxGenerations')
                errors{end+1} = 'maxGenerations is required';
            elseif isnan(params.maxGenerations)
                errors{end+1} = 'maxGenerations is NaN (invalid numeric input)';
            elseif params.maxGenerations < 1
                errors{end+1} = sprintf('maxGenerations (%d) must be at least 1', params.maxGenerations);
            end

            % 根据算法类型检查特定参数
            upperAlgType = upper(strrep(algType, '-', ''));
            if contains(upperAlgType, 'NSGA')
                [validNSGA, errNSGA, warnNSGA] = ConfigValidator.validateNSGAIIParameters(params);
                errors = [errors, errNSGA];
                warnings = [warnings, warnNSGA];
            elseif contains(upperAlgType, 'PSO')
                [validPSO, errPSO, warnPSO] = ConfigValidator.validatePSOParameters(params);
                errors = [errors, errPSO];
                warnings = [warnings, warnPSO];
            end

            valid = isempty(errors);
        end

        function [valid, errors, warnings] = validateNSGAIIParameters(params)
            %% validateNSGAIIParameters - 验证 NSGA-II 特定参数
            errors = {};
            warnings = {};

            % 交叉概率
            if isfield(params, 'crossoverRate')
                if isnan(params.crossoverRate)
                    errors{end+1} = 'crossoverRate is NaN (invalid numeric input)';
                elseif params.crossoverRate < 0 || params.crossoverRate > 1
                    errors{end+1} = sprintf('crossoverRate (%.2f) must be in [0, 1]', params.crossoverRate);
                end
            end

            % 变异概率
            if isfield(params, 'mutationRate')
                if isnan(params.mutationRate)
                    errors{end+1} = 'mutationRate is NaN (invalid numeric input)';
                elseif params.mutationRate < 0
                    errors{end+1} = sprintf('mutationRate (%.2f) must be >= 0', params.mutationRate);
                end
            end

            % 分布指数
            if isfield(params, 'crossoverDistIndex')
                if isnan(params.crossoverDistIndex)
                    errors{end+1} = 'crossoverDistIndex is NaN (invalid numeric input)';
                elseif params.crossoverDistIndex < 0
                    errors{end+1} = sprintf('crossoverDistIndex (%.0f) must be >= 0', params.crossoverDistIndex);
                end
            end

            if isfield(params, 'mutationDistIndex')
                if isnan(params.mutationDistIndex)
                    errors{end+1} = 'mutationDistIndex is NaN (invalid numeric input)';
                elseif params.mutationDistIndex < 0
                    errors{end+1} = sprintf('mutationDistIndex (%.0f) must be >= 0', params.mutationDistIndex);
                end
            end

            valid = isempty(errors);
        end

        function [valid, errors, warnings] = validatePSOParameters(params)
            %% validatePSOParameters - 验证 PSO 特定参数
            errors = {};
            warnings = {};

            % 惯性权重
            if isfield(params, 'inertiaWeight')
                if isnan(params.inertiaWeight)
                    errors{end+1} = 'inertiaWeight is NaN (invalid numeric input)';
                elseif params.inertiaWeight < 0 || params.inertiaWeight > 1
                    warnings{end+1} = sprintf('inertiaWeight (%.2f) typically in [0, 1]', params.inertiaWeight);
                end
            end

            % 学习因子
            if isfield(params, 'cognitiveCoeff')
                if isnan(params.cognitiveCoeff)
                    errors{end+1} = 'cognitiveCoeff is NaN (invalid numeric input)';
                elseif params.cognitiveCoeff < 0
                    errors{end+1} = sprintf('cognitiveCoeff (%.2f) must be >= 0', params.cognitiveCoeff);
                end
            end

            if isfield(params, 'socialCoeff')
                if isnan(params.socialCoeff)
                    errors{end+1} = 'socialCoeff is NaN (invalid numeric input)';
                elseif params.socialCoeff < 0
                    errors{end+1} = sprintf('socialCoeff (%.2f) must be >= 0', params.socialCoeff);
                end
            end

            % 最大速度比例
            if isfield(params, 'maxVelocityRatio')
                if isnan(params.maxVelocityRatio)
                    errors{end+1} = 'maxVelocityRatio is NaN (invalid numeric input)';
                elseif params.maxVelocityRatio <= 0 || params.maxVelocityRatio > 1
                    warnings{end+1} = sprintf('maxVelocityRatio (%.2f) typically in (0, 1]', params.maxVelocityRatio);
                end
            end

            valid = isempty(errors);
        end

    end
end
