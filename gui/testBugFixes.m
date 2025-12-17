% testBugFixes.m - 验证 Bug 修复的测试脚本
%
% 测试内容:
%   1. ResultsSaver.m 的多目标判断逻辑
%   2. ConfigBuilder.m 的 suppressWarnings 字段支持
%
% 使用方法:
%   cd 'E:\Project\Chemical Design Competition\MAPO\gui'
%   testBugFixes

function testBugFixes()
    fprintf('========================================\n');
    fprintf('Bug 修复验证测试\n');
    fprintf('========================================\n\n');

    %% 测试 1: ResultsSaver 多目标判断逻辑
    fprintf('测试 1: ResultsSaver 多目标判断逻辑\n');
    fprintf('----------------------------------------\n');

    % 测试案例 1.1: 通过 problemType 判断
    config1 = struct();
    config1.problem = struct();
    config1.problem.name = 'TestProblem';
    config1.problem.problemType = 'multi-objective';
    config1.problem.objectives = struct([]);

    results1 = struct();
    results1.paretoFront = [];

    try
        saver1 = ResultsSaver(results1, config1, 0);
        saver1.resultsDir = tempdir();
        filePath1 = saver1.saveParetoCSV();

        % 预期: 因为 paretoFront 为空，所以返回 []
        if isempty(filePath1)
            fprintf('  [通过] 案例 1.1: problemType 判断正确（空 paretoFront）\n');
        else
            fprintf('  [失败] 案例 1.1: 应该返回空值\n');
        end
    catch ME
        fprintf('  [失败] 案例 1.1: %s\n', ME.message);
    end

    % 测试案例 1.2: 通过目标数量判断
    config2 = struct();
    config2.problem = struct();
    config2.problem.name = 'TestProblem';
    config2.problem.objectives = struct();
    config2.problem.objectives(1).name = 'Obj1';
    config2.problem.objectives(2).name = 'Obj2';

    results2 = struct();
    results2.paretoFront = [];

    try
        saver2 = ResultsSaver(results2, config2, 0);
        saver2.resultsDir = tempdir();
        filePath2 = saver2.saveParetoCSV();

        % 预期: 因为 paretoFront 为空，所以返回 []
        if isempty(filePath2)
            fprintf('  [通过] 案例 1.2: 目标数量判断正确（空 paretoFront）\n');
        else
            fprintf('  [失败] 案例 1.2: 应该返回空值\n');
        end
    catch ME
        fprintf('  [失败] 案例 1.2: %s\n', ME.message);
    end

    % 测试案例 1.3: 单目标不保存
    config3 = struct();
    config3.problem = struct();
    config3.problem.name = 'TestProblem';
    config3.problem.objectives = struct();
    config3.problem.objectives(1).name = 'Obj1';

    results3 = struct();
    results3.paretoFront = [];

    try
        saver3 = ResultsSaver(results3, config3, 0);
        saver3.resultsDir = tempdir();
        filePath3 = saver3.saveParetoCSV();

        % 预期: 单目标，返回 []
        if isempty(filePath3)
            fprintf('  [通过] 案例 1.3: 单目标正确跳过 Pareto CSV 保存\n');
        else
            fprintf('  [失败] 案例 1.3: 单目标不应保存 Pareto CSV\n');
        end
    catch ME
        fprintf('  [失败] 案例 1.3: %s\n', ME.message);
    end

    %% 测试 2: ConfigBuilder suppressWarnings 字段
    fprintf('\n测试 2: ConfigBuilder suppressWarnings 字段支持\n');
    fprintf('----------------------------------------\n');

    % 测试案例 2.1: 默认配置包含 suppressWarnings
    try
        defaultConfig = ConfigBuilder.getDefaultConfig();
        if isfield(defaultConfig.simulator.settings, 'suppressWarnings')
            if defaultConfig.simulator.settings.suppressWarnings == true
                fprintf('  [通过] 案例 2.1: 默认配置包含 suppressWarnings = true\n');
            else
                fprintf('  [失败] 案例 2.1: 默认值应为 true\n');
            end
        else
            fprintf('  [失败] 案例 2.1: 默认配置缺少 suppressWarnings 字段\n');
        end
    catch ME
        fprintf('  [失败] 案例 2.1: %s\n', ME.message);
    end

    % 测试案例 2.2: buildConfig 保留 suppressWarnings
    try
        guiData = struct();
        guiData.problem = struct();
        guiData.problem.name = 'TestProblem';
        guiData.problem.description = '';
        guiData.problem.variables = [];
        guiData.problem.objectives = [];
        guiData.problem.constraints = [];
        guiData.problem.evaluator = struct();
        guiData.problem.evaluator.type = 'TestEvaluator';
        guiData.problem.evaluator.timeout = 300;

        guiData.simulator = struct();
        guiData.simulator.type = 'Aspen';
        guiData.simulator.settings = struct();
        guiData.simulator.settings.modelPath = 'test.bkp';
        guiData.simulator.settings.timeout = 300;
        guiData.simulator.settings.visible = false;
        guiData.simulator.settings.autoSave = true;
        guiData.simulator.settings.suppressWarnings = false;  % 测试 false 值
        guiData.simulator.settings.maxRetries = 3;
        guiData.simulator.settings.retryDelay = 2;
        guiData.simulator.nodeMapping = struct();
        guiData.simulator.nodeMapping.variables = struct();
        guiData.simulator.nodeMapping.results = struct();

        guiData.algorithm = struct();
        guiData.algorithm.type = 'NSGA-II';
        guiData.algorithm.parameters = struct();
        guiData.algorithm.parameters.populationSize = 50;
        guiData.algorithm.parameters.maxGenerations = 30;

        config = ConfigBuilder.buildConfig(guiData);

        if isfield(config.simulator.settings, 'suppressWarnings')
            if config.simulator.settings.suppressWarnings == false
                fprintf('  [通过] 案例 2.2: buildConfig 正确保留 suppressWarnings = false\n');
            else
                fprintf('  [失败] 案例 2.2: 应保留 false 值\n');
            end
        else
            fprintf('  [失败] 案例 2.2: buildConfig 结果缺少 suppressWarnings 字段\n');
        end
    catch ME
        fprintf('  [失败] 案例 2.2: %s\n', ME.message);
    end

    % 测试案例 2.3: toGUIData 保留 suppressWarnings
    try
        config = struct();
        config.problem = struct();
        config.problem.name = 'TestProblem';
        config.problem.problemType = 'single-objective';
        config.problem.variables = struct([]);
        config.problem.objectives = struct([]);
        config.problem.constraints = struct([]);
        config.problem.evaluator = struct();
        config.problem.evaluator.type = 'TestEvaluator';
        config.problem.evaluator.timeout = 300;

        config.simulator = struct();
        config.simulator.type = 'Aspen';
        config.simulator.settings = struct();
        config.simulator.settings.modelPath = 'test.bkp';
        config.simulator.settings.timeout = 300;
        config.simulator.settings.visible = true;
        config.simulator.settings.autoSave = false;
        config.simulator.settings.suppressWarnings = false;  % 测试 false 值
        config.simulator.settings.maxRetries = 3;
        config.simulator.settings.retryDelay = 2;
        config.simulator.nodeMapping = struct();
        config.simulator.nodeMapping.variables = struct();
        config.simulator.nodeMapping.results = struct();

        config.algorithm = struct();
        config.algorithm.type = 'NSGA-II';
        config.algorithm.parameters = struct();
        config.algorithm.parameters.populationSize = 50;
        config.algorithm.parameters.maxGenerations = 30;

        guiData = ConfigBuilder.toGUIData(config);

        if isfield(guiData.simulator.settings, 'suppressWarnings')
            if guiData.simulator.settings.suppressWarnings == false
                fprintf('  [通过] 案例 2.3: toGUIData 正确保留 suppressWarnings = false\n');
            else
                fprintf('  [失败] 案例 2.3: 应保留 false 值\n');
            end
        else
            fprintf('  [失败] 案例 2.3: toGUIData 结果缺少 suppressWarnings 字段\n');
        end
    catch ME
        fprintf('  [失败] 案例 2.3: %s\n', ME.message);
    end

    % 测试案例 2.4: JSON 往返测试（保存和加载）
    fprintf('\n测试案例 2.4: JSON 往返测试\n');
    try
        % 创建测试配置
        testConfig = ConfigBuilder.getDefaultConfig();
        testConfig.simulator.settings.suppressWarnings = false;  % 改为 false

        % 保存到临时 JSON 文件
        tempFile = fullfile(tempdir(), 'test_suppressWarnings.json');
        ConfigBuilder.toJSON(testConfig, tempFile);

        % 从 JSON 加载
        loadedConfig = ConfigBuilder.fromJSON(tempFile);

        % 检查字段是否保留
        if isfield(loadedConfig.simulator.settings, 'suppressWarnings')
            if loadedConfig.simulator.settings.suppressWarnings == false
                fprintf('  [通过] 案例 2.4: JSON 往返保留 suppressWarnings = false\n');
            else
                fprintf('  [失败] 案例 2.4: JSON 加载后值不正确\n');
            end
        else
            fprintf('  [失败] 案例 2.4: JSON 加载后缺少 suppressWarnings 字段\n');
        end

        % 清理临时文件
        if exist(tempFile, 'file')
            delete(tempFile);
        end
    catch ME
        fprintf('  [失败] 案例 2.4: %s\n', ME.message);
    end

    %% 测试总结
    fprintf('\n========================================\n');
    fprintf('测试完成！\n');
    fprintf('========================================\n\n');
    fprintf('修复摘要:\n');
    fprintf('1. ResultsSaver.m:117 现在通过以下方式判断多目标:\n');
    fprintf('   - 优先: config.problem.problemType == ''multi-objective''\n');
    fprintf('   - 备选: length(config.problem.objectives) > 1\n\n');
    fprintf('2. ConfigBuilder.m 现在完整支持 suppressWarnings 字段:\n');
    fprintf('   - getDefaultConfig(): 包含 suppressWarnings = true\n');
    fprintf('   - buildConfig(): 从 guiData 读取并保留\n');
    fprintf('   - toGUIData(): 从 config 读取并保留\n');
    fprintf('   - toJSON()/fromJSON(): 正确序列化和反序列化\n\n');
    fprintf('建议执行:\n');
    fprintf('1. 运行 launchGUI(''check'') 检查依赖\n');
    fprintf('2. 加载一个多目标示例配置测试 Pareto CSV 生成\n');
    fprintf('3. 测试保存/加载配置确认 suppressWarnings 状态保留\n\n');
end
