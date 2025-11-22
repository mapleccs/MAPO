classdef AspenNodeMapper < handle
    % AspenNodeMapper Aspen Plus节点映射管理器
    % 管理优化变量和Aspen Plus节点之间的映射关系
    %
    % 功能:
    %   - 变量到节点的双向映射
    %   - 结果节点映射
    %   - 节点路径验证
    %   - 批量节点操作
    %   - 路径模板支持
    %   - 单位转换辅助
    %
    % 示例:
    %   % 创建映射器
    %   mapper = AspenNodeMapper();
    %
    %   % 设置输入变量映射
    %   mapper.addInputMapping('temperature', '\Data\Blocks\B1\Input\TEMP');
    %   mapper.addInputMapping('pressure', '\Data\Blocks\B1\Input\PRES');
    %
    %   % 设置输出结果映射
    %   mapper.addOutputMapping('TAC', '\Data\Streams\S1\Output\TOT_FLOW');
    %   mapper.addOutputMapping('Purity', '\Data\Streams\S2\Output\MASSFRAC\ETHANOL');
    %
    %   % 使用映射
    %   inputPaths = mapper.getInputPaths({'temperature', 'pressure'});
    %   outputPaths = mapper.getOutputPaths({'TAC', 'Purity'});


    properties (Access = private)
        inputMapping;      % 输入变量映射 (containers.Map)
        outputMapping;     % 输出结果映射 (containers.Map)
        pathTemplates;     % 路径模板 (containers.Map)
        unitConversions;   % 单位转换因子 (containers.Map)
        aspenApp;          % Aspen应用对象引用（用于验证）
        enableValidation;  % 是否启用节点验证
    end

    methods
        function obj = AspenNodeMapper()
            % AspenNodeMapper 构造函数
            %
            % 示例:
            %   mapper = AspenNodeMapper();

            obj.inputMapping = containers.Map('KeyType', 'char', 'ValueType', 'char');
            obj.outputMapping = containers.Map('KeyType', 'char', 'ValueType', 'char');
            obj.pathTemplates = containers.Map('KeyType', 'char', 'ValueType', 'char');
            obj.unitConversions = containers.Map('KeyType', 'char', 'ValueType', 'any');
            obj.aspenApp = [];
            obj.enableValidation = false;
        end

        function addInputMapping(obj, variableName, nodePath, varargin)
            % addInputMapping 添加输入变量映射
            %
            % 输入:
            %   variableName - 变量名称
            %   nodePath - Aspen节点路径
            %   varargin - 可选参数
            %              'UnitConversion', factor - 单位转换因子
            %              'Validate', true/false - 是否验证节点存在
            %
            % 示例:
            %   mapper.addInputMapping('temp', '\Data\Blocks\B1\Input\TEMP');
            %   mapper.addInputMapping('flow', '\Data\Streams\S1\Input\FLOW', ...
            %                          'UnitConversion', 1000); % kg/h to ton/h

            % 解析可选参数
            p = inputParser;
            addParameter(p, 'UnitConversion', 1, @isnumeric);
            addParameter(p, 'Validate', false, @islogical);
            parse(p, varargin{:});

            % 如果需要验证
            if p.Results.Validate && obj.enableValidation
                obj.validateNodePath(nodePath);
            end

            % 添加映射
            obj.inputMapping(variableName) = nodePath;

            % 保存单位转换因子（如果不是1）
            if p.Results.UnitConversion ~= 1
                conversionData = struct();
                conversionData.factor = p.Results.UnitConversion;
                conversionData.direction = 'input';
                obj.unitConversions(variableName) = conversionData;
            end
        end

        function addOutputMapping(obj, resultName, nodePath, varargin)
            % addOutputMapping 添加输出结果映射
            %
            % 输入:
            %   resultName - 结果名称
            %   nodePath - Aspen节点路径
            %   varargin - 可选参数
            %              'UnitConversion', factor - 单位转换因子
            %              'Validate', true/false - 是否验证节点存在
            %
            % 示例:
            %   mapper.addOutputMapping('TAC', '\Data\Results\TAC');

            % 解析可选参数
            p = inputParser;
            addParameter(p, 'UnitConversion', 1, @isnumeric);
            addParameter(p, 'Validate', false, @islogical);
            parse(p, varargin{:});

            % 如果需要验证
            if p.Results.Validate && obj.enableValidation
                obj.validateNodePath(nodePath);
            end

            % 添加映射
            obj.outputMapping(resultName) = nodePath;

            % 保存单位转换因子（如果不是1）
            if p.Results.UnitConversion ~= 1
                conversionData = struct();
                conversionData.factor = p.Results.UnitConversion;
                conversionData.direction = 'output';
                obj.unitConversions(resultName) = conversionData;
            end
        end

        function removeInputMapping(obj, variableName)
            % removeInputMapping 移除输入变量映射
            %
            % 输入:
            %   variableName - 变量名称
            %
            % 示例:
            %   mapper.removeInputMapping('temp');

            if obj.inputMapping.isKey(variableName)
                remove(obj.inputMapping, variableName);
            end

            if obj.unitConversions.isKey(variableName)
                remove(obj.unitConversions, variableName);
            end
        end

        function removeOutputMapping(obj, resultName)
            % removeOutputMapping 移除输出结果映射
            %
            % 输入:
            %   resultName - 结果名称
            %
            % 示例:
            %   mapper.removeOutputMapping('TAC');

            if obj.outputMapping.isKey(resultName)
                remove(obj.outputMapping, resultName);
            end

            if obj.unitConversions.isKey(resultName)
                remove(obj.unitConversions, resultName);
            end
        end

        function nodePath = getInputPath(obj, variableName)
            % getInputPath 获取输入变量的节点路径
            %
            % 输入:
            %   variableName - 变量名称
            %
            % 输出:
            %   nodePath - 节点路径
            %
            % 示例:
            %   path = mapper.getInputPath('temperature');

            if obj.inputMapping.isKey(variableName)
                nodePath = obj.inputMapping(variableName);
            else
                error('AspenNodeMapper:InputNotFound', ...
                      '输入变量 ''%s'' 未映射', variableName);
            end
        end

        function nodePath = getOutputPath(obj, resultName)
            % getOutputPath 获取输出结果的节点路径
            %
            % 输入:
            %   resultName - 结果名称
            %
            % 输出:
            %   nodePath - 节点路径
            %
            % 示例:
            %   path = mapper.getOutputPath('TAC');

            if obj.outputMapping.isKey(resultName)
                nodePath = obj.outputMapping(resultName);
            else
                error('AspenNodeMapper:OutputNotFound', ...
                      '输出结果 ''%s'' 未映射', resultName);
            end
        end

        function paths = getInputPaths(obj, variableNames)
            % getInputPaths 批量获取输入节点路径
            %
            % 输入:
            %   variableNames - 变量名称的cell array
            %
            % 输出:
            %   paths - 节点路径的cell array
            %
            % 示例:
            %   paths = mapper.getInputPaths({'temp', 'pressure'});

            if isempty(variableNames)
                variableNames = keys(obj.inputMapping);
            end

            paths = cell(size(variableNames));
            for i = 1:length(variableNames)
                paths{i} = obj.getInputPath(variableNames{i});
            end
        end

        function paths = getOutputPaths(obj, resultNames)
            % getOutputPaths 批量获取输出节点路径
            %
            % 输入:
            %   resultNames - 结果名称的cell array
            %
            % 输出:
            %   paths - 节点路径的cell array
            %
            % 示例:
            %   paths = mapper.getOutputPaths({'TAC', 'Purity'});

            if isempty(resultNames)
                resultNames = keys(obj.outputMapping);
            end

            paths = cell(size(resultNames));
            for i = 1:length(resultNames)
                paths{i} = obj.getOutputPath(resultNames{i});
            end
        end

        function names = getInputNames(obj)
            % getInputNames 获取所有输入变量名称
            %
            % 输出:
            %   names - 变量名称的cell array
            %
            % 示例:
            %   inputVars = mapper.getInputNames();

            names = keys(obj.inputMapping);
        end

        function names = getOutputNames(obj)
            % getOutputNames 获取所有输出结果名称
            %
            % 输出:
            %   names - 结果名称的cell array
            %
            % 示例:
            %   outputs = mapper.getOutputNames();

            names = keys(obj.outputMapping);
        end

        function clearInputMappings(obj)
            % clearInputMappings 清空所有输入映射
            %
            % 示例:
            %   mapper.clearInputMappings();

            obj.inputMapping = containers.Map('KeyType', 'char', 'ValueType', 'char');

            % 清除输入相关的单位转换
            if ~isempty(obj.unitConversions)
                toRemove = {};
                convNames = keys(obj.unitConversions);
                for i = 1:length(convNames)
                    name = convNames{i};
                    if obj.unitConversions(name).direction == 'input'
                        toRemove{end+1} = name; %#ok<AGROW>
                    end
                end
                for i = 1:length(toRemove)
                    remove(obj.unitConversions, toRemove{i});
                end
            end
        end

        function clearOutputMappings(obj)
            % clearOutputMappings 清空所有输出映射
            %
            % 示例:
            %   mapper.clearOutputMappings();

            obj.outputMapping = containers.Map('KeyType', 'char', 'ValueType', 'char');

            % 清除输出相关的单位转换
            if ~isempty(obj.unitConversions)
                toRemove = {};
                convNames = keys(obj.unitConversions);
                for i = 1:length(convNames)
                    name = convNames{i};
                    if obj.unitConversions(name).direction == 'output'
                        toRemove{end+1} = name; %#ok<AGROW>
                    end
                end
                for i = 1:length(toRemove)
                    remove(obj.unitConversions, toRemove{i});
                end
            end
        end

        function clearAllMappings(obj)
            % clearAllMappings 清空所有映射
            %
            % 示例:
            %   mapper.clearAllMappings();

            obj.inputMapping = containers.Map('KeyType', 'char', 'ValueType', 'char');
            obj.outputMapping = containers.Map('KeyType', 'char', 'ValueType', 'char');
            obj.unitConversions = containers.Map('KeyType', 'char', 'ValueType', 'any');
        end

        function addPathTemplate(obj, templateName, templatePath)
            % addPathTemplate 添加路径模板
            %
            % 输入:
            %   templateName - 模板名称
            %   templatePath - 模板路径（使用{VAR}作为占位符）
            %
            % 示例:
            %   mapper.addPathTemplate('blockInput', '\Data\Blocks\{BLOCK}\Input\{PARAM}');
            %
            %   % 使用模板
            %   path = mapper.expandTemplate('blockInput', ...
            %                                 'BLOCK', 'B1', 'PARAM', 'TEMP');

            obj.pathTemplates(templateName) = templatePath;
        end

        function path = expandTemplate(obj, templateName, varargin)
            % expandTemplate 展开路径模板
            %
            % 输入:
            %   templateName - 模板名称
            %   varargin - 变量名-值对
            %
            % 输出:
            %   path - 展开的路径
            %
            % 示例:
            %   path = mapper.expandTemplate('blockInput', ...
            %                                 'BLOCK', 'B1', 'PARAM', 'TEMP');

            if ~obj.pathTemplates.isKey(templateName)
                error('AspenNodeMapper:TemplateNotFound', ...
                      '模板 ''%s'' 不存在', templateName);
            end

            path = obj.pathTemplates(templateName);

            % 替换占位符
            for i = 1:2:length(varargin)
                placeholder = sprintf('{%s}', varargin{i});
                value = varargin{i+1};
                path = strrep(path, placeholder, value);
            end
        end

        function setAspenApp(obj, aspenApp)
            % setAspenApp 设置Aspen应用对象引用
            %
            % 输入:
            %   aspenApp - Aspen COM对象
            %
            % 说明:
            %   设置后可以启用节点验证功能
            %
            % 示例:
            %   mapper.setAspenApp(aspenApp);
            %   mapper.enableNodeValidation(true);

            obj.aspenApp = aspenApp;
        end

        function enableNodeValidation(obj, enable)
            % enableNodeValidation 启用/禁用节点验证
            %
            % 输入:
            %   enable - 布尔值
            %
            % 说明:
            %   需要先调用setAspenApp设置Aspen对象
            %
            % 示例:
            %   mapper.enableNodeValidation(true);

            if enable && isempty(obj.aspenApp)
                warning('AspenNodeMapper:NoAspenApp', ...
                        '未设置Aspen应用对象，无法启用验证');
                return;
            end

            obj.enableValidation = enable;
        end

        function convertedValue = applyInputConversion(obj, variableName, value)
            % applyInputConversion 应用输入单位转换
            %
            % 输入:
            %   variableName - 变量名称
            %   value - 原始值
            %
            % 输出:
            %   convertedValue - 转换后的值
            %
            % 示例:
            %   converted = mapper.applyInputConversion('flow', 10.5);

            if obj.unitConversions.isKey(variableName)
                convData = obj.unitConversions(variableName);
                convertedValue = value * convData.factor;
            else
                convertedValue = value;
            end
        end

        function convertedValue = applyOutputConversion(obj, resultName, value)
            % applyOutputConversion 应用输出单位转换
            %
            % 输入:
            %   resultName - 结果名称
            %   value - 原始值
            %
            % 输出:
            %   convertedValue - 转换后的值
            %
            % 示例:
            %   converted = mapper.applyOutputConversion('TAC', 1000000);

            if obj.unitConversions.isKey(resultName)
                convData = obj.unitConversions(resultName);
                convertedValue = value * convData.factor;
            else
                convertedValue = value;
            end
        end

        function loadFromConfig(obj, config)
            % loadFromConfig 从SimulatorConfig加载映射
            %
            % 输入:
            %   config - SimulatorConfig对象或结构体
            %
            % 示例:
            %   simConfig = SimulatorConfig.fromFile('config.json');
            %   mapper.loadFromConfig(simConfig);

            if isa(config, 'SimulatorConfig')
                % 从SimulatorConfig加载输入映射
                varNames = config.getVariableNames();
                for i = 1:length(varNames)
                    varName = varNames{i};
                    nodePath = config.getNodePath(varName);
                    obj.addInputMapping(varName, nodePath);
                end
            elseif isstruct(config)
                % 从结构体加载
                if isfield(config, 'inputMapping')
                    inputFields = fieldnames(config.inputMapping);
                    for i = 1:length(inputFields)
                        field = inputFields{i};
                        obj.addInputMapping(field, config.inputMapping.(field));
                    end
                end

                if isfield(config, 'outputMapping')
                    outputFields = fieldnames(config.outputMapping);
                    for i = 1:length(outputFields)
                        field = outputFields{i};
                        obj.addOutputMapping(field, config.outputMapping.(field));
                    end
                end
            else
                error('AspenNodeMapper:InvalidInput', ...
                      '输入必须是SimulatorConfig对象或结构体');
            end
        end

        function s = toStruct(obj)
            % toStruct 转换为结构体
            %
            % 输出:
            %   s - 映射信息的结构体
            %
            % 示例:
            %   data = mapper.toStruct();

            s = struct();

            % 输入映射
            if ~isempty(obj.inputMapping)
                inputNames = keys(obj.inputMapping);
                for i = 1:length(inputNames)
                    name = inputNames{i};
                    s.inputMapping.(name) = obj.inputMapping(name);
                end
            else
                s.inputMapping = struct();
            end

            % 输出映射
            if ~isempty(obj.outputMapping)
                outputNames = keys(obj.outputMapping);
                for i = 1:length(outputNames)
                    name = outputNames{i};
                    s.outputMapping.(name) = obj.outputMapping(name);
                end
            else
                s.outputMapping = struct();
            end

            % 单位转换
            if ~isempty(obj.unitConversions)
                convNames = keys(obj.unitConversions);
                for i = 1:length(convNames)
                    name = convNames{i};
                    s.unitConversions.(name) = obj.unitConversions(name);
                end
            else
                s.unitConversions = struct();
            end
        end

        function display(obj)
            % display 显示映射信息
            %
            % 示例:
            %   mapper.display();

            fprintf('========================================\n');
            fprintf('Aspen Node Mapper\n');
            fprintf('========================================\n');

            fprintf('\n输入映射 (%d):\n', obj.inputMapping.Count);
            if ~isempty(obj.inputMapping)
                inputNames = keys(obj.inputMapping);
                for i = 1:length(inputNames)
                    name = inputNames{i};
                    path = obj.inputMapping(name);
                    if obj.unitConversions.isKey(name)
                        factor = obj.unitConversions(name).factor;
                        fprintf('  %s -> %s (×%.4g)\n', name, path, factor);
                    else
                        fprintf('  %s -> %s\n', name, path);
                    end
                end
            else
                fprintf('  无\n');
            end

            fprintf('\n输出映射 (%d):\n', obj.outputMapping.Count);
            if ~isempty(obj.outputMapping)
                outputNames = keys(obj.outputMapping);
                for i = 1:length(outputNames)
                    name = outputNames{i};
                    path = obj.outputMapping(name);
                    if obj.unitConversions.isKey(name)
                        factor = obj.unitConversions(name).factor;
                        fprintf('  %s <- %s (×%.4g)\n', name, path, factor);
                    else
                        fprintf('  %s <- %s\n', name, path);
                    end
                end
            else
                fprintf('  无\n');
            end

            fprintf('\n路径模板 (%d):\n', obj.pathTemplates.Count);
            if ~isempty(obj.pathTemplates)
                templateNames = keys(obj.pathTemplates);
                for i = 1:length(templateNames)
                    name = templateNames{i};
                    template = obj.pathTemplates(name);
                    fprintf('  %s: %s\n', name, template);
                end
            else
                fprintf('  无\n');
            end

            fprintf('========================================\n');
        end
    end

    methods (Access = private)
        function validateNodePath(obj, nodePath)
            % validateNodePath 验证节点路径是否存在
            %
            % 输入:
            %   nodePath - 节点路径
            %
            % 抛出:
            %   错误 - 如果节点不存在

            if isempty(obj.aspenApp)
                return;
            end

            try
                node = obj.aspenApp.Tree.FindNode(nodePath);
                if isempty(node)
                    error('AspenNodeMapper:NodeNotFound', ...
                          '节点不存在: %s', nodePath);
                end
            catch ME
                error('AspenNodeMapper:ValidationFailed', ...
                      '节点验证失败: %s\n原因: %s', nodePath, ME.message);
            end
        end
    end

    methods (Static)
        function mapper = fromConfig(config)
            % fromConfig 从配置创建映射器
            %
            % 输入:
            %   config - SimulatorConfig对象或结构体
            %
            % 输出:
            %   mapper - AspenNodeMapper对象
            %
            % 示例:
            %   mapper = AspenNodeMapper.fromConfig(simConfig);

            mapper = AspenNodeMapper();
            mapper.loadFromConfig(config);
        end
    end
end
