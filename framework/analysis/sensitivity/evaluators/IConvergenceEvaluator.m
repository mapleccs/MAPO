classdef (Abstract) IConvergenceEvaluator < handle
    % IConvergenceEvaluator - 收敛性评估器接口
    %
    % 描述:
    %   定义如何判断仿真是否收敛
    %   所有收敛性评估器必须实现此接口
    %
    % 作者: MAPO Framework
    % 日期: 2024

    methods (Abstract)
        % check - 检查仿真结果是否收敛
        %
        % 语法:
        %   converged = check(obj, result, simulator)
        %
        % 输入:
        %   result - 评估器返回的结果
        %   simulator - 仿真器对象（可选）
        %
        % 输出:
        %   converged - 布尔值，true表示收敛
        converged = check(obj, result, simulator)
    end
end