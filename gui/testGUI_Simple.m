% testGUI_Simple.m - 简单的 GUI 启动测试
% 用于验证 5-Tab 结构是否正确

function testGUI_Simple()
    fprintf('======================================\n');
    fprintf('MAPOGUI 5-Tab 结构测试\n');
    fprintf('======================================\n\n');

    fprintf('正在启动 GUI...\n');
    try
        app = MAPOGUI();
        fprintf('[成功] GUI 已启动\n\n');

        fprintf('请手动验证以下内容:\n');
        fprintf('1. 窗口标题是否为 "MAPO - MATLAB-Aspen Process Optimizer v2.0"\n');
        fprintf('2. 是否显示 5 个 Tab 标签页?\n');
        fprintf('   - Tab 1: 1. 问题配置\n');
        fprintf('   - Tab 2: 2. 评估器配置\n');
        fprintf('   - Tab 3: 3. 仿真器配置\n');
        fprintf('   - Tab 4: 4. 算法配置\n');
        fprintf('   - Tab 5: 5. 运行与结果\n');
        fprintf('3. Tab 1 是否包含 4 个面板:\n');
        fprintf('   - 基本信息 (淡蓝色)\n');
        fprintf('   - 决策变量配置 (淡红色)\n');
        fprintf('   - 优化目标配置 (淡绿色)\n');
        fprintf('   - 约束条件配置 (淡黄色)\n');
        fprintf('4. Tab 1 是否有竖向滚动条?\n');
        fprintf('5. Tab 2 是否为独立的评估器配置界面?\n');
        fprintf('6. Tab 3/4/5 是否为完整界面（非占位）?\n');
        fprintf('7. 底部是否有深色状态栏?\n\n');

        fprintf('如果以上都正确，说明 5-Tab 结构已修复成功。\n');
        fprintf('GUI 窗口将保持打开，请手动关闭。\n\n');

        fprintf('======================================\n');
        fprintf('测试完成\n');
        fprintf('======================================\n');

        % 将 app 保存到基础工作空间供调试
        assignin('base', 'app', app);

    catch ME
        fprintf('[失败] GUI 启动失败\n');
        fprintf('错误信息: %s\n', ME.message);
        fprintf('错误位置: %s:%d\n', ME.stack(1).file, ME.stack(1).line);
        fprintf('\n');
        rethrow(ME);
    end
end
