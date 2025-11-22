function validateAspenNodes(simulator, nodeMap, type)
% validateAspenNodes 验证Aspen节点路径的有效性
%
% 功能：
%   检查所有配置的节点路径是否在Aspen模型中存在且可访问
%   帮助诊断节点路径配置错误
%
% 输入：
%   simulator - AspenPlusSimulator对象（已连接）
%   nodeMap - 节点映射的cell数组或结构体
%   type - 节点类型 ('input' 或 'output')
%
% 示例：
%   % 验证输入变量节点
%   inputNodes = {
%       'TOTAL_FLOW',  '\Data\Streams\OUT-P\Input\TOTFLOW\MIXED';
%       'SPLIT_RATIO', '\Data\Blocks\B2\Input\FRAC\S7';
%       'P_EVAP',      '\Data\Blocks\PUM\Input\PRES';
%       'P_COND',      '\Data\Blocks\TUR\Input\PRES'
%   };
%   validateAspenNodes(simulator, inputNodes, 'input');
%
%   % 验证输出结果节点
%   outputNodes = {
%       'W_TUR', '\Data\Blocks\TUR\Output\WORK';
%       'W_PUM', '\Data\Blocks\PUM\Output\WORK';
%       'Q_EV1', '\Data\Blocks\EV1\Output\QCALC';
%       'Q_EV2', '\Data\Blocks\EV2\Output\QCALC';
%       'Q_CON', '\Data\Blocks\CON\Output\QCALC'
%   };
%   validateAspenNodes(simulator, outputNodes, 'output');

    if nargin < 3
        type = 'unknown';
    end

    fprintf('\n========================================\n');
    fprintf('验证Aspen节点路径 (%s nodes)\n', type);
    fprintf('========================================\n\n');

    % 转换为统一格式
    if iscell(nodeMap)
        % Cell array格式
        numNodes = size(nodeMap, 1);
        varNames = nodeMap(:, 1);
        nodePaths = nodeMap(:, 2);
    elseif isstruct(nodeMap)
        % 结构体格式
        varNames = fieldnames(nodeMap);
        numNodes = length(varNames);
        nodePaths = cell(numNodes, 1);
        for i = 1:numNodes
            nodePaths{i} = nodeMap.(varNames{i});
        end
    else
        error('nodeMap必须是cell数组或结构体');
    end

    % 验证每个节点
    validCount = 0;
    invalidNodes = {};

    for i = 1:numNodes
        varName = varNames{i};
        nodePath = nodePaths{i};

        fprintf('[%d/%d] 验证 %s:\n', i, numNodes, varName);
        fprintf('  路径: %s\n', nodePath);

        try
            % 尝试访问节点
            node = simulator.aspenApp.Tree.FindNode(nodePath);

            % 检查节点有效性
            if isempty(node)
                fprintf('  ✗ 错误: 节点不存在\n');
                invalidNodes{end+1} = sprintf('%s: 节点不存在', varName);
            elseif strcmp(class(node), 'handle')
                fprintf('  ✗ 错误: 返回无效的handle对象（路径可能错误）\n');
                invalidNodes{end+1} = sprintf('%s: 无效的handle对象', varName);
            else
                % 尝试读取值
                try
                    value = node.Value;
                    fprintf('  ✓ 成功: 节点有效，当前值 = %s\n', num2str(value));
                    validCount = validCount + 1;

                    % 对于输入节点，检查是否可写
                    if strcmpi(type, 'input')
                        try
                            oldValue = value;
                            node.Value = value;  % 尝试写入相同的值
                            fprintf('  ✓ 可写: 节点支持设置值\n');
                        catch
                            fprintf('  ⚠ 警告: 节点可能是只读的\n');
                        end
                    end

                catch ME
                    fprintf('  ✗ 错误: 无法访问Value属性 - %s\n', ME.message);
                    invalidNodes{end+1} = sprintf('%s: 无法访问Value属性', varName);
                end
            end

        catch ME
            fprintf('  ✗ 错误: %s\n', ME.message);
            invalidNodes{end+1} = sprintf('%s: %s', varName, ME.message);
        end

        fprintf('\n');
    end

    % 总结
    fprintf('========================================\n');
    fprintf('验证结果总结\n');
    fprintf('========================================\n');
    fprintf('总节点数: %d\n', numNodes);
    fprintf('有效节点: %d (%.1f%%)\n', validCount, validCount/numNodes*100);
    fprintf('无效节点: %d (%.1f%%)\n', numNodes-validCount, (numNodes-validCount)/numNodes*100);

    if ~isempty(invalidNodes)
        fprintf('\n无效节点列表:\n');
        for i = 1:length(invalidNodes)
            fprintf('  • %s\n', invalidNodes{i});
        end

        fprintf('\n建议:\n');
        fprintf('1. 在Aspen Plus中使用Variable Explorer查看正确的节点路径\n');
        fprintf('2. 检查流股和设备名称是否正确\n');
        fprintf('3. 确认节点类型（Input vs Output）\n');
        fprintf('4. 验证路径中的MIXED后缀是否必要\n');
    else
        fprintf('\n✓ 所有节点路径验证成功！\n');
    end

    fprintf('========================================\n\n');
end