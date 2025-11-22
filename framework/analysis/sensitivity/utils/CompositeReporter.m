classdef CompositeReporter < IReporter
    % CompositeReporter - 复合报告生成器
    %
    % 描述:
    %   组合多个报告生成器，同时生成多种格式的报告
    %   支持链式添加和批量执行
    %
    % 作者: MAPO Framework
    % 日期: 2024

    properties (Access = private)
        reporters = {}          % 报告生成器列表
        reporterNames = {}      % 报告生成器名称
        enabledStatus = []      % 启用状态
    end

    properties
        parallelGeneration = false    % 是否并行生成报告
        stopOnError = false           % 遇到错误时是否停止
        showProgress = true           % 是否显示进度
    end

    methods
        function obj = CompositeReporter(varargin)
            % 构造函数
            %
            % 可选参数（名称-值对）:
            %   'ParallelGeneration' - 是否并行生成报告
            %   'StopOnError' - 遇到错误时是否停止
            %   'ShowProgress' - 是否显示进度

            if nargin > 0
                p = inputParser;
                addParameter(p, 'ParallelGeneration', false, @islogical);
                addParameter(p, 'StopOnError', false, @islogical);
                addParameter(p, 'ShowProgress', true, @islogical);
                parse(p, varargin{:});

                obj.parallelGeneration = p.Results.ParallelGeneration;
                obj.stopOnError = p.Results.StopOnError;
                obj.showProgress = p.Results.ShowProgress;
            end
        end

        function obj = addReporter(obj, reporter, name)
            % 添加报告生成器
            %
            % 输入:
            %   reporter - IReporter实例
            %   name - 报告器名称（可选）

            % 验证输入
            if ~isa(reporter, 'IReporter')
                error('CompositeReporter:InvalidReporter', ...
                    '报告生成器必须实现IReporter接口');
            end

            % 生成默认名称
            if nargin < 3 || isempty(name)
                name = sprintf('Reporter_%d', length(obj.reporters) + 1);
            end

            % 添加到列表
            obj.reporters{end + 1} = reporter;
            obj.reporterNames{end + 1} = name;
            obj.enabledStatus(end + 1) = true;

            if obj.showProgress
                fprintf('已添加报告生成器: %s\n', name);
            end
        end

        function obj = addMultipleReporters(obj, reporters)
            % 批量添加报告生成器
            %
            % 输入:
            %   reporters - 报告生成器数组或元胞数组

            if iscell(reporters)
                for i = 1:length(reporters)
                    obj.addReporter(reporters{i});
                end
            else
                for i = 1:length(reporters)
                    obj.addReporter(reporters(i));
                end
            end
        end

        function obj = removeReporter(obj, nameOrIndex)
            % 移除报告生成器
            %
            % 输入:
            %   nameOrIndex - 报告器名称或索引

            if ischar(nameOrIndex)
                % 按名称移除
                idx = find(strcmp(obj.reporterNames, nameOrIndex), 1);
                if isempty(idx)
                    warning('CompositeReporter:NotFound', ...
                        '未找到报告生成器: %s', nameOrIndex);
                    return;
                end
            else
                % 按索引移除
                idx = nameOrIndex;
                if idx < 1 || idx > length(obj.reporters)
                    error('CompositeReporter:InvalidIndex', ...
                        '无效的索引: %d', idx);
                end
            end

            % 移除
            name = obj.reporterNames{idx};
            obj.reporters(idx) = [];
            obj.reporterNames(idx) = [];
            obj.enabledStatus(idx) = [];

            if obj.showProgress
                fprintf('已移除报告生成器: %s\n', name);
            end
        end

        function obj = setEnabled(obj, nameOrIndex, enabled)
            % 设置报告生成器的启用状态
            %
            % 输入:
            %   nameOrIndex - 报告器名称或索引
            %   enabled - 是否启用

            if ischar(nameOrIndex)
                % 按名称设置
                idx = find(strcmp(obj.reporterNames, nameOrIndex), 1);
                if isempty(idx)
                    warning('CompositeReporter:NotFound', ...
                        '未找到报告生成器: %s', nameOrIndex);
                    return;
                end
            else
                % 按索引设置
                idx = nameOrIndex;
                if idx < 1 || idx > length(obj.reporters)
                    error('CompositeReporter:InvalidIndex', ...
                        '无效的索引: %d', idx);
                end
            end

            obj.enabledStatus(idx) = enabled;
            status = '禁用';
            if enabled
                status = '启用';
            end

            if obj.showProgress
                fprintf('%s报告生成器: %s\n', status, obj.reporterNames{idx});
            end
        end

        function generate(obj, context)
            % 生成报告（使用所有启用的报告生成器）
            %
            % 输入:
            %   context - SensitivityContext对象

            if isempty(obj.reporters)
                warning('CompositeReporter:NoReporters', ...
                    '没有配置报告生成器');
                return;
            end

            % 获取启用的报告器
            enabledIndices = find(obj.enabledStatus);
            if isempty(enabledIndices)
                warning('CompositeReporter:NoEnabledReporters', ...
                    '没有启用的报告生成器');
                return;
            end

            if obj.showProgress
                fprintf('\n开始生成报告 (%d个生成器)\n', ...
                    length(enabledIndices));
                fprintf('========================================\n');
            end

            % 生成报告
            if obj.parallelGeneration && length(enabledIndices) > 1
                obj.generateParallel(context, enabledIndices);
            else
                obj.generateSequential(context, enabledIndices);
            end

            if obj.showProgress
                fprintf('========================================\n');
                fprintf('报告生成完成\n\n');
            end
        end

        function list = getReporterList(obj)
            % 获取报告生成器列表
            %
            % 输出:
            %   list - 包含名称和状态的结构体数组

            list = struct('Name', {}, 'Class', {}, 'Enabled', {});
            for i = 1:length(obj.reporters)
                list(i).Name = obj.reporterNames{i};
                list(i).Class = class(obj.reporters{i});
                list(i).Enabled = obj.enabledStatus(i);
            end
        end

        function clear(obj)
            % 清除所有报告生成器

            obj.reporters = {};
            obj.reporterNames = {};
            obj.enabledStatus = [];

            if obj.showProgress
                fprintf('已清除所有报告生成器\n');
            end
        end

        function obj = configureAll(obj, propertyName, propertyValue)
            % 配置所有报告生成器的共同属性
            %
            % 输入:
            %   propertyName - 属性名
            %   propertyValue - 属性值

            successCount = 0;
            for i = 1:length(obj.reporters)
                try
                    if isprop(obj.reporters{i}, propertyName)
                        obj.reporters{i}.(propertyName) = propertyValue;
                        successCount = successCount + 1;
                    end
                catch ME
                    warning('CompositeReporter:ConfigError', ...
                        '配置报告器 %s 失败: %s', ...
                        obj.reporterNames{i}, ME.message);
                end
            end

            if obj.showProgress
                fprintf('已配置 %d/%d 个报告生成器的属性: %s\n', ...
                    successCount, length(obj.reporters), propertyName);
            end
        end

        function reporter = getReporter(obj, nameOrIndex)
            % 获取特定的报告生成器
            %
            % 输入:
            %   nameOrIndex - 报告器名称或索引
            %
            % 输出:
            %   reporter - 报告生成器实例

            if ischar(nameOrIndex)
                % 按名称获取
                idx = find(strcmp(obj.reporterNames, nameOrIndex), 1);
                if isempty(idx)
                    error('CompositeReporter:NotFound', ...
                        '未找到报告生成器: %s', nameOrIndex);
                end
            else
                % 按索引获取
                idx = nameOrIndex;
                if idx < 1 || idx > length(obj.reporters)
                    error('CompositeReporter:InvalidIndex', ...
                        '无效的索引: %d', idx);
                end
            end

            reporter = obj.reporters{idx};
        end
    end

    methods (Access = private)
        function generateSequential(obj, context, indices)
            % 顺序生成报告

            totalCount = length(indices);
            successCount = 0;
            failedReporters = {};

            for i = 1:totalCount
                idx = indices(i);
                name = obj.reporterNames{idx};
                reporter = obj.reporters{idx};

                if obj.showProgress
                    fprintf('[%d/%d] 正在生成: %s... ', ...
                        i, totalCount, name);
                end

                try
                    startTime = tic;
                    reporter.generate(context);
                    elapsedTime = toc(startTime);
                    successCount = successCount + 1;

                    if obj.showProgress
                        fprintf('完成 (%.2f秒)\n', elapsedTime);
                    end
                catch ME
                    failedReporters{end + 1} = name;

                    if obj.showProgress
                        fprintf('失败\n');
                    end

                    warning('CompositeReporter:GenerateError', ...
                        '生成报告失败 (%s): %s', name, ME.message);

                    if obj.stopOnError
                        error('CompositeReporter:StoppedOnError', ...
                            '因错误停止执行');
                    end
                end
            end

            % 输出摘要
            if obj.showProgress
                fprintf('\n生成摘要: %d成功, %d失败\n', ...
                    successCount, length(failedReporters));
                if ~isempty(failedReporters)
                    fprintf('失败的报告器: %s\n', ...
                        strjoin(failedReporters, ', '));
                end
            end
        end

        function generateParallel(obj, context, indices)
            % 并行生成报告

            totalCount = length(indices);
            results = cell(totalCount, 1);
            errors = cell(totalCount, 1);

            if obj.showProgress
                fprintf('并行生成 %d 个报告...\n', totalCount);
            end

            % 使用parfor并行生成
            parfor i = 1:totalCount
                idx = indices(i);
                reporter = obj.reporters{idx};

                try
                    reporter.generate(context);
                    results{i} = true;
                catch ME
                    results{i} = false;
                    errors{i} = ME.message;
                end
            end

            % 统计结果
            successCount = sum(cell2mat(results));
            failedIndices = find(~cell2mat(results));
            failedReporters = {};

            for i = 1:length(failedIndices)
                idx = indices(failedIndices(i));
                failedReporters{end + 1} = obj.reporterNames{idx};

                warning('CompositeReporter:GenerateError', ...
                    '生成报告失败 (%s): %s', ...
                    obj.reporterNames{idx}, errors{failedIndices(i)});
            end

            % 输出摘要
            if obj.showProgress
                fprintf('\n生成摘要: %d成功, %d失败\n', ...
                    successCount, length(failedReporters));
                if ~isempty(failedReporters)
                    fprintf('失败的报告器: %s\n', ...
                        strjoin(failedReporters, ', '));
                end
            end

            if obj.stopOnError && ~isempty(failedReporters)
                error('CompositeReporter:ParallelErrors', ...
                    '并行生成中发生 %d 个错误', ...
                    length(failedReporters));
            end
        end
    end
end