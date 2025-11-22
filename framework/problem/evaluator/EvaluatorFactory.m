classdef EvaluatorFactory
    % EvaluatorFactory 评估器工厂类
    % 根据类型字符串动态创建评估器实例
    %
    % 功能:
    %   - 根据类型名称创建对应的评估器
    %   - 支持内置和自定义评估器
    %   - 自动设置通用参数
    %
    % 示例:
    %   % 创建ORC评估器
    %   evaluator = EvaluatorFactory.create('ORCEvaluator', simulator, 300);
    %
    %   % 创建自定义评估器
    %   evaluator = EvaluatorFactory.create('MyCustomEvaluator', simulator);
    %
    % 作者: MAPO Framework
    % 版本: 1.0.0

    methods (Static)
        function evaluator = create(evaluatorType, simulator, timeout, additionalParams)
            % create 创建评估器实例
            %
            % 输入:
            %   evaluatorType - 评估器类型字符串
            %   simulator - 仿真器实例
            %   timeout - (可选) 超时时间，默认300秒
            %   additionalParams - (可选) 额外参数结构体
            %
            % 输出:
            %   evaluator - 评估器实例
            %
            % 示例:
            %   evaluator = EvaluatorFactory.create('ORCEvaluator', simulator);
            %   evaluator = EvaluatorFactory.create('MyCaseEvaluator', simulator, 600);

            % 参数验证
            if nargin < 2
                error('EvaluatorFactory:InsufficientArguments', ...
                      '至少需要提供evaluatorType和simulator参数');
            end

            if nargin < 3
                timeout = 300;  % 默认超时时间
            end

            if nargin < 4
                additionalParams = struct();
            end

            % 验证仿真器
            if ~isa(simulator, 'SimulatorBase')
                error('EvaluatorFactory:InvalidSimulator', ...
                      'simulator必须是SimulatorBase的实例');
            end

            % 记录日志
            fprintf('  创建评估器: %s\n', evaluatorType);

            try
                % 尝试创建评估器实例
                switch evaluatorType
                    % 内置评估器
                    case 'ORCEvaluator'
                        evaluator = ORCEvaluator(simulator);
                        % 设置ORC特定参数
                        if isfield(additionalParams, 'electricityPrice')
                            evaluator.electricityPrice = additionalParams.electricityPrice;
                        end
                        if isfield(additionalParams, 'operatingHours')
                            evaluator.operatingHours = additionalParams.operatingHours;
                        end
                        if isfield(additionalParams, 'coolingWaterCost')
                            evaluator.coolingWaterCost = additionalParams.coolingWaterCost;
                        end

                    case 'ADNProductionEvaluator'
                        evaluator = ADNProductionEvaluator(simulator);
                        % 设置ADN特定参数
                        if isfield(additionalParams, 'productPrice')
                            evaluator.productPrice = additionalParams.productPrice;
                        end
                        if isfield(additionalParams, 'rawMaterialCost')
                            evaluator.rawMaterialCost = additionalParams.rawMaterialCost;
                        end

                    case 'DistillationEvaluator'
                        evaluator = DistillationEvaluator(simulator);

                    case 'MyCaseEvaluator'
                        evaluator = MyCaseEvaluator(simulator);

                    case 'SimpleTemplateEvaluator'
                        % 创建简单模板评估器
                        if isfield(additionalParams, 'objectives')
                            objectives = additionalParams.objectives;
                        else
                            objectives = {};
                        end

                        if isfield(additionalParams, 'economicParams')
                            economicParams = additionalParams.economicParams;
                        else
                            economicParams = struct();
                        end

                        evaluator = SimpleTemplateEvaluator(simulator, objectives, economicParams);

                    otherwise
                        % 尝试动态创建自定义评估器
                        try
                            % 检查类是否存在
                            if exist(evaluatorType, 'class') == 8
                                % 使用feval动态创建实例
                                evaluator = feval(evaluatorType, simulator);
                            else
                                error('EvaluatorFactory:ClassNotFound', ...
                                      '找不到评估器类: %s', evaluatorType);
                            end
                        catch ME
                            % 提供详细的错误信息
                            error('EvaluatorFactory:CreationFailed', ...
                                  ['无法创建评估器 "%s"\n' ...
                                   '可能的原因:\n' ...
                                   '1. 评估器类不存在\n' ...
                                   '2. 类名拼写错误\n' ...
                                   '3. 类文件不在MATLAB路径中\n' ...
                                   '4. 构造函数参数不匹配\n\n' ...
                                   '原始错误: %s'], ...
                                  evaluatorType, ME.message);
                        end
                end

                % 设置通用参数
                if isprop(evaluator, 'timeout')
                    evaluator.timeout = timeout;
                end

                % 设置额外参数
                if ~isempty(fieldnames(additionalParams))
                    fields = fieldnames(additionalParams);
                    for i = 1:length(fields)
                        field = fields{i};
                        % 跳过已处理的特殊字段
                        if ismember(field, {'objectives', 'economicParams', ...
                                           'electricityPrice', 'operatingHours', ...
                                           'coolingWaterCost', 'productPrice', ...
                                           'rawMaterialCost'})
                            continue;
                        end

                        % 尝试设置属性
                        if isprop(evaluator, field)
                            evaluator.(field) = additionalParams.(field);
                        end
                    end
                end

                fprintf('    评估器创建成功\n');

            catch ME
                % 重新抛出错误，保留调用栈
                rethrow(ME);
            end
        end

        function types = getAvailableTypes()
            % getAvailableTypes 获取所有可用的评估器类型
            %
            % 输出:
            %   types - 可用评估器类型的cell数组
            %
            % 示例:
            %   types = EvaluatorFactory.getAvailableTypes();

            types = {
                'ORCEvaluator', ...
                'ADNProductionEvaluator', ...
                'DistillationEvaluator', ...
                'MyCaseEvaluator', ...
                'SimpleTemplateEvaluator'
            };

            % 动态查找其他评估器
            % 获取evaluator目录路径
            factoryPath = mfilename('fullpath');
            evaluatorDir = fileparts(factoryPath);

            % 查找所有*Evaluator.m文件
            evaluatorFiles = dir(fullfile(evaluatorDir, '*Evaluator.m'));

            for i = 1:length(evaluatorFiles)
                [~, className, ~] = fileparts(evaluatorFiles(i).name);

                % 排除基类和已包含的类
                if strcmp(className, 'Evaluator') || ...
                   strcmp(className, 'MATLABFunctionEvaluator') || ...
                   ismember(className, types)
                    continue;
                end

                % 检查是否是有效的评估器类
                try
                    % 检查是否继承自Evaluator
                    mc = meta.class.fromName(className);
                    if ~isempty(mc)
                        superclasses = mc.SuperclassList;
                        for j = 1:length(superclasses)
                            if strcmp(superclasses(j).Name, 'Evaluator')
                                types{end+1} = className;
                                break;
                            end
                        end
                    end
                catch
                    % 忽略无法加载的类
                end
            end
        end

        function info = getEvaluatorInfo(evaluatorType)
            % getEvaluatorInfo 获取评估器信息
            %
            % 输入:
            %   evaluatorType - 评估器类型字符串
            %
            % 输出:
            %   info - 评估器信息结构体
            %
            % 示例:
            %   info = EvaluatorFactory.getEvaluatorInfo('ORCEvaluator');

            info = struct();
            info.type = evaluatorType;

            switch evaluatorType
                case 'ORCEvaluator'
                    info.description = '有机朗肯循环(ORC)系统评估器';
                    info.requiredParams = {'simulator'};
                    info.optionalParams = {'electricityPrice', 'operatingHours', 'coolingWaterCost'};
                    info.objectives = {'PROFIT', 'EFFICIENCY'};

                case 'ADNProductionEvaluator'
                    info.description = 'ADN生产工艺评估器';
                    info.requiredParams = {'simulator'};
                    info.optionalParams = {'productPrice', 'rawMaterialCost'};
                    info.objectives = {'TAC', 'YIELD'};

                case 'DistillationEvaluator'
                    info.description = '精馏塔评估器';
                    info.requiredParams = {'simulator'};
                    info.optionalParams = {};
                    info.objectives = {'TAC', 'PURITY'};

                case 'MyCaseEvaluator'
                    info.description = '用户自定义评估器模板';
                    info.requiredParams = {'simulator'};
                    info.optionalParams = {};
                    info.objectives = {'OBJECTIVE1', 'OBJECTIVE2'};

                case 'SimpleTemplateEvaluator'
                    info.description = '简单通用评估器模板';
                    info.requiredParams = {'simulator', 'objectives', 'economicParams'};
                    info.optionalParams = {};
                    info.objectives = {'CUSTOM'};

                otherwise
                    info.description = '自定义评估器';
                    info.requiredParams = {'simulator'};
                    info.optionalParams = {};
                    info.objectives = {};
            end
        end

        function printAvailableTypes()
            % printAvailableTypes 打印所有可用的评估器类型
            %
            % 示例:
            %   EvaluatorFactory.printAvailableTypes();

            types = EvaluatorFactory.getAvailableTypes();

            fprintf('\n========================================\n');
            fprintf('可用的评估器类型:\n');
            fprintf('========================================\n\n');

            for i = 1:length(types)
                info = EvaluatorFactory.getEvaluatorInfo(types{i});
                fprintf('%d. %s\n', i, types{i});
                fprintf('   描述: %s\n', info.description);

                if ~isempty(info.objectives)
                    fprintf('   目标: %s\n', strjoin(info.objectives, ', '));
                end

                if ~isempty(info.optionalParams)
                    fprintf('   可选参数: %s\n', strjoin(info.optionalParams, ', '));
                end

                fprintf('\n');
            end

            fprintf('========================================\n\n');
        end
    end
end