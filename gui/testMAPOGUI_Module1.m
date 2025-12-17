% testMAPOGUI_Module1.m - 模块 1 测试脚本（基于 UI 对象搜索）
%
% 说明:
%   MAPOGUI 的 UI 组件为 private 属性，本脚本通过查找 UI 对象进行验证，
%   避免直接访问私有属性导致报错。
%
% 使用方法:
%   在 MATLAB 命令窗口运行: testMAPOGUI_Module1

function testMAPOGUI_Module1()
    fprintf('========================================\n');
    fprintf('MAPOGUI 模块 1 测试脚本\n');
    fprintf('========================================\n\n');

    %% 测试 1: 创建 GUI
    fprintf('测试 1: 创建 MAPOGUI 实例...\n');
    try
        app = MAPOGUI();
        pause(0.5);
        fprintf('  [通过] GUI 创建成功\n');
    catch ME
        fprintf('  [失败] GUI 创建失败: %s\n', ME.message);
        if ~isempty(ME.stack)
            fprintf('  错误位置: %s:%d\n', ME.stack(1).file, ME.stack(1).line);
        end
        return;
    end

    % 将 app 赋值到基础工作空间（便于手动调试）
    assignin('base', 'app', app);

    %% 定位主窗口
    fig = [];
    try
        figs = findall(groot, 'Type', 'figure', 'Name', 'MAPO - MATLAB-Aspen Process Optimizer v2.0');
        if ~isempty(figs)
            fig = figs(1);
        end
    catch
        fig = [];
    end

    if isempty(fig)
        fprintf('  [失败] 未找到主窗口（请确认窗口标题）\n');
        fprintf('  提示: GUI 实例已保存在 base 工作空间变量 app 中\n');
        return;
    end

    %% 测试 2: 检查主窗口属性
    fprintf('\n测试 2: 检查主窗口属性...\n');
    try
        pos = fig.Position;
        assert(pos(3) == 1400 && pos(4) == 850, sprintf('窗口尺寸不匹配: %dx%d', pos(3), pos(4)));
        fprintf('  [通过] 主窗口尺寸: %dx%d\n', pos(3), pos(4));
    catch ME
        fprintf('  [失败] 主窗口属性检查失败: %s\n', ME.message);
    end

    %% 测试 3: 检查 5 个 Tab
    fprintf('\n测试 3: 检查 5 个 Tab...\n');
    try
        tg = findall(fig, 'Type', 'uitabgroup');
        assert(~isempty(tg), '未找到 TabGroup');
        tg = tg(1);

        tabs = findall(tg, 'Type', 'uitab');
        titles = arrayfun(@(t) t.Title, tabs, 'UniformOutput', false);
        expected = {'1. 问题配置', '2. 评估器配置', '3. 仿真器配置', '4. 算法配置', '5. 运行与结果'};
        for i = 1:length(expected)
            assert(any(strcmp(titles, expected{i})), sprintf('缺少 Tab: %s', expected{i}));
        end
        fprintf('  [通过] 5-Tab 结构存在\n');
    catch ME
        fprintf('  [失败] Tab 检查失败: %s\n', ME.message);
    end

    %% 测试 4: Tab 2（评估器配置）默认值
    fprintf('\n测试 4: 检查 Tab 2（评估器配置）默认值...\n');
    try
        evalTab = findall(fig, 'Type', 'uitab', 'Title', '2. 评估器配置');
        assert(~isempty(evalTab), '未找到 Tab 2');
        evalTab = evalTab(1);

        dd = findall(evalTab, 'Type', 'uidropdown');
        assert(~isempty(dd), '未找到评估器下拉框');
        dd = dd(1);
        assert(strcmp(char(dd.Value), 'ORCEvaluator'), sprintf('默认评估器类型不正确: %s', char(dd.Value)));

        sp = findall(evalTab, 'Type', 'uispinner');
        assert(~isempty(sp), '未找到评估器超时 Spinner');
        sp = sp(1);
        assert(sp.Value == 300, sprintf('默认超时时间不正确: %g', sp.Value));

        tbl = findall(evalTab, 'Type', 'uitable');
        assert(~isempty(tbl), '未找到评估器参数表');

        fprintf('  [通过] Tab 2 默认配置正确\n');
    catch ME
        fprintf('  [失败] Tab 2 检查失败: %s\n', ME.message);
    end

    %% 测试 5: 添加变量功能（Tab 1）
    fprintf('\n测试 5: 测试添加变量功能...\n');
    try
        probTab = findall(fig, 'Type', 'uitab', 'Title', '1. 问题配置');
        assert(~isempty(probTab), '未找到 Tab 1');
        probTab = probTab(1);

        % 变量表格：唯一 6 列的表格
        tables = findall(probTab, 'Type', 'uitable');
        varTable = [];
        for k = 1:length(tables)
            cn = tables(k).ColumnName;
            if iscell(cn) && numel(cn) == 6
                varTable = tables(k);
                break;
            end
        end
        assert(~isempty(varTable), '未找到变量表格');

        addBtn = findall(probTab, 'Type', 'uibutton', 'Text', '+ 添加变量');
        assert(~isempty(addBtn), '未找到 + 添加变量 按钮');
        addBtn = addBtn(1);

        initialRowCount = size(varTable.Data, 1);
        fcn = addBtn.ButtonPushedFcn;
        if isa(fcn, 'function_handle')
            fcn(addBtn, []);
        end
        pause(0.1);

        newRowCount = size(varTable.Data, 1);
        assert(newRowCount == initialRowCount + 1, '添加变量未生效');
        fprintf('  [通过] 添加变量功能正常\n');
    catch ME
        fprintf('  [失败] 添加变量测试失败: %s\n', ME.message);
    end

    %% 测试总结
    fprintf('\n========================================\n');
    fprintf('测试完成！GUI 实例已保存在 base 工作空间变量 app 中。\n');
    fprintf('========================================\n\n');
end
