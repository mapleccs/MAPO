classdef (Abstract) IVariationStrategy < handle
    % IVariationStrategy - 变量变化策略接口
    %
    % 描述:
    %   定义如何生成灵敏度分析的测试点
    %   所有变化策略必须实现此接口
    %
    % 作者: MAPO Framework
    % 日期: 2024

    methods (Abstract)
        % generateTestPoints - 生成测试点
        %
        % 语法:
        %   testPoints = generateTestPoints(obj, variable, options)
        %
        % 输入:
        %   variable - 变量对象，包含名称、范围等信息
        %   options - 可选参数结构体
        %
        % 输出:
        %   testPoints - 测试点数组
        testPoints = generateTestPoints(obj, variable, options)
    end
end