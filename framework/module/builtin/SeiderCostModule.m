classdef SeiderCostModule < ModuleBase
    % SeiderCostModule Seider设备成本估算模块
    % Equipment Cost Estimation Module Based on Seider Method
    %
    % 功能:
    %   - 基于Seider方法的设备成本估算
    %   - 支持精馏塔、换热器等化工设备
    %   - CAPEX（固定资产投资）计算
    %   - OPEX（运营成本）计算
    %   - CO2排放计算
    %   - CEPCI成本指数自动校正
    %
    % 参考文献:
    %   Seider, W. D., et al. (2017). Product and Process Design Principles:
    %   Synthesis, Analysis and Evaluation. John Wiley & Sons.
    %   Chapter 16.5: Equipment Cost Estimation
    %
    % 使用示例:
    %   % 创建模块实例
    %   costModule = SeiderCostModule();
    %
    %   % 配置模块
    %   config = struct();
    %   config.langFactor = 4.74;
    %   config.annualHours = 8000;
    %   config.capexAnnualizationFactor = 3;
    %   config.baseCEPCI = 567;   % 2006年基准
    %   config.currentCEPCI = 607.5;  % 2019年
    %   costModule.configure(config);
    %
    %   % 初始化模块
    %   costModule.initialize();
    %
    %   % 准备输入数据
    %   inputData = struct();
    %   inputData.equipmentType = 'column';
    %   inputData.temperature = 373;  % K
    %   inputData.pressure = 101325;  % Pa
    %   inputData.diameter = 1.5;     % m
    %   inputData.numStages = 20;
    %   inputData.materialColumn = 'SS304';
    %   inputData.materialTray = 'SS304';
    %   inputData.coolingCost = 100;  % USD/h
    %   inputData.steamCost = 200;    % USD/h
    %   inputData.steamCO2Rate = 50;  % kg/h
    %   inputData.coolingCO2Rate = 10; % kg/h
    %
    %   % 执行成本计算
    %   result = costModule.execute(inputData);
    %
    %   % 查看结果
    %   fprintf('CAPEX: %.2f USD/year\n', result.capex);
    %   fprintf('OPEX: %.2f USD/year\n', result.opex);
    %   fprintf('Total Cost: %.2f USD/year\n', result.totalCost);
    %   fprintf('CO2 Emission: %.2f ton/year\n', result.co2Emission);


    properties (Constant)
        % 材料类型映射
        MATERIAL_CARBON_STEEL = 0;
        MATERIAL_SS304 = 1;
        MATERIAL_SS316 = 2;
    end

    properties (Access = private)
        langFactor;                  % Lang系数
        annualHours;                 % 年运行小时数
        capexAnnualizationFactor;   % CAPEX年化系数
        baseCEPCI;                   % 基准CEPCI指数
        currentCEPCI;                % 当前CEPCI指数
    end

    methods
        function obj = SeiderCostModule()
            % SeiderCostModule 构造函数
            %
            % 功能:
            %   - 调用父类构造函数
            %   - 设置模块元数据

            % 调用父类构造函数
            obj@ModuleBase('SeiderCostModule', '1.0.0', ...
                          '基于Seider方法的设备成本估算模块');

            % 设置标签
            obj.tags = {'cost', 'economics', 'estimation', 'seider', 'capex', 'opex'};

            % 设置作者和许可证
            obj.author = '开发团队';
            obj.license = 'MIT';

            % 初始化默认值
            obj.langFactor = 4.74;
            obj.annualHours = 8000;
            obj.capexAnnualizationFactor = 3;
            obj.baseCEPCI = 567;      % 2006年基准
            obj.currentCEPCI = 607.5;  % 2019年估计值
        end

        % ==================== IModule接口实现 ====================

        function initialize(obj)
            % initialize 初始化模块
            %
            % 功能:
            %   - 从配置中读取参数
            %   - 验证参数有效性
            %   - 标记为已初始化

            obj.logInfo('初始化SeiderCostModule...');

            % 读取配置参数
            if obj.hasConfigField('langFactor')
                obj.langFactor = obj.getConfigValue('langFactor');
            end

            if obj.hasConfigField('annualHours')
                obj.annualHours = obj.getConfigValue('annualHours');
            end

            if obj.hasConfigField('capexAnnualizationFactor')
                obj.capexAnnualizationFactor = obj.getConfigValue('capexAnnualizationFactor');
            end

            if obj.hasConfigField('baseCEPCI')
                obj.baseCEPCI = obj.getConfigValue('baseCEPCI');
            end

            if obj.hasConfigField('currentCEPCI')
                obj.currentCEPCI = obj.getConfigValue('currentCEPCI');
            end

            % 验证参数
            obj.validateNumericRange(obj.langFactor, 'langFactor', 1, 10);
            obj.validateNumericRange(obj.annualHours, 'annualHours', 1000, 8760);
            obj.validateNumericRange(obj.capexAnnualizationFactor, 'capexAnnualizationFactor', 1, 10);

            obj.logInfo(sprintf('配置参数: Lang=%.2f, 年运行=%dh, 年化系数=%d', ...
                       obj.langFactor, obj.annualHours, obj.capexAnnualizationFactor));

            % 标记为已初始化
            obj.markInitialized();
        end

        function result = execute(obj, inputData)
            % execute 执行成本计算
            %
            % 输入:
            %   inputData - struct, 包含以下字段:
            %       equipmentType: 设备类型 ('column', 'heatExchanger', etc.)
            %       temperature: 操作温度 (K)
            %       pressure: 操作压力 (Pa)
            %       diameter: 直径 (m)
            %       numStages: 理论板数（塔设备）
            %       materialColumn: 塔体材料 ('CarbonSteel', 'SS304', 'SS316')
            %       materialTray: 塔板材料
            %       coolingCost: 冷却水成本 (USD/h)
            %       steamCost: 蒸汽成本 (USD/h)
            %       steamCO2Rate: 蒸汽CO2排放速率 (kg/h)
            %       coolingCO2Rate: 冷却水CO2排放速率 (kg/h)
            %
            % 输出:
            %   result - struct, 包含:
            %       capex: 年化固定资产成本 (USD/year)
            %       opex: 年运营成本 (USD/year)
            %       totalCost: 总年成本 (USD/year)
            %       co2Emission: 年CO2排放量 (ton/year)
            %       breakdown: 成本分解详情

            % 检查初始化状态
            obj.checkInitialized();

            % 验证输入
            requiredFields = {'equipmentType', 'temperature', 'pressure', 'diameter'};
            obj.validateInput(inputData, requiredFields);

            obj.logInfo(sprintf('计算设备成本: %s', inputData.equipmentType));

            % 开始计时
            tic_id = obj.startTimer('成本计算');

            try
                % 根据设备类型计算成本
                switch lower(inputData.equipmentType)
                    case 'column'
                        result = obj.calculateColumnCost(inputData);
                    case 'heatexchanger'
                        result = obj.calculateHeatExchangerCost(inputData);
                    otherwise
                        error('SeiderCostModule:UnsupportedType', ...
                              '不支持的设备类型: %s', inputData.equipmentType);
                end

                % 停止计时
                elapsed = obj.stopTimer(tic_id, '成本计算');
                result.computationTime = elapsed;

                obj.logInfo(sprintf('成本计算完成: CAPEX=%.2f, OPEX=%.2f', ...
                           result.capex, result.opex));

            catch ME
                obj.handleError(ME, '成本计算失败');
            end
        end

        function finalize(obj)
            % finalize 清理模块资源
            %
            % 功能:
            %   - 清理内部状态
            %   - 标记为已清理

            obj.logInfo('清理SeiderCostModule...');

            % 标记为已清理
            obj.markFinalized();
        end

        function isValid = validate(obj)
            % validate 验证配置
            %
            % 输出:
            %   isValid - logical, 配置是否有效

            isValid = true;

            % 验证必需参数
            try
                if obj.hasConfigField('langFactor')
                    obj.validateNumericRange(obj.config.langFactor, 'langFactor', 1, 10);
                end

                if obj.hasConfigField('annualHours')
                    obj.validateNumericRange(obj.config.annualHours, 'annualHours', 1000, 8760);
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
                struct('name', 'equipmentType', 'type', 'string', 'required', true, ...
                       'description', '设备类型', 'choices', {'column', 'heatExchanger'});
                struct('name', 'temperature', 'type', 'double', 'required', true, ...
                       'description', '操作温度(K)', 'range', [200, 800]);
                struct('name', 'pressure', 'type', 'double', 'required', true, ...
                       'description', '操作压力(Pa)', 'range', [1e4, 1e7]);
                struct('name', 'diameter', 'type', 'double', 'required', true, ...
                       'description', '设备直径(m)', 'range', [0.1, 10]);
                struct('name', 'numStages', 'type', 'double', 'required', false, ...
                       'description', '理论板数（塔设备）', 'range', [5, 100]);
                struct('name', 'materialColumn', 'type', 'string', 'required', false, ...
                       'description', '设备材料', 'choices', {'CarbonSteel', 'SS304', 'SS316'});
            };
        end

        function schema = getOutputSchema(obj)
            % getOutputSchema 获取输出数据架构
            %
            % 输出:
            %   schema - struct, 输出架构定义

            schema = struct();
            schema.fields = {
                struct('name', 'capex', 'type', 'double', 'unit', 'USD/year', ...
                       'description', '年化固定资产成本');
                struct('name', 'opex', 'type', 'double', 'unit', 'USD/year', ...
                       'description', '年运营成本');
                struct('name', 'totalCost', 'type', 'double', 'unit', 'USD/year', ...
                       'description', '总年成本');
                struct('name', 'co2Emission', 'type', 'double', 'unit', 'ton/year', ...
                       'description', '年CO2排放量');
                struct('name', 'breakdown', 'type', 'struct', ...
                       'description', '成本分解详情');
            };
        end

        % ==================== 私有方法：精馏塔成本计算 ====================

        function result = calculateColumnCost(obj, inputData)
            % calculateColumnCost 计算精馏塔成本
            %
            % 输入:
            %   inputData - struct, 输入数据
            %
            % 输出:
            %   result - struct, 计算结果

            % 验证塔设备必需参数
            if ~isfield(inputData, 'numStages')
                error('SeiderCostModule:MissingParameter', '塔设备需要numStages参数');
            end

            % 获取参数
            temperature = inputData.temperature;
            pressure = inputData.pressure;
            diameter = inputData.diameter;
            numStages = inputData.numStages;

            % 材料类型
            materialColumn = obj.getMaterialType(inputData, 'materialColumn', 'SS304');
            materialTray = obj.getMaterialType(inputData, 'materialTray', 'SS304');

            % 计算设备成本
            equipmentCost = obj.calculateColumnEquipmentCost(...
                materialColumn, temperature, pressure, diameter, numStages, materialTray);

            % 计算CAPEX（应用Lang系数并年化）
            capex = equipmentCost * obj.langFactor / obj.capexAnnualizationFactor;

            % 计算OPEX
            opex = 0;
            if isfield(inputData, 'coolingCost') && isfield(inputData, 'steamCost')
                coolingCost = inputData.coolingCost;
                steamCost = inputData.steamCost;
                opex = (coolingCost + steamCost) * obj.annualHours;
            end

            % 计算CO2排放
            co2Emission = 0;
            if isfield(inputData, 'steamCO2Rate') && isfield(inputData, 'coolingCO2Rate')
                steamCO2 = inputData.steamCO2Rate;
                coolingCO2 = inputData.coolingCO2Rate;
                % kg/h * h/year / 1000 = ton/year
                co2Emission = (steamCO2 + coolingCO2) * obj.annualHours / 1000;
            end

            % 创建结果
            result = obj.createResultStruct(...
                'capex', capex, ...
                'opex', opex, ...
                'totalCost', capex + opex, ...
                'co2Emission', co2Emission, ...
                'breakdown', struct(...
                    'equipmentCost', equipmentCost, ...
                    'langFactor', obj.langFactor, ...
                    'annualizationFactor', obj.capexAnnualizationFactor ...
                ));
        end

        function equipmentCost = calculateColumnEquipmentCost(obj, ...
                materialTypeColumn, temperature, pressure, diameter, numStages, materialTypeTray)
            % calculateColumnEquipmentCost 计算精馏塔设备成本
            % 基于Seider方法
            %
            % 参考: Seider et al., Product and Process Design Principles

            % ========== 单位转换 ==========
            % 温度: K -> F
            temperatureF = temperature * 9/5 - 459.67;
            designTemperatureF = temperatureF + 50;

            % 压力: Pa -> PSIG
            pressurePSI = pressure * 0.145038 / 1000;
            pressurePSIG = pressurePSI - 14.696;

            % 尺寸: m -> ft
            diameterFt = diameter * 3.28084;
            columnHeightFt = (2 * numStages + 30) * 3.28084;

            % ========== 设计压力计算 ==========
            if pressurePSIG > 0 && pressurePSIG < 5
                designPressure = 10;
            elseif pressurePSIG >= 5 && pressurePSIG < 1000
                designPressure = exp(0.60608 + 0.91615 * log(pressurePSIG) + ...
                                     0.0015655 * (log(pressurePSIG))^2);
            else
                designPressure = pressurePSIG * 1.1;
            end

            % ========== 材料许用应力 ==========
            if designTemperatureF < 650
                allowableStress = 15000;
            elseif designTemperatureF < 750
                allowableStress = 15000;
            elseif designTemperatureF < 800
                allowableStress = 14750;
            elseif designTemperatureF < 850
                allowableStress = 14200;
            else
                allowableStress = 13100;
            end

            % ========== 材料属性 ==========
            [materialDensity, materialFactor] = obj.getColumnMaterialProperties(materialTypeColumn);

            % ========== 壁厚计算 ==========
            weldEfficiency = 1.0;

            % 压力壁厚
            thicknessPressure = (designPressure * diameterFt * 12) / ...
                                (2 * allowableStress * weldEfficiency - 1.2 * designPressure);

            % 风载壁厚
            thicknessWind = 0.22 * (diameterFt + 18) * (columnHeightFt * 12)^2 / ...
                            (allowableStress * diameterFt^2);

            % 平均壁厚
            thicknessMean = (thicknessPressure + thicknessWind) / 2;
            thicknessShell = thicknessMean + 1/8;  % 加入腐蚀余量

            % 最小壁厚要求
            minThickness = obj.getMinimumThickness(diameterFt);
            thicknessShell = max(thicknessShell, minThickness);

            % ========== 塔体重量和成本 ==========
            weight = pi * (diameterFt + thicknessShell/12) * ...
                     (columnHeightFt + 0.8 * diameterFt) * ...
                     (thicknessShell/12) * materialDensity;

            % 塔体成本 (2018年美元)
            shellCost = exp(10.5449 - 0.4672 * log(weight) + ...
                           0.05482 * (log(weight))^2);

            % 塔板平台成本
            platformCost = 341 * (diameterFt^0.63316) * (columnHeightFt^0.80161);

            % 总塔体成本
            totalShellCost = materialFactor * shellCost + platformCost;

            % ========== 塔板成本 ==========
            totalTrayCost = obj.calculateTrayCost(diameter, numStages, materialTypeTray);

            % ========== 总成本（CEPCI校正） ==========
            costIndexRatio = obj.currentCEPCI / obj.baseCEPCI;
            equipmentCost = (totalShellCost + totalTrayCost) * costIndexRatio;
        end

        function trayCost = calculateTrayCost(obj, diameter, numStages, materialTypeTray)
            % calculateTrayCost 计算塔板成本
            %
            % 输入:
            %   diameter - 塔直径 (m)
            %   numStages - 理论板数
            %   materialTypeTray - 塔板材料类型

            diameterFt = diameter * 3.28084;

            % 单板基础成本
            baseTrayCost = 468 * exp(0.1739 * diameterFt);

            % 塔板数量因子
            if numStages < 20
                numStagesFactor = 1.0;
            else
                numStagesFactor = 2.25 / (1.0414^numStages);
            end

            % 塔板类型因子 (默认筛板)
            trayTypeFactor = 1.0;

            % 塔板材料因子
            trayMaterialFactor = obj.getTrayMaterialFactor(materialTypeTray, diameterFt);

            % 总塔板成本
            trayCost = numStages * numStagesFactor * trayTypeFactor * ...
                       trayMaterialFactor * baseTrayCost;
        end

        function result = calculateHeatExchangerCost(obj, inputData)
            % calculateHeatExchangerCost 计算换热器成本
            % （预留接口，可以后续实现）

            obj.logWarning('换热器成本计算功能尚未实现');

            result = obj.createResultStruct(...
                'capex', 0, ...
                'opex', 0, ...
                'totalCost', 0, ...
                'co2Emission', 0, ...
                'breakdown', struct());
        end

        % ==================== 辅助方法 ====================

        function materialType = getMaterialType(obj, inputData, fieldName, defaultMaterial)
            % getMaterialType 获取材料类型代码
            %
            % 输入:
            %   inputData - 输入数据
            %   fieldName - 字段名
            %   defaultMaterial - 默认材料名称
            %
            % 输出:
            %   materialType - 材料类型代码

            if isfield(inputData, fieldName)
                materialName = inputData.(fieldName);
            else
                materialName = defaultMaterial;
            end

            switch upper(materialName)
                case 'CARBONSTEEL'
                    materialType = obj.MATERIAL_CARBON_STEEL;
                case 'SS304'
                    materialType = obj.MATERIAL_SS304;
                case 'SS316'
                    materialType = obj.MATERIAL_SS316;
                otherwise
                    obj.logWarning(sprintf('未知材料类型 "%s"，使用SS304', materialName));
                    materialType = obj.MATERIAL_SS304;
            end
        end

        function [density, factor] = getColumnMaterialProperties(obj, materialType)
            % getColumnMaterialProperties 获取塔体材料属性
            %
            % 输入:
            %   materialType - 材料类型代码
            %
            % 输出:
            %   density - 材料密度 (lb/ft^3)
            %   factor - 材料成本因子

            switch materialType
                case obj.MATERIAL_CARBON_STEEL
                    density = 690;
                    factor = 1.0;
                case obj.MATERIAL_SS304
                    density = 493.181;
                    factor = 1.7;
                case obj.MATERIAL_SS316
                    density = 499.424;
                    factor = 2.1;
                otherwise
                    density = 493.181;
                    factor = 1.7;
            end
        end

        function factor = getTrayMaterialFactor(obj, materialType, diameterFt)
            % getTrayMaterialFactor 获取塔板材料因子
            %
            % 输入:
            %   materialType - 材料类型代码
            %   diameterFt - 塔直径 (ft)
            %
            % 输出:
            %   factor - 材料因子

            switch materialType
                case obj.MATERIAL_CARBON_STEEL
                    factor = 1.0;
                case obj.MATERIAL_SS304
                    factor = 1.189 + 0.0577 * diameterFt;
                case obj.MATERIAL_SS316
                    factor = 1.401 + 0.0724 * diameterFt;
                otherwise
                    factor = 1.0;
            end
        end

        function minThickness = getMinimumThickness(obj, diameterFt)
            % getMinimumThickness 获取最小壁厚
            %
            % 输入:
            %   diameterFt - 直径 (ft)
            %
            % 输出:
            %   minThickness - 最小壁厚 (inch)

            if diameterFt <= 4
                minThickness = 1/4;
            elseif diameterFt <= 6
                minThickness = 5/16;
            elseif diameterFt <= 8
                minThickness = 3/8;
            elseif diameterFt <= 10
                minThickness = 7/16;
            else
                minThickness = 1/2;
            end
        end
    end
end
