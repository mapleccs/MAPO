function launchGUI(varargin)
%% launchGUI - 启动 MAPO 图形用户界面
%
% 用法:
%   launchGUI()           % 启动 GUI
%   launchGUI('test')     % 启动并加载测试配置
%   launchGUI('check')    % 仅检查依赖，不启动 GUI
%
% 说明:
%   该函数启动 MAPO (MATLAB-Aspen Process Optimizer) 的图形用户界面，
%   让用户可以通过可视化方式配置和运行优化任务。
%
% 示例:
%   launchGUI()          % 正常启动
%   launchGUI('test')    % 加载示例配置启动
%   launchGUI('check')   % 检查依赖项

    %% 解析输入参数
    checkOnly = false;
    loadTest = false;

    if nargin > 0
        if strcmpi(varargin{1}, 'check')
            checkOnly = true;
        elseif strcmpi(varargin{1}, 'test')
            loadTest = true;
        end
    end

    %% 获取当前脚本所在目录
    scriptPath = fileparts(mfilename('fullpath'));

    fprintf('========================================\n');
    fprintf('MAPO 图形用户界面启动器 v2.0\n');
    fprintf('========================================\n');
    fprintf('项目根目录: %s\n', scriptPath);

    %% 检查 MATLAB 版本
    matlabVersion = ver('MATLAB');
    releaseYear = str2double(matlabVersion.Release(3:6));
    fprintf('MATLAB 版本: %s\n', matlabVersion.Release);

    if releaseYear < 2018
        error('MAPO:VersionTooOld', ...
            'MAPO GUI 需要 MATLAB R2018b 或更高版本（当前: %s）', matlabVersion.Release);
    end

    if releaseYear < 2019
        warning('MAPO:VersionWarning', ...
            'App Designer 在 MATLAB R2019a 及以上版本中效果最佳');
    end

    %% 添加必要路径
    fprintf('\n添加路径...\n');

    % 添加框架路径
    frameworkPath = fullfile(scriptPath, 'framework');
    if exist(frameworkPath, 'dir')
        addpath(genpath(frameworkPath));
        fprintf('  [OK] Framework 路径已添加\n');
    else
        error('MAPO:PathNotFound', '未找到 framework 目录: %s', frameworkPath);
    end

    % 添加GUI路径
    guiPath = fullfile(scriptPath, 'gui');
    if exist(guiPath, 'dir')
        addpath(genpath(guiPath));
        fprintf('  [OK] GUI 路径已添加\n');
    else
        error('MAPO:PathNotFound', '未找到 gui 目录: %s', guiPath);
    end

    %% 检查依赖文件
    fprintf('\n检查依赖文件...\n');

    requiredFiles = {
        fullfile(guiPath, 'helpers', 'ConfigBuilder.m');
        fullfile(guiPath, 'helpers', 'ConfigValidator.m');
        fullfile(guiPath, 'helpers', 'AspenNodeTemplates.m');
        fullfile(guiPath, 'helpers', 'ResultsSaver.m');
        fullfile(guiPath, 'helpers', 'handleOptimizationData.m');
        fullfile(guiPath, 'callbacks', 'OptimizationCallbacks.m');
        fullfile(guiPath, 'runOptimizationAsync.m');
    };

    missingFiles = {};
    for i = 1:length(requiredFiles)
        if exist(requiredFiles{i}, 'file')
            [~, fname, ext] = fileparts(requiredFiles{i});
            fprintf('  [OK] %s%s\n', fname, ext);
        else
            [~, fname, ext] = fileparts(requiredFiles{i});
            fprintf('  [MISSING] %s%s\n', fname, ext);
            missingFiles{end+1} = requiredFiles{i};
        end
    end

    if ~isempty(missingFiles)
        error('MAPO:MissingDependencies', ...
            '缺少必需文件:\n  %s', strjoin(missingFiles, '\n  '));
    end

    %% 检查 Parallel Computing Toolbox
    hasParallelToolbox = license('test', 'Distrib_Computing_Toolbox');
    if hasParallelToolbox
        fprintf('\n  [OK] Parallel Computing Toolbox 可用\n');
    else
        fprintf('\n  [INFO] Parallel Computing Toolbox 不可用\n');
        fprintf('        优化将以同步模式运行\n');
    end

    %% 检查 GUI 文件
    % 优先检查 MAPOGUI.m（代码版本）
    guiFileM = fullfile(guiPath, 'MAPOGUI.m');
    guiFileMLAPP = fullfile(guiPath, 'MAPOGUI.mlapp');

    guiFileExists = false;
    guiFileType = '';

    if exist(guiFileM, 'file')
        guiFileExists = true;
        guiFileType = 'M-file';
        fprintf('  [OK] MAPOGUI.m (代码版本)\n');
    elseif exist(guiFileMLAPP, 'file')
        guiFileExists = true;
        guiFileType = 'MLAPP';
        fprintf('  [OK] MAPOGUI.mlapp (App Designer)\n');
    end

    if ~guiFileExists
        fprintf('\n========================================\n');
        fprintf('警告: MAPOGUI 文件未找到！\n');
        fprintf('========================================\n\n');
        fprintf('GUI 文件尚未创建。\n\n');
        fprintf('可选方式:\n');
        fprintf('方式 1: 使用已创建的代码版本\n');
        fprintf('  文件位置: %s\n\n', guiFileM);
        fprintf('方式 2: 使用 App Designer 创建\n');
        fprintf('  1. 打开 App Designer: appdesigner\n');
        fprintf('  2. 创建新的 Blank App\n');
        fprintf('  3. 按照指南创建界面: %s\n', ...
            fullfile(guiPath, 'MAPOGUI_CreationGuide.md'));
        fprintf('  4. 保存为: %s\n\n', guiFileMLAPP);
        fprintf('回调函数实现参考: %s\n', ...
            fullfile(guiPath, 'MAPOGUI_Callbacks.m'));
        fprintf('\n========================================\n');

        % 询问是否打开 App Designer
        if ~checkOnly
            answer = input('是否现在打开 App Designer? (y/n): ', 's');
            if strcmpi(answer, 'y')
                appdesigner;
            end
        end
        return;
    end

    %% 如果仅检查依赖，到此结束
    if checkOnly
        fprintf('\n========================================\n');
        fprintf('依赖检查完成！所有文件就绪。\n');
        fprintf('========================================\n');
        return;
    end

    %% 启动GUI
    fprintf('\n========================================\n');
    fprintf('启动 MAPOGUI...\n');
    fprintf('========================================\n\n');

    try
        % 启动应用
        app = MAPOGUI();

        % 如果需要加载测试配置
        if loadTest
            fprint('尝试加载测试配置...\n');

            % 查找示例配置文件
            exampleConfig = fullfile(scriptPath, 'example', 'R601', 'case_config.json');
            if exist(exampleConfig, 'file')
                try
                    % 注意：这需要在 MAPOGUI 中实现公开的加载方法
                    % 或者通过 UI 元素触发加载
                    fprintf('找到测试配置: %s\n', exampleConfig);
                    fprintf('请在 GUI 中点击"加载配置"按钮手动加载\n');
                catch ME
                    fprintf('无法自动加载测试配置: %s\n', ME.message);
                end
            else
                fprintf('未找到测试配置文件: %s\n', exampleConfig);
            end
        end

        fprintf('GUI 启动成功！\n');
        fprintf('使用版本: %s\n', guiFileType);
        fprintf('\n帮助文档:\n');
        fprintf('  创建指南: %s\n', fullfile(guiPath, 'MAPOGUI_CreationGuide.md'));
        fprintf('  回调参考: %s\n', fullfile(guiPath, 'MAPOGUI_Callbacks.m'));
        fprintf('\n========================================\n');

    catch ME
        fprintf('\n========================================\n');
        fprintf('启动失败！\n');
        fprintf('========================================\n');
        fprintf('错误信息: %s\n', ME.message);

        if ~isempty(ME.stack)
            fprintf('错误位置: %s (第 %d 行)\n\n', ...
                ME.stack(1).file, ME.stack(1).line);
        end

        % 如果是找不到类的错误，给出详细提示
        if contains(ME.identifier, 'UndefinedFunction') || contains(ME.message, 'MAPOGUI')
            fprintf('提示:\n');
            fprintf('  MAPOGUI 文件可能存在问题。\n');
            fprintf('  请确保:\n');
            if exist(guiFileM, 'file')
                fprintf('  1. 文件在正确位置: %s\n', guiFileM);
                fprintf('  2. 文件没有语法错误\n');
                fprintf('  3. 可以运行: MAPOGUI() 测试\n\n');
            elseif exist(guiFileMLAPP, 'file')
                fprintf('  1. 文件在正确位置: %s\n', guiFileMLAPP);
                fprintf('  2. 文件没有语法错误（在 App Designer 中打开检查）\n');
                fprintf('  3. 所有回调函数已正确实现\n\n');
            end
            fprintf('  参考文档:\n');
            fprintf('    %s\n', fullfile(guiPath, 'MAPOGUI_CreationGuide.md'));
            fprintf('    %s\n', fullfile(guiPath, 'MAPOGUI_Callbacks.m'));
        end

        fprintf('========================================\n');
        rethrow(ME);
    end
end
