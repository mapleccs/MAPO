classdef AspenConvergenceEvaluator < IConvergenceEvaluator
    % AspenConvergenceEvaluator - Aspen Plus收敛性评估器
    %
    % 描述:
    %   专门用于检查Aspen Plus仿真的收敛性
    %   通过检查仿真器状态和结果有效性判断收敛
    %
    % 作者: MAPO Framework
    % 日期: 2024

    properties
        checkSimulatorStatus = true  % 是否检查仿真器状态
        checkResultValidity = true   % 是否检查结果有效性
        penaltyThreshold = 1e6      % 惩罚值阈值（超过此值认为未收敛）
    end

    methods
        function obj = AspenConvergenceEvaluator(varargin)
            % 构造函数
            %
            % 可选参数（名称-值对）:
            %   'CheckSimulatorStatus' - 是否检查仿真器状态
            %   'CheckResultValidity' - 是否检查结果有效性
            %   'PenaltyThreshold' - 惩罚值阈值

            if nargin > 0
                p = inputParser;
                addParameter(p, 'CheckSimulatorStatus', true, @islogical);
                addParameter(p, 'CheckResultValidity', true, @islogical);
                addParameter(p, 'PenaltyThreshold', 1e6, @(x) x > 0);
                parse(p, varargin{:});

                obj.checkSimulatorStatus = p.Results.CheckSimulatorStatus;
                obj.checkResultValidity = p.Results.CheckResultValidity;
                obj.penaltyThreshold = p.Results.PenaltyThreshold;
            end
        end

        function converged = check(obj, result, simulator)
            % 检查Aspen Plus仿真是否收敛
            %
            % 输入:
            %   result - 评估结果
            %   simulator - AspenPlusSimulator对象（可选）
            %
            % 输出:
            %   converged - true表示收敛

            converged = true;

            % 检查结果是否存在
            if isempty(result)
                converged = false;
                return;
            end

            % 检查结果有效性
            if obj.checkResultValidity
                if ~isfield(result, 'objectives') || isempty(result.objectives)
                    converged = false;
                    return;
                end

                % 检查是否有NaN或Inf
                if any(isnan(result.objectives)) || any(isinf(result.objectives))
                    converged = false;
                    return;
                end

                % 检查是否超过惩罚阈值
                if any(abs(result.objectives) > obj.penaltyThreshold)
                    converged = false;
                    return;
                end
            end

            % 检查仿真器状态
            if obj.checkSimulatorStatus && nargin >= 3 && ~isempty(simulator)
                % 如果有仿真器对象，可以检查其内部状态
                if isprop(simulator, 'lastRunStatus')
                    if ~simulator.lastRunStatus
                        converged = false;
                        return;
                    end
                end

                % 可以添加更多的仿真器状态检查
                % 例如：检查Aspen历史文件、检查特定的错误标志等
            end
        end

        function description = getDescription(obj)
            % 获取评估器描述
            description = 'Aspen Plus收敛性评估器';
            if obj.checkSimulatorStatus
                description = [description, ' (检查仿真器状态)'];
            end
            if obj.checkResultValidity
                description = [description, ' (检查结果有效性)'];
            end
        end
    end
end