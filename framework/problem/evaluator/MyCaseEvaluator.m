classdef MyCaseEvaluator < Evaluator
    % MyCaseEvaluator 评估器模板类
    % 这是一个极简的评估器模板，用户可以基于此模板创建自定义评估器
    %
    % 使用说明:
    %   1. 复制此文件并重命名为您的评估器名称（如: MyReactorEvaluator.m）
    %   2. 修改类名以匹配文件名
    %   3. 在evaluate方法中实现您的目标函数计算逻辑
    %   4. 在配置文件中设置evaluator.type为您的评估器类名
    %
    % 重要提示:
    %   - 最大化问题需要取负值（框架内部统一为最小化）
    %   - 仿真失败时返回惩罚值（如1e8）
    %   - 可以添加自定义属性存储经济参数等
    %
    % 示例:
    %   evaluator = MyCaseEvaluator(simulator);
    %   evaluator.productPrice = 1000;  % 设置自定义参数
    %   [objectives, constraints] = evaluator.evaluate(x);
    %
    % 作者: MAPO Framework
    % 版本: 1.0.0

    properties
        % 在这里添加您的自定义属性
        % 例如：经济参数、物理常数等

        % 经济参数示例
        productPrice = 1000;        % 产品价格 ($/ton)
        energyCost = 0.1;          % 能源成本 ($/kWh)
        operatingHours = 8000;      % 年运行小时数

        % 物理参数示例
        conversionFactor = 1.0;     % 转换系数
        efficiencyTarget = 0.9;     % 目标效率
    end

    methods
        function obj = MyCaseEvaluator(simulator)
            % MyCaseEvaluator 构造函数
            %
            % 输入:
            %   simulator - 仿真器实例（AspenPlusSimulator等）

            % 调用父类构造函数
            obj@Evaluator(simulator);

            % 可以在这里初始化默认参数
            obj.timeout = 300;  % 默认超时时间
        end

        function [objectiveValues, constraintViolations] = evaluate(obj, x)
            % evaluate 评估函数 - 核心方法
            % 这是您需要重点修改的方法
            %
            % 输入:
            %   x - 决策变量向量
            %       例如: x = [流量, 温度, 压力, ...]
            %
            % 输出:
            %   objectiveValues - 目标函数值向量
            %       注意: 最大化问题需要取负值
            %   constraintViolations - 约束违反值向量（可选）
            %       违反约束时为正值，满足约束时为0或负值

            try
                %% Step 1: 设置仿真器变量
                % 将决策变量传递给仿真器
                obj.simulator.setVariables(x);

                % 记录评估
                obj.incrementEvaluationCount();

                %% Step 2: 运行仿真
                success = obj.simulator.run();

                % 检查仿真是否成功
                if ~success
                    % 仿真失败，返回惩罚值
                    obj.logMessage('WARNING', '仿真失败，返回惩罚值');

                    % 假设有2个目标函数
                    objectiveValues = [1e8, 1e8];
                    constraintViolations = [];
                    return;
                end

                %% Step 3: 获取仿真结果
                % 获取所有配置的结果变量
                resultNames = obj.simulator.config.getResultMappingNames();
                results = obj.simulator.getResults(resultNames);

                % 也可以获取特定结果
                % results = obj.simulator.getResults({'PRODUCT_FLOW', 'ENERGY', 'PURITY'});

                %% Step 4: 计算目标函数
                % ========================================
                % 这里是您需要修改的核心部分
                % 根据您的具体问题计算目标函数值
                % ========================================

                % 示例1: 经济目标 - 年度利润（最大化，需要取负）
                if isKey(results, 'PRODUCT_FLOW') && isKey(results, 'ENERGY')
                    productFlow = results('PRODUCT_FLOW');    % kg/hr
                    energyUsage = results('ENERGY');           % kW

                    % 计算年度收入
                    annualRevenue = productFlow * obj.operatingHours * obj.productPrice / 1000;  % $/year

                    % 计算年度成本
                    annualCost = energyUsage * obj.operatingHours * obj.energyCost;  % $/year

                    % 计算利润（最大化，取负值）
                    profit = annualRevenue - annualCost;
                    objective1 = -profit;  % 转为最小化
                else
                    % 缺少必要结果，使用默认值
                    objective1 = 0;
                end

                % 示例2: 技术目标 - 效率（最大化，需要取负）
                if isKey(results, 'EFFICIENCY') || (isKey(results, 'OUTPUT') && isKey(results, 'INPUT'))
                    if isKey(results, 'EFFICIENCY')
                        efficiency = results('EFFICIENCY');
                    else
                        % 计算效率
                        output = results('OUTPUT');
                        input = results('INPUT');
                        efficiency = output / input;
                    end

                    % 效率目标（最大化，取负值）
                    objective2 = -efficiency * 100;  % 转为百分比并取负
                else
                    % 使用默认效率
                    objective2 = -50;  % 假设50%效率
                end

                % 组合目标函数值
                objectiveValues = [objective1, objective2];

                %% Step 5: 计算约束违反（可选）
                constraintViolations = [];

                % 示例约束1: 最小产量约束
                % 要求: productFlow >= 1000 kg/hr
                % 转换为: 1000 - productFlow <= 0
                if isKey(results, 'PRODUCT_FLOW')
                    minProductFlow = 1000;
                    productFlow = results('PRODUCT_FLOW');
                    constraint1 = minProductFlow - productFlow;  % <= 0 表示满足
                    constraintViolations(end+1) = max(0, constraint1);  % 违反时为正
                end

                % 示例约束2: 最大能耗约束
                % 要求: energyUsage <= 5000 kW
                % 转换为: energyUsage - 5000 <= 0
                if isKey(results, 'ENERGY')
                    maxEnergy = 5000;
                    energyUsage = results('ENERGY');
                    constraint2 = energyUsage - maxEnergy;  % <= 0 表示满足
                    constraintViolations(end+1) = max(0, constraint2);  % 违反时为正
                end

                %% 记录日志（可选）
                obj.logMessage('INFO', sprintf('评估完成: x=[%s], obj=[%.2f, %.2f]', ...
                    num2str(x, '%.4f '), objectiveValues(1), objectiveValues(2)));

            catch ME
                % 错误处理
                obj.logMessage('ERROR', sprintf('评估失败: %s', ME.message));

                % 返回惩罚值
                objectiveValues = [1e8, 1e8];  % 根据实际目标数调整
                constraintViolations = [];
            end
        end

        function reset(obj)
            % reset 重置评估器状态
            % 可以在这里重置自定义的内部状态

            % 调用父类的重置方法
            reset@Evaluator(obj);

            % 重置自定义状态（如果有）
            % obj.someInternalState = [];
        end

        function setEconomicParameters(obj, params)
            % setEconomicParameters 设置经济参数
            % 这是一个辅助方法示例，您可以添加自己的辅助方法
            %
            % 输入:
            %   params - 参数结构体

            if isfield(params, 'productPrice')
                obj.productPrice = params.productPrice;
            end

            if isfield(params, 'energyCost')
                obj.energyCost = params.energyCost;
            end

            if isfield(params, 'operatingHours')
                obj.operatingHours = params.operatingHours;
            end
        end

        function displayParameters(obj)
            % displayParameters 显示当前参数设置
            % 用于调试和验证

            fprintf('\n========================================\n');
            fprintf('MyCaseEvaluator 参数设置:\n');
            fprintf('========================================\n');
            fprintf('  产品价格: %.2f $/ton\n', obj.productPrice);
            fprintf('  能源成本: %.4f $/kWh\n', obj.energyCost);
            fprintf('  年运行时间: %d hours\n', obj.operatingHours);
            fprintf('  转换系数: %.4f\n', obj.conversionFactor);
            fprintf('  目标效率: %.2f%%\n', obj.efficiencyTarget * 100);
            fprintf('========================================\n\n');
        end
    end

    methods (Access = protected)
        function valid = validateResults(obj, results)
            % validateResults 验证仿真结果
            % 可选的辅助方法，用于验证结果的合理性
            %
            % 输入:
            %   results - 结果字典
            %
            % 输出:
            %   valid - 是否有效

            valid = true;

            % 检查关键结果是否存在
            requiredResults = {'PRODUCT_FLOW', 'ENERGY'};  % 根据需要修改

            for i = 1:length(requiredResults)
                if ~isKey(results, requiredResults{i})
                    obj.logMessage('WARNING', sprintf('缺少必要结果: %s', requiredResults{i}));
                    valid = false;
                    return;
                end
            end

            % 检查结果范围的合理性
            if isKey(results, 'PRODUCT_FLOW')
                flow = results('PRODUCT_FLOW');
                if flow < 0 || flow > 1e6
                    obj.logMessage('WARNING', sprintf('产品流量超出合理范围: %.2f', flow));
                    valid = false;
                end
            end

            if isKey(results, 'EFFICIENCY')
                eff = results('EFFICIENCY');
                if eff < 0 || eff > 1
                    obj.logMessage('WARNING', sprintf('效率超出[0,1]范围: %.4f', eff));
                    valid = false;
                end
            end
        end
    end
end