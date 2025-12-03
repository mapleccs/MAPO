function config = orc_sensitivity_config()
% orc_sensitivity_config - ORC灵敏度分析配置
%
% 描述:
%   定义ORC系统灵敏度分析的配置参数
%   可以根据具体需求调整各项参数
%
% 输出:
%   config - 配置结构体
%
% 作者: MAPO Framework
% 日期: 2024

%% 基本配置
config = struct();

% 分析名称
config.name = 'ORC_Sensitivity_Analysis';

% 输出目录
config.outputDirectory = 'results/sensitivity';

%% 分析配置
% 目标变量（空数组表示分析所有变量）
config.targetVariables = {};  % 例如: {'FLOW_S7', 'P_EVAP'}

% 每个变量的测试点数 (默认值，可被变量特定配置覆盖)
config.numPoints = 15;

% 变化策略
config.variationStrategy = 'linear';  % 'linear' 或 'logarithmic'

% 范围扩展因子（用于线性策略）
config.rangeExpansion = 0.15;  % 15%扩展

% 基准值策略
config.baselineStrategy = 'center';  % 'center', 'current', 或具体数值

%% 仿真配置
% 仿真模式
config.simulationMode = 'sequential';  % 'sequential' 或 'parallel'

% 是否显示进度
config.showProgress = true;

% 是否使用缓存
config.useCache = true;

% 缓存目录
config.cacheDirectory = 'cache/sensitivity';

% 最大重试次数
config.maxRetries = 2;

% 超时时间（秒）
config.timeout = 60;

%% 收敛性配置
% 惩罚值阈值
config.penaltyThreshold = 1e6;

% 检查仿真器状态
config.checkSimulatorStatus = true;

% 检查结果有效性
config.checkResultValidity = true;

% 可行域确定阈值
config.feasibilityThreshold = 0.5;  % 50%的点收敛才认为是可行域

%% 报告配置
% 生成控制台报告
config.generateConsoleReport = true;

% 生成文件报告
config.generateFileReport = true;

% 生成图形报告
config.generatePlotReport = true;

% 图形设置
config.plotConfig = struct();
config.plotConfig.figureSize = [1200, 600];
config.plotConfig.dpi = 300;
config.plotConfig.showUnconverged = true;
config.plotConfig.gridOn = true;
config.plotConfig.fontSize = 12;

% 文件报告设置
config.fileConfig = struct();
config.fileConfig.saveTextReport = true;
config.fileConfig.saveCSV = true;
config.fileConfig.saveMAT = true;
config.fileConfig.precision = 4;

%% 变量特定配置
% 为特定变量设置不同的配置
config.variableConfigs = struct();

% FLOW_S7配置
config.variableConfigs.FLOW_S7 = struct();
config.variableConfigs.FLOW_S7.numPoints = 15;      % 减少点数以提高速度
config.variableConfigs.FLOW_S7.rangeExpansion = 0.1;  % 小幅扩展 (10%)

% FLOW_S8配置
config.variableConfigs.FLOW_S8 = struct();
config.variableConfigs.FLOW_S8.numPoints = 15;
config.variableConfigs.FLOW_S8.rangeExpansion = 0.1;

% P_EVAP配置 (2.0-5.0 bar范围较小，适当增加测试点)
config.variableConfigs.P_EVAP = struct();
config.variableConfigs.P_EVAP.numPoints = 20;
config.variableConfigs.P_EVAP.rangeExpansion = 0.2;  % 20%扩展

% P_COND配置 (0.5-1.5 bar范围更小，需要更密集的测试点)
config.variableConfigs.P_COND = struct();
config.variableConfigs.P_COND.numPoints = 20;
config.variableConfigs.P_COND.rangeExpansion = 0.2;

%% 优化建议配置
% 是否生成优化建议
config.generateOptimizationSuggestions = true;

% 安全边界余量
config.safetyMargin = 0.05;  % 5%

% 建议的种群大小因子
config.populationSizeFactor = 10;  % 每个变量10个个体

%% 高级配置
% 并行池设置
config.parallelConfig = struct();
config.parallelConfig.numWorkers = 4;
config.parallelConfig.clusterProfile = 'local';

% 内存管理
config.memoryConfig = struct();
config.memoryConfig.clearWorkspaceAfterVariable = true;
config.memoryConfig.maxCacheSize = 1000;  % MB

% 错误处理
config.errorConfig = struct();
config.errorConfig.continueOnError = true;
config.errorConfig.logErrors = true;
config.errorConfig.errorLogFile = 'errors/sensitivity_errors.log';

%% 验证配置
config = validateConfig(config);

end

function config = validateConfig(config)
% 验证配置参数

% 确保输出目录存在
if ~exist(config.outputDirectory, 'dir')
    mkdir(config.outputDirectory);
end

% 确保缓存目录存在
if config.useCache && ~exist(config.cacheDirectory, 'dir')
    mkdir(config.cacheDirectory);
end

% 验证数值参数
if config.numPoints < 5
    warning('测试点数过少，建议至少使用10个点');
    config.numPoints = 10;
end

if config.rangeExpansion < 0 || config.rangeExpansion > 1
    warning('范围扩展因子应在0到1之间');
    config.rangeExpansion = 0.3;
end

if config.timeout < 10
    warning('超时时间过短，设置为最小值10秒');
    config.timeout = 10;
end

% 验证策略参数
validStrategies = {'linear', 'logarithmic'};
if ~ismember(config.variationStrategy, validStrategies)
    warning('无效的变化策略，使用默认linear');
    config.variationStrategy = 'linear';
end

validModes = {'sequential', 'parallel'};
if ~ismember(config.simulationMode, validModes)
    warning('无效的仿真模式，使用默认sequential');
    config.simulationMode = 'sequential';
end

% 创建错误日志目录
if config.errorConfig.logErrors
    errorDir = fileparts(config.errorConfig.errorLogFile);
    if ~isempty(errorDir) && ~exist(errorDir, 'dir')
        mkdir(errorDir);
    end
end

end