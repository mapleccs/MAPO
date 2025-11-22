classdef LogarithmicVariationStrategy < IVariationStrategy
    % LogarithmicVariationStrategy - 对数变化策略
    %
    % 描述:
    %   生成对数分布的测试点
    %   适用于范围跨度较大的变量（如跨越多个数量级）
    %
    % 作者: MAPO Framework
    % 日期: 2024

    properties
        expansionFactor = 1.2   % 范围扩展因子
        numPoints = 21           % 测试点数量
        base = 10                % 对数底数
    end

    methods
        function obj = LogarithmicVariationStrategy(varargin)
            % 构造函数
            %
            % 可选参数（名称-值对）:
            %   'ExpansionFactor' - 范围扩展因子
            %   'NumPoints' - 测试点数量
            %   'Base' - 对数底数

            if nargin > 0
                p = inputParser;
                addParameter(p, 'ExpansionFactor', 1.2, @(x) x >= 1);
                addParameter(p, 'NumPoints', 21, @(x) x >= 2);
                addParameter(p, 'Base', 10, @(x) x > 0 && x ~= 1);
                parse(p, varargin{:});

                obj.expansionFactor = p.Results.ExpansionFactor;
                obj.numPoints = p.Results.NumPoints;
                obj.base = p.Results.Base;
            end
        end

        function testPoints = generateTestPoints(obj, variable, options)
            % 生成对数分布的测试点
            %
            % 输入:
            %   variable - 变量对象
            %   options - 可选参数
            %     .customRange - 自定义范围 [min, max]
            %     .customNumPoints - 自定义点数
            %
            % 输出:
            %   testPoints - 测试点数组

            if nargin < 3
                options = struct();
            end

            % 确定测试范围
            if isfield(options, 'customRange') && ~isempty(options.customRange)
                minVal = options.customRange(1);
                maxVal = options.customRange(2);
            else
                % 自动扩展范围
                minVal = variable.lowerBound / obj.expansionFactor;
                maxVal = variable.upperBound * obj.expansionFactor;

                % 确保正值（对数需要正数）
                minVal = max(eps, minVal);
            end

            % 确定点数
            if isfield(options, 'customNumPoints') && ~isempty(options.customNumPoints)
                numPts = options.customNumPoints;
            else
                numPts = obj.numPoints;
            end

            % 在对数空间生成均匀分布的点
            if obj.base == exp(1)
                % 自然对数
                logMin = log(minVal);
                logMax = log(maxVal);
                logPoints = linspace(logMin, logMax, numPts);
                testPoints = exp(logPoints);
            else
                % 其他底数
                logMin = log(minVal) / log(obj.base);
                logMax = log(maxVal) / log(obj.base);
                logPoints = linspace(logMin, logMax, numPts);
                testPoints = obj.base .^ logPoints;
            end

            % 确保测试点是行向量
            testPoints = testPoints(:)';
        end

        function description = getDescription(obj)
            % 获取策略描述
            description = sprintf('对数变化策略 (底数:%.1f, 扩展因子:%.2f, 点数:%d)', ...
                obj.base, obj.expansionFactor, obj.numPoints);
        end
    end
end