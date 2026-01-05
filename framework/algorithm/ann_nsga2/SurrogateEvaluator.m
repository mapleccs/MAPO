classdef SurrogateEvaluator < handle
    % SurrogateEvaluator
    % A lightweight evaluator adapter used by surrogate-assisted algorithms.

    properties (Access = private)
        model
        evaluationCount
    end

    methods
        function obj = SurrogateEvaluator(model)
            if nargin < 1 || isempty(model)
                error('SurrogateEvaluator:InvalidInput', 'Surrogate model is required.');
            end

            obj.model = model;
            obj.evaluationCount = 0;
        end

        function result = evaluate(obj, variables)
            obj.evaluationCount = obj.evaluationCount + 1;

            [objectives, constraints, success, message] = obj.predict(variables);

            result = struct();
            result.objectives = objectives;
            result.constraints = constraints;
            result.success = success;
            result.message = message;
        end

        function count = getEvaluationCount(obj)
            count = obj.evaluationCount;
        end

        function resetCount(obj)
            obj.evaluationCount = 0;
        end
    end

    methods (Access = private)
        function [objectives, constraints, success, message] = predict(obj, variables)
            success = true;
            message = '';

            nObjectives = obj.model.nObjectives;
            nConstraints = obj.model.nConstraints;

            try
                x = variables(:)';
                xz = (x - obj.model.inputMean) ./ obj.model.inputStd;

                switch lower(obj.model.type)
                    case 'poly2'
                        phi = SurrogateEvaluator.buildPoly2Features(xz);
                        yz = phi * obj.model.W;

                    case 'ann'
                        yz = obj.model.net(xz')';

                    otherwise
                        error('SurrogateEvaluator:UnknownModel', ...
                            'Unknown surrogate type: %s', obj.model.type);
                end

                y = yz .* obj.model.outputStd + obj.model.outputMean;

                if any(~isfinite(y))
                    error('SurrogateEvaluator:NonFinite', 'Non-finite surrogate prediction.');
                end

                objectives = y(1:nObjectives);
                if nConstraints > 0
                    constraints = y(nObjectives + 1:nObjectives + nConstraints);
                else
                    constraints = [];
                end
            catch ME
                success = false;
                message = ME.message;

                penalty = obj.model.penaltyValue;
                objectives = penalty * ones(1, nObjectives);
                constraints = penalty * ones(1, nConstraints);
            end
        end
    end

    methods (Static)
        function phi = buildPoly2Features(x)
            x = x(:)';
            d = numel(x);

            p = 1 + 2 * d + d * (d - 1) / 2;
            phi = zeros(1, p);

            phi(1) = 1;
            phi(2:1 + d) = x;
            phi(2 + d:1 + 2 * d) = x .^ 2;

            k = 1 + 2 * d;
            for i = 1:(d - 1)
                for j = (i + 1):d
                    k = k + 1;
                    phi(k) = x(i) * x(j);
                end
            end
        end

        function Phi = buildPoly2FeatureMatrix(X)
            [n, d] = size(X);

            p = 1 + 2 * d + d * (d - 1) / 2;
            Phi = zeros(n, p);

            Phi(:, 1) = 1;
            Phi(:, 2:1 + d) = X;
            Phi(:, 2 + d:1 + 2 * d) = X .^ 2;

            col = 1 + 2 * d;
            for i = 1:(d - 1)
                for j = (i + 1):d
                    col = col + 1;
                    Phi(:, col) = X(:, i) .* X(:, j);
                end
            end
        end
    end
end
