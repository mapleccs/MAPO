classdef (Abstract) IOptimizer < handle
    % IOptimizer 优化算法抽象接口
    % 定义所有优化算法必须实现的统一接口
    %
    % 功能:
    %   - 运行优化算法
    %   - 停止算法执行
    %   - 获取优化结果
    %   - 状态管理和查询
    %   - 回调函数支持
    %
    % 使用方法:
    %   所有优化算法必须继承此接口并实现所有抽象方法
    %
    % 示例:
    %   classdef MyAlgorithm < IOptimizer
    %       methods
    %           function results = optimize(obj, problem, config)
    %               % 实现优化逻辑
    %           end
    %
    %           function stop(obj)
    %               % 实现停止逻辑
    %           end
    %       end
    %   end


    properties (Access = protected)
        problem;              % OptimizationProblem对象
        config;               % 算法配置对象
        running;              % 是否正在运行
        stopped;              % 是否已停止
        completed;            % 是否已完成
        evaluationCount;      % 评估次数
        startTime;            % 开始时间
        endTime;              % 结束时间
        results;              % 优化结果
        bestSolution;         % 最优解
        onIterationEnd;       % 迭代结束回调函数
        onAlgorithmEnd;       % 算法结束回调函数
    end

    methods
        function obj = IOptimizer()
            % IOptimizer 构造函数
            %
            % 示例:
            %   algorithm = MyAlgorithm();

            obj.running = false;
            obj.stopped = false;
            obj.completed = false;
            obj.evaluationCount = 0;
            obj.startTime = [];
            obj.endTime = [];
            obj.results = [];
            obj.bestSolution = [];
            obj.onIterationEnd = [];
            obj.onAlgorithmEnd = [];
        end

        function setIterationCallback(obj, callback)
            % setIterationCallback 设置迭代结束回调函数
            %
            % 输入:
            %   callback - 函数句柄 @(iteration, data)
            %
            % 示例:
            %   algorithm.setIterationCallback(@(iter, data) fprintf('Iter %d\n', iter));

            if isa(callback, 'function_handle')
                obj.onIterationEnd = callback;
            else
                error('IOptimizer:InvalidCallback', '回调必须是函数句柄');
            end
        end

        function setAlgorithmEndCallback(obj, callback)
            % setAlgorithmEndCallback 设置算法结束回调函数
            %
            % 输入:
            %   callback - 函数句柄 @(results)
            %
            % 示例:
            %   algorithm.setAlgorithmEndCallback(@(res) fprintf('Done!\n'));

            if isa(callback, 'function_handle')
                obj.onAlgorithmEnd = callback;
            else
                error('IOptimizer:InvalidCallback', '回调必须是函数句柄');
            end
        end

        function tf = isRunning(obj)
            % isRunning 检查算法是否正在运行
            %
            % 输出:
            %   tf - 布尔值
            %
            % 示例:
            %   if algorithm.isRunning()

            tf = obj.running;
        end

        function tf = isStopped(obj)
            % isStopped 检查算法是否已停止
            %
            % 输出:
            %   tf - 布尔值
            %
            % 示例:
            %   if algorithm.isStopped()

            tf = obj.stopped;
        end

        function tf = isCompleted(obj)
            % isCompleted 检查算法是否已完成
            %
            % 输出:
            %   tf - 布尔值
            %
            % 示例:
            %   if algorithm.isCompleted()

            tf = obj.completed;
        end

        function count = getEvaluationCount(obj)
            % getEvaluationCount 获取评估次数
            %
            % 输出:
            %   count - 评估次数
            %
            % 示例:
            %   n = algorithm.getEvaluationCount();

            count = obj.evaluationCount;
        end

        function elapsed = getElapsedTime(obj)
            % getElapsedTime 获取运行时间（秒）
            %
            % 输出:
            %   elapsed - 运行时间（秒）
            %
            % 示例:
            %   time = algorithm.getElapsedTime();

            if isempty(obj.startTime)
                elapsed = 0;
            elseif isempty(obj.endTime)
                % 正在运行
                elapsed = toc(obj.startTime);
            else
                % 已完成
                elapsed = obj.endTime;
            end
        end

        function status = getStatus(obj)
            % getStatus 获取算法状态信息
            %
            % 输出:
            %   status - 状态结构体
            %
            % 示例:
            %   status = algorithm.getStatus();
            %   disp(status);

            status = struct();
            status.running = obj.running;
            status.stopped = obj.stopped;
            status.completed = obj.completed;
            status.evaluationCount = obj.evaluationCount;
            status.elapsedTime = obj.getElapsedTime();

            % 算法状态描述
            if obj.running
                status.state = 'Running';
            elseif obj.stopped
                status.state = 'Stopped';
            elseif obj.completed
                status.state = 'Completed';
            else
                status.state = 'Idle';
            end

            % 问题信息
            if ~isempty(obj.problem)
                status.problemName = obj.problem.name;
                status.numVariables = obj.problem.getNumberOfVariables();
                status.numObjectives = obj.problem.getNumberOfObjectives();
                status.numConstraints = obj.problem.getNumberOfConstraints();
            else
                status.problemName = '';
                status.numVariables = 0;
                status.numObjectives = 0;
                status.numConstraints = 0;
            end
        end

        function res = getResults(obj)
            % getResults 获取优化结果
            %
            % 输出:
            %   res - 结果对象或结构体
            %
            % 说明:
            %   子类可以覆盖此方法返回特定格式的结果
            %   默认实现返回存储的results属性
            %
            % 示例:
            %   results = algorithm.getResults();

            res = obj.results;
        end

        function solution = getBestSolution(obj)
            % getBestSolution 获取最优解
            %
            % 输出:
            %   solution - Individual对象或解向量
            %
            % 示例:
            %   best = algorithm.getBestSolution();

            solution = obj.bestSolution;
        end

        function prob = getProblem(obj)
            % getProblem 获取优化问题
            %
            % 输出:
            %   prob - OptimizationProblem对象
            %
            % 示例:
            %   problem = algorithm.getProblem();

            prob = obj.problem;
        end

        function cfg = getConfig(obj)
            % getConfig 获取算法配置
            %
            % 输出:
            %   cfg - 配置对象
            %
            % 示例:
            %   config = algorithm.getConfig();

            cfg = obj.config;
        end

        function reset(obj)
            % reset 重置算法状态
            %
            % 说明:
            %   将算法恢复到初始状态，可以重新运行
            %   子类可以覆盖此方法实现更复杂的重置逻辑
            %
            % 示例:
            %   algorithm.reset();

            obj.running = false;
            obj.stopped = false;
            obj.completed = false;
            obj.evaluationCount = 0;
            obj.startTime = [];
            obj.endTime = [];
            obj.results = [];
            obj.bestSolution = [];
        end

        function info = getInfo(obj)
            % getInfo 获取算法信息
            %
            % 输出:
            %   info - 信息字符串
            %
            % 说明:
            %   返回算法类型和状态的描述
            %
            % 示例:
            %   disp(algorithm.getInfo());

            className = class(obj);
            status = obj.getStatus();

            info = sprintf('%s (%s, Evaluations: %d, Time: %.2fs)', ...
                          className, status.state, ...
                          obj.evaluationCount, obj.getElapsedTime());
        end
    end

    methods (Abstract)
        % optimize 运行优化算法
        %
        % 输入:
        %   problem - OptimizationProblem对象
        %   config - 算法配置对象或结构体
        %
        % 输出:
        %   results - 优化结果（格式由子类定义）
        %
        % 说明:
        %   执行优化算法的主方法
        %   子类必须实现此方法
        %
        % 示例实现:
        %   function results = optimize(obj, problem, config)
        %       obj.problem = problem;
        %       obj.config = config;
        %       obj.running = true;
        %       obj.startTime = tic;
        %
        %       % 算法主循环
        %       while ~obj.stopped && ~stoppingCriteriaMet
        %           % 执行迭代
        %           % 更新evaluationCount
        %           % 调用回调函数
        %       end
        %
        %       obj.running = false;
        %       obj.completed = true;
        %       obj.endTime = toc(obj.startTime);
        %       results = obj.results;
        %   end
        results = optimize(obj, problem, config)

        % stop 停止算法执行
        %
        % 说明:
        %   请求算法停止运行
        %   算法应该在下次迭代时检查stopped标志并退出
        %   子类必须实现此方法
        %
        % 示例实现:
        %   function stop(obj)
        %       if obj.running
        %           obj.stopped = true;
        %           obj.running = false;
        %       end
        %   end
        stop(obj)
    end

    methods (Access = protected)
        function setRunning(obj, running)
            % setRunning 设置运行状态
            %
            % 输入:
            %   running - 布尔值
            %
            % 说明:
            %   子类在开始/结束运行时调用此方法

            obj.running = running;
        end

        function setStopped(obj, stopped)
            % setStopped 设置停止状态
            %
            % 输入:
            %   stopped - 布尔值
            %
            % 说明:
            %   子类在检测到停止请求时调用此方法

            obj.stopped = stopped;
        end

        function setCompleted(obj, completed)
            % setCompleted 设置完成状态
            %
            % 输入:
            %   completed - 布尔值
            %
            % 说明:
            %   子类在算法正常完成时调用此方法

            obj.completed = completed;
        end

        function incrementEvaluationCount(obj, count)
            % incrementEvaluationCount 增加评估计数
            %
            % 输入:
            %   count - 增加的数量（默认为1）
            %
            % 说明:
            %   子类在评估后调用此方法更新计数

            if nargin < 2
                count = 1;
            end
            obj.evaluationCount = obj.evaluationCount + count;
        end

        function callIterationCallback(obj, iteration, data)
            % callIterationCallback 调用迭代回调函数
            %
            % 输入:
            %   iteration - 当前迭代次数
            %   data - 传递给回调的数据
            %
            % 说明:
            %   子类在每次迭代结束时调用此方法

            if ~isempty(obj.onIterationEnd)
                try
                    obj.onIterationEnd(iteration, data);
                catch ME
                    warning('IOptimizer:CallbackError', ...
                            '迭代回调函数执行失败: %s', ME.message);
                end
            end
        end

        function callAlgorithmEndCallback(obj, results)
            % callAlgorithmEndCallback 调用算法结束回调函数
            %
            % 输入:
            %   results - 算法结果
            %
            % 说明:
            %   子类在算法完成时调用此方法

            if ~isempty(obj.onAlgorithmEnd)
                try
                    obj.onAlgorithmEnd(results);
                catch ME
                    warning('IOptimizer:CallbackError', ...
                            '算法结束回调函数执行失败: %s', ME.message);
                end
            end
        end
    end

    methods (Static)
        function type = getAlgorithmType()
            % getAlgorithmType 获取算法类型
            %
            % 输出:
            %   type - 算法类型字符串
            %
            % 说明:
            %   子类应覆盖此方法返回具体的类型名称
            %
            % 示例:
            %   type = MyAlgorithm.getAlgorithmType();

            type = 'Generic';
        end
    end
end
