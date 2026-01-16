classdef ExpressionEngine
    % ExpressionEngine - Parse and evaluate math expressions with unit checks.

    methods (Static)
        function compiled = compile(exprText)
            if nargin < 1
                error('ExpressionEngine:MissingExpression', 'Expression text is required.');
            end
            exprText = char(string(exprText));
            tokens = ExpressionEngine.tokenize(exprText);
            rpn = ExpressionEngine.toRpn(tokens);
            ids = ExpressionEngine.collectIdentifiers(tokens);
            compiled = struct();
            compiled.expression = exprText;
            compiled.tokens = rpn;
            compiled.identifiers = ids;
        end

        function [value, dims] = evaluate(compiled, context)
            % evaluate - Evaluate a compiled expression.
            if ~isfield(compiled, 'tokens')
                error('ExpressionEngine:InvalidCompiled', 'Compiled expression missing tokens.');
            end
            if ~isfield(context, 'lookup') || ~isa(context.lookup, 'function_handle')
                error('ExpressionEngine:InvalidContext', 'Context.lookup function is required.');
            end

            stack = {};
            tokens = compiled.tokens;
            for i = 1:numel(tokens)
                tok = tokens{i};
                switch tok.type
                    case 'number'
                        if isempty(tok.unit)
                            u = UnitRegistry.parseUnit('');
                        else
                            u = UnitRegistry.parseUnit(tok.unit);
                        end
                        item.value = tok.value * u.scale;
                        item.dims = u.dims;
                        stack{end+1} = item; %#ok<AGROW>

                    case 'identifier'
                        item = context.lookup(tok.value);
                        stack{end+1} = item; %#ok<AGROW>

                    case 'operator'
                        stack = ExpressionEngine.applyOperator(stack, tok.value);

                    case 'function'
                        stack = ExpressionEngine.applyFunction(stack, tok.value, tok.arity);

                    otherwise
                        error('ExpressionEngine:InvalidToken', 'Unknown token type: %s', tok.type);
                end
            end

            if numel(stack) ~= 1
                error('ExpressionEngine:EvalError', 'Invalid expression evaluation state.');
            end
            value = stack{1}.value;
            dims = stack{1}.dims;
        end
    end

    methods (Static, Access = private)
        function tokens = tokenize(exprText)
            tokens = {};
            i = 1;
            n = length(exprText);
            prevType = 'start';
            while i <= n
                ch = exprText(i);
                if isspace(ch)
                    i = i + 1;
                    continue;
                end

                if isstrprop(ch, 'digit') || ch == '.'
                    [numVal, nextIdx] = ExpressionEngine.readNumber(exprText, i);
                    i = nextIdx;
                    unitStr = '';
                    if i <= n && exprText(i) == '['
                        [unitStr, nextIdx] = ExpressionEngine.readUnitBracket(exprText, i);
                        i = nextIdx;
                    end
                    tok = struct('type', 'number', 'value', numVal, 'unit', unitStr);
                    tokens{end+1} = tok; %#ok<AGROW>
                    prevType = 'value';
                    continue;
                end

                if isstrprop(ch, 'alpha') || ch == '_' || ch == '$'
                    [ident, nextIdx] = ExpressionEngine.readIdentifier(exprText, i);
                    i = nextIdx;
                    [isFunc, funcName] = ExpressionEngine.peekFunction(exprText, i, ident);
                    if isFunc
                        arity = ExpressionEngine.functionArity(funcName);
                        tok = struct('type', 'function', 'value', funcName, 'arity', arity);
                        tokens{end+1} = tok; %#ok<AGROW>
                        prevType = 'function';
                    else
                        tok = struct('type', 'identifier', 'value', ident);
                        tokens{end+1} = tok; %#ok<AGROW>
                        prevType = 'value';
                    end
                    continue;
                end

                % Operators and punctuation
                [op, nextIdx] = ExpressionEngine.readOperator(exprText, i);
                if isempty(op)
                    error('ExpressionEngine:UnexpectedChar', 'Unexpected character: %s', ch);
                end

                if strcmp(op, '-')
                    if any(strcmp(prevType, {'start', 'operator', 'left_paren', 'comma'}))
                        op = 'u-';
                    end
                elseif strcmp(op, '!')
                    if ~any(strcmp(prevType, {'start', 'operator', 'left_paren', 'comma'}))
                        % treat as unary not only
                    end
                end

                if strcmp(op, '(')
                    tok = struct('type', 'left_paren', 'value', op);
                    prevType = 'left_paren';
                elseif strcmp(op, ')')
                    tok = struct('type', 'right_paren', 'value', op);
                    prevType = 'right_paren';
                elseif strcmp(op, ',')
                    tok = struct('type', 'comma', 'value', op);
                    prevType = 'comma';
                else
                    tok = struct('type', 'operator', 'value', op);
                    prevType = 'operator';
                end
                tokens{end+1} = tok; %#ok<AGROW>
                i = nextIdx;
            end
        end

        function [numVal, nextIdx] = readNumber(text, startIdx)
            n = length(text);
            i = startIdx;
            hasExp = false;
            while i <= n
                ch = text(i);
                if isstrprop(ch, 'digit') || ch == '.'
                    i = i + 1;
                    continue;
                end
                if (ch == 'e' || ch == 'E') && ~hasExp
                    hasExp = true;
                    i = i + 1;
                    if i <= n && (text(i) == '+' || text(i) == '-')
                        i = i + 1;
                    end
                    continue;
                end
                break;
            end
            numVal = str2double(text(startIdx:i-1));
            if ~isfinite(numVal)
                error('ExpressionEngine:InvalidNumber', 'Invalid number in expression.');
            end
            nextIdx = i;
        end

        function [unitStr, nextIdx] = readUnitBracket(text, startIdx)
            n = length(text);
            i = startIdx + 1;
            depth = 1;
            while i <= n && depth > 0
                if text(i) == '['
                    depth = depth + 1;
                elseif text(i) == ']'
                    depth = depth - 1;
                    if depth == 0
                        break;
                    end
                end
                i = i + 1;
            end
            if depth ~= 0
                error('ExpressionEngine:InvalidUnit', 'Unclosed unit bracket in expression.');
            end
            unitStr = strtrim(text(startIdx+1:i-1));
            nextIdx = i + 1;
        end

        function [ident, nextIdx] = readIdentifier(text, startIdx)
            n = length(text);
            i = startIdx;
            while i <= n
                ch = text(i);
                if isstrprop(ch, 'alphanum') || ch == '_' || ch == '.' || ch == '$'
                    i = i + 1;
                else
                    break;
                end
            end
            ident = text(startIdx:i-1);
            nextIdx = i;
        end

        function [isFunc, funcName] = peekFunction(text, idx, ident)
            funcName = ident;
            isFunc = false;
            j = idx;
            n = length(text);
            while j <= n && isspace(text(j))
                j = j + 1;
            end
            if j <= n && text(j) == '('
                if ExpressionEngine.isKnownFunction(ident)
                    isFunc = true;
                end
            end
        end

        function [op, nextIdx] = readOperator(text, startIdx)
            op = '';
            nextIdx = startIdx + 1;
            n = length(text);
            if startIdx > n
                return;
            end
            two = '';
            if startIdx < n
                two = text(startIdx:startIdx+1);
            end

            if any(strcmp(two, {'<=', '>=', '==', '!=', '&&', '||'}))
                op = two;
                nextIdx = startIdx + 2;
                return;
            end

            one = text(startIdx);
            if any(one == ['+', '-', '*', '/', '^', '(', ')', ',', '<', '>', '!'])
                op = one;
                nextIdx = startIdx + 1;
            end
        end

        function rpn = toRpn(tokens)
            rpn = {};
            stack = {};
            prec = ExpressionEngine.operatorPrecedence();
            for i = 1:numel(tokens)
                tok = tokens{i};
                switch tok.type
                    case {'number', 'identifier'}
                        rpn{end+1} = tok; %#ok<AGROW>
                    case 'function'
                        stack{end+1} = tok; %#ok<AGROW>
                    case 'comma'
                        while ~isempty(stack) && ~strcmp(stack{end}.type, 'left_paren')
                            rpn{end+1} = stack{end}; %#ok<AGROW>
                            stack(end) = [];
                        end
                        if isempty(stack)
                            error('ExpressionEngine:ParseError', 'Misplaced comma.');
                        end
                    case 'operator'
                        while ~isempty(stack) && strcmp(stack{end}.type, 'operator')
                            top = stack{end}.value;
                            if (ExpressionEngine.isRightAssociative(tok.value) && prec(top) > prec(tok.value)) || ...
                               (~ExpressionEngine.isRightAssociative(tok.value) && prec(top) >= prec(tok.value))
                                rpn{end+1} = stack{end}; %#ok<AGROW>
                                stack(end) = [];
                            else
                                break;
                            end
                        end
                        stack{end+1} = tok; %#ok<AGROW>
                    case 'left_paren'
                        stack{end+1} = tok; %#ok<AGROW>
                    case 'right_paren'
                        while ~isempty(stack) && ~strcmp(stack{end}.type, 'left_paren')
                            rpn{end+1} = stack{end}; %#ok<AGROW>
                            stack(end) = [];
                        end
                        if isempty(stack)
                            error('ExpressionEngine:ParseError', 'Mismatched parentheses.');
                        end
                        stack(end) = [];
                        if ~isempty(stack) && strcmp(stack{end}.type, 'function')
                            rpn{end+1} = stack{end}; %#ok<AGROW>
                            stack(end) = [];
                        end
                    otherwise
                        error('ExpressionEngine:InvalidToken', 'Unknown token type: %s', tok.type);
                end
            end

            while ~isempty(stack)
                if any(strcmp(stack{end}.type, {'left_paren', 'right_paren'}))
                    error('ExpressionEngine:ParseError', 'Mismatched parentheses.');
                end
                rpn{end+1} = stack{end}; %#ok<AGROW>
                stack(end) = [];
            end
        end

        function ids = collectIdentifiers(tokens)
            ids = {};
            for i = 1:numel(tokens)
                tok = tokens{i};
                if strcmp(tok.type, 'identifier')
                    ids{end+1} = tok.value; %#ok<AGROW>
                end
            end
        end

        function stack = applyOperator(stack, op)
            if strcmp(op, 'u-') || strcmp(op, '!')
                if isempty(stack)
                    error('ExpressionEngine:EvalError', 'Missing operand for unary operator.');
                end
                a = stack{end};
                stack(end) = [];
                if strcmp(op, 'u-')
                    a.value = -a.value;
                else
                    if ~UnitRegistry.isDimensionless(a.dims)
                        error('ExpressionEngine:UnitMismatch', 'Logical not requires dimensionless input.');
                    end
                    a.value = double(~(a.value ~= 0));
                end
                stack{end+1} = a;
                return;
            end

            if numel(stack) < 2
                error('ExpressionEngine:EvalError', 'Missing operands for operator.');
            end

            b = stack{end};
            a = stack{end-1};
            stack(end-1:end) = [];

            switch op
                case {'+', '-'}
                    if ~UnitRegistry.sameDims(a.dims, b.dims)
                        error('ExpressionEngine:UnitMismatch', 'Add/Sub requires matching units.');
                    end
                    if strcmp(op, '+')
                        out.value = a.value + b.value;
                    else
                        out.value = a.value - b.value;
                    end
                    out.dims = a.dims;

                case '*'
                    out.value = a.value * b.value;
                    out.dims = a.dims + b.dims;

                case '/'
                    out.value = a.value / b.value;
                    out.dims = a.dims - b.dims;

                case '^'
                    if ~UnitRegistry.isDimensionless(b.dims)
                        error('ExpressionEngine:UnitMismatch', 'Exponent must be dimensionless.');
                    end
                    expVal = b.value;
                    if ~isscalar(expVal) || ~isfinite(expVal)
                        error('ExpressionEngine:EvalError', 'Invalid exponent value.');
                    end
                    out.value = a.value ^ expVal;
                    out.dims = a.dims * expVal;

                case {'<', '<=', '>', '>=', '==', '!='}
                    if ~UnitRegistry.sameDims(a.dims, b.dims)
                        error('ExpressionEngine:UnitMismatch', 'Comparison requires matching units.');
                    end
                    out.value = ExpressionEngine.compareValues(a.value, b.value, op);
                    out.dims = ExpressionEngine.dimlessDims();

                case {'&&', '||'}
                    if ~UnitRegistry.isDimensionless(a.dims) || ~UnitRegistry.isDimensionless(b.dims)
                        error('ExpressionEngine:UnitMismatch', 'Logical ops require dimensionless inputs.');
                    end
                    av = a.value ~= 0;
                    bv = b.value ~= 0;
                    if strcmp(op, '&&')
                        out.value = double(av && bv);
                    else
                        out.value = double(av || bv);
                    end
                    out.dims = ExpressionEngine.dimlessDims();

                otherwise
                    error('ExpressionEngine:InvalidOperator', 'Unknown operator: %s', op);
            end

            stack{end+1} = out;
        end

        function stack = applyFunction(stack, fname, arity)
            if numel(stack) < arity
                error('ExpressionEngine:EvalError', 'Not enough arguments for function %s.', fname);
            end
            args = stack(end-arity+1:end);
            stack(end-arity+1:end) = [];

            switch fname
                case 'if'
                    cond = args{1};
                    a = args{2};
                    b = args{3};
                    if ~UnitRegistry.isDimensionless(cond.dims)
                        error('ExpressionEngine:UnitMismatch', 'if() condition must be dimensionless.');
                    end
                    if ~UnitRegistry.sameDims(a.dims, b.dims)
                        error('ExpressionEngine:UnitMismatch', 'if() branches must share units.');
                    end
                    if cond.value ~= 0
                        out = a;
                    else
                        out = b;
                    end

                case 'min'
                    a = args{1};
                    b = args{2};
                    if ~UnitRegistry.sameDims(a.dims, b.dims)
                        error('ExpressionEngine:UnitMismatch', 'min() requires matching units.');
                    end
                    out = a;
                    out.value = min(a.value, b.value);

                case 'max'
                    a = args{1};
                    b = args{2};
                    if ~UnitRegistry.sameDims(a.dims, b.dims)
                        error('ExpressionEngine:UnitMismatch', 'max() requires matching units.');
                    end
                    out = a;
                    out.value = max(a.value, b.value);

                case 'abs'
                    a = args{1};
                    out = a;
                    out.value = abs(a.value);

                case 'sqrt'
                    a = args{1};
                    out = a;
                    out.value = sqrt(a.value);
                    out.dims = a.dims * 0.5;

                case 'log'
                    a = args{1};
                    if ~UnitRegistry.isDimensionless(a.dims)
                        error('ExpressionEngine:UnitMismatch', 'log() requires dimensionless input.');
                    end
                    out.value = log(a.value);
                    out.dims = ExpressionEngine.dimlessDims();

                case 'log10'
                    a = args{1};
                    if ~UnitRegistry.isDimensionless(a.dims)
                        error('ExpressionEngine:UnitMismatch', 'log10() requires dimensionless input.');
                    end
                    out.value = log10(a.value);
                    out.dims = ExpressionEngine.dimlessDims();

                case 'exp'
                    a = args{1};
                    if ~UnitRegistry.isDimensionless(a.dims)
                        error('ExpressionEngine:UnitMismatch', 'exp() requires dimensionless input.');
                    end
                    out.value = exp(a.value);
                    out.dims = ExpressionEngine.dimlessDims();

                otherwise
                    error('ExpressionEngine:UnknownFunction', 'Unknown function: %s', fname);
            end

            stack{end+1} = out;
        end

        function tf = isKnownFunction(name)
            funcs = {'if', 'min', 'max', 'abs', 'sqrt', 'log', 'log10', 'exp'};
            tf = any(strcmp(name, funcs));
        end

        function arity = functionArity(name)
            switch name
                case 'if'
                    arity = 3;
                case {'min', 'max'}
                    arity = 2;
                case {'abs', 'sqrt', 'log', 'log10', 'exp'}
                    arity = 1;
                otherwise
                    error('ExpressionEngine:UnknownFunction', 'Unknown function: %s', name);
            end
        end

        function prec = operatorPrecedence()
            prec = containers.Map();
            prec('u-') = 5;
            prec('!') = 5;
            prec('^') = 4;
            prec('*') = 3;
            prec('/') = 3;
            prec('+') = 2;
            prec('-') = 2;
            prec('<') = 1;
            prec('<=') = 1;
            prec('>') = 1;
            prec('>=') = 1;
            prec('==') = 1;
            prec('!=') = 1;
            prec('&&') = 0;
            prec('||') = -1;
        end

        function tf = isRightAssociative(op)
            tf = strcmp(op, '^') || strcmp(op, 'u-') || strcmp(op, '!');
        end

        function val = compareValues(a, b, op)
            switch op
                case '<'
                    val = double(a < b);
                case '<='
                    val = double(a <= b);
                case '>'
                    val = double(a > b);
                case '>='
                    val = double(a >= b);
                case '=='
                    val = double(a == b);
                case '!='
                    val = double(a ~= b);
                otherwise
                    val = 0;
            end
        end

        function dims = dimlessDims()
            u = UnitRegistry.parseUnit('');
            dims = u.dims;
        end
    end
end
