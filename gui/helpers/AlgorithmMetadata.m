classdef AlgorithmMetadata
    % AlgorithmMetadata
    % A lightweight metadata loader for GUI algorithm integration.
    %
    % Metadata convention:
    %   Put an `algorithm_meta.json` under the algorithm folder (any depth under
    %   `framework/algorithm/`). Example fields:
    %     - type             (char)   canonical type shown in GUI (e.g. "NSGA-II")
    %     - displayName      (char)   optional, defaults to type
    %     - class            (char)   optional class name (e.g. "NSGAII")
    %     - description      (char)   optional, shown in GUI
    %     - aliases          (cell)   optional list of alias type strings
    %     - defaultParameters(struct) optional, used to prefill GUI parameters

    methods (Static)
        function metas = getAll(forceReload)
            % getAll Load all algorithm metadata (cached).
            if nargin < 1
                forceReload = false;
            end

            persistent cache;
            if isempty(cache) || forceReload
                cache = AlgorithmMetadata.loadFromDisk();
            end
            metas = cache;
        end

        function types = listTypes()
            % listTypes Return available algorithm types (from metadata).
            metas = AlgorithmMetadata.getAll(false);
            types = {};
            if isempty(metas)
                return;
            end
            types = {metas.type};
            types = types(~cellfun(@isempty, types));
            types = unique(types, 'stable');
            types = sort(types);
        end

        function meta = getByType(type)
            % getByType Find metadata by canonical type or alias (case-insensitive).
            meta = struct();
            if nargin < 1 || isempty(type)
                meta = struct();
                return;
            end

            metas = AlgorithmMetadata.getAll(false);
            if isempty(metas)
                meta = struct();
                return;
            end

            targetKey = AlgorithmMetadata.normalizeTypeKey(type);

            for i = 1:length(metas)
                candidateKeys = AlgorithmMetadata.collectTypeKeys(metas(i));
                if any(strcmp(candidateKeys, targetKey))
                    meta = metas(i);
                    return;
                end
            end

            meta = struct();
        end

        function params = getDefaultParameters(type)
            % getDefaultParameters Return default parameters for the given type.
            params = struct();
            meta = AlgorithmMetadata.getByType(type);
            if isempty(meta) || ~isstruct(meta)
                return;
            end
            if isfield(meta, 'defaultParameters') && isstruct(meta.defaultParameters)
                params = meta.defaultParameters;
            end
        end

        function desc = getDescription(type)
            % getDescription Return GUI description (metadata first, then factory).
            desc = '';
            meta = AlgorithmMetadata.getByType(type);
            if isstruct(meta) && ~isempty(fieldnames(meta)) && isfield(meta, 'description')
                desc = char(string(meta.description));
                return;
            end

            if exist('AlgorithmFactory', 'class') == 8
                try
                    desc = AlgorithmFactory.getAlgorithmInfo(type);
                catch
                    desc = '';
                end
            end
        end

        function tableData = toTableData(params)
            % toTableData Flatten parameters struct to a 2-column cell array.
            tableData = cell(0, 2);
            if nargin < 1 || isempty(params) || ~isstruct(params)
                return;
            end

            rows = AlgorithmMetadata.flattenStruct(params, '');
            if isempty(rows)
                return;
            end
            tableData = rows;
        end

        function params = fromTableData(tableData)
            % fromTableData Build (nested) parameters struct from a 2-column table.
            params = struct();
            if nargin < 1 || isempty(tableData) || ~iscell(tableData) || size(tableData, 2) < 2
                return;
            end

            for i = 1:size(tableData, 1)
                key = '';
                try
                    key = char(string(tableData{i, 1}));
                catch
                    key = '';
                end
                key = strtrim(key);
                if isempty(key)
                    continue;
                end

                rawVal = tableData{i, 2};
                if AlgorithmMetadata.isBlankValue(rawVal)
                    continue;
                end

                val = AlgorithmMetadata.parseValue(rawVal);
                params = AlgorithmMetadata.setNestedField(params, key, val);
            end
        end
    end

    methods (Static, Access = private)
        function metas = loadFromDisk()
            metas = struct('type', {}, 'displayName', {}, 'class', {}, 'description', {}, 'aliases', {}, 'defaultParameters', {}, 'filePath', {});

            projectRoot = AlgorithmMetadata.getProjectRoot();
            algRoot = fullfile(projectRoot, 'framework', 'algorithm');
            if ~exist(algRoot, 'dir')
                return;
            end

            % Find algorithm_meta.json under framework/algorithm/** via genpath
            allDirs = strsplit(genpath(algRoot), pathsep);
            metaFiles = {};
            for i = 1:length(allDirs)
                dirPath = allDirs{i};
                if isempty(dirPath)
                    continue;
                end
                candidate = fullfile(dirPath, 'algorithm_meta.json');
                if exist(candidate, 'file')
                    metaFiles{end+1} = candidate; %#ok<AGROW>
                end
            end

            if isempty(metaFiles)
                return;
            end

            % Load and normalize
            seenKeys = containers.Map('KeyType', 'char', 'ValueType', 'logical');
            for i = 1:length(metaFiles)
                filePath = metaFiles{i};
                try
                    raw = jsondecode(fileread(filePath));
                catch
                    continue;
                end

                meta = AlgorithmMetadata.normalizeMeta(raw, filePath);
                if isempty(meta.type)
                    continue;
                end

                key = AlgorithmMetadata.normalizeTypeKey(meta.type);
                if isKey(seenKeys, key)
                    continue;
                end
                seenKeys(key) = true;

                metas(end+1) = meta; %#ok<AGROW>
            end
        end

        function projectRoot = getProjectRoot()
            % getProjectRoot Return MAPO project root based on this file location.
            thisFile = mfilename('fullpath');
            helpersDir = fileparts(thisFile);
            guiDir = fileparts(helpersDir);
            projectRoot = fileparts(guiDir);
        end

        function meta = normalizeMeta(raw, filePath)
            meta = struct();
            meta.type = '';
            meta.displayName = '';
            meta.class = '';
            meta.description = '';
            meta.aliases = {};
            meta.defaultParameters = struct();
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

            if isfield(raw, 'defaultParameters') && isstruct(raw.defaultParameters)
                meta.defaultParameters = raw.defaultParameters;
            end

            % Filter unusable entries early (optional)
            if exist('AlgorithmFactory', 'class') == 8 && ~isempty(meta.type)
                try
                    if ~AlgorithmFactory.isRegistered(meta.type)
                        % Keep metadata, but GUI may choose to hide it.
                    end
                catch
                end
            end
        end

        function keys = collectTypeKeys(meta)
            keys = {};
            if ~isstruct(meta)
                return;
            end
            if isfield(meta, 'type') && ~isempty(meta.type)
                keys{end+1} = AlgorithmMetadata.normalizeTypeKey(meta.type); %#ok<AGROW>
            end
            if isfield(meta, 'aliases') && ~isempty(meta.aliases)
                for i = 1:length(meta.aliases)
                    try
                        keys{end+1} = AlgorithmMetadata.normalizeTypeKey(meta.aliases{i}); %#ok<AGROW>
                    catch
                    end
                end
            end
            keys = unique(keys, 'stable');
        end

        function key = normalizeTypeKey(type)
            try
                type = char(string(type));
            catch
                type = '';
            end
            key = upper(regexprep(type, '[-_\\s]', ''));
        end

        function rows = flattenStruct(s, prefix)
            rows = cell(0, 2);
            if isempty(s) || ~isstruct(s)
                return;
            end

            fields = fieldnames(s);
            for i = 1:length(fields)
                name = fields{i};
                try
                    val = s.(name);
                catch
                    continue;
                end

                if isempty(prefix)
                    key = name;
                else
                    key = [prefix '.' name];
                end

                if isstruct(val)
                    sub = AlgorithmMetadata.flattenStruct(val, key);
                    if ~isempty(sub)
                        rows = [rows; sub]; %#ok<AGROW>
                    end
                else
                    rows(end+1, :) = {key, AlgorithmMetadata.encodeValue(val)}; %#ok<AGROW>
                end
            end
        end

        function out = encodeValue(val)
            if isempty(val)
                out = '';
                return;
            end

            if ischar(val)
                out = val;
                return;
            end
            if isstring(val)
                out = char(val);
                return;
            end

            if isnumeric(val) || islogical(val)
                if isscalar(val)
                    out = val;
                else
                    try
                        out = char(jsonencode(val));
                    catch
                        out = '';
                    end
                end
                return;
            end

            try
                out = char(jsonencode(val));
            catch
                try
                    out = char(string(val));
                catch
                    out = '';
                end
            end
        end

        function tf = isBlankValue(val)
            tf = false;
            if isempty(val)
                tf = true;
                return;
            end
            if isstring(val) || ischar(val)
                tf = isempty(strtrim(char(string(val))));
            end
        end

        function val = parseValue(rawVal)
            if isnumeric(rawVal) || islogical(rawVal) || isstruct(rawVal)
                val = rawVal;
                return;
            end

            try
                txt = char(string(rawVal));
            catch
                val = rawVal;
                return;
            end

            txt = strtrim(txt);

            if strcmpi(txt, 'true')
                val = true;
                return;
            end
            if strcmpi(txt, 'false')
                val = false;
                return;
            end

            num = str2double(txt);
            if ~isnan(num) && isfinite(num)
                val = num;
                return;
            end

            if startsWith(txt, '[') || startsWith(txt, '{') || startsWith(txt, '"')
                try
                    val = jsondecode(txt);
                    return;
                catch
                end
            end

            val = txt;
        end

        function s = setNestedField(s, dottedKey, value)
            if ~isstruct(s)
                s = struct();
            end

            parts = strsplit(dottedKey, '.');
            if isempty(parts)
                return;
            end

            for i = 1:length(parts)
                parts{i} = strtrim(parts{i});
            end
            parts = parts(~cellfun(@isempty, parts));
            if isempty(parts)
                return;
            end

            current = s;
            for i = 1:(length(parts) - 1)
                name = parts{i};
                if ~isvarname(name)
                    return;
                end
                if ~isfield(current, name) || ~isstruct(current.(name))
                    current.(name) = struct();
                end
                current = current.(name);
            end

            leaf = parts{end};
            if ~isvarname(leaf)
                return;
            end

            % Write back (MATLAB struct copy semantics)
            s = AlgorithmMetadata.assignNested(s, parts, value);
        end

        function s = assignNested(s, parts, value)
            if length(parts) == 1
                s.(parts{1}) = value;
                return;
            end
            head = parts{1};
            tail = parts(2:end);
            if ~isfield(s, head) || ~isstruct(s.(head))
                s.(head) = struct();
            end
            s.(head) = AlgorithmMetadata.assignNested(s.(head), tail, value);
        end
    end
end

