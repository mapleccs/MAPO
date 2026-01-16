classdef ConfigBuilder
    %% ConfigBuilder - 配置文件构建器
    %
    % 负责 GUI 配置数据与 JSON 配置文件之间的转换。
    % 确保生成的配置与 run_case.m 的格式完全兼容。
    %
    % 关键设计点:
    %   1. 数值类型保持为数值（不转为字符串）
    %   2. 算法类型大小写兼容（NSGA-II / NSGAII）
    %   3. 结构完全匹配现有 case_config.json
    %   4. 节点映射始终为 struct 类型
    %
    % 用法:
    %   % 从 GUI 数据构建配置
    %   config = ConfigBuilder.buildConfig(guiData);
    %
    %   % 保存到文件
    %   ConfigBuilder.toJSON(config, 'my_config.json');
    %
    %   % 从文件加载
    %   config = ConfigBuilder.fromJSON('my_config.json');

    methods (Static)

        function config = buildConfig(guiData)
            %% buildConfig - 从 GUI 数据构建配置结构体
            %
            % 输入:
            %   guiData - GUI 数据结构体，包含 problem, simulator, algorithm 字段
            %
            % 返回:
            %   config - 与 case_config.json 格式兼容的配置结构体

            config = struct();

            %% ==================== problem 部分 ====================
            config.problem = struct();
            config.problem.name = ConfigBuilder.ensureString(...
                ConfigBuilder.getFieldOrDefault(guiData.problem, 'name', 'NewOptimization'));
            config.problem.description = ConfigBuilder.ensureString(...
                ConfigBuilder.getFieldOrDefault(guiData.problem, 'description', ''));

            % 变量数组 - 确保数值类型正确
            if isfield(guiData.problem, 'variables') && ~isempty(guiData.problem.variables)
                vars = guiData.problem.variables;
                numVars = length(vars);
                for i = 1:numVars
                    vars(i).name = ConfigBuilder.ensureString(...
                        ConfigBuilder.getFieldOrDefault(vars(i), 'name', sprintf('VAR%d', i)));
                    vars(i).description = ConfigBuilder.ensureString(...
                        ConfigBuilder.getFieldOrDefault(vars(i), 'description', ''));

                    rawType = ConfigBuilder.ensureString(...
                        ConfigBuilder.getFieldOrDefault(vars(i), 'type', 'continuous'));
                    varType = lower(strtrim(rawType));
                    vars(i).type = varType;

                    vars(i).unit = ConfigBuilder.ensureString(...
                        ConfigBuilder.getFieldOrDefault(vars(i), 'unit', ''));

                    parsedValues = [];
                    if isfield(vars(i), 'values')
                        parsedValues = ConfigBuilder.parseVariableValues(vars(i).values, varType);
                    end

                    if ismember(varType, {'continuous', 'integer'})
                        if isfield(vars(i), 'values')
                            vars(i).values = [];
                        end
                        vars(i).lowerBound = ConfigBuilder.ensureNumericStrict(...
                            ConfigBuilder.getFieldOrDefault(vars(i), 'lowerBound', 0), 'lowerBound');
                        vars(i).upperBound = ConfigBuilder.ensureNumericStrict(...
                            ConfigBuilder.getFieldOrDefault(vars(i), 'upperBound', 100), 'upperBound');

                        if isfield(vars(i), 'initialValue') && ~isempty(vars(i).initialValue)
                            vars(i).initialValue = ConfigBuilder.ensureNumericStrict(...
                                vars(i).initialValue, 'initialValue');
                        else
                            vars(i).initialValue = (vars(i).lowerBound + vars(i).upperBound) / 2;
                        end
                    else
                        if isempty(parsedValues) && strcmp(varType, 'discrete')
                            lbFallback = ConfigBuilder.ensureNumericStrict(...
                                ConfigBuilder.getFieldOrDefault(vars(i), 'lowerBound', 0), 'lowerBound');
                            ubFallback = ConfigBuilder.ensureNumericStrict(...
                                ConfigBuilder.getFieldOrDefault(vars(i), 'upperBound', 100), 'upperBound');
                            if isfinite(lbFallback) && isfinite(ubFallback)
                                parsedValues = [lbFallback, ubFallback];
                            end
                        end

                        vars(i).values = parsedValues;
                        if ~isempty(parsedValues)
                            if isnumeric(parsedValues)
                                vars(i).lowerBound = min(parsedValues);
                                vars(i).upperBound = max(parsedValues);
                            else
                                vars(i).lowerBound = [];
                                vars(i).upperBound = [];
                            end

                            if ~isfield(vars(i), 'initialValue') || isempty(vars(i).initialValue)
                                if isnumeric(parsedValues)
                                    vars(i).initialValue = parsedValues(1);
                                elseif iscell(parsedValues) && ~isempty(parsedValues)
                                    vars(i).initialValue = parsedValues{1};
                                else
                                    vars(i).initialValue = parsedValues;
                                end
                            end
                        else
                            vars(i).lowerBound = ConfigBuilder.ensureNumericStrict(...
                                ConfigBuilder.getFieldOrDefault(vars(i), 'lowerBound', 0), 'lowerBound');
                            vars(i).upperBound = ConfigBuilder.ensureNumericStrict(...
                                ConfigBuilder.getFieldOrDefault(vars(i), 'upperBound', 100), 'upperBound');

                            if isfield(vars(i), 'initialValue') && ~isempty(vars(i).initialValue)
                                vars(i).initialValue = ConfigBuilder.ensureNumericStrict(...
                                    vars(i).initialValue, 'initialValue');
                            else
                                vars(i).initialValue = (vars(i).lowerBound + vars(i).upperBound) / 2;
                            end
                        end
                    end
                end
                config.problem.variables = vars;
            else
                config.problem.variables = [];
            end

            % 目标数组 - 确保数值类型正确
            if isfield(guiData.problem, 'objectives') && ~isempty(guiData.problem.objectives)
                objs = guiData.problem.objectives;
                numObjs = length(objs);
                for i = 1:numObjs
                    objs(i).name = ConfigBuilder.ensureString(...
                        ConfigBuilder.getFieldOrDefault(objs(i), 'name', sprintf('OBJ%d', i)));
                    objs(i).description = ConfigBuilder.ensureString(...
                        ConfigBuilder.getFieldOrDefault(objs(i), 'description', ''));
                    objs(i).type = ConfigBuilder.ensureString(...
                        ConfigBuilder.getFieldOrDefault(objs(i), 'type', 'minimize'));
                    objs(i).unit = ConfigBuilder.ensureString(...
                        ConfigBuilder.getFieldOrDefault(objs(i), 'unit', ''));
                    objs(i).expression = ConfigBuilder.ensureString(...
                        ConfigBuilder.getFieldOrDefault(objs(i), 'expression', ''));
                    objs(i).weight = ConfigBuilder.ensureNumericStrict(...
                        ConfigBuilder.getFieldOrDefault(objs(i), 'weight', 1.0), 'weight');
                end
                config.problem.objectives = objs;
            else
                config.problem.objectives = [];
            end

            % 约束数组
            if isfield(guiData.problem, 'constraints') && ~isempty(guiData.problem.constraints)
                cons = guiData.problem.constraints;
                numCons = length(cons);
                for i = 1:numCons
                    cons(i).name = ConfigBuilder.ensureString(...
                        ConfigBuilder.getFieldOrDefault(cons(i), 'name', sprintf('CON%d', i)));
                    cons(i).description = ConfigBuilder.ensureString(...
                        ConfigBuilder.getFieldOrDefault(cons(i), 'description', ''));
                    cons(i).type = ConfigBuilder.ensureString(...
                        ConfigBuilder.getFieldOrDefault(cons(i), 'type', 'inequality'));
                    cons(i).expression = ConfigBuilder.ensureString(...
                        ConfigBuilder.getFieldOrDefault(cons(i), 'expression', ''));
                    cons(i).unit = ConfigBuilder.ensureString(...
                        ConfigBuilder.getFieldOrDefault(cons(i), 'unit', ''));
                end
                config.problem.constraints = cons;
            else
                config.problem.constraints = [];
            end

            % 派生表达式
            if isfield(guiData.problem, 'derived') && ~isempty(guiData.problem.derived)
                derived = guiData.problem.derived;
                numDerived = length(derived);
                for i = 1:numDerived
                    derived(i).name = ConfigBuilder.ensureString(...
                        ConfigBuilder.getFieldOrDefault(derived(i), 'name', sprintf('D%d', i)));
                    derived(i).expression = ConfigBuilder.ensureString(...
                        ConfigBuilder.getFieldOrDefault(derived(i), 'expression', ''));
                    derived(i).unit = ConfigBuilder.ensureString(...
                        ConfigBuilder.getFieldOrDefault(derived(i), 'unit', ''));
                    derived(i).description = ConfigBuilder.ensureString(...
                        ConfigBuilder.getFieldOrDefault(derived(i), 'description', ''));
                end
                config.problem.derived = derived;
            else
                config.problem.derived = [];
            end

            % 评估器配置
            config.problem.evaluator = struct();
            if isfield(guiData.problem, 'evaluator')
                config.problem.evaluator.type = ConfigBuilder.ensureString(...
                    ConfigBuilder.getFieldOrDefault(guiData.problem.evaluator, 'type', 'MyCaseEvaluator'));
                config.problem.evaluator.timeout = ConfigBuilder.ensureNumericStrict(...
                    ConfigBuilder.getFieldOrDefault(guiData.problem.evaluator, 'timeout', 300), 'timeout');

                if isfield(guiData.problem.evaluator, 'economicParameters') && ...
                   isstruct(guiData.problem.evaluator.economicParameters) && ...
                   ~isempty(fieldnames(guiData.problem.evaluator.economicParameters))
                    % 确保所有经济参数为数值
                    ecoParams = guiData.problem.evaluator.economicParameters;
                    fields = fieldnames(ecoParams);
                    for i = 1:length(fields)
                        ecoParams.(fields{i}) = ConfigBuilder.ensureNumericStrict(...
                            ecoParams.(fields{i}), fields{i});
                    end
                    config.problem.evaluator.economicParameters = ecoParams;
                end

                if isfield(guiData.problem.evaluator, 'parameterUnits') && ...
                   isstruct(guiData.problem.evaluator.parameterUnits) && ...
                   ~isempty(fieldnames(guiData.problem.evaluator.parameterUnits))
                    unitParams = guiData.problem.evaluator.parameterUnits;
                    fields = fieldnames(unitParams);
                    for i = 1:length(fields)
                        unitParams.(fields{i}) = ConfigBuilder.ensureString(unitParams.(fields{i}));
                    end
                    config.problem.evaluator.parameterUnits = unitParams;
                end
            else
                config.problem.evaluator.type = 'MyCaseEvaluator';
                config.problem.evaluator.timeout = 300;
            end

            %% ==================== simulator 部分 ====================
            config.simulator = struct();
            config.simulator.type = ConfigBuilder.ensureString(...
                ConfigBuilder.getFieldOrDefault(guiData.simulator, 'type', 'Aspen'));

            % settings - 确保数值和布尔类型正确
            config.simulator.settings = struct();
            if isfield(guiData.simulator, 'settings')
                settings = guiData.simulator.settings;
                config.simulator.settings.modelPath = ConfigBuilder.ensureString(...
                    ConfigBuilder.getFieldOrDefault(settings, 'modelPath', ''));
                config.simulator.settings.timeout = ConfigBuilder.ensureNumericStrict(...
                    ConfigBuilder.getFieldOrDefault(settings, 'timeout', 300), 'simulator.timeout');
                config.simulator.settings.visible = ConfigBuilder.ensureLogical(...
                    ConfigBuilder.getFieldOrDefault(settings, 'visible', false));
                config.simulator.settings.autoSave = ConfigBuilder.ensureLogical(...
                    ConfigBuilder.getFieldOrDefault(settings, 'autoSave', false));
                config.simulator.settings.suppressWarnings = ConfigBuilder.ensureLogical(...
                    ConfigBuilder.getFieldOrDefault(settings, 'suppressWarnings', true));
                config.simulator.settings.maxRetries = ConfigBuilder.ensureNumericStrict(...
                    ConfigBuilder.getFieldOrDefault(settings, 'maxRetries', 3), 'maxRetries');
                config.simulator.settings.retryDelay = ConfigBuilder.ensureNumericStrict(...
                    ConfigBuilder.getFieldOrDefault(settings, 'retryDelay', 2), 'retryDelay');
            else
                config.simulator.settings.modelPath = '';
                config.simulator.settings.timeout = 300;
                config.simulator.settings.visible = false;
                config.simulator.settings.autoSave = false;
                config.simulator.settings.suppressWarnings = true;
                config.simulator.settings.maxRetries = 3;
                config.simulator.settings.retryDelay = 2;
            end

            % 节点映射 - 确保始终为 struct，值为 char 字符串
            config.simulator.nodeMapping = struct();
            config.simulator.nodeMapping.variables = ConfigBuilder.ensureNodeMappingStruct(...
                ConfigBuilder.getFieldOrDefault(...
                    ConfigBuilder.getFieldOrDefault(guiData.simulator, 'nodeMapping', struct()), ...
                    'variables', struct()));
            config.simulator.nodeMapping.results = ConfigBuilder.ensureNodeMappingStruct(...
                ConfigBuilder.getFieldOrDefault(...
                    ConfigBuilder.getFieldOrDefault(guiData.simulator, 'nodeMapping', struct()), ...
                    'results', struct()));
            config.simulator.nodeMapping.resultUnits = ConfigBuilder.ensureNodeMappingStruct(...
                ConfigBuilder.getFieldOrDefault(...
                    ConfigBuilder.getFieldOrDefault(guiData.simulator, 'nodeMapping', struct()), ...
                    'resultUnits', struct()));

            %% ==================== algorithm 部分 ====================
            config.algorithm = struct();
            % 算法类型 - 规范化
            algType = ConfigBuilder.normalizeAlgorithmType(...
                ConfigBuilder.getFieldOrDefault(guiData.algorithm, 'type', 'NSGA-II'));
            config.algorithm.type = algType;

            % 参数 - 根据算法类型分支填充
            config.algorithm.parameters = ConfigBuilder.buildAlgorithmParameters(...
                algType, ...
                ConfigBuilder.getFieldOrDefault(guiData.algorithm, 'parameters', struct()));

            % 统一规范化（兼容 fromJSON 的行为）
            config = ConfigBuilder.normalizeConfig(config);
        end

        function params = buildAlgorithmParameters(algType, inputParams)
            %% buildAlgorithmParameters - 根据算法类型构建参数
            %
            % 输入:
            %   algType     - 算法类型 ('NSGA-II', 'PSO', etc.)
            %   inputParams - 用户输入的参数结构体
            %
            % 返回:
            %   params - 完整的参数结构体

            params = struct();

            switch upper(strrep(algType, '-', ''))
                case 'NSGAII'
                    % NSGA-II 参数
                    params.populationSize = ConfigBuilder.ensureNumericStrict(...
                        ConfigBuilder.getFieldOrDefault(inputParams, 'populationSize', 50), 'populationSize');
                    params.maxGenerations = ConfigBuilder.ensureNumericStrict(...
                        ConfigBuilder.getFieldOrDefault(inputParams, 'maxGenerations', 30), 'maxGenerations');
                    params.crossoverRate = ConfigBuilder.ensureNumericStrict(...
                        ConfigBuilder.getFieldOrDefault(inputParams, 'crossoverRate', 0.9), 'crossoverRate');
                    params.mutationRate = ConfigBuilder.ensureNumericStrict(...
                        ConfigBuilder.getFieldOrDefault(inputParams, 'mutationRate', 1.0), 'mutationRate');
                    params.crossoverDistIndex = ConfigBuilder.ensureNumericStrict(...
                        ConfigBuilder.getFieldOrDefault(inputParams, 'crossoverDistIndex', 20), 'crossoverDistIndex');
                    params.mutationDistIndex = ConfigBuilder.ensureNumericStrict(...
                        ConfigBuilder.getFieldOrDefault(inputParams, 'mutationDistIndex', 20), 'mutationDistIndex');
                    % 可选参数
                    if isfield(inputParams, 'tournamentSize')
                        params.tournamentSize = ConfigBuilder.ensureNumericStrict(...
                            inputParams.tournamentSize, 'tournamentSize');
                    end

                case 'PSO'
                    % PSO 参数
                    % 优先使用 swarmSize，回退到 populationSize
                    swarmSize = ConfigBuilder.ensureNumericStrict(...
                        ConfigBuilder.getFieldOrDefault(inputParams, 'swarmSize', ...
                            ConfigBuilder.getFieldOrDefault(inputParams, 'populationSize', 30)), 'swarmSize');
                    params.swarmSize = swarmSize;
                    % 同时填充 populationSize 以兼容 run_case.m
                    params.populationSize = swarmSize;

                    % 优先使用 maxIterations，回退到 maxGenerations
                    maxIter = ConfigBuilder.ensureNumericStrict(...
                        ConfigBuilder.getFieldOrDefault(inputParams, 'maxIterations', ...
                            ConfigBuilder.getFieldOrDefault(inputParams, 'maxGenerations', 100)), 'maxIterations');
                    params.maxIterations = maxIter;
                    % 同时填充 maxGenerations 以兼容 run_case.m
                    params.maxGenerations = maxIter;

                    params.inertiaWeight = ConfigBuilder.ensureNumericStrict(...
                        ConfigBuilder.getFieldOrDefault(inputParams, 'inertiaWeight', 0.73), 'inertiaWeight');
                    params.cognitiveCoeff = ConfigBuilder.ensureNumericStrict(...
                        ConfigBuilder.getFieldOrDefault(inputParams, 'cognitiveCoeff', 1.5), 'cognitiveCoeff');
                    params.socialCoeff = ConfigBuilder.ensureNumericStrict(...
                        ConfigBuilder.getFieldOrDefault(inputParams, 'socialCoeff', 1.5), 'socialCoeff');
                    params.maxVelocityRatio = ConfigBuilder.ensureNumericStrict(...
                        ConfigBuilder.getFieldOrDefault(inputParams, 'maxVelocityRatio', 0.2), 'maxVelocityRatio');

                otherwise
                    % 未知算法 - 直接复制所有参数（支持嵌套 struct/char/logical/数组）
                    if isstruct(inputParams)
                        params = inputParams;
                    end

                    % 兼容：如果后续流程依赖通用字段，则补齐默认值
                    if ~isfield(params, 'populationSize')
                        params.populationSize = 50;
                    end
                    if ~isfield(params, 'maxGenerations')
                        params.maxGenerations = 30;
                    end
            end
        end

        function mapping = ensureNodeMappingStruct(input)
            %% ensureNodeMappingStruct - 确保节点映射为 struct，值为 char
            %
            % 输入:
            %   input - 输入数据（可能是 struct, [], cell 等）
            %
            % 返回:
            %   mapping - 规范化的 struct（空时返回空 struct）
            %
            % 注意:
            %   - 字段名必须是有效的 MATLAB 标识符（变量名）
            %   - 含空格/特殊字符的字段名会被跳过并发出警告
            %   - 建议在 GUI 中使用合法的变量名作为节点映射的 key

            % 处理空值或非 struct
            if isempty(input) || ~isstruct(input)
                mapping = struct();
                return;
            end

            % 转换所有值为 char 字符串
            mapping = struct();
            fields = fieldnames(input);
            skippedFields = {};

            for i = 1:length(fields)
                fieldName = fields{i};
                fieldValue = input.(fieldName);

                % 检查字段名是否为有效的 MATLAB 标识符
                % MATLAB struct 的字段名必须是合法标识符
                if ~isvarname(fieldName)
                    skippedFields{end+1} = fieldName; %#ok<AGROW>
                    continue;
                end

                % 确保值为 char 字符串
                if isstring(fieldValue)
                    mapping.(fieldName) = char(fieldValue);
                elseif ischar(fieldValue)
                    mapping.(fieldName) = fieldValue;
                elseif iscell(fieldValue) && ~isempty(fieldValue)
                    % 如果是 cell，取第一个元素
                    mapping.(fieldName) = char(fieldValue{1});
                else
                    skippedFields{end+1} = fieldName; %#ok<AGROW>
                end
            end

            % 如果有被跳过的字段，发出警告
            if ~isempty(skippedFields)
                warning('ConfigBuilder:InvalidNodeMapping', ...
                    'Skipped invalid node mapping fields (must be valid MATLAB identifiers): %s', ...
                    strjoin(skippedFields, ', '));
            end
        end

        function toJSON(config, filePath)
            %% toJSON - 将配置保存为 JSON 文件
            %
            % 输入:
            %   config   - 配置结构体
            %   filePath - 输出文件路径（建议使用绝对路径）

            % 转换为 JSON 字符串（使用 jsonencode 的 PrettyPrint 选项）
            try
                % MATLAB R2021a+ 支持 PrettyPrint
                jsonStr = jsonencode(config, 'PrettyPrint', true);
            catch
                % 旧版本 MATLAB 回退方案
                jsonStr = jsonencode(config);
                jsonStr = ConfigBuilder.formatJSON(jsonStr);
            end

            % 确保目录存在
            [parentDir, ~, ~] = fileparts(filePath);
            if ~isempty(parentDir) && ~exist(parentDir, 'dir')
                mkdir(parentDir);
            end

            % 写入文件（UTF-8 编码）
            fid = fopen(filePath, 'w', 'n', 'UTF-8');
            if fid == -1
                error('ConfigBuilder:FileError', '无法创建文件: %s', filePath);
            end

            try
                fprintf(fid, '%s', jsonStr);
                fclose(fid);
            catch ME
                fclose(fid);
                rethrow(ME);
            end
        end

        function config = fromJSON(filePath)
            %% fromJSON - 从 JSON 文件加载配置
            %
            % 输入:
            %   filePath - JSON 配置文件路径
            %
            % 返回:
            %   config - 配置结构体（已规范化）

            if ~exist(filePath, 'file')
                error('ConfigBuilder:FileNotFound', '配置文件不存在: %s', filePath);
            end

            % 读取文件内容
            jsonStr = fileread(filePath);

            % 解析 JSON
            try
                config = jsondecode(jsonStr);
            catch ME
                error('ConfigBuilder:ParseError', 'JSON 解析失败: %s\n%s', filePath, ME.message);
            end

            % 规范化配置结构
            config = ConfigBuilder.normalizeConfig(config);
        end

        function guiData = toGUIData(config)
            %% toGUIData - 将配置转换为 GUI 数据格式
            %
            % 输入:
            %   config - 从 JSON 加载的配置结构体
            %
            % 返回:
            %   guiData - GUI 使用的数据结构体

            guiData = struct();

            %% 问题部分
            guiData.problem = struct();
            guiData.problem.name = ConfigBuilder.getFieldOrDefault(config.problem, 'name', 'NewOptimization');
            guiData.problem.description = ConfigBuilder.getFieldOrDefault(config.problem, 'description', '');

            % 变量 - 确保是结构体数组
            if isfield(config.problem, 'variables') && ~isempty(config.problem.variables)
                guiData.problem.variables = ConfigBuilder.ensureStructArray(config.problem.variables);
            else
                guiData.problem.variables = struct([]);
            end

            % 目标
            if isfield(config.problem, 'objectives') && ~isempty(config.problem.objectives)
                guiData.problem.objectives = ConfigBuilder.ensureStructArray(config.problem.objectives);
            else
                guiData.problem.objectives = struct([]);
            end

            % 约束
            if isfield(config.problem, 'constraints') && ~isempty(config.problem.constraints)
                guiData.problem.constraints = ConfigBuilder.ensureStructArray(config.problem.constraints);
            else
                guiData.problem.constraints = struct([]);
            end

            % 派生表达式
            if isfield(config.problem, 'derived') && ~isempty(config.problem.derived)
                guiData.problem.derived = ConfigBuilder.ensureStructArray(config.problem.derived);
            else
                guiData.problem.derived = struct([]);
            end

            % 评估器
            guiData.problem.evaluator = struct();
            if isfield(config.problem, 'evaluator')
                guiData.problem.evaluator.type = ConfigBuilder.getFieldOrDefault(...
                    config.problem.evaluator, 'type', 'MyCaseEvaluator');
                guiData.problem.evaluator.timeout = ConfigBuilder.getFieldOrDefault(...
                    config.problem.evaluator, 'timeout', 300);

                if isfield(config.problem.evaluator, 'economicParameters')
                    guiData.problem.evaluator.economicParameters = config.problem.evaluator.economicParameters;
                else
                    guiData.problem.evaluator.economicParameters = struct();
                end
                if isfield(config.problem.evaluator, 'parameterUnits')
                    guiData.problem.evaluator.parameterUnits = config.problem.evaluator.parameterUnits;
                else
                    guiData.problem.evaluator.parameterUnits = struct();
                end
            else
                guiData.problem.evaluator.type = 'MyCaseEvaluator';
                guiData.problem.evaluator.timeout = 300;
                guiData.problem.evaluator.economicParameters = struct();
                guiData.problem.evaluator.parameterUnits = struct();
            end

            %% 仿真器部分
            guiData.simulator = struct();
            guiData.simulator.type = ConfigBuilder.getFieldOrDefault(config.simulator, 'type', 'Aspen');

            % settings
            guiData.simulator.settings = struct();
            if isfield(config.simulator, 'settings')
                s = config.simulator.settings;
                guiData.simulator.settings.modelPath = ConfigBuilder.getFieldOrDefault(s, 'modelPath', '');
                guiData.simulator.settings.timeout = ConfigBuilder.getFieldOrDefault(s, 'timeout', 300);
                guiData.simulator.settings.visible = ConfigBuilder.getFieldOrDefault(s, 'visible', false);
                guiData.simulator.settings.autoSave = ConfigBuilder.getFieldOrDefault(s, 'autoSave', false);
                guiData.simulator.settings.suppressWarnings = ConfigBuilder.getFieldOrDefault(s, 'suppressWarnings', true);
                guiData.simulator.settings.maxRetries = ConfigBuilder.getFieldOrDefault(s, 'maxRetries', 3);
                guiData.simulator.settings.retryDelay = ConfigBuilder.getFieldOrDefault(s, 'retryDelay', 2);
            else
                guiData.simulator.settings = ConfigBuilder.getDefaultConfig().simulator.settings;
            end

            % 节点映射 - 确保为 struct
            guiData.simulator.nodeMapping = struct();
            if isfield(config.simulator, 'nodeMapping')
                guiData.simulator.nodeMapping.variables = ConfigBuilder.ensureNodeMappingStruct(...
                    ConfigBuilder.getFieldOrDefault(config.simulator.nodeMapping, 'variables', struct()));
                guiData.simulator.nodeMapping.results = ConfigBuilder.ensureNodeMappingStruct(...
                    ConfigBuilder.getFieldOrDefault(config.simulator.nodeMapping, 'results', struct()));
                guiData.simulator.nodeMapping.resultUnits = ConfigBuilder.ensureNodeMappingStruct(...
                    ConfigBuilder.getFieldOrDefault(config.simulator.nodeMapping, 'resultUnits', struct()));
            else
                guiData.simulator.nodeMapping.variables = struct();
                guiData.simulator.nodeMapping.results = struct();
                guiData.simulator.nodeMapping.resultUnits = struct();
            end

            %% 算法部分
            guiData.algorithm = struct();
            algType = ConfigBuilder.normalizeAlgorithmType(...
                ConfigBuilder.getFieldOrDefault(config.algorithm, 'type', 'NSGA-II'));
            guiData.algorithm.type = algType;

            % 参数 - 根据算法类型补齐默认字段
            if isfield(config.algorithm, 'parameters')
                inputParams = config.algorithm.parameters;
            else
                inputParams = struct();
            end

            % 确保 GUI 所需的通用字段存在（populationSize, maxGenerations）
            guiData.algorithm.parameters = struct();

            % 根据算法类型处理参数
            switch upper(strrep(algType, '-', ''))
                case 'NSGAII'
                    guiData.algorithm.parameters.populationSize = ...
                        ConfigBuilder.getFieldOrDefault(inputParams, 'populationSize', 50);
                    guiData.algorithm.parameters.maxGenerations = ...
                        ConfigBuilder.getFieldOrDefault(inputParams, 'maxGenerations', 30);
                    guiData.algorithm.parameters.crossoverRate = ...
                        ConfigBuilder.getFieldOrDefault(inputParams, 'crossoverRate', 0.9);
                    guiData.algorithm.parameters.mutationRate = ...
                        ConfigBuilder.getFieldOrDefault(inputParams, 'mutationRate', 1.0);
                    guiData.algorithm.parameters.crossoverDistIndex = ...
                        ConfigBuilder.getFieldOrDefault(inputParams, 'crossoverDistIndex', 20);
                    guiData.algorithm.parameters.mutationDistIndex = ...
                        ConfigBuilder.getFieldOrDefault(inputParams, 'mutationDistIndex', 20);
                    guiData.algorithm.parameters.tournamentSize = ...
                        ConfigBuilder.getFieldOrDefault(inputParams, 'tournamentSize', 2);

                case 'PSO'
                    % PSO 参数，同时保持通用字段
                    swarmSize = ConfigBuilder.getFieldOrDefault(inputParams, 'swarmSize', ...
                        ConfigBuilder.getFieldOrDefault(inputParams, 'populationSize', 30));
                    maxIter = ConfigBuilder.getFieldOrDefault(inputParams, 'maxIterations', ...
                        ConfigBuilder.getFieldOrDefault(inputParams, 'maxGenerations', 100));

                    guiData.algorithm.parameters.swarmSize = swarmSize;
                    guiData.algorithm.parameters.maxIterations = maxIter;
                    % 通用字段（兼容 run_case.m）
                    guiData.algorithm.parameters.populationSize = swarmSize;
                    guiData.algorithm.parameters.maxGenerations = maxIter;

                    guiData.algorithm.parameters.inertiaWeight = ...
                        ConfigBuilder.getFieldOrDefault(inputParams, 'inertiaWeight', 0.73);
                    guiData.algorithm.parameters.cognitiveCoeff = ...
                        ConfigBuilder.getFieldOrDefault(inputParams, 'cognitiveCoeff', 1.5);
                    guiData.algorithm.parameters.socialCoeff = ...
                        ConfigBuilder.getFieldOrDefault(inputParams, 'socialCoeff', 1.5);
                    guiData.algorithm.parameters.maxVelocityRatio = ...
                        ConfigBuilder.getFieldOrDefault(inputParams, 'maxVelocityRatio', 0.2);

                otherwise
                    % 未知算法 - 复制所有参数并确保通用字段
                    if isstruct(inputParams)
                        guiData.algorithm.parameters = inputParams;
                    end
                    if ~isfield(guiData.algorithm.parameters, 'populationSize')
                        guiData.algorithm.parameters.populationSize = 50;
                    end
                    if ~isfield(guiData.algorithm.parameters, 'maxGenerations')
                        guiData.algorithm.parameters.maxGenerations = 30;
                    end
            end
        end

        function defaultConfig = getDefaultConfig()
            %% getDefaultConfig - 获取默认配置
            %
            % 返回:
            %   defaultConfig - 默认的 GUI 数据结构

            defaultConfig = struct();

            %% 问题配置
            defaultConfig.problem = struct();
            defaultConfig.problem.name = 'NewOptimization';
            defaultConfig.problem.description = '';
            defaultConfig.problem.variables = struct([]);
            defaultConfig.problem.objectives = struct([]);
            defaultConfig.problem.constraints = struct([]);
            defaultConfig.problem.derived = struct([]);

            % 默认评估器
            defaultConfig.problem.evaluator = struct();
            defaultConfig.problem.evaluator.type = 'MyCaseEvaluator';
            defaultConfig.problem.evaluator.timeout = 300;
            defaultConfig.problem.evaluator.economicParameters = struct();
            defaultConfig.problem.evaluator.parameterUnits = struct();

            %% 仿真器配置
            defaultConfig.simulator = struct();
            defaultConfig.simulator.type = 'Aspen';
            defaultConfig.simulator.settings = struct();
            defaultConfig.simulator.settings.modelPath = '';
            defaultConfig.simulator.settings.timeout = 300;
            defaultConfig.simulator.settings.visible = false;
            defaultConfig.simulator.settings.autoSave = false;
            defaultConfig.simulator.settings.suppressWarnings = true;
            defaultConfig.simulator.settings.maxRetries = 3;
            defaultConfig.simulator.settings.retryDelay = 2;

            defaultConfig.simulator.nodeMapping = struct();
            defaultConfig.simulator.nodeMapping.variables = struct();
            defaultConfig.simulator.nodeMapping.results = struct();
            defaultConfig.simulator.nodeMapping.resultUnits = struct();

            %% 算法配置
            defaultConfig.algorithm = struct();
            defaultConfig.algorithm.type = 'NSGA-II';
            defaultConfig.algorithm.parameters = struct();
            defaultConfig.algorithm.parameters.populationSize = 50;
            defaultConfig.algorithm.parameters.maxGenerations = 30;
            defaultConfig.algorithm.parameters.crossoverRate = 0.9;
            defaultConfig.algorithm.parameters.mutationRate = 1.0;
            defaultConfig.algorithm.parameters.crossoverDistIndex = 20;
            defaultConfig.algorithm.parameters.mutationDistIndex = 20;
            defaultConfig.algorithm.parameters.tournamentSize = 2;
        end

        function newVar = createVariable(name, type, lb, ub, unit, desc)
            %% createVariable - 创建变量结构
            if nargin < 5, unit = ''; end
            if nargin < 6, desc = ''; end

            newVar = struct();
            newVar.name = name;
            newVar.type = type;
            newVar.lowerBound = lb;
            newVar.upperBound = ub;
            newVar.unit = unit;
            newVar.description = desc;
            newVar.initialValue = (lb + ub) / 2;
        end

        function newObj = createObjective(name, type, unit, desc, weight, expression)
            %% createObjective - 创建目标结构
            if nargin < 3, unit = ''; end
            if nargin < 4, desc = ''; end
            if nargin < 5, weight = 1.0; end
            if nargin < 6, expression = ''; end

            newObj = struct();
            newObj.name = name;
            newObj.type = type;
            newObj.unit = unit;
            newObj.expression = expression;
            newObj.description = desc;
            newObj.weight = weight;
        end

        function newCon = createConstraint(name, type, expression, unit, desc)
            %% createConstraint - 创建约束结构
            if nargin < 4, unit = ''; end
            if nargin < 5, desc = ''; end

            newCon = struct();
            newCon.name = name;
            newCon.type = type;
            newCon.expression = expression;
            newCon.unit = unit;
            newCon.description = desc;
        end

        function algType = normalizeAlgorithmType(algType)
            %% normalizeAlgorithmType - 规范化算法类型名称
            if isempty(algType)
                algType = 'NSGA-II';
                return;
            end

            upperType = upper(regexprep(char(algType), '[-_\\s]', ''));

            if (contains(upperType, 'ANN') || contains(upperType, 'SURROGATE')) && contains(upperType, 'NSGA')
                algType = 'ANN-NSGA-II';
            elseif contains(upperType, 'NSGA')
                algType = 'NSGA-II';
            elseif contains(upperType, 'PSO')
                algType = 'PSO';
            else
                algType = char(algType);
            end
        end

    end

    methods (Static, Access = private)

        function values = parseVariableValues(rawValues, varType)
            values = [];

            if nargin < 2
                varType = '';
            end

            if isempty(rawValues)
                return;
            end

            if isstring(rawValues)
                if isscalar(rawValues)
                    rawValues = char(rawValues);
                else
                    rawValues = cellstr(rawValues);
                end
            end

            if ischar(rawValues)
                text = strtrim(rawValues);
                if isempty(text)
                    return;
                end

                if (startsWith(text, '[') && endsWith(text, ']')) || ...
                   (startsWith(text, '{') && endsWith(text, '}'))
                    text = strtrim(text(2:end-1));
                end

                tokens = regexp(text, '[^,;\s]+', 'match');
                if isempty(tokens)
                    return;
                end

                if ~strcmpi(varType, 'categorical')
                    nums = str2double(tokens);
                    if all(isfinite(nums))
                        values = nums;
                        return;
                    end
                end

                values = tokens;
            elseif isnumeric(rawValues)
                values = rawValues;
            elseif iscell(rawValues)
                flat = rawValues(:)';
                if all(cellfun(@(x) isnumeric(x) && isscalar(x) && isfinite(x), flat))
                    values = cellfun(@(x) double(x), flat);
                else
                    cleaned = cell(size(flat));
                    for i = 1:numel(flat)
                        v = flat{i};
                        if isstring(v)
                            v = char(v);
                        elseif isnumeric(v)
                            v = num2str(v);
                        elseif ~ischar(v)
                            v = '';
                        end
                        cleaned{i} = v;
                    end
                    cleaned = cleaned(~cellfun(@isempty, cleaned));
                    values = cleaned;
                end
            end

            if strcmpi(varType, 'categorical')
                if isnumeric(values)
                    values = arrayfun(@(x) num2str(x), values(:)', 'UniformOutput', false);
                elseif ischar(values)
                    values = {values};
                elseif iscell(values)
                    values = cellfun(@(x) char(string(x)), values, 'UniformOutput', false);
                end
            end
        end

        function val = ensureNumericStrict(val, fieldName)
            %% ensureNumericStrict - 确保值为数值类型（严格模式）
            %
            % 如果无法转换，保留 NaN 让上层验证器处理
            % 并发出警告

            if nargin < 2
                fieldName = 'unknown';
            end

            if isnumeric(val)
                return;
            end

            if ischar(val) || isstring(val)
                converted = str2double(val);
                if isnan(converted)
                    warning('ConfigBuilder:InvalidNumeric', ...
                        'Field "%s" value "%s" cannot be converted to numeric, keeping NaN', ...
                        fieldName, char(val));
                end
                val = converted;
            else
                warning('ConfigBuilder:InvalidType', ...
                    'Field "%s" has invalid type, expected numeric', fieldName);
                val = NaN;
            end
        end

        function val = ensureString(val)
            %% ensureString - 确保值为字符串类型 (char)
            if isnumeric(val)
                val = num2str(val);
            elseif isstring(val)
                val = char(val);
            elseif iscell(val) && ~isempty(val)
                val = char(val{1});
            elseif isempty(val)
                val = '';
            elseif ~ischar(val)
                val = '';
            end
        end

        function val = ensureLogical(val)
            %% ensureLogical - 确保值为逻辑类型
            if islogical(val)
                return;
            elseif ischar(val) || isstring(val)
                val = strcmpi(val, 'true') || strcmpi(val, '1') || strcmpi(val, 'yes');
            elseif isnumeric(val)
                val = logical(val);
            else
                val = false;
            end
        end

        function arr = ensureStructArray(data)
            %% ensureStructArray - 确保数据为结构体数组
            if isempty(data)
                arr = struct([]);
            elseif isstruct(data)
                arr = data;
            else
                arr = struct([]);
            end
        end

        function val = getFieldOrDefault(s, field, default)
            %% getFieldOrDefault - 获取字段值或返回默认值
            if ~isstruct(s)
                val = default;
            elseif isfield(s, field) && ~isempty(s.(field))
                val = s.(field);
            else
                val = default;
            end
        end

        function config = normalizeConfig(config)
            %% normalizeConfig - 规范化配置结构
            if ~isfield(config, 'problem')
                config.problem = struct();
            end
            if ~isfield(config, 'simulator')
                config.simulator = struct();
            end
            if ~isfield(config, 'algorithm')
                config.algorithm = struct();
            end

            % Simulator type
            if ~isfield(config.simulator, 'type') || isempty(config.simulator.type)
                config.simulator.type = 'Aspen';
            end

            % Normalize Aspen node mapping paths (e.g. pasted from JSON: \\Data\\...)
            try
                simType = char(string(config.simulator.type));
            catch
                simType = '';
            end

            if strcmpi(simType, 'Aspen') && isfield(config.simulator, 'nodeMapping') && isstruct(config.simulator.nodeMapping)
                if isfield(config.simulator.nodeMapping, 'variables') && isstruct(config.simulator.nodeMapping.variables)
                    config.simulator.nodeMapping.variables = ConfigBuilder.normalizeAspenNodeMappingStruct(...
                        config.simulator.nodeMapping.variables);
                end
                if isfield(config.simulator.nodeMapping, 'results') && isstruct(config.simulator.nodeMapping.results)
                    config.simulator.nodeMapping.results = ConfigBuilder.normalizeAspenNodeMappingStruct(...
                        config.simulator.nodeMapping.results);
                end
            end

            if isfield(config.algorithm, 'type')
                config.algorithm.type = ConfigBuilder.normalizeAlgorithmType(config.algorithm.type);
            end
        end

        function mapping = normalizeAspenNodeMappingStruct(mapping)
            if isempty(mapping) || ~isstruct(mapping)
                mapping = struct();
                return;
            end

            fields = fieldnames(mapping);
            for i = 1:length(fields)
                name = fields{i};
                try
                    mapping.(name) = ConfigBuilder.normalizeAspenNodePath(mapping.(name));
                catch
                end
            end
        end

        function nodePath = normalizeAspenNodePath(nodePath)
            nodePath = ConfigBuilder.ensureString(nodePath);
            nodePath = strtrim(nodePath);
            if isempty(nodePath)
                return;
            end

            nodePath = strrep(nodePath, '/', '\');

            while contains(nodePath, '\\')
                nodePath = strrep(nodePath, '\\', '\');
            end

            if startsWith(nodePath, 'Data\')
                nodePath = ['\' nodePath];
            end
        end

        function jsonStr = formatJSON(jsonStr)
            %% formatJSON - 格式化 JSON 字符串（旧版 MATLAB 回退方案）
            jsonStr = strrep(jsonStr, ',"', sprintf(',\n  "'));
            jsonStr = strrep(jsonStr, '{"', sprintf('{\n  "'));
            jsonStr = strrep(jsonStr, '"}', sprintf('"\n}'));
            jsonStr = strrep(jsonStr, ':[', sprintf(':\n  ['));
            jsonStr = strrep(jsonStr, ':{', sprintf(':\n  {'));
        end

    end
end
