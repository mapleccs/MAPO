function out = run_smoke_all_algorithms(varargin)
%% run_smoke_all_algorithms - Convenience wrapper for run_smoke_algorithm('all', ...)
%
% Example:
%   out = run_smoke_all_algorithms('PopulationSize', 20, 'Iterations', 5);

    out = run_smoke_algorithm('all', varargin{:});
end
