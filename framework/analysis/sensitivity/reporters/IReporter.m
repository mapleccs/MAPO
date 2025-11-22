classdef (Abstract) IReporter < handle
    % IReporter - 报告生成器接口
    %
    % 描述:
    %   定义如何生成灵敏度分析报告
    %   所有报告生成器必须实现此接口
    %
    % 作者: MAPO Framework
    % 日期: 2024

    methods (Abstract)
        % generate - 生成报告
        %
        % 语法:
        %   generate(obj, context)
        %
        % 输入:
        %   context - SensitivityContext对象，包含分析结果
        generate(obj, context)
    end
end