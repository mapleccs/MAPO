%% example_expression_evaluator.m
% 表达式评估器使用示例
% 演示如何使用ExpressionEvaluator进行基于表达式的优化

%% ========================================
%% 示例1: 简单的数学函数优化（无仿真器）
%% ========================================

fprintf('========================================\n');
fprintf('示例1: 简单数学函数优化\n');
fprintf('========================================\n\n');

% 配置：优化 Rosenbrock 函数
config1 = struct();
config1.problem = struct();

% 定义变量
config1.problem.variables = [
    struct('name', 'x1', 'type', 'continuous', 'lowerBound', -5, 'upperBound', 5, 'unit', '')
    struct('name', 'x2', 'type', 'continuous', 'lowerBound', -5, 'upperBound', 5, 'unit', '')
];

% 定义派生变量
config1.problem.derived = [
    struct('name', 'term1', 'expression', '(1 - x.x1) ^ 2', 'unit', '', 'description', '第一项')
    struct('name', 'term2', 'expression', '100 * (x.x2 - x.x1 ^ 2) ^ 2', 'unit', '', 'description', '第二项')
];

% 定义目标（使用派生变量）
config1.problem.objectives = [
    struct('name', 'rosenbrock', 'type', 'minimize', ...
           'expression', 'derived.term1 + derived.term2', 'unit', '', 'weight', 1.0)
];

config1.problem.constraints = [];
config1.problem.evaluator = struct('type', 'ExpressionEvaluator', 'timeout', 300);

% 创建评估器（无仿真器）
evaluator1 = ExpressionEvaluator([], config1);

% 测试评估
x_test = [1.0, 1.0];  % 最优解
result1 = evaluator1.evaluate(x_test);

fprintf('测试点 x = [%.2f, %.2f]\n', x_test(1), x_test(2));
fprintf('目标值 = %.6f (应接近0)\n\n', result1.objectives(1));

%% ========================================
%% 示例2: 带仿真器的化工过程优化
%% ========================================

fprintf('========================================\n');
fprintf('示例2: 化工过程优化（模拟）\n');
fprintf('========================================\n\n');

% 配置：优化布雷顿循环
config2 = struct();
config2.problem = struct();

% 定义变量
config2.problem.variables = [
    struct('name', 'T_in', 'type', 'continuous', 'lowerBound', 500, 'upperBound', 800, 'unit', 'K')
    struct('name', 'P_ratio', 'type', 'continuous', 'lowerBound', 2, 'upperBound', 10, 'unit', '')
];

% 定义经济参数
config2.problem.evaluator = struct();
config2.problem.evaluator.type = 'ExpressionEvaluator';
config2.problem.evaluator.timeout = 300;
config2.problem.evaluator.economicParameters = struct();
config2.problem.evaluator.economicParameters.interestRate = 0.12;
config2.problem.evaluator.economicParameters.systemLifetime = 20;
config2.problem.evaluator.economicParameters.maintenanceFactor = 0.06;
config2.problem.evaluator.economicParameters.operatingHours = 7200;

% 定义派生变量（经济计算）
config2.problem.derived = [
    struct('name', 'CRF', ...
           'expression', 'param.interestRate * (1 + param.interestRate) ^ param.systemLifetime / ((1 + param.interestRate) ^ param.systemLifetime - 1)', ...
           'unit', '', 'description', '资本回收因子')
    struct('name', 'c_c', ...
           'expression', '((derived.CRF + param.maintenanceFactor) / param.operatingHours) * result.C_compressor', ...
           'unit', '$/h', 'description', '压缩机成本率')
    struct('name', 'c_t', ...
           'expression', '((derived.CRF + param.maintenanceFactor) / param.operatingHours) * result.C_turbine', ...
           'unit', '$/h', 'description', '透平成本率')
    struct('name', 'c_total', ...
           'expression', 'derived.c_c + derived.c_t', ...
           'unit', '$/h', 'description', '总成本率')
];

% 定义目标
config2.problem.objectives = [
    struct('name', 'LEC', 'type', 'minimize', ...
           'expression', 'derived.c_total / result.W_net', ...
           'unit', '$/kW', 'weight', 1.0, 'description', '平准化能源成本')
    struct('name', 'efficiency', 'type', 'maximize', ...
           'expression', 'result.W_net / result.Q_in * 100', ...
           'unit', '%', 'weight', 1.0, 'description', '热效率')
];

% 定义约束
config2.problem.constraints = [
    struct('name', 'min_power', 'type', 'inequality', ...
           'expression', 'result.W_net >= 1000', ...
           'unit', 'kW', 'description', '最小输出功率')
    struct('name', 'max_temp', 'type', 'inequality', ...
           'expression', 'result.T_turbine_out <= 900', ...
           'unit', 'K', 'description', '最大透平出口温度')
];

% 配置仿真器节点映射
config2.simulator = struct();
config2.simulator.type = 'Aspen';
config2.simulator.nodeMapping = struct();
config2.simulator.nodeMapping.results = struct();
config2.simulator.nodeMapping.results.W_net = '\Data\Streams\POWER\Output\WORK';
config2.simulator.nodeMapping.results.Q_in = '\Data\Streams\HEAT_IN\Output\HEAT';
config2.simulator.nodeMapping.results.C_compressor = '\Data\Blocks\COMP\Output\COST';
config2.simulator.nodeMapping.results.C_turbine = '\Data\Blocks\TURB\Output\COST';
config2.simulator.nodeMapping.results.T_turbine_out = '\Data\Streams\TURB_OUT\Output\TEMP';

config2.simulator.nodeMapping.resultUnits = struct();
config2.simulator.nodeMapping.resultUnits.W_net = 'kW';
config2.simulator.nodeMapping.resultUnits.Q_in = 'kW';
config2.simulator.nodeMapping.resultUnits.C_compressor = '$';
config2.simulator.nodeMapping.resultUnits.C_turbine = '$';
config2.simulator.nodeMapping.resultUnits.T_turbine_out = 'K';

fprintf('配置已创建，包含:\n');
fprintf('  - 2个决策变量\n');
fprintf('  - 4个派生变量（经济计算）\n');
fprintf('  - 2个优化目标（LEC, 效率）\n');
fprintf('  - 2个约束条件\n\n');

%% ========================================
%% 示例3: 表达式语法演示
%% ========================================

fprintf('========================================\n');
fprintf('示例3: 表达式语法演示\n');
fprintf('========================================\n\n');

% 创建测试上下文
valueMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
valueMap('x.T') = struct('value', 600, 'dims', zeros(1,8));
valueMap('x.P') = struct('value', 5, 'dims', zeros(1,8));
valueMap('result.W') = struct('value', 1000, 'dims', zeros(1,8));
valueMap('result.Q') = struct('value', 5000, 'dims', zeros(1,8));
valueMap('param.k') = struct('value', 0.1, 'dims', zeros(1,8));

ctx.lookup = @(name) valueMap(name);

% 测试各种表达式
expressions = {
    '2 + 3 * 4', '基本算术';
    '(2 + 3) * 4', '括号优先级';
    'x.T + x.P', '变量引用';
    'result.W / result.Q', '结果变量';
    'result.W / result.Q * 100', '效率计算';
    'sqrt(x.T)', '平方根函数';
    'abs(x.T - 500)', '绝对值函数';
    'min(x.T, 700)', 'min函数';
    'max(x.P, 3)', 'max函数';
    'log(x.P)', '自然对数';
    'exp(param.k)', '指数函数';
    'if(x.T > 550, 1, 0)', '条件函数';
    'x.T ^ 2', '幂运算';
    '(x.T - 500) / 100', '归一化';
};

fprintf('%-40s | %-20s | %s\n', '表达式', '描述', '结果');
fprintf('%s\n', repmat('-', 1, 80));

for i = 1:size(expressions, 1)
    expr = expressions{i, 1};
    desc = expressions{i, 2};
    try
        compiled = ExpressionEngine.compile(expr);
        [value, ~] = ExpressionEngine.evaluate(compiled, ctx);
        fprintf('%-40s | %-20s | %.4f\n', expr, desc, value);
    catch ME
        fprintf('%-40s | %-20s | 错误: %s\n', expr, desc, ME.message);
    end
end

fprintf('\n');

%% ========================================
%% 示例4: 单位检查演示
%% ========================================

fprintf('========================================\n');
fprintf('示例4: 单位检查演示\n');
fprintf('========================================\n\n');

% 测试单位解析
units = {'kg', 'g', 'ton', 'm', 'km', 's', 'h', 'K', 'Pa', 'bar', 'kW', 'MW', 'kWh'};

fprintf('%-10s | %-15s | %s\n', '单位', '基准单位倍数', '维度');
fprintf('%s\n', repmat('-', 1, 60));

for i = 1:length(units)
    unitStr = units{i};
    try
        u = UnitRegistry.parseUnit(unitStr);
        fprintf('%-10s | %-15.6e | [', unitStr, u.scale);
        fprintf('%.0f ', u.dims);
        fprintf(']\n');
    catch ME
        fprintf('%-10s | 错误: %s\n', unitStr, ME.message);
    end
end

fprintf('\n');

%% ========================================
%% 示例5: 完整优化流程
%% ========================================

fprintf('========================================\n');
fprintf('示例5: 完整优化流程示例\n');
fprintf('========================================\n\n');

fprintf('完整的优化流程包括:\n\n');

fprintf('1. 在GUI中配置问题:\n');
fprintf('   - 定义决策变量（x.变量名）\n');
fprintf('   - 定义优化目标（可使用表达式）\n');
fprintf('   - 定义派生变量（简化复杂计算）\n');
fprintf('   - 定义约束条件（支持 <=, >=, == 运算符）\n\n');

fprintf('2. 配置仿真器:\n');
fprintf('   - 设置变量映射（决策变量 -> Aspen节点）\n');
fprintf('   - 设置结果映射（result.变量名 -> Aspen节点）\n');
fprintf('   - 指定单位（可选，用于单位检查）\n\n');

fprintf('3. 配置评估器参数:\n');
fprintf('   - 添加经济参数（param.参数名）\n');
fprintf('   - 指定参数单位（可选）\n\n');

fprintf('4. 运行优化:\n');
fprintf('   - ExpressionEvaluator自动:\n');
fprintf('     * 编译所有表达式\n');
fprintf('     * 运行仿真获取结果\n');
fprintf('     * 计算派生变量\n');
fprintf('     * 计算目标和约束\n');
fprintf('     * 检查单位一致性\n\n');

fprintf('5. 分析结果:\n');
fprintf('   - 查看Pareto前沿\n');
fprintf('   - 导出优化解\n');
fprintf('   - 验证约束满足情况\n\n');

fprintf('========================================\n');
fprintf('示例完成！\n');
fprintf('========================================\n\n');

fprintf('提示:\n');
fprintf('  - 表达式中使用 x.变量名 引用决策变量\n');
fprintf('  - 使用 result.变量名 引用仿真结果\n');
fprintf('  - 使用 param.参数名 引用经济参数\n');
fprintf('  - 使用 derived.变量名 引用派生变量\n');
fprintf('  - 支持的函数: if, min, max, abs, sqrt, log, log10, exp\n');
fprintf('  - 支持的运算符: +, -, *, /, ^, <, <=, >, >=, ==, !=, &&, ||\n\n');
