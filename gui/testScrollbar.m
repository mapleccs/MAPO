% testScrollbar.m - 测试滚动条功能
% 验证 Tab 1 是否显示滚动条

function testScrollbar()
    fprintf('======================================\n');
    fprintf('滚动条测试\n');
    fprintf('======================================\n\n');

    fprintf('正在启动 GUI...\n');
    app = MAPOGUI();

    fprintf('[成功] GUI 已启动\n\n');

    fprintf('面板高度配置:\n');
    fprintf('  Panel 1 (基本信息):    180 px\n');
    fprintf('  Panel 2 (决策变量):    350 px\n');
    fprintf('  Panel 3 (优化目标):    300 px\n');
    fprintf('  Panel 4 (约束条件):    280 px\n');
    fprintf('  间距 (3×15px):          45 px\n');
    fprintf('  内边距 (上下40px):      40 px\n');
    fprintf('  --------------------------------\n');
    fprintf('  总计:                ~1195 px\n');
    fprintf('  窗口高度:            ~750 px\n\n');

    fprintf('预期结果:\n');
    fprintf('  - Tab 1 右侧应显示垂直滚动条\n');
    fprintf('  - 每个面板都有充足的显示空间\n');
    fprintf('  - 可以通过滚动查看所有4个面板\n\n');

    fprintf('请手动验证:\n');
    fprintf('  1. 切换到 Tab 1 (问题配置)\n');
    fprintf('  2. 检查右侧是否有滚动条\n');
    fprintf('  3. 尝试滚动查看所有面板\n');
    fprintf('  4. 确认每个面板内容都能完整显示\n\n');

    fprintf('======================================\n');
    fprintf('测试完成，GUI 保持打开状态\n');
    fprintf('======================================\n');

    assignin('base', 'app', app);
end
