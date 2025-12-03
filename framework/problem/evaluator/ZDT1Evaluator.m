classdef ZDT1Evaluator < Evaluator
    % ZDT1Evaluator ZDT1测试函数评估器
    % 用于测试多目标优化算法性能
    %
    % ZDT1问题:
    %   f1(x) = x1
    %   f2(x) = g(x) * (1 - sqrt(f1/g))
    %   g(x) = 1 + 9 * sum(x2:xn) / (n-1)
    %
    % 变量范围: xi ∈ [0, 1], i = 1, ..., n
    % Pareto最优前沿: f2 = 1 - sqrt(f1), 0 ≤ f1 ≤ 1
    %
    % 特点:
    %   - 连续凸Pareto前沿
    %   - 适合测试并行评估性能
    %   - 可选模拟计算延迟
    %
    % 示例:
    %   evaluator = ZDT1Evaluator();
    %   evaluator.setProblem(problem);
    %   result = evaluator.evaluate([0.5, 0.5, 0.5, ...]);
    %
    % 作者: MAPO Framework
    % 日期: 2024

    properties (Access = private)
        simulateDelay       % 是否模拟计算延迟
        delayTime           % 延迟时间（秒）
    end

    methods
        function obj = ZDT1Evaluator(varargin)
            % ZDT1Evaluator 构造函数
            %
            % 可选参数:
            %   'SimulateDelay' - 是否模拟延迟 (默认false)
            %   'DelayTime' - 延迟时间(秒) (默认0.1)

            obj@Evaluator();

            p = inputParser;
            addParameter(p, 'SimulateDelay', false, @islogical);
            addParameter(p, 'DelayTime', 0.1, @isnumeric);
            parse(p, varargin{:});

            obj.simulateDelay = p.Results.SimulateDelay;
            obj.delayTime = p.Results.DelayTime;
        end

        function result = evaluate(obj, variables)
            % evaluate 评估ZDT1函数
            %
            % 输入:
            %   variables - 变量向量 [1×n]
            %
            % 输出:
            %   result - 评估结果结构体
            %            result.objectives - [f1, f2]
            %            result.constraints - []
            %            result.success - true/false
            %            result.message - 消息

            % 增加评估计数
            obj.evaluationCounter = obj.evaluationCounter + 1;

            try
                % 确保变量为行向量
                x = variables(:)';
                n = length(x);

                % 检查变量范围
                if any(x < 0) || any(x > 1)
                    result = obj.createErrorResult('变量超出范围 [0, 1]');
                    return;
                end

                % 计算ZDT1
                f1 = x(1);

                if n > 1
                    g = 1 + 9 * sum(x(2:end)) / (n - 1);
                else
                    g = 1;
                end

                f2 = g * (1 - sqrt(f1 / g));

                % 模拟计算延迟（用于测试并行性能）
                if obj.simulateDelay && obj.delayTime > 0
                    pause(obj.delayTime);
                end

                % 创建成功结果
                result = obj.createSuccessResult([f1, f2], []);

            catch ME
                result = obj.createErrorResult(ME.message);
            end
        end

        function setSimulateDelay(obj, enable, delayTime)
            % setSimulateDelay 设置是否模拟延迟
            %
            % 输入:
            %   enable - 是否启用
            %   delayTime - 延迟时间(秒)

            obj.simulateDelay = enable;
            if nargin >= 3
                obj.delayTime = delayTime;
            end
        end
    end

    methods (Static)
        function [f1, f2] = trueParetoFront(numPoints)
            % trueParetoFront 获取理论Pareto前沿
            %
            % 输入:
            %   numPoints - 采样点数 (默认100)
            %
            % 输出:
            %   f1, f2 - Pareto前沿坐标

            if nargin < 1
                numPoints = 100;
            end

            f1 = linspace(0, 1, numPoints);
            f2 = 1 - sqrt(f1);
        end

        function igd = calculateIGD(objectives, numRefPoints)
            % calculateIGD 计算反向世代距离(IGD)
            %
            % 输入:
            %   objectives - 目标值矩阵 [N×2]
            %   numRefPoints - 参考点数量 (默认100)
            %
            % 输出:
            %   igd - IGD指标值

            if nargin < 2
                numRefPoints = 100;
            end

            % 获取理论Pareto前沿
            [refF1, refF2] = ZDT1Evaluator.trueParetoFront(numRefPoints);
            refPoints = [refF1', refF2'];

            % 计算每个参考点到最近解的距离
            distances = zeros(numRefPoints, 1);
            for i = 1:numRefPoints
                dists = sqrt(sum((objectives - refPoints(i, :)).^2, 2));
                distances(i) = min(dists);
            end

            igd = mean(distances);
        end
    end
end
