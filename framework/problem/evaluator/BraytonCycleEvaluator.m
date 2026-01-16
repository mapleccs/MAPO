classdef BraytonCycleEvaluator < Evaluator
    % BraytonCycleEvaluator - 布雷顿循环评估器（中间冷却再热循环）
    %
    % 功能:
    %   - 评估中间冷却再热布雷顿循环的热效率和净输出功率
    %   - 支持多级透平（高压透平T + 低压透平LT）
    %   - 支持多级压缩机（主压缩机MC1, MC2 + 再压缩机RC）
    %   - 支持多个加热器（HEATER + HEATER2）
    %   - 支持经济性分析（可选）
    %   - 自动处理仿真失败和约束违反
    %
    % 决策变量:
    %   1. P_HP_in - 高压透平入口压力 [17-35 MPa]
    %   2. T_LP_in - 低压透平入口温度 [500-600 °C]
    %   3. split_ratio - 分流比 [0.2-0.5]
    %   4. P_LP_in - 低压透平入口压力 [8-16 MPa]
    %   5. P_inter - 中间压力 [8-16 MPa]
    %   6. T_comp_in - 压缩机入口温度 [32-46 °C]
    %
    % 优化目标:
    %   1. thermal_efficiency - 热效率 (最大化)
    %   2. net_power - 净输出功率 (最大化)
    %
    % 从Aspen获取的结果:
    %   - W_turbine_HP, W_turbine_LP - 高压和低压透平功率
    %   - W_compressor_1, W_compressor_2, W_compressor_RC - 两个主压缩机和再压缩机功率
    %   - Q_heater_1, Q_heater_2 - 两个加热器的热量
    %   - mass_flow - 质量流量（从流股7读取）
    %   计算值: W_turbine = |W_turbine_HP| + |W_turbine_LP|（透平做功，取绝对值）
    %           W_compressor = |W_compressor_1| + |W_compressor_2| + |W_compressor_RC|（压缩机耗功，取绝对值）
    %           Q_in = Q_heater_1 + Q_heater_2（总热输入，固定为150MW）
    %           W_net = W_turbine - W_compressor（净输出功率）
    %
    % 示例:
    %   simulator = AspenPlusSimulator();
    %   simulator.connect(simConfig);
    %   evaluator = BraytonCycleEvaluator(simulator);
    %   result = evaluator.evaluate(x);

    properties
        timeout = 300;              % 仿真超时时间(秒)

        % 经济参数（可选）
        interestRate = 0.12;        % 年利率
        systemLifetime = 20;        % 系统寿命(年)
        maintenanceFactor = 0.06;   % 维护因子
        operatingHours = 7200;      % 年运行小时数
        electricityPrice = 0.1;     % 电价($/kWh)

        % 设备成本系数（可选，用于经济分析）
        turbineCostCoeff = 1000;    % 透平成本系数($/kW)
        compressorCostCoeff = 800;  % 压缩机成本系数($/kW)
        heatExchangerCostCoeff = 500; % 换热器成本系数($/kW)
    end

    properties (Access = private)
        simulator;                  % 仿真器对象
        variableNames;              % 变量名列表
    end

    methods
        function obj = BraytonCycleEvaluator(simulator)
            % 构造函数
            %
            % 输入:
            %   simulator - Aspen Plus仿真器对象

            obj@Evaluator();

            if nargin >= 1
                obj.simulator = simulator;
            else
                obj.simulator = [];
            end

            % 定义变量名（与配置文件中的顺序一致）
            obj.variableNames = {
                'P_HP_in'       % 1. 高压透平入口压力
                'T_LP_in'       % 2. 低压透平入口温度
                'split_ratio'   % 3. 分流比
                'P_LP_in'       % 4. 低压透平入口压力
                'P_inter'       % 5. 中间压力
                'T_comp_in'     % 6. 压缩机入口温度
            };
        end

        function setProblem(obj, problem)
            % 设置优化问题
            %
            % 输入:
            %   problem - OptimizationProblem对象

            setProblem@Evaluator(obj, problem);

            % 从problem中提取变量名（如果可用）
            if ~isempty(problem)
                try
                    varSet = problem.getVariableSet();
                    obj.variableNames = varSet.getNames();
                catch
                    % 使用默认变量名
                end
            end
        end

        function result = evaluate(obj, x)
            % 评估布雷顿循环性能
            %
            % 输入:
            %   x - 决策变量向量 [P_HP_in, T_LP_in, split_ratio, P_LP_in, P_inter, T_comp_in]
            %
            % 输出:
            %   result - 评估结果结构体
            %     .objectives - 目标函数值 [负的热效率, 负的净功率]
            %     .constraints - 约束违反度
            %     .success - 是否成功
            %     .message - 消息

            obj.evaluationCounter = obj.evaluationCounter + 1;

            try
                % 1. 验证输入
                if length(x) ~= 6
                    error('BraytonCycleEvaluator:InvalidInput', ...
                        '期望6个决策变量，实际收到%d个', length(x));
                end

                % 2. 提取决策变量
                P_HP_in = x(1);      % MPa
                T_LP_in = x(2);      % °C
                split_ratio = x(3); % -
                P_LP_in = x(4);      % MPa
                P_inter = x(5);      % MPa
                T_comp_in = x(6);    % °C

                % 3. 快速约束检查（避免无效仿真）
                if P_HP_in < P_LP_in
                    result = obj.createPenaltyResult('压力不一致: P_HP_in < P_LP_in');
                    return;
                end

                if P_inter < P_LP_in || P_inter > P_HP_in
                    result = obj.createPenaltyResult('中间压力超出范围');
                    return;
                end

                if split_ratio < 0.2 || split_ratio > 0.5
                    result = obj.createPenaltyResult('分流比超出范围');
                    return;
                end

                % 4. 运行Aspen Plus仿真
                if isempty(obj.simulator)
                    % 如果没有仿真器，使用简化模型
                    [W_net, Q_in, W_turbine, W_compressor, mass_flow] = ...
                        obj.simplifiedModel(P_HP_in, T_LP_in, split_ratio, P_LP_in, P_inter, T_comp_in);
                else
                    % 设置仿真器变量
                    obj.simulator.setVariables(x);

                    % 运行仿真
                    success = obj.simulator.run(obj.timeout);

                    if ~success
                        result = obj.createPenaltyResult('Aspen Plus仿真失败或未收敛');
                        return;
                    end

                    % 提取仿真结果（分别获取各设备功率）
                    W_turbine_HP = obj.simulator.getVariable('W_turbine_HP');       % kW
                    W_turbine_LP = obj.simulator.getVariable('W_turbine_LP');       % kW
                    W_compressor_1 = obj.simulator.getVariable('W_compressor_1');   % kW
                    W_compressor_2 = obj.simulator.getVariable('W_compressor_2');   % kW
                    W_compressor_RC = obj.simulator.getVariable('W_compressor_RC'); % kW (再压缩机)
                    Q_heater_1 = obj.simulator.getVariable('Q_heater_1');           % kW
                    Q_heater_2 = obj.simulator.getVariable('Q_heater_2');           % kW
                    mass_flow = obj.simulator.getVariable('mass_flow');             % kg/s

                    % 计算总功率和热量
                    % 注意：Aspen中透平WNET通常为负值（做功输出），压缩机WNET为正值（耗功）
                    % 使用绝对值确保符号正确
                    W_turbine = abs(W_turbine_HP) + abs(W_turbine_LP);  % 总透平做功
                    W_compressor = abs(W_compressor_1) + abs(W_compressor_2) + abs(W_compressor_RC); % 总压缩机耗功
                    Q_in = Q_heater_1 + Q_heater_2;                      % 总输入热量
                    W_net = W_turbine - W_compressor;                    % 净输出功率
                end

                % 5. 计算目标函数
                thermal_efficiency = W_net / Q_in * 100;  % %
                net_power = W_net;                         % kW

                % 6. 计算约束
                constraints = obj.calculateConstraints(W_net, Q_in, thermal_efficiency, ...
                    P_HP_in, P_LP_in, P_inter);

                % 7. 返回结果（最大化转为最小化）
                objectives = [-thermal_efficiency, -net_power];

                result = obj.createSuccessResult(objectives, constraints, '');

                % 8. 附加信息（用于后处理）
                result.derived = struct();
                result.derived.thermal_efficiency = thermal_efficiency;
                result.derived.net_power = net_power;
                result.derived.power_ratio = W_turbine / W_compressor;
                result.derived.specific_work = W_net / mass_flow;

                % 各设备详细功率（用于诊断和分析）
                result.derived.W_turbine_HP = W_turbine_HP;
                result.derived.W_turbine_LP = W_turbine_LP;
                result.derived.W_compressor_1 = W_compressor_1;
                result.derived.W_compressor_2 = W_compressor_2;
                result.derived.W_compressor_RC = W_compressor_RC;
                result.derived.Q_heater_1 = Q_heater_1;
                result.derived.Q_heater_2 = Q_heater_2;
                result.derived.W_turbine_total = W_turbine;
                result.derived.W_compressor_total = W_compressor;
                result.derived.Q_in_total = Q_in;

            catch ME
                % 捕获所有错误
                result = obj.createPenaltyResult(ME.message);
            end
        end
    end

    methods (Access = private)
        function constraints = calculateConstraints(obj, W_net, Q_in, efficiency, ...
                P_HP_in, P_LP_in, P_inter)
            % 计算约束违反度
            %
            % 约束格式: g(x) <= 0 (正值表示违反)

            constraints = [];

            % 约束1: 最小热效率 >= 30%
            % g1 = 0.30 - efficiency/100 <= 0
            constraints(end+1) = 0.30 - (efficiency / 100);

            % 约束2: 最小净功率 >= 1000 kW
            % g2 = 1000 - W_net <= 0
            constraints(end+1) = 1000 - W_net;

            % 约束3: 压力一致性 P_HP_in >= P_LP_in
            % g3 = P_LP_in - P_HP_in <= 0
            constraints(end+1) = P_LP_in - P_HP_in;

            % 约束4: 中间压力范围 P_LP_in <= P_inter <= P_HP_in
            % g4 = P_LP_in - P_inter <= 0
            constraints(end+1) = P_LP_in - P_inter;
            % g5 = P_inter - P_HP_in <= 0
            constraints(end+1) = P_inter - P_HP_in;
        end

        function [W_net, Q_in, W_turbine, W_compressor, mass_flow] = ...
                simplifiedModel(obj, P_HP_in, T_LP_in, split_ratio, P_LP_in, P_inter, T_comp_in)
            % 简化的布雷顿循环模型（用于测试，无Aspen Plus）
            %
            % 注意: 这是简化模型，不包含再压缩机RC的详细计算
            % 基于理想布雷顿循环的简化计算

            % 工质参数（假设为空气）
            cp = 1.005;  % kJ/(kg·K)
            gamma = 1.4; % 比热比

            % 转换温度为K
            T_LP_in_K = T_LP_in + 273.15;
            T_comp_in_K = T_comp_in + 273.15;

            % 质量流量（假设）
            mass_flow = 10;  % kg/s

            % 压缩机功耗（等熵压缩）
            pressure_ratio_comp = P_inter / 0.1;  % 假设环境压力0.1 MPa
            T_comp_out_K = T_comp_in_K * pressure_ratio_comp^((gamma-1)/gamma);
            W_compressor = mass_flow * cp * (T_comp_out_K - T_comp_in_K);

            % 高压透平功率
            pressure_ratio_HP = P_HP_in / P_inter;
            T_HP_out_K = T_LP_in_K / pressure_ratio_HP^((gamma-1)/gamma);
            W_HP_turbine = (1 - split_ratio) * mass_flow * cp * (T_LP_in_K - T_HP_out_K);

            % 低压透平功率
            pressure_ratio_LP = P_LP_in / 0.1;
            T_LP_out_K = T_LP_in_K / pressure_ratio_LP^((gamma-1)/gamma);
            W_LP_turbine = split_ratio * mass_flow * cp * (T_LP_in_K - T_LP_out_K);

            % 总透平功率
            W_turbine = W_HP_turbine + W_LP_turbine;

            % 净输出功率
            W_net = W_turbine - W_compressor;

            % 输入热量（假设）
            Q_in = mass_flow * cp * (T_LP_in_K - T_comp_out_K);

            % 确保物理合理性
            if W_net < 0
                W_net = 1;  % 避免负功率
            end
            if Q_in <= 0
                Q_in = 1000;  % 避免零或负热量
            end
        end

        function result = createPenaltyResult(obj, message)
            % 创建惩罚结果（用于失败的评估）
            %
            % 输入:
            %   message - 错误消息
            %
            % 输出:
            %   result - 惩罚结果结构体

            nObj = 2;  % 2个目标
            nCon = 5;  % 5个约束

            result = struct();
            result.objectives = 1e8 * ones(1, nObj);  % 大惩罚值
            result.constraints = 1e8 * ones(1, nCon);
            result.success = false;
            result.message = message;
        end
    end
end
