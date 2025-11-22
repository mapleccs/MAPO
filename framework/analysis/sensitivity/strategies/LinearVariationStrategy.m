classdef LinearVariationStrategy < IVariationStrategy
    % LinearVariationStrategy - 线性变化策略
    %
    % 描述:
    %   生成线性分布的测试点
    %   支持自动范围扩展和自定义步长
    %
    % 作者: MAPO Framework
    % 日期: 2024

    properties
        expansionFactor = 1.3   % 范围扩展因子（默认扩展30%）
        numPoints = 21           % 测试点数量（默认21个点）
        ensureNonNegative = true % 确保值非负
    end

    methods
        function obj = LinearVariationStrategy(varargin)
            % 构造函数
            %
            % 可选参数（名称-值对）:
            %   'ExpansionFactor' - 范围扩展因子
            %   'NumPoints' - 测试点数量
            %   'EnsureNonNegative' - 是否确保非负

            if nargin > 0
                p = inputParser;
                addParameter(p, 'ExpansionFactor', 1.3, @(x) x >= 1);
                addParameter(p, 'NumPoints', 21, @(x) x >= 2);
                addParameter(p, 'EnsureNonNegative', true, @islogical);
                parse(p, varargin{:});

                obj.expansionFactor = p.Results.ExpansionFactor;
                obj.numPoints = p.Results.NumPoints;
                obj.ensureNonNegative = p.Results.EnsureNonNegative;
            end
        end

        function testPoints = generateTestPoints(obj, variable, options)
            % 生成线性分布的测试点
            %
            % 输入:
            %   variable - 变量对象
            %   options - 可选参数
            %     .customRange - 自定义范围 [min, max]
            %     .customStep - 自定义步长
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
                range = variable.upperBound - variable.lowerBound;
                center = (variable.upperBound + variable.lowerBound) / 2;
                expansion = range * (obj.expansionFactor - 1) / 2;

                minVal = variable.lowerBound - expansion;
                maxVal = variable.upperBound + expansion;

                % 确保非负（如果需要）
                if obj.ensureNonNegative
                    minVal = max(0, minVal);
                end
            end

            % 生成测试点
            if isfield(options, 'customStep') && ~isempty(options.customStep)
                % 使用自定义步长
                testPoints = minVal:options.customStep:maxVal;
            elseif isfield(options, 'customNumPoints') && ~isempty(options.customNumPoints)
                % 使用自定义点数
                testPoints = linspace(minVal, maxVal, options.customNumPoints);
            else
                % 使用默认点数
                testPoints = linspace(minVal, maxVal, obj.numPoints);
            end

            % 确保测试点是行向量
            testPoints = testPoints(:)';
        end

        function description = getDescription(obj)
            % 获取策略描述
            description = sprintf('线性变化策略 (扩展因子:%.2f, 点数:%d)', ...
                obj.expansionFactor, obj.numPoints);
        end
    end
end