classdef EvaluatorMetadata
    % EvaluatorMetadata
    % GUI metadata loader for evaluator integration (simple mode).
    %
    % Metadata convention:
    %   Put an `evaluator_meta.json` under `framework/problem/evaluator/`.
    %   The file can be a single object or an array of objects.
    %   Example fields:
    %     - type        (char)  canonical name (often the class name)
    %     - displayName (char)  optional, shown in GUI
    %     - class       (char)  optional class name
    %     - description (char)  optional, shown in GUI
    %     - aliases     (cell)  optional list of alias strings
    %     - parameters (array)  optional list of parameter definitions

    methods (Static)
        function metas = getAll(forceReload)
            if nargin < 1
                forceReload = false;
            end

            persistent cache;
            if isempty(cache) || forceReload
                cache = EvaluatorMetadata.loadFromDisk();
            end
            metas = cache;
        end

        function [items, itemsData] = getDropdownItems()
            items = {};
            itemsData = {};

            metas = EvaluatorMetadata.getAll(false);
            if isempty(metas)
                return;
            end

            for i = 1:length(metas)
                meta = metas(i);
                displayName = meta.displayName;
                if isempty(displayName)
                    displayName = meta.type;
                end
                className = meta.class;
                if isempty(className)
                    className = meta.type;
                end
                if isempty(displayName) || isempty(className)
                    continue;
                end
                items{end+1} = displayName; %#ok<AGROW>
                itemsData{end+1} = className; %#ok<AGROW>
            end

            % De-dup by className
            [itemsData, ia] = unique(itemsData, 'stable');
            items = items(ia);
        end

        function meta = getByType(type)
            meta = struct();
            if nargin < 1 || isempty(type)
                return;
            end

            metas = EvaluatorMetadata.getAll(false);
            if isempty(metas)
                return;
            end

            targetKey = EvaluatorMetadata.normalizeKey(type);
            for i = 1:length(metas)
                keys = EvaluatorMetadata.collectKeys(metas(i));
                if any(strcmp(keys, targetKey))
                    meta = metas(i);
                    return;
                end
            end
        end

        function params = getDefaultParameters(type)
            params = struct();
            meta = EvaluatorMetadata.getByType(type);
            if isempty(meta) || ~isstruct(meta)
                return;
            end

            if isfield(meta, 'parameters') && ~isempty(meta.parameters)
                for i = 1:length(meta.parameters)
                    p = meta.parameters(i);
                    if ~isfield(p, 'name') || isempty(p.name)
                        continue;
                    end
                    if isfield(p, 'default')
                        params.(char(string(p.name))) = p.default;
                    end
                end
            end
        end
    end

    methods (Static, Access = private)
        function metas = loadFromDisk()
            metas = struct('type', {}, 'displayName', {}, 'class', {}, 'description', {}, ...
                           'aliases', {}, 'parameters', {}, 'filePath', {});

            projectRoot = EvaluatorMetadata.getProjectRoot();
            evalRoot = fullfile(projectRoot, 'framework', 'problem', 'evaluator');
            if ~exist(evalRoot, 'dir')
                return;
            end

            allDirs = strsplit(genpath(evalRoot), pathsep);
            metaFiles = {};
            for i = 1:length(allDirs)
                dirPath = allDirs{i};
                if isempty(dirPath)
                    continue;
                end
                candidate = fullfile(dirPath, 'evaluator_meta.json');
                if exist(candidate, 'file')
                    metaFiles{end+1} = candidate; %#ok<AGROW>
                end
            end

            if isempty(metaFiles)
                return;
            end

            seenKeys = containers.Map('KeyType', 'char', 'ValueType', 'logical');
            for i = 1:length(metaFiles)
                filePath = metaFiles{i};
                try
                    raw = jsondecode(fileread(filePath));
                catch
                    continue;
                end

                entries = EvaluatorMetadata.expandEntries(raw);
                for j = 1:length(entries)
                    meta = EvaluatorMetadata.normalizeMeta(entries(j), filePath);
                    if isempty(meta.type) && isempty(meta.class)
                        continue;
                    end
                    key = EvaluatorMetadata.normalizeKey(EvaluatorMetadata.pickKey(meta));
                    if isempty(key)
                        continue;
                    end
                    if isKey(seenKeys, key)
                        continue;
                    end
                    seenKeys(key) = true;
                    metas(end+1) = meta; %#ok<AGROW>
                end
            end
        end

        function projectRoot = getProjectRoot()
            thisFile = mfilename('fullpath');
            helpersDir = fileparts(thisFile);
            guiDir = fileparts(helpersDir);
            projectRoot = fileparts(guiDir);
        end

        function entries = expandEntries(raw)
            entries = struct([]);
            if isempty(raw)
                return;
            end

            if isstruct(raw)
                if isfield(raw, 'evaluators')
                    entries = raw.evaluators;
                else
                    entries = raw;
                end
                return;
            end

            if iscell(raw)
                try
                    entries = [raw{:}];
                catch
                    entries = struct([]);
                end
            end
        end

        function meta = normalizeMeta(raw, filePath)
            meta = struct();
            meta.type = '';
            meta.displayName = '';
            meta.class = '';
            meta.description = '';
            meta.aliases = {};
            meta.parameters = struct([]);
            meta.filePath = filePath;

            if ~isstruct(raw)
                return;
            end

            if isfield(raw, 'type')
                meta.type = char(string(raw.type));
            end
            if isempty(meta.type) && isfield(raw, 'displayName')
                meta.type = char(string(raw.displayName));
            end

            if isfield(raw, 'displayName')
                meta.displayName = char(string(raw.displayName));
            else
                meta.displayName = meta.type;
            end

            if isfield(raw, 'class')
                meta.class = char(string(raw.class));
            elseif isfield(raw, 'className')
                meta.class = char(string(raw.className));
            end

            if isfield(raw, 'description')
                meta.description = char(string(raw.description));
            end

            if isfield(raw, 'aliases')
                aliases = raw.aliases;
                if isstring(aliases)
                    meta.aliases = cellstr(aliases);
                elseif iscell(aliases)
                    meta.aliases = aliases;
                elseif ischar(aliases)
                    meta.aliases = {aliases};
                end
            end

            if isfield(raw, 'parameters')
                params = raw.parameters;
                if isstruct(params)
                    meta.parameters = params;
                elseif iscell(params)
                    try
                        meta.parameters = [params{:}];
                    catch
                        meta.parameters = struct([]);
                    end
                end
            end
        end

        function keys = collectKeys(meta)
            keys = {};
            if ~isstruct(meta)
                return;
            end
            if isfield(meta, 'type') && ~isempty(meta.type)
                keys{end+1} = EvaluatorMetadata.normalizeKey(meta.type); %#ok<AGROW>
            end
            if isfield(meta, 'class') && ~isempty(meta.class)
                keys{end+1} = EvaluatorMetadata.normalizeKey(meta.class); %#ok<AGROW>
            end
            if isfield(meta, 'aliases') && ~isempty(meta.aliases)
                for i = 1:length(meta.aliases)
                    try
                        keys{end+1} = EvaluatorMetadata.normalizeKey(meta.aliases{i}); %#ok<AGROW>
                    catch
                    end
                end
            end
            keys = unique(keys, 'stable');
        end

        function key = pickKey(meta)
            key = '';
            if isfield(meta, 'class') && ~isempty(meta.class)
                key = meta.class;
                return;
            end
            if isfield(meta, 'type') && ~isempty(meta.type)
                key = meta.type;
            end
        end

        function key = normalizeKey(value)
            try
                value = char(string(value));
            catch
                value = '';
            end
            key = upper(regexprep(value, '[-_\\s]', ''));
        end
    end
end
