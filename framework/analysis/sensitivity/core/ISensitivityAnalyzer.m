classdef (Abstract) ISensitivityAnalyzer < handle
    % ISensitivityAnalyzer - 灵敏度分析器接口
    %
    % 描述:
    %   定义所有灵敏度分析器必须实现的方法
    %   这是一个抽象接口，确保所有分析器实现具有一致的行为
    %
    % 作者: MAPO Framework
    % 日期: 2024

    methods (Abstract)
        % analyzeVariable - 执行单变量分析
        %
        % 语法:
        %   result = analyzeVariable(obj, variableName)
        %
        % 输入:
        %   variableName - 要分析的变量名称
        %
        % 输出:
        %   result - SensitivityResult对象，包含分析结果
        result = analyzeVariable(obj, variableName)

        % analyzeAll - 执行所有变量的分析
        %
        % 语法:
        %   results = analyzeAll(obj)
        %
        % 输出:
        %   results - SensitivityResult对象的cell数组
        results = analyzeAll(obj)

        % getFeasibleRanges - 获取所有变量的可行域
        %
        % 语法:
        %   ranges = getFeasibleRanges(obj, convergenceThreshold)
        %
        % 输入:
        %   convergenceThreshold - 收敛率阈值，默认0.7 (70%)
        %
        % 输出:
        %   ranges - containers.Map对象，键为变量名，值为[min, max]数组
        ranges = getFeasibleRanges(obj, convergenceThreshold)

        % report - 生成分析报告
        %
        % 语法:
        %   report(obj, reporter)
        %
        % 输入:
        %   reporter - IReporter对象，用于生成报告（可选）
        report(obj, reporter)
    end
end