classdef (Abstract) IModule < handle
    % IModule 模块接口
    % Module Interface for the Plugin System
    %
    % 功能:
    %   - 定义模块的标准接口
    %   - 规范模块的生命周期
    %   - 统一配置和数据交互方式
    %   - 支持模块元数据和依赖管理
    %
    % 模块生命周期:
    %   1. configure()  - 配置模块参数
    %   2. validate()   - 验证配置有效性
    %   3. initialize() - 初始化模块资源
    %   4. execute()    - 执行模块功能（可多次调用）
    %   5. finalize()   - 清理模块资源
    %
    % 实现示例:
    %   classdef MyModule < ModuleBase
    %       methods
    %           function obj = MyModule()
    %               obj@ModuleBase('MyModule', '1.0.0', '我的自定义模块');
    %           end
    %
    %           function result = execute(obj, inputData)
    %               % 实现具体功能
    %               result = struct();
    %               result.output = inputData.input * 2;
    %           end
    %       end
    %   end
    %
    % 使用示例:
    %   % 创建模块实例
    %   module = MyModule();
    %
    %   % 配置模块
    %   config = struct('param1', 10);
    %   module.configure(config);
    %
    %   % 验证配置
    %   if module.validate()
    %       % 初始化模块
    %       module.initialize();
    %
    %       % 执行模块
    %       inputData = struct('input', 5);
    %       result = module.execute(inputData);
    %
    %       % 清理资源
    %       module.finalize();
    %   end


    properties (Abstract, Access = protected)
        % 模块配置（子类必须定义）
        config;
    end

    methods (Abstract)
        % ==================== 生命周期方法 ====================

        initialize(obj)
        % initialize 初始化模块
        %
        % 功能:
        %   - 分配资源
        %   - 建立连接
        %   - 加载数据
        %   - 准备模块执行环境
        %
        % 注意:
        %   - 必须在execute()之前调用
        %   - 应该是幂等的（多次调用结果相同）
        %   - 失败时应该抛出异常

        result = execute(obj, inputData)
        % execute 执行模块功能
        %
        % 输入:
        %   inputData - struct, 输入数据（格式由getInputSchema()定义）
        %
        % 输出:
        %   result - struct, 输出结果（格式由getOutputSchema()定义）
        %
        % 功能:
        %   - 实现模块的核心功能
        %   - 处理输入数据
        %   - 返回计算结果
        %
        % 注意:
        %   - 可以被多次调用
        %   - 应该是无副作用的（除了记录日志）
        %   - 输入验证应该在此方法中进行

        finalize(obj)
        % finalize 清理模块资源
        %
        % 功能:
        %   - 释放资源
        %   - 关闭连接
        %   - 保存状态
        %   - 清理临时数据
        %
        % 注意:
        %   - 应该在模块使用完成后调用
        %   - 应该是幂等的
        %   - 即使initialize()失败也应该能安全调用

        % ==================== 元数据方法 ====================

        name = getName(obj)
        % getName 获取模块名称
        %
        % 输出:
        %   name - string, 模块的唯一名称
        %
        % 示例:
        %   'SeiderCostModule'
        %   'EmissionCalculator'

        ver = getVersion(obj)
        % getVersion 获取模块版本
        %
        % 输出:
        %   ver - string, 语义化版本号 (MAJOR.MINOR.PATCH)
        %
        % 示例:
        %   '1.0.0'
        %   '2.1.3-beta'

        desc = getDescription(obj)
        % getDescription 获取模块描述
        %
        % 输出:
        %   desc - string, 模块功能的简短描述
        %
        % 示例:
        %   '基于Seider方法的设备成本估算模块'

        deps = getDependencies(obj)
        % getDependencies 获取模块依赖
        %
        % 输出:
        %   deps - cell array of strings, 依赖的模块名称列表
        %
        % 示例:
        %   {'ConfigModule', 'LoggerModule'}
        %   {}  % 无依赖
        %
        % 注意:
        %   - ModuleManager会根据此信息自动加载依赖
        %   - 循环依赖会导致加载失败

        % ==================== 配置管理 ====================

        configure(obj, config)
        % configure 配置模块
        %
        % 输入:
        %   config - struct, 配置参数
        %
        % 功能:
        %   - 设置模块参数
        %   - 存储配置信息
        %   - 不进行验证（验证在validate()中）
        %
        % 注意:
        %   - 必须在initialize()之前调用
        %   - 可以多次调用以更新配置

        isValid = validate(obj)
        % validate 验证配置
        %
        % 输出:
        %   isValid - logical, 配置是否有效
        %
        % 功能:
        %   - 检查必需参数是否存在
        %   - 验证参数范围和类型
        %   - 检查依赖是否满足
        %
        % 注意:
        %   - 应该在initialize()之前调用
        %   - 验证失败时可以通过getLogger()输出错误信息

        % ==================== 数据架构 ====================

        schema = getInputSchema(obj)
        % getInputSchema 获取输入数据架构
        %
        % 输出:
        %   schema - struct, 输入数据的结构定义
        %
        % 功能:
        %   - 定义execute()方法期望的输入格式
        %   - 用于文档生成和数据验证
        %   - 帮助用户正确调用模块
        %
        % 返回格式:
        %   schema.fields = {
        %       struct('name', 'temperature', 'type', 'double', 'required', true, ...
        %              'description', '操作温度(K)', 'range', [273, 573]);
        %       struct('name', 'pressure', 'type', 'double', 'required', true, ...
        %              'description', '操作压力(Pa)', 'range', [1e5, 1e7]);
        %   };
        %
        % 注意:
        %   - 可以返回空struct表示不限制输入格式

        schema = getOutputSchema(obj)
        % getOutputSchema 获取输出数据架构
        %
        % 输出:
        %   schema - struct, 输出数据的结构定义
        %
        % 功能:
        %   - 定义execute()方法返回的数据格式
        %   - 用于文档生成和结果处理
        %   - 帮助下游模块正确使用输出
        %
        % 返回格式:
        %   schema.fields = {
        %       struct('name', 'totalCost', 'type', 'double', 'unit', 'USD', ...
        %              'description', '总设备成本');
        %       struct('name', 'breakdown', 'type', 'struct', ...
        %              'description', '成本分解详情');
        %   };
        %
        % 注意:
        %   - 可以返回空struct表示输出格式不固定
    end

    methods
        % ==================== 辅助方法（可选重写） ====================

        function tags = getTags(obj)
            % getTags 获取模块标签
            %
            % 输出:
            %   tags - cell array of strings, 模块标签列表
            %
            % 功能:
            %   - 用于模块分类和搜索
            %   - 帮助用户发现相关模块
            %
            % 示例:
            %   {'cost', 'economics', 'estimation'}
            %   {'emission', 'environment', 'sustainability'}
            %
            % 默认实现返回空列表
            tags = {};
        end

        function author = getAuthor(obj)
            % getAuthor 获取模块作者
            %
            % 输出:
            %   author - string, 模块作者信息
            %
            % 示例:
            %   '开发团队'
            %   'John Doe <john@example.com>'
            %
            % 默认实现返回空字符串
            author = '';
        end

        function license = getLicense(obj)
            % getLicense 获取模块许可证
            %
            % 输出:
            %   license - string, 许可证类型
            %
            % 示例:
            %   'MIT'
            %   'Apache-2.0'
            %   'Proprietary'
            %
            % 默认实现返回空字符串
            license = '';
        end

        function info = getInfo(obj)
            % getInfo 获取模块完整信息
            %
            % 输出:
            %   info - struct, 包含所有元数据
            %
            % 功能:
            %   - 汇总所有模块信息
            %   - 便于展示和调试
            %
            % 返回字段:
            %   - name: 模块名称
            %   - version: 版本号
            %   - description: 描述
            %   - dependencies: 依赖列表
            %   - tags: 标签列表
            %   - author: 作者
            %   - license: 许可证

            info = struct();
            info.name = obj.getName();
            info.version = obj.getVersion();
            info.description = obj.getDescription();
            info.dependencies = obj.getDependencies();
            info.tags = obj.getTags();
            info.author = obj.getAuthor();
            info.license = obj.getLicense();
        end

        function printInfo(obj)
            % printInfo 打印模块信息
            %
            % 功能:
            %   - 格式化输出模块元数据
            %   - 便于调试和文档生成

            info = obj.getInfo();
            fprintf('========================================\n');
            fprintf('模块信息\n');
            fprintf('========================================\n');
            fprintf('名称: %s\n', info.name);
            fprintf('版本: %s\n', info.version);
            fprintf('描述: %s\n', info.description);

            if ~isempty(info.dependencies)
                fprintf('依赖: %s\n', strjoin(info.dependencies, ', '));
            else
                fprintf('依赖: 无\n');
            end

            if ~isempty(info.tags)
                fprintf('标签: %s\n', strjoin(info.tags, ', '));
            end

            if ~isempty(info.author)
                fprintf('作者: %s\n', info.author);
            end

            if ~isempty(info.license)
                fprintf('许可: %s\n', info.license);
            end

            fprintf('========================================\n');
        end
    end
end
