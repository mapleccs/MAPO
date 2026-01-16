classdef UnitRegistry
    % UnitRegistry - Parse and convert unit expressions with dimension checks.

    methods (Static)
        function u = parseUnit(unitStr)
            % parseUnit - Parse unit string into scale and dimension vector.
            % Returns struct with fields: scale, dims, text.
            if nargin < 1 || isempty(unitStr)
                u = UnitRegistry.unitStruct(1, UnitRegistry.zeroDims(), '');
                return;
            end

            text = UnitRegistry.normalizeUnitString(unitStr);
            if isempty(text)
                u = UnitRegistry.unitStruct(1, UnitRegistry.zeroDims(), '');
                return;
            end

            tokens = UnitRegistry.tokenizeUnit(text);
            rpn = UnitRegistry.toRpn(tokens);
            stack = {};
            for i = 1:numel(rpn)
                tok = rpn{i};
                if ischar(tok)
                    if strcmp(tok, '*') || strcmp(tok, '/') || strcmp(tok, '^')
                        stack = UnitRegistry.applyUnitOperator(stack, tok);
                    else
                        stack{end+1} = UnitRegistry.resolveUnitToken(tok); %#ok<AGROW>
                    end
                else
                    % numeric exponent
                    stack{end+1} = tok; %#ok<AGROW>
                end
            end

            if numel(stack) ~= 1
                error('UnitRegistry:ParseError', 'Unable to parse unit: %s', unitStr);
            end
            u = stack{1};
            u.text = unitStr;
        end

        function valueBase = toBase(value, unitStr)
            % toBase - Convert value in unitStr to base units.
            u = UnitRegistry.parseUnit(unitStr);
            valueBase = value * u.scale;
        end

        function value = fromBase(valueBase, unitStr)
            % fromBase - Convert value in base units to unitStr.
            u = UnitRegistry.parseUnit(unitStr);
            value = valueBase / u.scale;
        end

        function tf = sameDims(d1, d2)
            tf = all(abs(d1 - d2) < 1e-9);
        end

        function tf = isDimensionless(dims)
            tf = all(abs(dims) < 1e-9);
        end
    end

    methods (Static, Access = private)
        function u = unitStruct(scale, dims, text)
            u = struct('scale', scale, 'dims', dims, 'text', text);
        end

        function dims = zeroDims()
            dims = zeros(1, 8);
        end

        function text = normalizeUnitString(text)
            text = strtrim(char(string(text)));
            if isempty(text)
                return;
            end

            % Normalize common separators.
            text = strrep(text, '·', '*');
            text = regexprep(text, '\s+', '*');

            % Normalize common Chinese units.
            text = strrep(text, '年', 'year');
            text = strrep(text, '小时', 'h');
            text = strrep(text, '天', 'day');
            text = strrep(text, '吨', 'ton');

            % Normalize micro sign.
            text = strrep(text, 'μ', 'u');
            text = strrep(text, 'µ', 'u');
        end

        function tokens = tokenizeUnit(text)
            tokens = {};
            i = 1;
            n = length(text);
            while i <= n
                ch = text(i);
                if ch == ' ' || ch == char(9)
                    i = i + 1;
                    continue;
                end
                if any(ch == ['*', '/', '^', '(', ')'])
                    tokens{end+1} = ch; %#ok<AGROW>
                    i = i + 1;
                    continue;
                end
                if isstrprop(ch, 'digit') || ch == '.'
                    j = i + 1;
                    while j <= n && (isstrprop(text(j), 'digit') || text(j) == '.')
                        j = j + 1;
                    end
                    tokens{end+1} = str2double(text(i:j-1)); %#ok<AGROW>
                    i = j;
                    continue;
                end
                % unit token (letters, $)
                j = i + 1;
                while j <= n && (isstrprop(text(j), 'alpha') || text(j) == '$')
                    j = j + 1;
                end
                token = text(i:j-1);
                tokens{end+1} = token; %#ok<AGROW>
                i = j;
            end

            % Handle suffix exponents like m2 -> m ^ 2
            out = {};
            for i = 1:numel(tokens)
                tok = tokens{i};
                if ischar(tok)
                    [baseTok, expTok] = UnitRegistry.splitSuffixExponent(tok);
                    out{end+1} = baseTok; %#ok<AGROW>
                    if ~isempty(expTok)
                        out{end+1} = '^'; %#ok<AGROW>
                        out{end+1} = expTok; %#ok<AGROW>
                    end
                else
                    out{end+1} = tok; %#ok<AGROW>
                end
            end
            tokens = out;
        end

        function [baseTok, expTok] = splitSuffixExponent(tok)
            baseTok = tok;
            expTok = [];
            if isempty(tok)
                return;
            end
            idx = regexp(tok, '^[A-Za-z$]+([0-9]+)$', 'tokens');
            if isempty(idx)
                return;
            end
            baseTok = tok(1:end-length(idx{1}{1}));
            expTok = str2double(idx{1}{1});
        end

        function rpn = toRpn(tokens)
            rpn = {};
            stack = {};
            prec = UnitRegistry.unitPrecedence();
            for i = 1:numel(tokens)
                tok = tokens{i};
                if ischar(tok) && any(strcmp(tok, {'*', '/', '^'}))
                    while ~isempty(stack)
                        top = stack{end};
                        if ischar(top) && any(strcmp(top, {'*', '/', '^'})) && ...
                                ((~strcmp(tok, '^') && prec(top) >= prec(tok)) || ...
                                 (strcmp(tok, '^') && prec(top) > prec(tok)))
                            rpn{end+1} = top; %#ok<AGROW>
                            stack(end) = [];
                        else
                            break;
                        end
                    end
                    stack{end+1} = tok; %#ok<AGROW>
                elseif ischar(tok) && strcmp(tok, '(')
                    stack{end+1} = tok; %#ok<AGROW>
                elseif ischar(tok) && strcmp(tok, ')')
                    while ~isempty(stack) && ~strcmp(stack{end}, '(')
                        rpn{end+1} = stack{end}; %#ok<AGROW>
                        stack(end) = [];
                    end
                    if isempty(stack)
                        error('UnitRegistry:ParseError', 'Mismatched parentheses in unit.');
                    end
                    stack(end) = [];
                else
                    rpn{end+1} = tok; %#ok<AGROW>
                end
            end
            while ~isempty(stack)
                if strcmp(stack{end}, '(')
                    error('UnitRegistry:ParseError', 'Mismatched parentheses in unit.');
                end
                rpn{end+1} = stack{end}; %#ok<AGROW>
                stack(end) = [];
            end
        end

        function stack = applyUnitOperator(stack, op)
            if isempty(stack) || (strcmp(op, '^') && numel(stack) < 2)
                error('UnitRegistry:ParseError', 'Invalid unit operator.');
            end
            if strcmp(op, '^')
                expVal = stack{end};
                base = stack{end-1};
                stack(end-1:end) = [];
                if ~isnumeric(expVal)
                    error('UnitRegistry:ParseError', 'Unit exponent must be numeric.');
                end
                base.scale = base.scale ^ expVal;
                base.dims = base.dims * expVal;
                stack{end+1} = base;
                return;
            end
            right = stack{end};
            left = stack{end-1};
            stack(end-1:end) = [];
            if strcmp(op, '*')
                out.scale = left.scale * right.scale;
                out.dims = left.dims + right.dims;
            else
                out.scale = left.scale / right.scale;
                out.dims = left.dims - right.dims;
            end
            out.text = '';
            stack{end+1} = out;
        end

        function u = resolveUnitToken(token)
            unitMap = UnitRegistry.unitMap();
            if isKey(unitMap, token)
                u = unitMap(token);
                return;
            end

            % Try case-insensitive match
            tokenLower = lower(token);
            unitMapLower = UnitRegistry.unitMapLower();
            if isKey(unitMapLower, tokenLower)
                u = unitMapLower(tokenLower);
                return;
            end

            % Try prefix + base
            [prefixes, prefixScale] = UnitRegistry.prefixes();
            for i = 1:numel(prefixes)
                p = prefixes{i};
                if strncmp(token, p, length(p))
                    baseToken = token(length(p) + 1:end);
                    if isempty(baseToken)
                        continue;
                    end
                    if isKey(unitMap, baseToken)
                        base = unitMap(baseToken);
                    else
                        baseLower = lower(baseToken);
                        if isKey(unitMapLower, baseLower)
                            base = unitMapLower(baseLower);
                        else
                            continue;
                        end
                    end
                    u = base;
                    u.scale = u.scale * prefixScale(i);
                    return;
                end
            end

            error('UnitRegistry:UnknownUnit', 'Unknown unit token: %s', token);
        end

        function prec = unitPrecedence()
            prec = containers.Map({'^', '*', '/'}, [3, 2, 2]);
        end

        function [prefixes, scales] = prefixes()
            prefixes = {'da', 'Y', 'Z', 'E', 'P', 'T', 'G', 'M', 'k', 'h', 'd', 'c', 'm', 'u', 'n', 'p', 'f'};
            scales = [1e1, 1e24, 1e21, 1e18, 1e15, 1e12, 1e9, 1e6, 1e3, 1e2, 1e-1, 1e-2, 1e-3, 1e-6, 1e-9, 1e-12, 1e-15];
        end

        function map = unitMap()
            map = containers.Map('KeyType', 'char', 'ValueType', 'any');

            dims = UnitRegistry.zeroDims();

            % Base units
            map('kg') = UnitRegistry.unitStruct(1, UnitRegistry.dimVec(1,0,0,0,0,0,0,0), 'kg');
            map('g') = UnitRegistry.unitStruct(1e-3, UnitRegistry.dimVec(1,0,0,0,0,0,0,0), 'g');
            map('m') = UnitRegistry.unitStruct(1, UnitRegistry.dimVec(0,1,0,0,0,0,0,0), 'm');
            map('s') = UnitRegistry.unitStruct(1, UnitRegistry.dimVec(0,0,1,0,0,0,0,0), 's');
            map('K') = UnitRegistry.unitStruct(1, UnitRegistry.dimVec(0,0,0,1,0,0,0,0), 'K');
            map('mol') = UnitRegistry.unitStruct(1, UnitRegistry.dimVec(0,0,0,0,1,0,0,0), 'mol');
            map('A') = UnitRegistry.unitStruct(1, UnitRegistry.dimVec(0,0,0,0,0,1,0,0), 'A');
            map('cd') = UnitRegistry.unitStruct(1, UnitRegistry.dimVec(0,0,0,0,0,0,1,0), 'cd');
            map('USD') = UnitRegistry.unitStruct(1, UnitRegistry.dimVec(0,0,0,0,0,0,0,1), 'USD');
            map('$') = map('USD');

            % Time units
            map('min') = UnitRegistry.unitStruct(60, UnitRegistry.dimVec(0,0,1,0,0,0,0,0), 'min');
            map('h') = UnitRegistry.unitStruct(3600, UnitRegistry.dimVec(0,0,1,0,0,0,0,0), 'h');
            map('hr') = map('h');
            map('day') = UnitRegistry.unitStruct(24 * 3600, UnitRegistry.dimVec(0,0,1,0,0,0,0,0), 'day');
            map('workday') = UnitRegistry.unitStruct((8000 / 330) * 3600, UnitRegistry.dimVec(0,0,1,0,0,0,0,0), 'workday');
            map('year') = UnitRegistry.unitStruct(8000 * 3600, UnitRegistry.dimVec(0,0,1,0,0,0,0,0), 'year');
            map('yr') = map('year');

            % Mass units
            map('ton') = UnitRegistry.unitStruct(1000, UnitRegistry.dimVec(1,0,0,0,0,0,0,0), 'ton');
            map('tonne') = map('ton');
            map('t') = map('ton');

            % Derived units
            map('N') = UnitRegistry.unitStruct(1, UnitRegistry.dimVec(1,1,-2,0,0,0,0,0), 'N');
            map('Pa') = UnitRegistry.unitStruct(1, UnitRegistry.dimVec(1,-1,-2,0,0,0,0,0), 'Pa');
            map('bar') = UnitRegistry.unitStruct(1e5, UnitRegistry.dimVec(1,-1,-2,0,0,0,0,0), 'bar');
            map('J') = UnitRegistry.unitStruct(1, UnitRegistry.dimVec(1,2,-2,0,0,0,0,0), 'J');
            map('W') = UnitRegistry.unitStruct(1, UnitRegistry.dimVec(1,2,-3,0,0,0,0,0), 'W');
            map('Wh') = UnitRegistry.unitStruct(3600, UnitRegistry.dimVec(1,2,-2,0,0,0,0,0), 'Wh');
            map('L') = UnitRegistry.unitStruct(1e-3, UnitRegistry.dimVec(0,3,0,0,0,0,0,0), 'L');
        end

        function map = unitMapLower()
            map = containers.Map('KeyType', 'char', 'ValueType', 'any');
            unitMap = UnitRegistry.unitMap();
            keysList = unitMap.keys();
            for i = 1:numel(keysList)
                key = keysList{i};
                map(lower(key)) = unitMap(key);
            end
        end

        function dims = dimVec(mass, length, time, temp, amount, current, luminous, currency)
            dims = [mass, length, time, temp, amount, current, luminous, currency];
        end
    end
end

