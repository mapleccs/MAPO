classdef CustomModuleTemplate < ModuleBase
    % CustomModuleTemplate 自定义模块模板
    % Template for Creating Custom Modules
    %
    % 使用说明:
    %   1. 复制此文件并重命名为你的模块名称 (例如: MyCustomModule.m)
    %   2. 将所有 "CustomModuleTemplate" 替换为你的模块类名
    %   3. 填写模块基本信息（名称、版本、描述）
    %   4. 根据需要添加自定义属性
    %   5. 实现 initialize(), execute(), finalize() 方法
    %   6. 可选：重写 validate(), getInputSchema(), getOutputSchema() 方法
    %   7. 测试你的模块
    %
    % 快速开始:
    %   >> module = MyCustomModule();
    %   >> module.configure(config);
    %   >> module.initialize();
    %   >> result = module.execute(inputData);
    %   >> module.finalize();
    %
    % 最佳实践:
    %   - 在 initialize() 中验证配置和初始化资源
    %   - 在 execute() 中实现核心业务逻辑
    %   - 在 finalize() 中清理资源
    %   - 使用 obj.logInfo/logWarning/logError 记录重要信息
    %   - 使用 obj.validateInput() 验证输入数据
    %   - 使用 obj.createResultStruct() 创建标准化结果

    % ==================== 自定义属性 ====================
    properties (Access = private)
        % TODO: 在这里添加你的模块需要的私有属性
        % 示例:
        % myParameter;     % double, 某个重要参数
        % dataCache;       % struct, 缓存数据
        % isReady;         % logical, 模块是否就绪
    end

    properties (Constant)
        % TODO: 在这里添加常量属性
        % 示例:
        % DEFAULT_VALUE = 100;
        % MAX_ITERATIONS = 1000;
    end

    % ==================== 构造函数 ====================
    methods
        function obj = CustomModuleTemplate()
            % CustomModuleTemplate 构造函数
            %
            % TODO: 修改以下三个参数为你的模块信息
            moduleName = 'CustomModuleTemplate';    % 模块名称
            moduleVersion = '1.0.0';                % 版本号
            moduleDescription = '自定义模块模板';   % 简短描述

            % 调用父类构造函数（必需）
            obj@ModuleBase(moduleName, moduleVersion, moduleDescription);

            % TODO: 可选 - 设置标签（用于分类和搜索）
            obj.tags = {'custom', 'template'};

            % TODO: 可选 - 设置依赖（如果你的模块依赖其他模块）
            % obj.dependencies = {'OtherModule'};

            % TODO: 可选 - 设置作者和许可证信息
            obj.author = 'Your Name';
            obj.license = 'MIT';

            % TODO: 初始化你的私有属性
            % 示例:
            % obj.myParameter = 0;
            % obj.dataCache = struct();
            % obj.isReady = false;
        end
    end

    % ==================== 必需方法（必须实现）====================
    methods
        function initialize(obj)
            % initialize 初始化模块
            %
            % 功能:
            %   - 验证配置参数
            %   - 初始化内部状态
            %   - 分配资源
            %   - 执行准备工作
            %
            % 注意:
            %   - 如果初始化失败，应该抛出异常
            %   - 必须在最后调用 obj.markInitialized()

            obj.logInfo('初始化 CustomModuleTemplate...');

            try
                % TODO: 验证必需的配置字段
                % 示例:
                % requiredFields = {'param1', 'param2'};
                % obj.validateConfigFields(requiredFields);

                % TODO: 从配置中读取参数
                % 示例:
                % obj.myParameter = obj.getConfigValue('myParameter', 100);

                % TODO: 执行初始化逻辑
                % 示例:
                % obj.dataCache = obj.loadData();
                % obj.isReady = true;

                % 标记为已初始化（必需）
                obj.markInitialized();

                obj.logInfo('CustomModuleTemplate 初始化完成');

            catch ME
                obj.handleError(ME, '初始化失败');
            end
        end

        function result = execute(obj, inputData)
            % execute 执行模块核心功能
            %
            % 输入:
            %   inputData - struct, 输入数据
            %
            % 输出:
            %   result - struct, 计算结果
            %
            % 功能:
            %   - 验证输入数据
            %   - 执行核心计算
            %   - 返回结构化结果
            %
            % 注意:
            %   - 必须在 initialize() 之后调用
            %   - 应该使用 obj.createResultStruct() 创建结果

            % 检查是否已初始化（必需）
            obj.checkInitialized();

            % TODO: 定义必需的输入字段
            requiredFields = {};  % 示例: {'input1', 'input2'}

            try
                % 验证输入数据
                obj.validateInput(inputData, requiredFields);

                obj.logInfo('执行 CustomModuleTemplate...');

                % TODO: 从输入数据中提取参数
                % 示例:
                % param1 = inputData.input1;
                % param2 = inputData.input2;

                % TODO: 执行核心计算逻辑
                % 这里实现你的主要功能
                % 示例:
                % output1 = obj.myCalculation(param1, param2);
                % output2 = obj.anotherCalculation(param1);

                % TODO: 创建结果结构体
                % 使用 createResultStruct 可以自动添加模块名和时间戳
                result = obj.createResultStruct(...
                    'success', true ...
                    % TODO: 添加你的输出字段
                    % 'output1', output1, ...
                    % 'output2', output2, ...
                    % 'metadata', metadata
                );

                obj.logInfo('CustomModuleTemplate 执行完成');

            catch ME
                obj.handleError(ME, '执行失败');
            end
        end

        function finalize(obj)
            % finalize 清理模块资源
            %
            % 功能:
            %   - 释放占用的资源
            %   - 清理临时数据
            %   - 保存必要的状态
            %   - 重置内部状态
            %
            % 注意:
            %   - 必须在最后调用 obj.markFinalized()

            obj.logInfo('清理 CustomModuleTemplate...');

            try
                % TODO: 执行清理逻辑
                % 示例:
                % obj.saveCache();
                % obj.closeConnections();
                % obj.dataCache = struct();
                % obj.isReady = false;

                % 标记为已清理（必需）
                obj.markFinalized();

                obj.logInfo('CustomModuleTemplate 清理完成');

            catch ME
                obj.handleError(ME, '清理失败');
            end
        end
    end

    % ==================== 可选方法（推荐重写）====================
    methods
        function isValid = validate(obj)
            % validate 验证模块配置
            %
            % 输出:
            %   isValid - logical, 配置是否有效
            %
            % 功能:
            %   - 检查配置参数的有效性
            %   - 验证参数范围和类型
            %   - 检查依赖关系
            %
            % 注意:
            %   - 如果不重写，默认返回 true
            %   - 建议重写以添加自定义验证逻辑

            % TODO: 实现自定义验证逻辑
            % 示例:
            % if ~obj.hasConfigField('myParameter')
            %     obj.logWarning('缺少配置参数: myParameter');
            %     isValid = false;
            %     return;
            % end
            %
            % myParam = obj.getConfigValue('myParameter');
            % if myParam < 0 || myParam > 100
            %     obj.logWarning('参数 myParameter 超出有效范围 [0, 100]');
            %     isValid = false;
            %     return;
            % end

            % 默认实现：调用父类验证
            isValid = validate@ModuleBase(obj);

            if isValid
                obj.logDebug('配置验证通过');
            end
        end

        function schema = getInputSchema(obj)
            % getInputSchema 获取输入数据架构
            %
            % 输出:
            %   schema - struct, 输入架构定义
            %
            % 功能:
            %   - 定义输入数据的结构
            %   - 指定必需和可选字段
            %   - 说明字段类型和范围
            %
            % 注意:
            %   - 用于文档和自动验证
            %   - 建议重写以提供清晰的接口定义

            schema = struct();

            % TODO: 定义输入字段
            % 示例:
            % schema.fields = {
            %     struct('name', 'input1', 'type', 'double', 'required', true, 'description', '第一个输入参数');
            %     struct('name', 'input2', 'type', 'double', 'required', true, 'description', '第二个输入参数');
            %     struct('name', 'input3', 'type', 'string', 'required', false, 'description', '可选参数');
            % };

            schema.fields = {};
            schema.description = 'CustomModuleTemplate 输入数据架构';
        end

        function schema = getOutputSchema(obj)
            % getOutputSchema 获取输出数据架构
            %
            % 输出:
            %   schema - struct, 输出架构定义
            %
            % 功能:
            %   - 定义输出数据的结构
            %   - 说明返回字段的含义
            %   - 提供类型信息
            %
            % 注意:
            %   - 用于文档和接口说明
            %   - 建议重写以提供清晰的输出定义

            schema = struct();

            % TODO: 定义输出字段
            % 示例:
            % schema.fields = {
            %     struct('name', 'output1', 'type', 'double', 'description', '计算结果1');
            %     struct('name', 'output2', 'type', 'double', 'description', '计算结果2');
            %     struct('name', 'metadata', 'type', 'struct', 'description', '元数据');
            % };

            schema.fields = {};
            schema.description = 'CustomModuleTemplate 输出数据架构';
        end
    end

    % ==================== 私有辅助方法 ====================
    methods (Access = private)
        % TODO: 在这里添加你的私有辅助方法
        % 这些方法只能在类内部使用，用于实现具体的计算逻辑

        % 示例私有方法:
        % function result = myCalculation(obj, param1, param2)
        %     % myCalculation 执行某个计算
        %     %
        %     % 输入:
        %     %   param1 - double, 第一个参数
        %     %   param2 - double, 第二个参数
        %     %
        %     % 输出:
        %     %   result - double, 计算结果
        %
        %     result = param1 * param2 + obj.myParameter;
        % end
    end

    % ==================== 公共辅助方法（可选）====================
    methods (Access = public)
        % TODO: 在这里添加公共辅助方法（如果需要）
        % 这些方法可以被外部调用，用于提供额外的功能

        % 示例公共方法:
        % function printInfo(obj)
        %     % printInfo 打印模块信息
        %     fprintf('模块名称: %s\n', obj.getName());
        %     fprintf('版本: %s\n', obj.getVersion());
        %     fprintf('描述: %s\n', obj.getDescription());
        % end
    end
end
