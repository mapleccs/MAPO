function config = loadConfig(configFile, configType)
% loadConfig 加载JSON配置文件
%
% 输入:
%   configFile - 配置文件路径（可以是相对或绝对路径）
%   configType - (可选) 配置类型 ('algorithm', 'simulator', 'problem')
%
% 输出:
%   config - 配置结构体
%
% 示例:
%   % 加载算法配置
%   algoConfig = loadConfig('config/algorithm_config.json');
%
%   % 加载并获取特定算法配置
%   nsga2Config = loadConfig('config/algorithm_config.json', 'NSGA-II');
%
%   % 加载仿真器配置
%   simConfig = loadConfig('config/simulator_config.json', 'aspen');

    % 检查文件是否存在
    if ~exist(configFile, 'file')
        % 尝试相对于项目根目录
        projectRoot = fileparts(fileparts(mfilename('fullpath')));
        configFile = fullfile(projectRoot, configFile);

        if ~exist(configFile, 'file')
            error('loadConfig:FileNotFound', ...
                  '配置文件不存在: %s', configFile);
        end
    end

    % 读取JSON文件
    try
        fid = fopen(configFile, 'r');
        if fid == -1
            error('loadConfig:FileOpenError', ...
                  '无法打开配置文件: %s', configFile);
        end

        raw = fread(fid, inf);
        str = char(raw');
        fclose(fid);

        % 解析JSON
        config = jsondecode(str);

    catch ME
        if exist('fid', 'var') && fid ~= -1
            fclose(fid);
        end
        error('loadConfig:ParseError', ...
              '解析配置文件失败: %s\n错误: %s', ...
              configFile, ME.message);
    end

    % 如果指定了配置类型，返回特定部分
    if nargin > 1 && ~isempty(configType)
        if isfield(config, configType)
            config = config.(configType);
        elseif isfield(config, 'algorithm') && isfield(config.algorithm, configType)
            % 兼容算法类型查找
            config = config.algorithm;
        else
            warning('loadConfig:TypeNotFound', ...
                    '配置类型 "%s" 不存在，返回完整配置', configType);
        end
    end

    % 日志输出
    fprintf('[INFO] 配置文件加载成功: %s\n', configFile);

    % 显示配置摘要
    if isstruct(config)
        fields = fieldnames(config);
        fprintf('  配置包含 %d 个顶级字段: ', length(fields));
        fprintf('%s ', fields{:});
        fprintf('\n');
    end
end