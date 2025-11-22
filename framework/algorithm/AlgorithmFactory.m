classdef AlgorithmFactory
    % AlgorithmFactory 算法工厂类
    % 提供创建算法实例的工厂方法
    %
    % 功能:
    %   - 根据类型字符串创建算法实例
    %   - 注册和管理算法类型
    %   - 从配置文件创建算法
    %   - 列出可用的算法类型
    %
    % 示例:
    %   % 创建算法
    %   config = struct('maxEvaluations', 10000, 'verbose', true);
    %   algorithm = AlgorithmFactory.create('PSO', config);
    %
    %   % 从配置文件创建
    %   algorithm = AlgorithmFactory.createFromFile('pso_config.json');
    %
    %   % 注册自定义算法
    %   AlgorithmFactory.register('MyAlgorithm', @MyAlgorithm);
    %
    %   % 列出可用算法
    %   algorithms = AlgorithmFactory.listAvailableAlgorithms();


    methods (Static)
        function algorithm = create(type, config)
            % create 创建算法实例
            %
            % 输入:
            %   type - 算法类型字符串 ('PSO', 'NSGA2', 'NSGA3'等)
            %   config - 算法配置对象或结构体（可选）
            %
            % 输出:
            %   algorithm - 算法实例
            %
            % 示例:
            %   config = struct('maxEvaluations', 10000);
            %   algorithm = AlgorithmFactory.create('PSO', config);

            % 获取注册表
            registry = AlgorithmFactory.getRegistry();

            % 规范化类型名称
            type = upper(type);

            % 检查是否已注册
            if ~registry.isKey(type)
                error('AlgorithmFactory:UnknownType', ...
                      '未知的算法类型: %s。使用listAvailableAlgorithms()查看可用类型', type);
            end

            % 获取构造函数
            constructor = registry(type);

            % 创建实例
            try
                algorithm = constructor();

                % 如果提供了配置，设置参数
                if nargin >= 2 && ~isempty(config)
                    AlgorithmFactory.configureAlgorithm(algorithm, config);
                end
            catch ME
                error('AlgorithmFactory:CreationFailed', ...
                      '创建算法失败: %s\n原因: %s', type, ME.message);
            end
        end

        function algorithm = createFromConfig(config)
            % createFromConfig 从Config对象创建算法
            %
            % 输入:
            %   config - Config对象（包含algorithm配置）
            %
            % 输出:
            %   algorithm - 算法实例
            %
            % 示例:
            %   globalConfig = Config('config.json');
            %   algorithm = AlgorithmFactory.createFromConfig(globalConfig);

            % 转换为结构体
            if isa(config, 'Config')
                configData = config.toStruct();
            elseif isstruct(config)
                configData = config;
            else
                error('AlgorithmFactory:InvalidInput', ...
                      '输入必须是Config对象或结构体');
            end

            % 获取algorithm配置
            if isfield(configData, 'algorithm')
                algConfig = configData.algorithm;
            else
                error('AlgorithmFactory:MissingField', ...
                      '配置中缺少algorithm字段');
            end

            % 获取算法类型
            if isfield(algConfig, 'type')
                algType = algConfig.type;
            else
                error('AlgorithmFactory:MissingType', ...
                      '算法配置中缺少type字段');
            end

            % 获取算法参数
            if isfield(algConfig, 'parameters')
                algParams = algConfig.parameters;
            else
                algParams = struct();
            end

            % 创建算法
            algorithm = AlgorithmFactory.create(algType, algParams);
        end

        function algorithm = createFromFile(filename)
            % createFromFile 从配置文件创建算法
            %
            % 输入:
            %   filename - JSON配置文件路径
            %
            % 输出:
            %   algorithm - 算法实例
            %
            % 示例:
            %   algorithm = AlgorithmFactory.createFromFile('pso_config.json');

            if ~exist(filename, 'file')
                error('AlgorithmFactory:FileNotFound', ...
                      '配置文件不存在: %s', filename);
            end

            % 加载配置
            config = Config(filename);

            % 创建算法
            algorithm = AlgorithmFactory.createFromConfig(config);
        end

        function register(type, constructor)
            % register 注册新的算法类型
            %
            % 输入:
            %   type - 算法类型字符串
            %   constructor - 构造函数句柄
            %
            % 示例:
            %   AlgorithmFactory.register('MyAlgorithm', @MyAlgorithm);

            % 获取注册表
            registry = AlgorithmFactory.getRegistry();

            % 规范化类型名称
            type = upper(type);

            % 验证构造函数
            if ~isa(constructor, 'function_handle')
                error('AlgorithmFactory:InvalidConstructor', ...
                      'constructor必须是函数句柄');
            end

            % 注册
            registry(type) = constructor;

            fprintf('已注册算法类型: %s\n', type);
        end

        function unregister(type)
            % unregister 取消注册算法类型
            %
            % 输入:
            %   type - 算法类型字符串
            %
            % 示例:
            %   AlgorithmFactory.unregister('MyAlgorithm');

            % 获取注册表
            registry = AlgorithmFactory.getRegistry();

            % 规范化类型名称
            type = upper(type);

            if registry.isKey(type)
                remove(registry, type);
                fprintf('已取消注册算法类型: %s\n', type);
            else
                warning('AlgorithmFactory:NotRegistered', ...
                        '算法类型 %s 未注册', type);
            end
        end

        function tf = isRegistered(type)
            % isRegistered 检查算法类型是否已注册
            %
            % 输入:
            %   type - 算法类型字符串
            %
            % 输出:
            %   tf - 布尔值
            %
            % 示例:
            %   if AlgorithmFactory.isRegistered('PSO')

            % 获取注册表
            registry = AlgorithmFactory.getRegistry();

            % 规范化类型名称
            type = upper(type);

            tf = registry.isKey(type);
        end

        function types = listAvailableAlgorithms()
            % listAvailableAlgorithms 列出所有可用的算法类型
            %
            % 输出:
            %   types - 算法类型的cell array
            %
            % 示例:
            %   types = AlgorithmFactory.listAvailableAlgorithms();
            %   disp(types);

            % 获取注册表
            registry = AlgorithmFactory.getRegistry();

            % 获取所有键
            types = keys(registry);
        end

        function info = getAlgorithmInfo(type)
            % getAlgorithmInfo 获取算法类型信息
            %
            % 输入:
            %   type - 算法类型字符串
            %
            % 输出:
            %   info - 信息字符串
            %
            % 示例:
            %   info = AlgorithmFactory.getAlgorithmInfo('PSO');
            %   disp(info);

            % 规范化类型名称
            type = upper(type);

            switch type
                case 'PSO'
                    info = '粒子群优化算法 (Particle Swarm Optimization) - 基于群体智能的优化算法';
                case {'NSGA2', 'NSGAII', 'NSGA-II'}
                    info = 'NSGA-II算法 - 快速非支配排序遗传算法，多目标优化';
                case {'NSGA3', 'NSGAIII', 'NSGA-III'}
                    info = 'NSGA-III算法 - 基于参考点的多目标优化算法';
                case 'MOEAD'
                    info = 'MOEA/D算法 - 基于分解的多目标进化算法';
                case 'GA'
                    info = '遗传算法 (Genetic Algorithm) - 经典进化算法';
                case 'DE'
                    info = '差分进化算法 (Differential Evolution) - 连续优化算法';
                case 'ABC'
                    info = '人工蜂群算法 (Artificial Bee Colony) - 基于蜜蜂行为的优化算法';
                otherwise
                    if AlgorithmFactory.isRegistered(type)
                        info = sprintf('自定义算法: %s', type);
                    else
                        info = sprintf('未知的算法类型: %s', type);
                    end
            end
        end

        function displayAvailableAlgorithms()
            % displayAvailableAlgorithms 显示所有可用的算法
            %
            % 示例:
            %   AlgorithmFactory.displayAvailableAlgorithms();

            fprintf('========================================\n');
            fprintf('可用的算法类型\n');
            fprintf('========================================\n');

            types = AlgorithmFactory.listAvailableAlgorithms();

            if isempty(types)
                fprintf('  无可用算法\n');
            else
                for i = 1:length(types)
                    type = types{i};
                    info = AlgorithmFactory.getAlgorithmInfo(type);
                    fprintf('  [%d] %s\n      %s\n\n', i, type, info);
                end
            end

            fprintf('========================================\n');
        end
    end

    methods (Static, Access = private)
        function registry = getRegistry()
            % getRegistry 获取算法注册表
            %
            % 输出:
            %   registry - containers.Map对象
            %
            % 说明:
            %   使用persistent变量实现单例注册表

            persistent algorithmRegistry;

            % 首次调用时初始化
            if isempty(algorithmRegistry)
                algorithmRegistry = containers.Map('KeyType', 'char', 'ValueType', 'any');

                % 注册内置算法类型
                % 注意：需要确保相应的类文件在路径中

                % PSO
                algorithmRegistry('PSO') = @PSO;

                % NSGA-II
                algorithmRegistry('NSGA2') = @NSGAII;
                algorithmRegistry('NSGAII') = @NSGAII;
                algorithmRegistry('NSGA-II') = @NSGAII;

                % NSGA-III - 待实现
                % algorithmRegistry('NSGA3') = @NSGAIII;
                % algorithmRegistry('NSGAIII') = @NSGAIII;
                % algorithmRegistry('NSGA-III') = @NSGAIII;

                % GA - 待实现
                % algorithmRegistry('GA') = @GeneticAlgorithm;

                % DE - 待实现
                % algorithmRegistry('DE') = @DifferentialEvolution;

                % ABC - 待实现
                % algorithmRegistry('ABC') = @ArtificialBeeColony;

                % MOEA/D - 待实现
                % algorithmRegistry('MOEAD') = @MOEAD;
            end

            registry = algorithmRegistry;
        end

        function configureAlgorithm(algorithm, config)
            % configureAlgorithm 配置算法参数
            %
            % 输入:
            %   algorithm - 算法实例
            %   config - 配置结构体
            %
            % 说明:
            %   根据配置设置算法参数

            if ~isstruct(config)
                return;
            end

            % 设置常用参数
            if isfield(config, 'maxEvaluations')
                algorithm.setMaxEvaluations(config.maxEvaluations);
            end

            if isfield(config, 'maxTime')
                algorithm.setMaxTime(config.maxTime);
            end

            if isfield(config, 'targetObjective')
                algorithm.setTargetObjective(config.targetObjective);
            end

            if isfield(config, 'verbose')
                algorithm.setVerbose(config.verbose);
            end

            % 设置日志器
            if isfield(config, 'logFile')
                logger = Logger(Logger.INFO, config.logFile);
                algorithm.setLogger(logger);
            elseif isfield(config, 'logger')
                algorithm.setLogger(config.logger);
            end

            % 设置回调函数
            if isfield(config, 'onIterationEnd')
                algorithm.setIterationCallback(config.onIterationEnd);
            end

            if isfield(config, 'onAlgorithmEnd')
                algorithm.setAlgorithmEndCallback(config.onAlgorithmEnd);
            end
        end
    end

    methods (Static)
        function config = createDefaultConfig(type)
            % createDefaultConfig 创建默认配置
            %
            % 输入:
            %   type - 算法类型字符串
            %
            % 输出:
            %   config - 默认配置结构体
            %
            % 示例:
            %   config = AlgorithmFactory.createDefaultConfig('PSO');

            % 规范化类型名称
            type = upper(type);

            % 通用默认配置
            config = struct();
            config.maxEvaluations = 10000;
            config.maxTime = inf;
            config.verbose = true;

            % 算法特定默认配置
            switch type
                case 'PSO'
                    config.swarmSize = 50;
                    config.maxIterations = 200;
                    config.w = 0.7298;        % 惯性权重
                    config.c1 = 1.49618;      % 个体学习因子
                    config.c2 = 1.49618;      % 社会学习因子
                    config.vMax = 0.2;        % 最大速度（相对于搜索空间）

                case {'NSGA2', 'NSGAII', 'NSGA-II'}
                    config.populationSize = 100;
                    config.maxGenerations = 250;
                    config.crossoverRate = 0.9;
                    config.mutationRate = 1.0;
                    config.crossoverDistIndex = 20;
                    config.mutationDistIndex = 20;

                case {'NSGA3', 'NSGAIII', 'NSGA-III'}
                    config.populationSize = 100;
                    config.maxGenerations = 200;
                    config.numDivisions = 12;  % 参考点划分数
                    config.crossoverProbability = 0.9;
                    config.mutationProbability = 0.1;

                case 'GA'
                    config.populationSize = 50;
                    config.maxGenerations = 200;
                    config.crossoverProbability = 0.8;
                    config.mutationProbability = 0.01;
                    config.selectionMethod = 'tournament';
                    config.tournamentSize = 2;

                case 'DE'
                    config.populationSize = 50;
                    config.maxGenerations = 200;
                    config.F = 0.8;           % 缩放因子
                    config.CR = 0.9;          % 交叉概率
                    config.strategy = 'rand/1/bin';

                case 'ABC'
                    config.colonySize = 50;
                    config.maxIterations = 200;
                    config.limit = 100;       % 放弃限制

                otherwise
                    % 未知类型，返回通用配置
            end
        end
    end
end
