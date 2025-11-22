classdef ThermodynamicModule < ModuleBase
    % ThermodynamicModule 热力学性质计算模块
    % Custom Module Example: Thermodynamic Property Calculations
    %
    % 本模块展示如何基于 CustomModuleTemplate 创建自定义模块
    % 实现了常见的热力学性质计算（理想气体状态方程）
    %
    % 功能:
    %   - 理想气体状态方程 PV=nRT
    %   - 热力学性质计算（焓、熵、吉布斯自由能）
    %   - 相平衡判断
    %   - 热力学效率计算
    %
    % 配置参数:
    %   gasConstant - double, 气体常数 (默认: 8.314 J/(mol*K))
    %   referenceTemperature - double, 参考温度 (默认: 298.15 K)
    %   referencePressure - double, 参考压力 (默认: 101325 Pa)
    %
    % 输入数据:
    %   temperature - double, 温度 (K)
    %   pressure - double, 压力 (Pa)
    %   moles - double, 摩尔数 (mol, 可选)
    %   volume - double, 体积 (m³, 可选，与 moles 二选一)
    %   molarHeatCapacity - double, 摩尔热容 (J/(mol*K), 可选)
    %
    % 输出数据:
    %   volume - double, 体积 (m³)
    %   enthalpy - double, 焓 (J/mol)
    %   entropy - double, 熵 (J/(mol*K))
    %   gibbsFreeEnergy - double, 吉布斯自由能 (J/mol)
    %   compressibilityFactor - double, 压缩因子


    properties (Access = private)
        gasConstant;            % double, 气体常数 (J/(mol*K))
        referenceTemperature;   % double, 参考温度 (K)
        referencePressure;      % double, 参考压力 (Pa)
    end

    properties (Constant)
        DEFAULT_R = 8.314;              % J/(mol*K), 通用气体常数
        DEFAULT_T_REF = 298.15;         % K, 标准温度
        DEFAULT_P_REF = 101325;         % Pa, 标准大气压
        DEFAULT_CP = 29.1;              % J/(mol*K), 理想气体摩尔热容（空气）
    end

    methods
        function obj = ThermodynamicModule()
            % ThermodynamicModule 构造函数

            % 调用父类构造函数
            obj@ModuleBase(...
                'thermodynamic', ...
                '1.0.0', ...
                '热力学性质计算模块（理想气体）');

            % 设置标签
            obj.tags = {'thermodynamics', 'properties', 'ideal-gas', 'custom'};

            % 设置作者信息
            obj.author = 'Development Team';
            obj.license = 'MIT';

            % 初始化默认值
            obj.gasConstant = obj.DEFAULT_R;
            obj.referenceTemperature = obj.DEFAULT_T_REF;
            obj.referencePressure = obj.DEFAULT_P_REF;
        end
    end

    methods
        function initialize(obj)
            % initialize 初始化模块

            obj.logInfo('初始化 ThermodynamicModule...');

            try
                % 读取配置参数（使用默认值）
                obj.gasConstant = obj.getConfigValue('gasConstant', obj.DEFAULT_R);
                obj.referenceTemperature = obj.getConfigValue('referenceTemperature', obj.DEFAULT_T_REF);
                obj.referencePressure = obj.getConfigValue('referencePressure', obj.DEFAULT_P_REF);

                % 验证参数范围
                obj.validateNumericRange(obj.gasConstant, 'gasConstant', 0, 100);
                obj.validateNumericRange(obj.referenceTemperature, 'referenceTemperature', 0, 1000);
                obj.validateNumericRange(obj.referencePressure, 'referencePressure', 0, 1e8);

                % 标记为已初始化
                obj.markInitialized();

                obj.logInfo(sprintf('配置: R=%.3f J/(mol*K), T_ref=%.2f K, P_ref=%.0f Pa', ...
                    obj.gasConstant, obj.referenceTemperature, obj.referencePressure));

            catch ME
                obj.handleError(ME, '初始化失败');
            end
        end

        function result = execute(obj, inputData)
            % execute 计算热力学性质

            obj.checkInitialized();

            try
                % 验证必需字段
                obj.validateInput(inputData, {'temperature', 'pressure'});

                obj.logInfo('执行热力学性质计算...');

                % 提取输入参数
                T = inputData.temperature;      % K
                P = inputData.pressure;          % Pa

                % 验证温度和压力范围
                if T <= 0
                    error('ThermodynamicModule:InvalidTemperature', '温度必须大于0 K');
                end
                if P <= 0
                    error('ThermodynamicModule:InvalidPressure', '压力必须大于0 Pa');
                end

                % 获取可选参数
                if isfield(inputData, 'moles')
                    n = inputData.moles;
                    V = obj.calculateVolume(n, T, P);
                elseif isfield(inputData, 'volume')
                    V = inputData.volume;
                    n = obj.calculateMoles(V, T, P);
                else
                    % 默认假设1 mol
                    n = 1.0;
                    V = obj.calculateVolume(n, T, P);
                    obj.logWarning('未提供 moles 或 volume，假设 n=1 mol');
                end

                % 获取摩尔热容
                Cp = obj.getConfigValue('molarHeatCapacity', obj.DEFAULT_CP);
                if isfield(inputData, 'molarHeatCapacity')
                    Cp = inputData.molarHeatCapacity;
                end

                % 计算热力学性质
                H = obj.calculateEnthalpy(T, Cp);
                S = obj.calculateEntropy(T, P, Cp);
                G = obj.calculateGibbsFreeEnergy(H, T, S);
                Z = obj.calculateCompressibilityFactor(P, V, n, T);

                % 判断相态
                phaseState = obj.determinePhase(T, P);

                % 创建结果
                result = obj.createResultStruct(...
                    'temperature', T, ...
                    'pressure', P, ...
                    'volume', V, ...
                    'moles', n, ...
                    'enthalpy', H, ...
                    'entropy', S, ...
                    'gibbsFreeEnergy', G, ...
                    'compressibilityFactor', Z, ...
                    'phaseState', phaseState, ...
                    'gasConstant', obj.gasConstant);

                obj.logInfo(sprintf('计算完成: T=%.2f K, P=%.0f Pa, V=%.6f m³, Z=%.4f', ...
                    T, P, V, Z));

            catch ME
                obj.handleError(ME, '执行失败');
            end
        end

        function finalize(obj)
            % finalize 清理模块

            obj.logInfo('清理 ThermodynamicModule...');

            try
                % 重置参数
                obj.gasConstant = obj.DEFAULT_R;
                obj.referenceTemperature = obj.DEFAULT_T_REF;
                obj.referencePressure = obj.DEFAULT_P_REF;

                % 标记为已清理
                obj.markFinalized();

                obj.logInfo('ThermodynamicModule 清理完成');

            catch ME
                obj.handleError(ME, '清理失败');
            end
        end
    end

    methods
        function isValid = validate(obj)
            % validate 验证配置

            isValid = true;

            % 检查气体常数
            if obj.hasConfigField('gasConstant')
                R = obj.getConfigValue('gasConstant');
                if R <= 0 || R > 100
                    obj.logWarning('气体常数超出合理范围');
                    isValid = false;
                end
            end

            % 检查参考温度
            if obj.hasConfigField('referenceTemperature')
                T = obj.getConfigValue('referenceTemperature');
                if T <= 0 || T > 1000
                    obj.logWarning('参考温度超出合理范围');
                    isValid = false;
                end
            end

            if isValid
                obj.logDebug('配置验证通过');
            end
        end

        function schema = getInputSchema(obj)
            % getInputSchema 输入架构

            schema = struct();
            schema.fields = {
                struct('name', 'temperature', 'type', 'double', 'required', true, ...
                       'description', '温度 (K)', 'range', [0, Inf]);
                struct('name', 'pressure', 'type', 'double', 'required', true, ...
                       'description', '压力 (Pa)', 'range', [0, Inf]);
                struct('name', 'moles', 'type', 'double', 'required', false, ...
                       'description', '摩尔数 (mol)', 'range', [0, Inf]);
                struct('name', 'volume', 'type', 'double', 'required', false, ...
                       'description', '体积 (m³)', 'range', [0, Inf]);
                struct('name', 'molarHeatCapacity', 'type', 'double', 'required', false, ...
                       'description', '摩尔热容 (J/(mol*K))', 'range', [0, Inf]);
            };
            schema.description = '热力学性质计算输入数据';
            schema.note = 'moles 和 volume 至少提供一个，如都不提供则默认 n=1 mol';
        end

        function schema = getOutputSchema(obj)
            % getOutputSchema 输出架构

            schema = struct();
            schema.fields = {
                struct('name', 'temperature', 'type', 'double', 'description', '温度 (K)');
                struct('name', 'pressure', 'type', 'double', 'description', '压力 (Pa)');
                struct('name', 'volume', 'type', 'double', 'description', '体积 (m³)');
                struct('name', 'moles', 'type', 'double', 'description', '摩尔数 (mol)');
                struct('name', 'enthalpy', 'type', 'double', 'description', '摩尔焓 (J/mol)');
                struct('name', 'entropy', 'type', 'double', 'description', '摩尔熵 (J/(mol*K))');
                struct('name', 'gibbsFreeEnergy', 'type', 'double', 'description', '摩尔吉布斯自由能 (J/mol)');
                struct('name', 'compressibilityFactor', 'type', 'double', 'description', '压缩因子');
                struct('name', 'phaseState', 'type', 'string', 'description', '相态 (gas/liquid/supercritical)');
            };
            schema.description = '热力学性质计算输出数据';
        end
    end

    % 私有计算方法
    methods (Access = private)
        function V = calculateVolume(obj, n, T, P)
            % calculateVolume 使用理想气体状态方程计算体积
            % PV = nRT  =>  V = nRT/P
            V = n * obj.gasConstant * T / P;
        end

        function n = calculateMoles(obj, V, T, P)
            % calculateMoles 使用理想气体状态方程计算摩尔数
            % PV = nRT  =>  n = PV/(RT)
            n = P * V / (obj.gasConstant * T);
        end

        function H = calculateEnthalpy(obj, T, Cp)
            % calculateEnthalpy 计算摩尔焓（相对于参考温度）
            % ΔH = Cp * (T - T_ref)
            H = Cp * (T - obj.referenceTemperature);
        end

        function S = calculateEntropy(obj, T, P, Cp)
            % calculateEntropy 计算摩尔熵（相对于参考状态）
            % ΔS = Cp*ln(T/T_ref) - R*ln(P/P_ref)
            S = Cp * log(T / obj.referenceTemperature) - ...
                obj.gasConstant * log(P / obj.referencePressure);
        end

        function G = calculateGibbsFreeEnergy(obj, H, T, S)
            % calculateGibbsFreeEnergy 计算吉布斯自由能
            % G = H - T*S
            G = H - T * S;
        end

        function Z = calculateCompressibilityFactor(obj, P, V, n, T)
            % calculateCompressibilityFactor 计算压缩因子
            % Z = PV/(nRT)
            % 对于理想气体 Z = 1
            Z = P * V / (n * obj.gasConstant * T);
        end

        function phase = determinePhase(obj, T, P)
            % determinePhase 简单的相态判断（基于理想气体假设）
            % 实际应用中应使用真实的相图数据

            % 简化假设：常压下，T < 273.15 K 为固态/液态区域
            if P < 10 * obj.referencePressure && T > 373.15
                phase = 'gas';
            elseif T < 273.15
                phase = 'liquid';
            elseif P > 100 * obj.referencePressure
                phase = 'supercritical';
            else
                phase = 'gas';
            end
        end
    end

    % 公共辅助方法
    methods (Access = public)
        function printProperties(obj, result)
            % printProperties 打印热力学性质

            fprintf('\n========== 热力学性质 ==========\n');
            fprintf('温度:         %.2f K (%.2f °C)\n', result.temperature, result.temperature - 273.15);
            fprintf('压力:         %.2f Pa (%.4f bar)\n', result.pressure, result.pressure / 1e5);
            fprintf('体积:         %.6f m³\n', result.volume);
            fprintf('摩尔数:       %.4f mol\n', result.moles);
            fprintf('摩尔焓:       %.2f J/mol\n', result.enthalpy);
            fprintf('摩尔熵:       %.4f J/(mol*K)\n', result.entropy);
            fprintf('吉布斯自由能: %.2f J/mol\n', result.gibbsFreeEnergy);
            fprintf('压缩因子:     %.6f\n', result.compressibilityFactor);
            fprintf('相态:         %s\n', result.phaseState);
            fprintf('================================\n\n');
        end
    end
end
