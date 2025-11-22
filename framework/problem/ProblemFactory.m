classdef ProblemFactory
    % ProblemFactory 优化问题工厂类
    % 提供创建OptimizationProblem对象的便捷方法
    %
    % 功能:
    %   - 从配置文件创建问题
    %   - 从结构体创建问题
    %   - 创建标准测试问题
    %   - 配置验证
    %
    % 示例:
    %   % 从配置文件创建
    %   problem = ProblemFactory.createFromFile('config.json');
    %
    %   % 从Config对象创建
    %   config = Config('config.json');
    %   problem = ProblemFactory.createFromConfig(config);
    %
    %   % 创建标准测试问题
    %   problem = ProblemFactory.createTestProblem('ZDT1');

    methods (Static)
        function problem = createFromFile(filename)
            % createFromFile 从配置文件创建优化问题
            %
            % 输入:
            %   filename - JSON配置文件路径
            %
            % 输出:
            %   problem - OptimizationProblem对象
            %
            % 示例:
            %   problem = ProblemFactory.createFromFile('config.json');

            if ~exist(filename, 'file')
                error('ProblemFactory:FileNotFound', '配置文件不存在: %s', filename);
            end

            % 加载配置
            config = Config(filename);

            % 创建问题
            problem = ProblemFactory.createFromConfig(config);
        end

        function problem = createFromConfig(config)
            % createFromConfig 从Config对象创建优化问题
            %
            % 输入:
            %   config - Config对象
            %
            % 输出:
            %   problem - OptimizationProblem对象
            %
            % 示例:
            %   config = Config('config.json');
            %   problem = ProblemFactory.createFromConfig(config);

            if ~isa(config, 'Config')
                error('ProblemFactory:InvalidInput', '输入必须是Config对象');
            end

            % 验证配置
            if ~ProblemFactory.validateConfig(config)
                error('ProblemFactory:InvalidConfig', '配置验证失败');
            end

            % 创建问题
            problem = OptimizationProblem('Problem');
            problem.loadFromConfig(config);
        end

        function problem = createFromStruct(s)
            % createFromStruct 从结构体创建优化问题
            %
            % 输入:
            %   s - 结构体
            %
            % 输出:
            %   problem - OptimizationProblem对象
            %
            % 示例:
            %   problem = ProblemFactory.createFromStruct(structData);

            problem = OptimizationProblem.fromStruct(s);
        end

        function problem = createTestProblem(problemType, nVars)
            % createTestProblem 创建标准测试问题
            %
            % 输入:
            %   problemType - 问题类型字符串
            %                 'ZDT1', 'ZDT2', 'ZDT3' - ZDT系列
            %                 'DTLZ2' - DTLZ系列
            %                 'Sphere' - 单目标球函数
            %   nVars - (可选) 变量数量，默认取决于问题类型
            %
            % 输出:
            %   problem - OptimizationProblem对象
            %
            % 示例:
            %   problem = ProblemFactory.createTestProblem('ZDT1');
            %   problem = ProblemFactory.createTestProblem('DTLZ2', 12);

            if nargin < 2
                nVars = [];
            end

            switch upper(problemType)
                case 'ZDT1'
                    problem = ProblemFactory.createZDT1(nVars);
                case 'ZDT2'
                    problem = ProblemFactory.createZDT2(nVars);
                case 'ZDT3'
                    problem = ProblemFactory.createZDT3(nVars);
                case 'DTLZ2'
                    problem = ProblemFactory.createDTLZ2(nVars);
                case 'SPHERE'
                    problem = ProblemFactory.createSphere(nVars);
                otherwise
                    error('ProblemFactory:UnknownProblem', ...
                          '未知的测试问题类型: %s', problemType);
            end
        end

        function tf = validateConfig(config)
            % validateConfig 验证配置的完整性
            %
            % 输入:
            %   config - Config对象或结构体
            %
            % 输出:
            %   tf - 布尔值，配置是否有效
            %
            % 示例:
            %   isValid = ProblemFactory.validateConfig(config);

            tf = false;

            % 转换为结构体
            if isa(config, 'Config')
                configData = config.toStruct();
            elseif isstruct(config)
                configData = config;
            else
                warning('ProblemFactory:InvalidInput', '输入必须是Config对象或结构体');
                return;
            end

            % 检查必需字段
            if ~isfield(configData, 'problem')
                warning('ProblemFactory:MissingField', '缺少problem字段');
                return;
            end

            problemConfig = configData.problem;

            % 检查变量
            if ~isfield(problemConfig, 'variables') || isempty(problemConfig.variables)
                warning('ProblemFactory:MissingVariables', '缺少变量定义');
                return;
            end

            % 检查目标函数
            if ~isfield(problemConfig, 'objectives') || isempty(problemConfig.objectives)
                warning('ProblemFactory:MissingObjectives', '缺少目标函数定义');
                return;
            end

            % 验证变量定义
            for i = 1:length(problemConfig.variables)
                var = problemConfig.variables(i);
                if ~isfield(var, 'name') || ~isfield(var, 'type')
                    warning('ProblemFactory:InvalidVariable', '变量%d缺少name或type字段', i);
                    return;
                end
            end

            % 验证目标函数定义
            for i = 1:length(problemConfig.objectives)
                obj = problemConfig.objectives(i);
                if ~isfield(obj, 'name') || ~isfield(obj, 'type')
                    warning('ProblemFactory:InvalidObjective', '目标%d缺少name或type字段', i);
                    return;
                end
            end

            tf = true;
        end

        function problems = listAvailableProblems()
            % listAvailableProblems 列出可用的预定义问题
            %
            % 输出:
            %   problems - 问题名称的cell array
            %
            % 示例:
            %   problems = ProblemFactory.listAvailableProblems();
            %   disp(problems);

            problems = {'ZDT1', 'ZDT2', 'ZDT3', 'DTLZ2', 'Sphere'};
        end

        function displayProblemInfo(problemType)
            % displayProblemInfo 显示预定义问题的信息
            %
            % 输入:
            %   problemType - 问题类型字符串
            %
            % 示例:
            %   ProblemFactory.displayProblemInfo('ZDT1');

            switch upper(problemType)
                case 'ZDT1'
                    fprintf('ZDT1: 双目标测试问题\n');
                    fprintf('  变量数: 30 (默认)\n');
                    fprintf('  目标数: 2\n');
                    fprintf('  特点: 凸Pareto前沿\n');

                case 'ZDT2'
                    fprintf('ZDT2: 双目标测试问题\n');
                    fprintf('  变量数: 30 (默认)\n');
                    fprintf('  目标数: 2\n');
                    fprintf('  特点: 非凸Pareto前沿\n');

                case 'ZDT3'
                    fprintf('ZDT3: 双目标测试问题\n');
                    fprintf('  变量数: 30 (默认)\n');
                    fprintf('  目标数: 2\n');
                    fprintf('  特点: 不连续Pareto前沿\n');

                case 'DTLZ2'
                    fprintf('DTLZ2: 可扩展多目标测试问题\n');
                    fprintf('  变量数: 12 (默认)\n');
                    fprintf('  目标数: 3\n');
                    fprintf('  特点: 球面Pareto前沿\n');

                case 'SPHERE'
                    fprintf('Sphere: 单目标测试问题\n');
                    fprintf('  变量数: 10 (默认)\n');
                    fprintf('  目标数: 1\n');
                    fprintf('  特点: 简单凸优化问题\n');

                otherwise
                    fprintf('未知的问题类型: %s\n', problemType);
            end
        end
    end

    methods (Static, Access = private)
        function problem = createZDT1(nVars)
            % createZDT1 创建ZDT1测试问题
            if isempty(nVars)
                nVars = 30;
            end

            problem = OptimizationProblem('ZDT1', 'ZDT1测试问题 - 凸Pareto前沿');

            % 添加变量 (所有在[0,1]范围内)
            for i = 1:nVars
                problem.addVariable(Variable(sprintf('x%d', i), 'continuous', [0, 1]));
            end

            % 添加目标函数
            problem.addObjective(Objective('f1', 'minimize', 'Description', '第一个目标'));
            problem.addObjective(Objective('f2', 'minimize', 'Description', '第二个目标'));
        end

        function problem = createZDT2(nVars)
            % createZDT2 创建ZDT2测试问题
            if isempty(nVars)
                nVars = 30;
            end

            problem = OptimizationProblem('ZDT2', 'ZDT2测试问题 - 非凸Pareto前沿');

            % 添加变量
            for i = 1:nVars
                problem.addVariable(Variable(sprintf('x%d', i), 'continuous', [0, 1]));
            end

            % 添加目标函数
            problem.addObjective(Objective('f1', 'minimize'));
            problem.addObjective(Objective('f2', 'minimize'));
        end

        function problem = createZDT3(nVars)
            % createZDT3 创建ZDT3测试问题
            if isempty(nVars)
                nVars = 30;
            end

            problem = OptimizationProblem('ZDT3', 'ZDT3测试问题 - 不连续Pareto前沿');

            % 添加变量
            for i = 1:nVars
                problem.addVariable(Variable(sprintf('x%d', i), 'continuous', [0, 1]));
            end

            % 添加目标函数
            problem.addObjective(Objective('f1', 'minimize'));
            problem.addObjective(Objective('f2', 'minimize'));
        end

        function problem = createDTLZ2(nVars)
            % createDTLZ2 创建DTLZ2测试问题
            if isempty(nVars)
                nVars = 12;
            end

            problem = OptimizationProblem('DTLZ2', 'DTLZ2测试问题 - 3目标球面');

            % 添加变量
            for i = 1:nVars
                problem.addVariable(Variable(sprintf('x%d', i), 'continuous', [0, 1]));
            end

            % 添加目标函数
            problem.addObjective(Objective('f1', 'minimize'));
            problem.addObjective(Objective('f2', 'minimize'));
            problem.addObjective(Objective('f3', 'minimize'));
        end

        function problem = createSphere(nVars)
            % createSphere 创建Sphere单目标测试问题
            if isempty(nVars)
                nVars = 10;
            end

            problem = OptimizationProblem('Sphere', 'Sphere函数 - 单目标测试');

            % 添加变量 (在[-5, 5]范围内)
            for i = 1:nVars
                problem.addVariable(Variable(sprintf('x%d', i), 'continuous', [-5, 5]));
            end

            % 添加目标函数
            problem.addObjective(Objective('f', 'minimize', 'Description', 'Sphere函数'));
        end
    end
end
