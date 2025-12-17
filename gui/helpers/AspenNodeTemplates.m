classdef AspenNodeTemplates
    %% AspenNodeTemplates - Aspen Plus 节点路径模板
    %
    % 提供常用的 Aspen Plus 节点路径模板，帮助用户快速配置变量映射。
    %
    % 用法:
    %   templates = AspenNodeTemplates.getVariableTemplates();
    %   templates = AspenNodeTemplates.getResultTemplates();
    %   path = AspenNodeTemplates.buildPath(template, 'STREAM', 'S1', 'COMP', 'H2O');
    %
    % 示例:
    %   % 获取流股输入模板
    %   templates = AspenNodeTemplates.getVariableTemplates();
    %   disp(templates.StreamInput);
    %
    %   % 构建具体路径
    %   path = AspenNodeTemplates.buildPath('\Data\Streams\{STREAM}\Input\TOTFLOW\MIXED', ...
    %                                        'STREAM', 'FEED');
    %   % 结果: '\Data\Streams\FEED\Input\TOTFLOW\MIXED'

    methods (Static)

        function templates = getVariableTemplates()
            %% getVariableTemplates - 获取变量（输入）节点模板
            %
            % 返回:
            %   templates - 结构体，包含各类型设备的输入节点模板

            templates = struct();

            %% 流股输入节点
            templates.StreamInput = {
                '总流量 (TOTFLOW)',         '\Data\Streams\{STREAM}\Input\TOTFLOW\MIXED';
                '温度 (TEMP)',              '\Data\Streams\{STREAM}\Input\TEMP\MIXED';
                '压力 (PRES)',              '\Data\Streams\{STREAM}\Input\PRES\MIXED';
                '蒸汽分率 (VFRAC)',         '\Data\Streams\{STREAM}\Input\VFRAC\MIXED';
                '组分摩尔流量 (MOLEFLOW)',   '\Data\Streams\{STREAM}\Input\FLOW\MIXED\{COMP}';
                '组分质量流量 (MASSFLOW)',   '\Data\Streams\{STREAM}\Input\MASSFLMX\{COMP}';
                '组分摩尔分数 (MOLEFRAC)',   '\Data\Streams\{STREAM}\Input\MOLE-FRAC\MIXED\{COMP}';
            };

            %% 精馏塔 (RadFrac) 输入节点
            templates.RadFrac = {
                '进料位置 (FEED_STAGE)',    '\Data\Blocks\{BLOCK}\Input\FEED_STAGE\{STREAM}';
                '理论板数 (NSTAGE)',        '\Data\Blocks\{BLOCK}\Input\NSTAGE';
                '回流比 (RR)',              '\Data\Blocks\{BLOCK}\Input\BASIS_RR';
                '塔底采出比 (B:F)',          '\Data\Blocks\{BLOCK}\Input\B:F';
                '塔顶产品流量 (D:F)',        '\Data\Blocks\{BLOCK}\Input\D:F';
                '塔顶压力 (PRES1)',          '\Data\Blocks\{BLOCK}\Input\PRES1';
                '塔底压力 (PRES-BOT)',       '\Data\Blocks\{BLOCK}\Input\PBOT-SPEC';
                '冷凝器类型',                '\Data\Blocks\{BLOCK}\Input\CONDENSER';
            };

            %% 反应器 (RStoic/RYield/RCSTR) 输入节点
            templates.Reactor = {
                '温度 (TEMP)',              '\Data\Blocks\{BLOCK}\Input\TEMP';
                '压力 (PRES)',              '\Data\Blocks\{BLOCK}\Input\PRES';
                '热负荷 (DUTY)',            '\Data\Blocks\{BLOCK}\Input\DUTY';
                '停留时间 (RES-TIME)',       '\Data\Blocks\{BLOCK}\Input\RES-TIME';
                '反应器体积 (VOL)',          '\Data\Blocks\{BLOCK}\Input\VOL';
            };

            %% 换热器 (HeatX/Heater) 输入节点
            templates.HeatExchanger = {
                '出口温度 (TEMP)',           '\Data\Blocks\{BLOCK}\Input\TEMP';
                '出口蒸汽分率 (VFRAC)',      '\Data\Blocks\{BLOCK}\Input\VFRAC';
                '热负荷 (DUTY)',             '\Data\Blocks\{BLOCK}\Input\DUTY';
                '压降 (PDROP)',              '\Data\Blocks\{BLOCK}\Input\PDROP';
                '压力 (PRES)',               '\Data\Blocks\{BLOCK}\Input\PRES';
            };

            %% 压缩机/泵 (Compr/Pump) 输入节点
            templates.CompressorPump = {
                '出口压力 (PRES)',           '\Data\Blocks\{BLOCK}\Input\PRES';
                '压缩比 (PRAT)',             '\Data\Blocks\{BLOCK}\Input\PRAT';
                '功耗 (POWER)',              '\Data\Blocks\{BLOCK}\Input\POWER';
                '效率 (EFF)',                '\Data\Blocks\{BLOCK}\Input\P-EFF';
            };

            %% 闪蒸罐 (Flash2/Flash3) 输入节点
            templates.Flash = {
                '温度 (TEMP)',               '\Data\Blocks\{BLOCK}\Input\TEMP';
                '压力 (PRES)',               '\Data\Blocks\{BLOCK}\Input\PRES';
                '热负荷 (DUTY)',             '\Data\Blocks\{BLOCK}\Input\DUTY';
                '蒸汽分率 (VFRAC)',          '\Data\Blocks\{BLOCK}\Input\VFRAC';
            };

            %% 分离器 (Sep/Sep2) 输入节点
            templates.Separator = {
                '分离效率 (FRAC)',           '\Data\Blocks\{BLOCK}\Input\FRAC\{STREAM}\{COMP}';
            };

            %% 混合器 (Mixer) 输入节点
            templates.Mixer = {
                '出口压力 (PRES)',           '\Data\Blocks\{BLOCK}\Input\PRES';
            };

            %% 分流器 (FSplit) 输入节点
            templates.Splitter = {
                '分流比 (FRAC)',             '\Data\Blocks\{BLOCK}\Input\FRAC\{STREAM}';
            };
        end

        function templates = getResultTemplates()
            %% getResultTemplates - 获取结果（输出）节点模板
            %
            % 返回:
            %   templates - 结构体，包含各类型设备的输出节点模板

            templates = struct();

            %% 流股输出节点
            templates.StreamOutput = {
                '总摩尔流量 (MOLEFLOW)',       '\Data\Streams\{STREAM}\Output\MOLEFLMX\MIXED';
                '总质量流量 (MASSFLOW)',       '\Data\Streams\{STREAM}\Output\MASSFLMX\MIXED';
                '温度 (TEMP)',                '\Data\Streams\{STREAM}\Output\TEMP\MIXED';
                '压力 (PRES)',                '\Data\Streams\{STREAM}\Output\PRES\MIXED';
                '蒸汽分率 (VFRAC)',           '\Data\Streams\{STREAM}\Output\VFRAC\MIXED';
                '密度 (RHO)',                 '\Data\Streams\{STREAM}\Output\RHOMX\MIXED';
                '焓 (H)',                     '\Data\Streams\{STREAM}\Output\HMX\MIXED';
                '熵 (S)',                     '\Data\Streams\{STREAM}\Output\SMX\MIXED';
                '组分摩尔分数 (MOLEFRAC)',     '\Data\Streams\{STREAM}\Output\MOLEFRAC\MIXED\{COMP}';
                '组分质量分数 (MASSFRAC)',     '\Data\Streams\{STREAM}\Output\MASSFRAC\MIXED\{COMP}';
                '组分摩尔流量 (MOLEFLOW)',     '\Data\Streams\{STREAM}\Output\MOLEFLOW\MIXED\{COMP}';
                '组分质量流量 (MASSFLOW)',     '\Data\Streams\{STREAM}\Output\MASSFLOW\MIXED\{COMP}';
            };

            %% 精馏塔 (RadFrac) 输出节点
            templates.RadFrac = {
                '再沸器负荷 (REB_DUTY)',      '\Data\Blocks\{BLOCK}\Output\REB_DUTY';
                '冷凝器负荷 (COND_DUTY)',     '\Data\Blocks\{BLOCK}\Output\COND_DUTY';
                '实际板数 (ACT_STAGES)',      '\Data\Blocks\{BLOCK}\Output\ACT_STAGES';
                '最小回流比 (MIN_REFLUX)',    '\Data\Blocks\{BLOCK}\Output\MIN_REFLUX';
                '塔底温度 (BOTTOM_TEMP)',     '\Data\Blocks\{BLOCK}\Output\BOTTOM_TEMP';
                '塔顶温度 (TOP_TEMP)',        '\Data\Blocks\{BLOCK}\Output\TOP_TEMP';
                '第N板温度 (TEMP_N)',         '\Data\Blocks\{BLOCK}\Output\TEMP_PROFILE\{N}';
            };

            %% 反应器 (RStoic/RYield/RCSTR) 输出节点
            templates.Reactor = {
                '热负荷 (QCALC)',             '\Data\Blocks\{BLOCK}\Output\QCALC';
                '出口温度 (TOT-TEMP)',        '\Data\Blocks\{BLOCK}\Output\TOT-TEMP';
                '转化率 (CONV)',              '\Data\Blocks\{BLOCK}\Output\CONV\{REACTION}';
                '反应热 (Q-RXN)',             '\Data\Blocks\{BLOCK}\Output\Q-RXN';
            };

            %% 换热器 (HeatX/Heater) 输出节点
            templates.HeatExchanger = {
                '热负荷 (DUTY)',              '\Data\Blocks\{BLOCK}\Output\QCALC';
                '出口温度 (TEMP-OUT)',        '\Data\Blocks\{BLOCK}\Output\TEMP_OUT';
                'LMTD',                       '\Data\Blocks\{BLOCK}\Output\LMTD';
                '传热面积 (AREA)',            '\Data\Blocks\{BLOCK}\Output\HX_AREA';
                '总传热系数 (U)',             '\Data\Blocks\{BLOCK}\Output\U';
            };

            %% 压缩机/泵 (Compr/Pump) 输出节点
            templates.CompressorPump = {
                '功耗 (WNET)',                '\Data\Blocks\{BLOCK}\Output\WNET';
                '出口温度 (TEMP-OUT)',        '\Data\Blocks\{BLOCK}\Output\TEMP_OUT';
                '出口压力 (PRES-OUT)',        '\Data\Blocks\{BLOCK}\Output\PRES_OUT';
                '效率 (EFF)',                 '\Data\Blocks\{BLOCK}\Output\ISENTROPIC_EFF';
            };

            %% 闪蒸罐 (Flash2/Flash3) 输出节点
            templates.Flash = {
                '热负荷 (DUTY)',              '\Data\Blocks\{BLOCK}\Output\QCALC';
                '出口温度 (TEMP)',            '\Data\Blocks\{BLOCK}\Output\B_TEMP';
                '出口压力 (PRES)',            '\Data\Blocks\{BLOCK}\Output\B_PRES';
            };

            %% 结果汇总节点
            templates.Summary = {
                '总热负荷',                   '\Data\Results Summary\Duty\{BLOCK}';
                '总功耗',                     '\Data\Results Summary\Power\{BLOCK}';
                '流股流量',                   '\Data\Results Summary\Streams\{STREAM}\MASSFLMX';
            };
        end

        function categories = getTemplateCategories()
            %% getTemplateCategories - 获取模板分类列表
            %
            % 返回:
            %   categories - 元胞数组，包含所有模板类别名称

            categories = {
                '流股输入 (Stream Input)';
                '流股输出 (Stream Output)';
                '精馏塔 (RadFrac)';
                '反应器 (Reactor)';
                '换热器 (HeatExchanger)';
                '压缩机/泵 (Compressor/Pump)';
                '闪蒸罐 (Flash)';
                '分离器 (Separator)';
                '混合器 (Mixer)';
                '分流器 (Splitter)';
                '结果汇总 (Summary)';
            };
        end

        function path = buildPath(template, varargin)
            %% buildPath - 根据模板构建具体路径
            %
            % 输入:
            %   template  - 模板路径字符串，如 '\Data\Streams\{STREAM}\Input\TEMP'
            %   varargin  - 键值对，如 'STREAM', 'FEED', 'COMP', 'H2O'
            %
            % 返回:
            %   path - 替换占位符后的具体路径
            %
            % 示例:
            %   path = AspenNodeTemplates.buildPath('\Data\Streams\{STREAM}\Input\TEMP', 'STREAM', 'FEED');
            %   % 结果: '\Data\Streams\FEED\Input\TEMP'

            path = template;

            % 解析键值对
            for i = 1:2:length(varargin)
                if i+1 <= length(varargin)
                    key = varargin{i};
                    value = varargin{i+1};
                    placeholder = ['{' key '}'];
                    path = strrep(path, placeholder, value);
                end
            end

            % 检查是否还有未替换的占位符
            if contains(path, '{')
                warning('AspenNodeTemplates:UnreplacedPlaceholder', ...
                    '路径中仍有未替换的占位符: %s', path);
            end
        end

        function [templateList, isVariable] = getTemplatesForCategory(category)
            %% getTemplatesForCategory - 获取指定类别的模板列表
            %
            % 输入:
            %   category - 类别名称
            %
            % 返回:
            %   templateList - N×2 元胞数组 {名称, 路径}
            %   isVariable   - 是否为变量（输入）模板

            varTemplates = AspenNodeTemplates.getVariableTemplates();
            resTemplates = AspenNodeTemplates.getResultTemplates();

            isVariable = true;

            switch category
                case '流股输入 (Stream Input)'
                    templateList = varTemplates.StreamInput;
                case '流股输出 (Stream Output)'
                    templateList = resTemplates.StreamOutput;
                    isVariable = false;
                case '精馏塔 (RadFrac)'
                    % 合并输入和输出
                    templateList = [varTemplates.RadFrac; resTemplates.RadFrac];
                    isVariable = [];  % 混合
                case '反应器 (Reactor)'
                    templateList = [varTemplates.Reactor; resTemplates.Reactor];
                    isVariable = [];
                case '换热器 (HeatExchanger)'
                    templateList = [varTemplates.HeatExchanger; resTemplates.HeatExchanger];
                    isVariable = [];
                case '压缩机/泵 (Compressor/Pump)'
                    templateList = [varTemplates.CompressorPump; resTemplates.CompressorPump];
                    isVariable = [];
                case '闪蒸罐 (Flash)'
                    templateList = [varTemplates.Flash; resTemplates.Flash];
                    isVariable = [];
                case '分离器 (Separator)'
                    templateList = varTemplates.Separator;
                case '混合器 (Mixer)'
                    templateList = varTemplates.Mixer;
                case '分流器 (Splitter)'
                    templateList = varTemplates.Splitter;
                case '结果汇总 (Summary)'
                    templateList = resTemplates.Summary;
                    isVariable = false;
                otherwise
                    templateList = {};
                    isVariable = true;
            end
        end

        function valid = validateNodePath(path)
            %% validateNodePath - 验证节点路径格式
            %
            % 输入:
            %   path - 节点路径字符串
            %
            % 返回:
            %   valid - 是否为有效路径格式

            valid = false;

            % 基本检查
            if isempty(path) || ~ischar(path)
                return;
            end

            % 必须以 \Data\ 开头
            if ~startsWith(path, '\Data\')
                return;
            end

            % 检查是否包含常见的路径模式
            validPatterns = {
                '\\Data\\Streams\\';
                '\\Data\\Blocks\\';
                '\\Data\\Results Summary\\';
                '\\Data\\Flowsheeting Options\\';
            };

            for i = 1:length(validPatterns)
                if contains(path, validPatterns{i})
                    valid = true;
                    return;
                end
            end
        end

        function placeholders = extractPlaceholders(path)
            %% extractPlaceholders - 提取路径中的占位符
            %
            % 输入:
            %   path - 节点路径模板
            %
            % 返回:
            %   placeholders - 元胞数组，包含所有占位符名称

            % 使用正则表达式提取 {XXX} 格式的占位符
            tokens = regexp(path, '\{([^}]+)\}', 'tokens');
            placeholders = cellfun(@(x) x{1}, tokens, 'UniformOutput', false);
        end

    end
end
