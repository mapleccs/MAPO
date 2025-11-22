classdef EmissionModule < ModuleBase
    % EmissionModule 环境排放计算模块
    % Environmental Emission Calculation Module
    %
    % 功能:
    %   - 计算工艺过程的环境排放（CO2、NOx、SOx等）
    %   - 能耗评估（电力、蒸汽、冷却水）
    %   - 环境影响评分
    %   - 支持自定义排放因子
    %   - 可扩展的排放指标
    %
    % 支持的排放类型:
    %   - CO2: 二氧化碳排放
    %   - NOx: 氮氧化物排放
    %   - SOx: 硫氧化物排放
    %   - 颗粒物: PM2.5, PM10
    %   - VOCs: 挥发性有机物
    %   - 废水: COD, BOD
    %
    % 使用示例:
    %   % 创建模块实例
    %   emissionModule = EmissionModule();
    %
    %   % 配置模块
    %   config = struct();
    %   config.annualHours = 8000;
    %   config.emissionFactors = struct(...
    %       'steam_CO2', 0.184, ...        % kg CO2/kg steam
    %       'electricity_CO2', 0.785, ...  % kg CO2/kWh
    %       'cooling_CO2', 0.001 ...       % kg CO2/kg water
    %   );
    %   emissionModule.configure(config);
    %
    %   % 初始化
    %   emissionModule.initialize();
    %
    %   % 准备输入数据
    %   inputData = struct();
    %   inputData.steamRate = 1000;        % kg/h
    %   inputData.electricityRate = 500;   % kW
    %   inputData.coolingWaterRate = 5000; % kg/h
    %   inputData.steamCO2Rate = 50;       % kg CO2/h (可选，直接提供)
    %   inputData.coolingCO2Rate = 10;     % kg CO2/h (可选)
    %
    %   % 执行计算
    %   result = emissionModule.execute(inputData);
    %
    %   % 查看结果
    %   fprintf('总CO2排放: %.2f ton/year\n', result.co2Emission);
    %   fprintf('环境影响评分: %.2f\n', result.environmentalScore);


    properties (Access = private)
        annualHours;           % 年运行小时数
        emissionFactors;       % 排放因子数据库
        includeIndirect;       % 是否包含间接排放
        useCustomFactors;      % 是否使用自定义排放因子
    end

    properties (Constant)
        % 默认排放因子（基于文献数据）
        % 单位说明：
        %   蒸汽: kg CO2/kg steam
        %   电力: kg CO2/kWh
        %   冷却水: kg CO2/kg water
        %   天然气: kg CO2/m^3

        DEFAULT_STEAM_CO2_FACTOR = 0.184;      % 蒸汽CO2排放因子
        DEFAULT_ELECTRICITY_CO2_FACTOR = 0.785; % 电力CO2排放因子（燃煤电厂）
        DEFAULT_COOLING_CO2_FACTOR = 0.001;    % 冷却水CO2排放因子
        DEFAULT_NATURAL_GAS_CO2_FACTOR = 2.0;  % 天然气CO2排放因子

        % 环境影响权重
        WEIGHT_CO2 = 1.0;          % CO2权重
        WEIGHT_ENERGY = 0.5;       % 能耗权重
        WEIGHT_WATER = 0.3;        % 水耗权重
    end

    methods
        function obj = EmissionModule()
            % EmissionModule 构造函数
            %
            % 功能:
            %   - 调用父类构造函数
            %   - 设置模块元数据
            %   - 初始化默认排放因子

            % 调用父类构造函数
            obj@ModuleBase('EmissionModule', '1.0.0', ...
                          '环境排放和能耗评估模块');

            % 设置标签
            obj.tags = {'emission', 'environment', 'sustainability', ...
                       'co2', 'energy', 'carbon'};

            % 设置作者和许可证
            obj.author = '开发团队';
            obj.license = 'MIT';

            % 初始化默认值
            obj.annualHours = 8000;
            obj.includeIndirect = true;
            obj.useCustomFactors = false;

            % 初始化默认排放因子
            obj.emissionFactors = obj.getDefaultEmissionFactors();
        end

        % ==================== IModule接口实现 ====================

        function initialize(obj)
            % initialize 初始化模块
            %
            % 功能:
            %   - 从配置中读取参数
            %   - 验证排放因子
            %   - 标记为已初始化

            obj.logInfo('初始化EmissionModule...');

            % 读取年运行小时数
            if obj.hasConfigField('annualHours')
                obj.annualHours = obj.getConfigValue('annualHours');
            end

            % 读取是否包含间接排放
            if obj.hasConfigField('includeIndirect')
                obj.includeIndirect = obj.getConfigValue('includeIndirect');
            end

            % 读取自定义排放因子
            if obj.hasConfigField('emissionFactors')
                customFactors = obj.getConfigValue('emissionFactors');
                obj.emissionFactors = obj.mergeEmissionFactors(customFactors);
                obj.useCustomFactors = true;
                obj.logInfo('使用自定义排放因子');
            end

            % 验证参数
            obj.validateNumericRange(obj.annualHours, 'annualHours', 1000, 8760);

            obj.logInfo(sprintf('配置参数: 年运行=%dh, 间接排放=%d', ...
                       obj.annualHours, obj.includeIndirect));

            % 标记为已初始化
            obj.markInitialized();
        end

        function result = execute(obj, inputData)
            % execute 执行排放计算
            %
            % 输入:
            %   inputData - struct, 包含以下字段:
            %       方式1：直接提供排放速率（优先级高）
            %         steamCO2Rate: 蒸汽CO2排放速率 (kg/h)
            %         coolingCO2Rate: 冷却水CO2排放速率 (kg/h)
            %         electricityCO2Rate: 电力CO2排放速率 (kg/h)
            %
            %       方式2：提供公用工程消耗量（使用排放因子计算）
            %         steamRate: 蒸汽消耗速率 (kg/h)
            %         electricityRate: 电力消耗速率 (kW)
            %         coolingWaterRate: 冷却水消耗速率 (kg/h)
            %         naturalGasRate: 天然气消耗速率 (m^3/h)
            %
            %       可选字段:
            %         processEmissions: 工艺直接排放 (kg CO2/h)
            %         fugitiveEmissions: 无组织排放 (kg CO2/h)
            %
            % 输出:
            %   result - struct, 包含:
            %       co2Emission: 总CO2排放 (ton/year)
            %       breakdown: 排放分解 (各来源的排放)
            %       energyConsumption: 能耗汇总
            %       environmentalScore: 环境影响评分
            %       intensity: 排放强度指标

            % 检查初始化状态
            obj.checkInitialized();

            obj.logInfo('执行排放计算...');

            % 开始计时
            tic_id = obj.startTimer('排放计算');

            try
                % 初始化排放分解
                breakdown = struct();
                breakdown.steam = 0;
                breakdown.electricity = 0;
                breakdown.cooling = 0;
                breakdown.naturalGas = 0;
                breakdown.process = 0;
                breakdown.fugitive = 0;

                % ========== 计算各来源的CO2排放 (kg/h) ==========

                % 蒸汽排放
                if isfield(inputData, 'steamCO2Rate')
                    % 直接使用提供的排放速率
                    breakdown.steam = inputData.steamCO2Rate;
                elseif isfield(inputData, 'steamRate')
                    % 使用排放因子计算
                    breakdown.steam = inputData.steamRate * ...
                                     obj.emissionFactors.steam_CO2;
                end

                % 冷却水排放
                if isfield(inputData, 'coolingCO2Rate')
                    breakdown.cooling = inputData.coolingCO2Rate;
                elseif isfield(inputData, 'coolingWaterRate')
                    breakdown.cooling = inputData.coolingWaterRate * ...
                                       obj.emissionFactors.cooling_CO2;
                end

                % 电力排放
                if isfield(inputData, 'electricityCO2Rate')
                    breakdown.electricity = inputData.electricityCO2Rate;
                elseif isfield(inputData, 'electricityRate')
                    breakdown.electricity = inputData.electricityRate * ...
                                          obj.emissionFactors.electricity_CO2;
                end

                % 天然气排放
                if isfield(inputData, 'naturalGasRate')
                    breakdown.naturalGas = inputData.naturalGasRate * ...
                                         obj.emissionFactors.naturalGas_CO2;
                end

                % 工艺直接排放
                if isfield(inputData, 'processEmissions')
                    breakdown.process = inputData.processEmissions;
                end

                % 无组织排放
                if isfield(inputData, 'fugitiveEmissions')
                    breakdown.fugitive = inputData.fugitiveEmissions;
                end

                % ========== 计算年排放量 ==========
                % 单位：kg/h * h/year / 1000 = ton/year

                totalHourlyEmission = breakdown.steam + breakdown.cooling + ...
                                     breakdown.electricity + breakdown.naturalGas + ...
                                     breakdown.process + breakdown.fugitive;

                co2EmissionTonPerYear = totalHourlyEmission * obj.annualHours / 1000;

                % ========== 能耗汇总 ==========
                energyConsumption = obj.calculateEnergyConsumption(inputData);

                % ========== 环境影响评分 ==========
                environmentalScore = obj.calculateEnvironmentalScore(...
                    co2EmissionTonPerYear, energyConsumption, inputData);

                % ========== 排放强度指标 ==========
                intensity = obj.calculateEmissionIntensity(...
                    co2EmissionTonPerYear, inputData);

                % ========== 年化排放分解 (ton/year) ==========
                breakdownAnnual = struct();
                breakdownAnnual.steam = breakdown.steam * obj.annualHours / 1000;
                breakdownAnnual.electricity = breakdown.electricity * obj.annualHours / 1000;
                breakdownAnnual.cooling = breakdown.cooling * obj.annualHours / 1000;
                breakdownAnnual.naturalGas = breakdown.naturalGas * obj.annualHours / 1000;
                breakdownAnnual.process = breakdown.process * obj.annualHours / 1000;
                breakdownAnnual.fugitive = breakdown.fugitive * obj.annualHours / 1000;

                % 停止计时
                elapsed = obj.stopTimer(tic_id, '排放计算');

                % 创建结果
                result = obj.createResultStruct(...
                    'co2Emission', co2EmissionTonPerYear, ...
                    'breakdown', breakdownAnnual, ...
                    'energyConsumption', energyConsumption, ...
                    'environmentalScore', environmentalScore, ...
                    'intensity', intensity, ...
                    'computationTime', elapsed);

                obj.logInfo(sprintf('排放计算完成: CO2=%.2f ton/year, 评分=%.2f', ...
                           co2EmissionTonPerYear, environmentalScore));

            catch ME
                obj.handleError(ME, '排放计算失败');
            end
        end

        function finalize(obj)
            % finalize 清理模块资源
            %
            % 功能:
            %   - 清理内部状态
            %   - 标记为已清理

            obj.logInfo('清理EmissionModule...');

            % 标记为已清理
            obj.markFinalized();
        end

        function isValid = validate(obj)
            % validate 验证配置
            %
            % 输出:
            %   isValid - logical, 配置是否有效

            isValid = true;

            try
                % 验证年运行小时数
                if obj.hasConfigField('annualHours')
                    obj.validateNumericRange(obj.config.annualHours, ...
                                           'annualHours', 1000, 8760);
                end

                % 验证排放因子
                if obj.hasConfigField('emissionFactors')
                    factors = obj.config.emissionFactors;
                    if ~isstruct(factors)
                        error('EmissionModule:InvalidFactors', ...
                              '排放因子必须是struct类型');
                    end
                end

                obj.logInfo('配置验证通过');
            catch ME
                obj.logError(sprintf('配置验证失败: %s', ME.message));
                isValid = false;
            end
        end

        function schema = getInputSchema(obj)
            % getInputSchema 获取输入数据架构
            %
            % 输出:
            %   schema - struct, 输入架构定义

            schema = struct();
            schema.fields = {
                struct('name', 'steamCO2Rate', 'type', 'double', 'required', false, ...
                       'description', '蒸汽CO2排放速率(kg/h)', 'range', [0, 10000]);
                struct('name', 'coolingCO2Rate', 'type', 'double', 'required', false, ...
                       'description', '冷却水CO2排放速率(kg/h)', 'range', [0, 10000]);
                struct('name', 'electricityCO2Rate', 'type', 'double', 'required', false, ...
                       'description', '电力CO2排放速率(kg/h)', 'range', [0, 10000]);
                struct('name', 'steamRate', 'type', 'double', 'required', false, ...
                       'description', '蒸汽消耗速率(kg/h)', 'range', [0, 100000]);
                struct('name', 'electricityRate', 'type', 'double', 'required', false, ...
                       'description', '电力消耗速率(kW)', 'range', [0, 100000]);
                struct('name', 'coolingWaterRate', 'type', 'double', 'required', false, ...
                       'description', '冷却水消耗速率(kg/h)', 'range', [0, 1000000]);
            };
        end

        function schema = getOutputSchema(obj)
            % getOutputSchema 获取输出数据架构
            %
            % 输出:
            %   schema - struct, 输出架构定义

            schema = struct();
            schema.fields = {
                struct('name', 'co2Emission', 'type', 'double', 'unit', 'ton/year', ...
                       'description', '年CO2排放量');
                struct('name', 'breakdown', 'type', 'struct', ...
                       'description', 'CO2排放分解（各来源）');
                struct('name', 'energyConsumption', 'type', 'struct', ...
                       'description', '能耗汇总');
                struct('name', 'environmentalScore', 'type', 'double', ...
                       'description', '环境影响综合评分');
                struct('name', 'intensity', 'type', 'struct', ...
                       'description', '排放强度指标');
            };
        end

        % ==================== 私有方法 ====================

        function factors = getDefaultEmissionFactors(obj)
            % getDefaultEmissionFactors 获取默认排放因子
            %
            % 输出:
            %   factors - struct, 排放因子数据库

            factors = struct();
            factors.steam_CO2 = obj.DEFAULT_STEAM_CO2_FACTOR;
            factors.electricity_CO2 = obj.DEFAULT_ELECTRICITY_CO2_FACTOR;
            factors.cooling_CO2 = obj.DEFAULT_COOLING_CO2_FACTOR;
            factors.naturalGas_CO2 = obj.DEFAULT_NATURAL_GAS_CO2_FACTOR;
        end

        function merged = mergeEmissionFactors(obj, customFactors)
            % mergeEmissionFactors 合并自定义排放因子
            %
            % 输入:
            %   customFactors - struct, 自定义排放因子
            %
            % 输出:
            %   merged - struct, 合并后的排放因子

            % 从默认值开始
            merged = obj.getDefaultEmissionFactors();

            % 覆盖自定义值
            fieldNames = fieldnames(customFactors);
            for i = 1:length(fieldNames)
                fieldName = fieldNames{i};
                merged.(fieldName) = customFactors.(fieldName);
                obj.logDebug(sprintf('使用自定义排放因子: %s = %.6f', ...
                           fieldName, customFactors.(fieldName)));
            end
        end

        function energy = calculateEnergyConsumption(obj, inputData)
            % calculateEnergyConsumption 计算能耗汇总
            %
            % 输入:
            %   inputData - struct, 输入数据
            %
            % 输出:
            %   energy - struct, 能耗汇总

            energy = struct();

            % 蒸汽能耗 (GJ/year)
            if isfield(inputData, 'steamRate')
                % 假设蒸汽焓值约为 2.7 MJ/kg
                energy.steam = inputData.steamRate * 2.7 * obj.annualHours / 1000;
            else
                energy.steam = 0;
            end

            % 电力能耗 (GJ/year)
            if isfield(inputData, 'electricityRate')
                % 1 kWh = 3.6 MJ
                energy.electricity = inputData.electricityRate * 3.6 * obj.annualHours / 1000;
            else
                energy.electricity = 0;
            end

            % 冷却水能耗 (GJ/year) - 通常很小
            if isfield(inputData, 'coolingWaterRate')
                % 假设温差10K，比热4.18 kJ/(kg·K)
                energy.cooling = inputData.coolingWaterRate * 4.18 * 10 * obj.annualHours / 1e6;
            else
                energy.cooling = 0;
            end

            % 总能耗
            energy.total = energy.steam + energy.electricity + energy.cooling;
        end

        function score = calculateEnvironmentalScore(obj, co2Emission, energy, inputData)
            % calculateEnvironmentalScore 计算环境影响综合评分
            %
            % 输入:
            %   co2Emission - double, CO2排放 (ton/year)
            %   energy - struct, 能耗汇总
            %   inputData - struct, 输入数据
            %
            % 输出:
            %   score - double, 环境影响评分 (0-100, 越高越好)

            % 基准值（用于归一化）
            baseCO2 = 1000;      % 1000 ton/year
            baseEnergy = 10000;  % 10000 GJ/year

            % 归一化得分（越小越好，所以取反）
            co2Score = max(0, 100 * (1 - co2Emission / baseCO2));
            energyScore = max(0, 100 * (1 - energy.total / baseEnergy));

            % 水耗评分
            waterScore = 100;  % 默认满分
            if isfield(inputData, 'coolingWaterRate')
                baseWater = 100000;  % kg/h
                waterScore = max(0, 100 * (1 - inputData.coolingWaterRate / baseWater));
            end

            % 加权综合评分
            score = obj.WEIGHT_CO2 * co2Score + ...
                   obj.WEIGHT_ENERGY * energyScore + ...
                   obj.WEIGHT_WATER * waterScore;

            % 归一化到0-100
            totalWeight = obj.WEIGHT_CO2 + obj.WEIGHT_ENERGY + obj.WEIGHT_WATER;
            score = score / totalWeight;
        end

        function intensity = calculateEmissionIntensity(obj, co2Emission, inputData)
            % calculateEmissionIntensity 计算排放强度指标
            %
            % 输入:
            %   co2Emission - double, CO2排放 (ton/year)
            %   inputData - struct, 输入数据
            %
            % 输出:
            %   intensity - struct, 排放强度指标

            intensity = struct();

            % 单位产品CO2排放（如果有产量数据）
            if isfield(inputData, 'productionRate')
                % kg product/h
                annualProduction = inputData.productionRate * obj.annualHours / 1000;  % ton/year
                intensity.perProduct = co2Emission / annualProduction;  % kg CO2/ton product
            else
                intensity.perProduct = NaN;
            end

            % 单位能耗CO2排放
            if isfield(inputData, 'steamRate') || isfield(inputData, 'electricityRate')
                energy = obj.calculateEnergyConsumption(inputData);
                if energy.total > 0
                    intensity.perEnergy = co2Emission * 1000 / energy.total;  % kg CO2/GJ
                else
                    intensity.perEnergy = NaN;
                end
            else
                intensity.perEnergy = NaN;
            end

            % 记录计算的强度指标
            obj.logDebug(sprintf('排放强度: %.2f kg CO2/ton product, %.2f kg CO2/GJ', ...
                       intensity.perProduct, intensity.perEnergy));
        end
    end
end
