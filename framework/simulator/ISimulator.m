classdef (Abstract) ISimulator < handle
    % ISimulator 仿真器抽象接口
    % 定义所有仿真器适配器必须实现的统一接口
    %
    % 功能:
    %   - 连接/断开仿真器
    %   - 设置变量和获取结果
    %   - 运行仿真
    %   - 状态管理
    %
    % 使用方法:
    %   所有仿真器适配器必须继承此接口并实现所有抽象方法
    %
    % 示例:
    %   classdef MySimulator < ISimulator
    %       methods
    %           function connect(obj, config)
    %               % 实现连接逻辑
    %           end
    %
    %           function success = run(obj, timeout)
    %               % 实现运行逻辑
    %           end
    %
    %           % 实现其他抽象方法...
    %       end
    %   end


    properties (Access = protected)
        config;           % 仿真器配置对象
        connected;        % 连接状态标志
        lastRunSuccess;   % 上次运行是否成功
        runCount;         % 运行次数计数器
    end

    methods
        function obj = ISimulator()
            % ISimulator 构造函数
            %
            % 示例:
            %   simulator = MySimulator();

            obj.connected = false;
            obj.lastRunSuccess = false;
            obj.runCount = 0;
            obj.config = [];
        end

        function tf = isConnected(obj)
            % isConnected 检查是否已连接到仿真器
            %
            % 输出:
            %   tf - 布尔值，true表示已连接
            %
            % 示例:
            %   if simulator.isConnected()

            tf = obj.connected;
        end

        function n = getRunCount(obj)
            % getRunCount 获取运行次数
            %
            % 输出:
            %   n - 运行次数
            %
            % 示例:
            %   count = simulator.getRunCount();

            n = obj.runCount;
        end

        function resetRunCount(obj)
            % resetRunCount 重置运行计数器
            %
            % 示例:
            %   simulator.resetRunCount();

            obj.runCount = 0;
        end

        function tf = wasLastRunSuccessful(obj)
            % wasLastRunSuccessful 检查上次运行是否成功
            %
            % 输出:
            %   tf - 布尔值
            %
            % 示例:
            %   if simulator.wasLastRunSuccessful()

            tf = obj.lastRunSuccess;
        end

        function cfg = getConfig(obj)
            % getConfig 获取仿真器配置
            %
            % 输出:
            %   cfg - 配置对象
            %
            % 示例:
            %   config = simulator.getConfig();

            cfg = obj.config;
        end
    end

    methods (Abstract)
        % connect 连接到仿真器
        %
        % 输入:
        %   config - 仿真器配置对象或结构体
        %
        % 说明:
        %   建立与仿真器的连接，加载模型文件等初始化操作
        %
        % 抛出:
        %   错误 - 如果连接失败
        %
        % 示例实现:
        %   function connect(obj, config)
        %       obj.config = config;
        %       % 连接到仿真器
        %       % 加载模型文件
        %       obj.connected = true;
        %   end
        connect(obj, config)

        % disconnect 断开与仿真器的连接
        %
        % 说明:
        %   释放资源，关闭仿真器连接
        %
        % 示例实现:
        %   function disconnect(obj)
        %       if obj.connected
        %           % 关闭连接
        %           obj.connected = false;
        %       end
        %   end
        disconnect(obj)

        % setVariables 设置仿真变量
        %
        % 输入:
        %   variables - 变量值向量 [1×n] 或变量名-值对的结构体
        %
        % 说明:
        %   将优化变量值传递给仿真器
        %   可以是向量（按预定义顺序）或结构体（变量名-值对）
        %
        % 示例实现:
        %   function setVariables(obj, variables)
        %       if isstruct(variables)
        %           % 处理结构体
        %           names = fieldnames(variables);
        %           for i = 1:length(names)
        %               % 设置变量值
        %           end
        %       else
        %           % 处理向量
        %           for i = 1:length(variables)
        %               % 设置变量值
        %           end
        %       end
        %   end
        setVariables(obj, variables)

        % run 运行仿真
        %
        % 输入:
        %   timeout - (可选) 超时时间（秒），默认无超时
        %
        % 输出:
        %   success - 布尔值，true表示仿真成功收敛
        %
        % 说明:
        %   执行仿真计算，等待收敛或超时
        %
        % 示例实现:
        %   function success = run(obj, timeout)
        %       if nargin < 2
        %           timeout = inf;
        %       end
        %
        %       try
        %           % 运行仿真
        %           % 等待完成或超时
        %           success = true;
        %           obj.lastRunSuccess = true;
        %           obj.runCount = obj.runCount + 1;
        %       catch
        %           success = false;
        %           obj.lastRunSuccess = false;
        %       end
        %   end
        success = run(obj, timeout)

        % getResults 获取仿真结果
        %
        % 输入:
        %   keys - 结果键的cell array，指定要获取的结果
        %
        % 输出:
        %   results - 结果结构体，字段名为keys，值为对应的结果
        %
        % 说明:
        %   从仿真器中提取指定的结果变量
        %
        % 抛出:
        %   错误 - 如果结果不可用或键不存在
        %
        % 示例实现:
        %   function results = getResults(obj, keys)
        %       results = struct();
        %       for i = 1:length(keys)
        %           key = keys{i};
        %           % 从仿真器获取结果
        %           results.(key) = value;
        %       end
        %   end
        results = getResults(obj, keys)
    end

    methods (Abstract, Access = protected)
        % validate 验证仿真器配置
        %
        % 输出:
        %   valid - 布尔值，配置是否有效
        %
        % 说明:
        %   检查配置是否完整和有效
        %   子类应实现此方法进行特定的配置验证
        %
        % 示例实现:
        %   function valid = validate(obj)
        %       valid = ~isempty(obj.config) && ...
        %               isfield(obj.config, 'modelPath');
        %   end
        valid = validate(obj)
    end

    methods
        function reset(obj)
            % reset 重置仿真器到初始状态
            %
            % 说明:
            %   子类可选实现此方法
            %   默认实现仅重置标志位
            %
            % 示例:
            %   simulator.reset();

            obj.lastRunSuccess = false;
            % 子类可以覆盖此方法实现更复杂的重置逻辑
        end

        function status = getStatus(obj)
            % getStatus 获取仿真器状态信息
            %
            % 输出:
            %   status - 状态结构体
            %
            % 说明:
            %   子类可选实现此方法
            %   默认实现返回基本状态信息
            %
            % 示例:
            %   status = simulator.getStatus();

            status = struct();
            status.connected = obj.connected;
            status.lastRunSuccess = obj.lastRunSuccess;
            status.runCount = obj.runCount;
        end

        function info = getInfo(obj)
            % getInfo 获取仿真器信息
            %
            % 输出:
            %   info - 信息字符串
            %
            % 说明:
            %   返回仿真器类型和状态的描述
            %
            % 示例:
            %   disp(simulator.getInfo());

            className = class(obj);
            if obj.connected
                connStatus = '已连接';
            else
                connStatus = '未连接';
            end

            info = sprintf('%s (%s, 运行次数: %d)', ...
                          className, connStatus, obj.runCount);
        end
    end

    methods (Static)
        function type = getSimulatorType()
            % getSimulatorType 获取仿真器类型
            %
            % 输出:
            %   type - 仿真器类型字符串
            %
            % 说明:
            %   子类应覆盖此方法返回具体的类型名称
            %
            % 示例:
            %   type = MySimulator.getSimulatorType();

            type = 'Generic';
        end
    end
end
