classdef SimulatorFactory
    % SimulatorFactory 仿真器工厂类
    % 提供创建仿真器实例的工厂方法
    %
    % 功能:
    %   - 根据类型字符串创建仿真器实例
    %   - 注册和管理仿真器类型
    %   - 从配置文件创建仿真器
    %   - 列出可用的仿真器类型
    %
    % 示例:
    %   % 创建仿真器
    %   config = SimulatorConfig('Aspen', 'ModelPath', 'model.bkp');
    %   simulator = SimulatorFactory.create('Aspen', config);
    %
    %   % 从配置文件创建
    %   simulator = SimulatorFactory.createFromFile('config.json');
    %
    %   % 注册自定义仿真器
    %   SimulatorFactory.register('MySimulator', @MySimulator);
    %
    %   % 列出可用类型
    %   types = SimulatorFactory.listAvailableSimulators();


    methods (Static)
        function simulator = create(type, config)
            % create 创建仿真器实例
            %
            % 输入:
            %   type - 仿真器类型字符串 ('Aspen', 'MATLAB', 'Python'等)
            %   config - SimulatorConfig对象或结构体
            %
            % 输出:
            %   simulator - 仿真器实例
            %
            % 示例:
            %   config = SimulatorConfig('Aspen');
            %   simulator = SimulatorFactory.create('Aspen', config);

            % 获取注册表
            registry = SimulatorFactory.getRegistry();

            % 规范化类型名称
            type = upper(type);

            % 检查是否已注册
            if ~registry.isKey(type)
                error('SimulatorFactory:UnknownType', ...
                      '未知的仿真器类型: %s。使用listAvailableSimulators()查看可用类型', type);
            end

            % 获取构造函数
            constructor = registry(type);

            % 创建实例
            try
                simulator = constructor();

                % 如果提供了配置，连接仿真器
                if nargin >= 2 && ~isempty(config)
                    simulator.connect(config);
                end
            catch ME
                error('SimulatorFactory:CreationFailed', ...
                      '创建仿真器失败: %s\n原因: %s', type, ME.message);
            end
        end

        function simulator = createFromConfig(config)
            % createFromConfig 从Config对象创建仿真器
            %
            % 输入:
            %   config - Config对象（包含simulator配置）
            %
            % 输出:
            %   simulator - 仿真器实例
            %
            % 示例:
            %   globalConfig = Config('config.json');
            %   simulator = SimulatorFactory.createFromConfig(globalConfig);

            % 创建SimulatorConfig
            simConfig = SimulatorConfig.fromConfig(config);

            % 根据类型创建仿真器
            simulator = SimulatorFactory.create(simConfig.simulatorType, simConfig);
        end

        function simulator = createFromFile(filename)
            % createFromFile 从配置文件创建仿真器
            %
            % 输入:
            %   filename - JSON配置文件路径
            %
            % 输出:
            %   simulator - 仿真器实例
            %
            % 示例:
            %   simulator = SimulatorFactory.createFromFile('config.json');

            if ~exist(filename, 'file')
                error('SimulatorFactory:FileNotFound', '配置文件不存在: %s', filename);
            end

            % 加载配置
            config = Config(filename);

            % 创建仿真器
            simulator = SimulatorFactory.createFromConfig(config);
        end

        function register(type, constructor)
            % register 注册新的仿真器类型
            %
            % 输入:
            %   type - 仿真器类型字符串
            %   constructor - 构造函数句柄
            %
            % 示例:
            %   SimulatorFactory.register('MySimulator', @MySimulator);

            % 获取注册表
            registry = SimulatorFactory.getRegistry();

            % 规范化类型名称
            type = upper(type);

            % 验证构造函数
            if ~isa(constructor, 'function_handle')
                error('SimulatorFactory:InvalidConstructor', ...
                      'constructor必须是函数句柄');
            end

            % 注册
            registry(type) = constructor;

            fprintf('已注册仿真器类型: %s\n', type);
        end

        function unregister(type)
            % unregister 取消注册仿真器类型
            %
            % 输入:
            %   type - 仿真器类型字符串
            %
            % 示例:
            %   SimulatorFactory.unregister('MySimulator');

            % 获取注册表
            registry = SimulatorFactory.getRegistry();

            % 规范化类型名称
            type = upper(type);

            if registry.isKey(type)
                remove(registry, type);
                fprintf('已取消注册仿真器类型: %s\n', type);
            else
                warning('SimulatorFactory:NotRegistered', ...
                        '仿真器类型 %s 未注册', type);
            end
        end

        function tf = isRegistered(type)
            % isRegistered 检查仿真器类型是否已注册
            %
            % 输入:
            %   type - 仿真器类型字符串
            %
            % 输出:
            %   tf - 布尔值
            %
            % 示例:
            %   if SimulatorFactory.isRegistered('Aspen')

            % 获取注册表
            registry = SimulatorFactory.getRegistry();

            % 规范化类型名称
            type = upper(type);

            tf = registry.isKey(type);
        end

        function types = listAvailableSimulators()
            % listAvailableSimulators 列出所有可用的仿真器类型
            %
            % 输出:
            %   types - 仿真器类型的cell array
            %
            % 示例:
            %   types = SimulatorFactory.listAvailableSimulators();
            %   disp(types);

            % 获取注册表
            registry = SimulatorFactory.getRegistry();

            % 获取所有键
            types = keys(registry);
        end

        function info = getSimulatorInfo(type)
            % getSimulatorInfo 获取仿真器类型信息
            %
            % 输入:
            %   type - 仿真器类型字符串
            %
            % 输出:
            %   info - 信息字符串
            %
            % 示例:
            %   info = SimulatorFactory.getSimulatorInfo('Aspen');
            %   disp(info);

            % 规范化类型名称
            type = upper(type);

            switch type
                case 'ASPEN'
                    info = 'Aspen Plus 仿真器 - 化工流程模拟软件';
                case 'HYSYS'
                    info = 'Aspen HYSYS 仿真器 - 化工流程模拟软件';
                case 'MATLAB'
                    info = 'MATLAB 函数仿真器 - 使用MATLAB函数进行仿真';
                case 'PYTHON'
                    info = 'Python 仿真器 - 调用Python脚本进行仿真';
                otherwise
                    if SimulatorFactory.isRegistered(type)
                        info = sprintf('自定义仿真器: %s', type);
                    else
                        info = sprintf('未知的仿真器类型: %s', type);
                    end
            end
        end

        function displayAvailableSimulators()
            % displayAvailableSimulators 显示所有可用的仿真器
            %
            % 示例:
            %   SimulatorFactory.displayAvailableSimulators();

            fprintf('========================================\n');
            fprintf('可用的仿真器类型\n');
            fprintf('========================================\n');

            types = SimulatorFactory.listAvailableSimulators();

            if isempty(types)
                fprintf('  无可用仿真器\n');
            else
                for i = 1:length(types)
                    type = types{i};
                    info = SimulatorFactory.getSimulatorInfo(type);
                    fprintf('  [%d] %s\n      %s\n\n', i, type, info);
                end
            end

            fprintf('========================================\n');
        end
    end

    methods (Static, Access = private)
        function registry = getRegistry()
            % getRegistry 获取仿真器注册表
            %
            % 输出:
            %   registry - containers.Map对象
            %
            % 说明:
            %   使用persistent变量实现单例注册表

            persistent simulatorRegistry;

            % 首次调用时初始化
            if isempty(simulatorRegistry)
                simulatorRegistry = containers.Map('KeyType', 'char', 'ValueType', 'any');

                % 注册内置仿真器类型
                % 注意：需要确保相应的类文件在路径中

                % Aspen Plus
                simulatorRegistry('ASPEN') = @AspenPlusSimulator;
                simulatorRegistry('ASPENPLUS') = @AspenPlusSimulator;

                % HYSYS - 待实现
                % simulatorRegistry('HYSYS') = @HYSYSSimulator;

                % MATLAB
                simulatorRegistry('MATLAB') = @MATLABSimulator;

                % Python - 预留接口
                simulatorRegistry('PYTHON') = @PythonSimulator;
            end

            registry = simulatorRegistry;
        end
    end
end
