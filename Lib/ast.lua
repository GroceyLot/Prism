-- Define keywords and operators at the start
keywords = {
    ["if"] = "if",
    ["then"] = "then",
    ["elseif"] = "elseif",
    ["else"] = "else",
    ["end"] = "end",
    ["ritual"] = "ritual",
    ["local"] = "local",
    ["class"] = "class",
    ["for"] = "for",
    ["while"] = "while",
    ["do"] = "do",
    ["reply"] = "reply",
    ["true"] = "true",
    ["false"] = "false",
    ["nil"] = "nil",
    ["in"] = "in",
    ["skip"] = "skip",
    ["extends"] = "extends"
}

operators = {
    ["+"] = "+",
    ["-"] = "-",
    ["*"] = "*",
    ["/"] = "/",
    ["<"] = "<",
    [">"] = ">",
    ["=="] = "==",
    ["~="] = "~=",
    ["<="] = "<=",
    [">="] = ">=",
    [".."] = "..",
    ["&"] = "&",
    ["|"] = "|",
    ["~"] = "~",
    ["#"] = "#",
    ["%"] = "%",
    ["^"] = "^"
}

specials = {
    ["="] = "=",
    ["..."] = "..."
}

strings = {
    ["`"] = "`",
    ["'"] = "'",
    ['"'] = '"'
}

delimiters = {
    ["{"] = "{",
    ["}"] = "}",
    ["("] = "(",
    [")"] = ")",
    ["["] = "[",
    ["]"] = "]",
    [","] = ",",
    [";"] = ";",
    ["."] = ".",
    [":"] = ":",
    ["!"] = "!"
}

local function tokenize(code)
    local tokens = {}
    local currentToken = ""
    local length = code:len()
    local i = 1
    local line = 1

    local function addToken(type, value, line)
        table.insert(tokens, {
            type = type,
            value = value,
            line = line
        })
    end

    local function n()
        i = i + 1
    end

    local function peek(n)
        n = n or 1
        return code:sub(i + n, i + n)
    end

    while i <= length do
        local char = code:sub(i, i)

        if char:match("%s") then
            if char == "\n" then
                line = line + 1
            end
            n()
        elseif char == "@" then
            n()
            local keyword = ""
            local iter = 0
            repeat
                keyword = keyword .. code:sub(i, i)
                n()
                iter = iter + 1
            until code:sub(i, i) == "=" or iter > 20
            if code:sub(i, i) == "=" and keywords[keyword] then
                n()
                local set = ""
                repeat
                    set = set .. code:sub(i, i)
                    n()
                    iter = iter + 1
                until code:sub(i, i) == "@" or iter > 20
                if code:sub(i, i) == "@" then
                    keywords[keyword] = set
                    n()
                else
                    error("Error tokenizing: keyword set trailing")
                end
            else
                error("Error tokenizing: keyword set")
            end
        elseif code:sub(i, i + 1) == "--" then
            n()
            if peek() == "[" then
                n()
                n()
                while i <= length and code:sub(i, i) ~= "]" do
                    if code:sub(i, i) == "\n" then
                        line = line + 1
                    end
                    n()
                end
                n()
                n()
            else
                while i <= length and code:sub(i, i) ~= "\n" do
                    n()
                end
                line = line + 1
                n()
            end
        elseif code:sub(i, i + 2) == specials["..."] then
            addToken("IDENT", "...", line)
            n()
            n()
            n()
        elseif char:match("%d") or (char == "-" and i + 1 <= length and code:sub(i + 1, i + 1):match("%d")) then
            currentToken = char
            n()
            while i <= length and code:sub(i, i):match("%d") do
                currentToken = currentToken .. code:sub(i, i)
                n()
            end
            if i <= length and code:sub(i, i) == "." then
                currentToken = currentToken .. "."
                n()
                while i <= length and code:sub(i, i):match("%d") do
                    currentToken = currentToken .. code:sub(i, i)
                    n()
                end
            end
            addToken("NUMBER", tonumber(currentToken), line)
        elseif char == ";" then
            n()
        elseif table.find(strings, char) then
            local quoteType = char
            currentToken = ""
            n()
            while i <= length and code:sub(i, i) ~= quoteType do
                currentToken = currentToken .. code:sub(i, i)
                if code:sub(i, i) == "\n" then
                    line = line + 1
                end
                n()
            end
            n()
            addToken("STRING", currentToken, line)
        elseif char:match("[A-Za-z_]") then
            currentToken = char
            n()
            while i <= length and code:sub(i, i):match("[%w_]") do
                currentToken = currentToken .. code:sub(i, i)
                n()
            end
            if table.find(keywords, currentToken) then
                addToken("KEYWORD", currentToken, line)
            else
                addToken("IDENT", currentToken, line)
            end
        elseif table.find(operators, char .. peek()) then
            local op = char .. peek()
            n()
            n()
            addToken("OP", op, line)
        elseif table.find(operators, char) then
            local op = char
            n()
            addToken("OP", op, line)
        elseif table.find(specials, char) then
            addToken("SPECIAL", char, line)
            n()
        elseif table.find(delimiters, char) then
            addToken("DELIM", char, line)
            n()
        else
            print("Unexpected character at line " .. line .. ": " .. char .. " skipping . . .")
            n()
        end
    end

    return tokens
end

local function parse(tokens)
    local pos = 1
    local length = #tokens

    local function peek(n)
        n = n or 0
        return tokens[pos + n]
    end

    local function nextToken()
        pos = pos + 1
    end

    local list = {
        ["KEYWORD"] = keywords,
        ["OP"] = operators,
        ["SPECIAL"] = specials,
        ["DELIM"] = delimiters
    }

    local function expect(type, value)
        local token = tokens[pos]
        value = value or tokens[pos].value
        if list[type] then
            value = list[type][value]
        end
        if not token or token.type ~= type or (value and token.value ~= value) then
            return nil, {
                type = "expect",
                expect = {
                    type = type,
                    value = value
                },
                got = {token},
                line = token.line
            }
        end
        nextToken()
        return token
    end

    local parseFunctionCall
    local parseExpression
    local parseBlock
    local parsePrimary
    local parseBinaryExpression
    local parseStatement

    parsePrimary = function(level)
        local token = tokens[pos]
        if token.type == "NUMBER" then
            nextToken()
            local node = {
                type = "NumberLiteral",
                value = token.value
            }
            return node
        elseif token.type == "STRING" then
            nextToken()
            local node = {
                type = "StringLiteral",
                value = token.value
            }
            return node
        elseif token.type == "IDENT" then
            local name = token.value
            nextToken()
            local node = {
                type = "Identifier",
                name = name
            }

            -- Handle nested table access with brackets and dots
            while tokens[pos] and tokens[pos].type == "DELIM" and
                (tokens[pos].value == delimiters["["] or tokens[pos].value == delimiters["."] or tokens[pos].value ==
                    delimiters["@"]) do
                if tokens[pos].value == delimiters["["] then
                    nextToken()
                    local index, err = parseExpression(level)
                    if err then
                        return nil, err
                    end
                    local _, err = expect("DELIM", "]")
                    if err then
                        return nil, err
                    end
                    node = {
                        type = "TableAccess",
                        table = node,
                        index = index
                    }
                elseif tokens[pos].value == delimiters["."] then
                    nextToken()
                    local index, err = expect("IDENT")
                    if err then
                        return nil, err
                    end
                    node = {
                        type = "TableAccess",
                        table = node,
                        index = {
                            type = "StringLiteral",
                            value = index.value
                        }
                    }
                end
            end

            -- Handle function calls
            if tokens[pos] and tokens[pos].type == "DELIM" and
                (tokens[pos].value == delimiters["("] or tokens[pos].value == delimiters[":"] or tokens[pos].value ==
                    delimiters["!"]) then
                return parseFunctionCall(node, level)
            end

            return node

        elseif token.type == "KEYWORD" and token.value == keywords["true"] then
            nextToken()
            local node = {
                type = "BooleanLiteral",
                value = true
            }
            return node
        elseif token.type == "KEYWORD" and token.value == keywords["false"] then
            nextToken()
            local node = {
                type = "BooleanLiteral",
                value = false
            }
            return node
        elseif token.type == "KEYWORD" and token.value == keywords["nil"] then
            nextToken()
            local node = {
                type = "NilLiteral"
            }
            return node
        elseif token.type == "KEYWORD" and token.value == keywords["ritual"] then
            nextToken()
            local parameters = {}
            if tokens[pos].type == "DELIM" and tokens[pos].value == delimiters["!"] then
                local _, err = expect("DELIM", "!")
                if err then
                    return nil, err
                end
            else
                local _, err = expect("DELIM", "(")
                if err then
                    return nil, err
                end
                if tokens[pos] and tokens[pos].type ~= "DELIM" and tokens[pos].value ~= delimiters[")"] then
                    repeat
                        local param, err = expect("IDENT")
                        if err then
                            return nil, err
                        end
                        table.insert(parameters, param.value)
                        if tokens[pos].type == "DELIM" and tokens[pos].value == delimiters[","] then
                            nextToken()
                        end
                    until tokens[pos].type == "DELIM" and tokens[pos].value == delimiters[")"]
                end
                local _, err = expect("DELIM", ")")
                if err then
                    return nil, err
                end
            end
            local body, err = parseBlock(level)
            if err then
                return nil, err
            end
            local _, err = expect("KEYWORD", "end")
            if err then
                return nil, err
            end
            local node = {
                type = "FunctionDeclaration",
                parameters = parameters,
                body = body
            }
            return node

        elseif token.type == "DELIM" and token.value == delimiters["{"] then
            nextToken()
            local fields = {}
            local isArray = nil
            local index = 1

            local function parseKeyValuePair()
                local key, value, err
                if tokens[pos].type == "IDENT" then
                    key = tokens[pos].value
                    nextToken()
                    if tokens[pos].value == specials["="] then
                        isArray = false
                        nextToken()
                        value, err = parseExpression(level)
                        if err then
                            return nil, err
                        end
                    elseif isArray == nil or isArray then
                        isArray = true
                        key = index
                        index = index + 1
                        value, err = parseExpression(level)
                        if err then
                            return nil, err
                        end
                    else
                        return nil, {
                            type = "specific",
                            line = tokens[pos].line,
                            string = "Dynamic arrays are not allowed."
                        }
                    end
                elseif tokens[pos].type == "DELIM" and tokens[pos].value == delimiters["["] then
                    isArray = false
                    nextToken()
                    key, err = parseExpression(level)
                    if err then
                        return nil, err
                    end
                    err = expect("DELIM", "]")
                    if err then
                        return nil, err
                    end
                    err = expect("SPECIAL", "=")
                    if err then
                        return nil, err
                    end
                    value, err = parseExpression(level)
                    if err then
                        return nil, err
                    end
                elseif isArray == nil or isArray then
                    isArray = true
                    key = index
                    index = index + 1
                    value, err = parseExpression(level)
                    if err then
                        return nil, err
                    end
                else
                    return nil, {
                        type = "specific",
                        line = tokens[pos].line,
                        string = "Dynamic arrays are not allowed."
                    }
                end

                return key, value
            end

            while tokens[pos] and tokens[pos].type ~= "DELIM" or tokens[pos].value ~= delimiters["}"] do
                local key, value, err = parseKeyValuePair()
                if err then
                    return nil, err
                end
                fields[key] = value

                if tokens[pos] and tokens[pos].type == "DELIM" and tokens[pos].value == delimiters[","] then
                    nextToken()
                elseif tokens[pos] and tokens[pos].type == "DELIM" and tokens[pos].value == delimiters["}"] then
                    break
                end
            end

            if not isArray then
                isArray = false
            end

            local _, err = expect("DELIM", "}")
            if err then
                return nil, err
            end

            local node = {
                type = "TableConstructor",
                fields = fields,
                isArray = isArray
            }
            return node

        elseif token.type == "DELIM" and token.value == delimiters["("] then
            nextToken()
            local expr, err = parseExpression(level)
            if err then
                return nil, err
            end
            local _, err = expect("DELIM", ")")
            if err then
                return nil, err
            end
            return expr
        else
            return nil, {
                type = "unexpected",
                got = token,
                line = token.line,
                from = "parsePrimary"
            }
        end
    end

    parseFunctionCall = function(node, level)
        local isMethod = false
        if tokens[pos] and tokens[pos].type == "DELIM" and tokens[pos].value == delimiters[":"] then
            isMethod = true
            nextToken()
            local value = tokens[pos].value
            local _, err = expect("IDENT")
            if err then
                return nil, err
            end
            node = {
                type = "TableAccess",
                table = node,
                index = {
                    type = "StringLiteral",
                    value = value
                }
            }
        end

        if tokens[pos] and tokens[pos].type == "DELIM" and tokens[pos].value == delimiters["!"] then
            local _, err = expect("DELIM", "!")
            if err then
                return nil, err
            end

            return {
                type = "FunctionCall",
                name = node,
                isMethod = isMethod,
                arguments = {}
            }
        end

        local _, err = expect("DELIM", "(")
        if err then
            return nil, err
        end

        local args = {}
        if tokens[pos] and (tokens[pos].type ~= "DELIM" or tokens[pos].value ~= delimiters[")"]) then
            repeat
                local expr, err = parseExpression(level)
                if err then
                    return nil, err
                end
                table.insert(args, expr)

                if tokens[pos] and tokens[pos].type == "DELIM" then
                    if tokens[pos].value == delimiters[")"] then
                        break
                    elseif tokens[pos].value == delimiters[","] then
                        nextToken()
                    else
                        return nil, {
                            type = "unexpected",
                            got = tokens[pos],
                            line = tokens[pos].line,
                            from = "parseFunctionCall"
                        }
                    end
                else
                    local _, err = expect("DELIM")
                    return nil, err
                end
            until false
        end

        local _, err = expect("DELIM", ")")
        if err then
            return nil, err
        end

        local functionCallNode = {
            type = "FunctionCall",
            name = node,
            isMethod = isMethod,
            arguments = args
        }

        return functionCallNode
    end

    parseBinaryExpression = function(left, minPrecedence, level)
        local precedence = {
            ["|"] = 1,
            ["&"] = 2,
            ["<"] = 3,
            [">"] = 3,
            ["<="] = 3,
            [">="] = 3,
            ["~="] = 3,
            ["=="] = 3,
            ["+"] = 8,
            ["-"] = 8,
            ["*"] = 9,
            ["/"] = 9,
            ["%"] = 9,
            ["~"] = 10,
            ["#"] = 10,
            ["^"] = 11,
            [".."] = 12
        }

        local function getPrecedence(op)
            return precedence[op] or -1
        end

        while true do
            local token = tokens[pos]
            if not token or token.type ~= "OP" or getPrecedence(operators[token.value]) < minPrecedence then
                return left
            end

            local op = operators[token.value]
            nextToken()

            local right, err = parsePrimary(level)
            if err then
                return nil, err
            end
            while true do
                local token = tokens[pos]
                if not token or token.type ~= "OP" or getPrecedence(operators[token.value]) <= getPrecedence(op) then
                    break
                end
                right, err = parseBinaryExpression(right, getPrecedence(operators[token.value]), level)
                if err then
                    return nil, err
                end
            end

            left = {
                type = "BinaryExpression",
                operator = op,
                left = left,
                right = right
            }
        end
    end

    parseExpression = function(level)
        local expr, err = parseBinaryExpression(parsePrimary(level), 0, level)
        return expr, err
    end

    parseStatement = function(level)
        local token = tokens[pos]

        if token.type == "KEYWORD" and token.value == keywords["if"] then
            nextToken()
            local test, err = parseExpression(level)
            if err then
                return nil, err
            end
            local _, err = expect("KEYWORD", "then")
            if err then
                return nil, err
            end
            local consequent, err = parseBlock(level)
            if err then
                return nil, err
            end

            local node = {
                type = "IfStatement",
                test = test,
                consequent = consequent,
                alternate = nil
            }

            local current = node
            while tokens[pos] and tokens[pos].type == "KEYWORD" do
                if tokens[pos].value == keywords["elseif"] then
                    nextToken()
                    local elseifTest, err = parseExpression(level)
                    if err then
                        return nil, err
                    end
                    local _, err = expect("KEYWORD", "then")
                    if err then
                        return nil, err
                    end
                    local elseifConsequent, err = parseBlock(level)
                    if err then
                        return nil, err
                    end
                    local elseifNode = {
                        type = "IfStatement",
                        test = elseifTest,
                        consequent = elseifConsequent,
                        alternate = nil
                    }
                    current.alternate = elseifNode
                    current = elseifNode
                elseif tokens[pos].value == keywords["else"] then
                    nextToken()
                    local alternate, err = parseBlock(level)
                    if err then
                        return nil, err
                    end
                    current.alternate = alternate
                    break
                else
                    break
                end
            end

            local _, err = expect("KEYWORD", "end")
            if err then
                return nil, err
            end

            return node
        elseif token.type == "KEYWORD" and token.value == keywords["while"] then
            nextToken()
            local test, err = parseExpression(level)
            if err then
                return nil, err
            end
            local _, err = expect("KEYWORD", "do")
            if err then
                return nil, err
            end
            local body, err = parseBlock(level)
            if err then
                return nil, err
            end
            local _, err = expect("KEYWORD", "end")
            if err then
                return nil, err
            end
            local node = {
                type = "WhileStatement",
                test = test,
                body = body
            }

            return node
        elseif tokens[pos] and tokens[pos].type == "KEYWORD" and tokens[pos].value == keywords["skip"] then
            local node = {
                type = "LoopSkipStatement"
            }
            nextToken()
            return node
        elseif tokens[pos] and tokens[pos].type == "KEYWORD" and tokens[pos].value == keywords["class"] then
            nextToken()
            local isLocal = false
            if tokens[pos].type == "KEYWORD" and tokens[pos].value == keywords["local"] then
                isLocal = true
                nextToken()
            end
            local name, err = expect("IDENT")
            if err then
                return nil, err
            end
            local _, err = expect("DELIM", "(")
            if err then
                return nil, err
            end
            local parameters = {}
            if tokens[pos] and tokens[pos].type ~= "DELIM" and tokens[pos].value ~= delimiters[")"] then
                repeat
                    local param, err = expect("IDENT")
                    if err then
                        return nil, err
                    end
                    table.insert(parameters, param.value)
                    if tokens[pos].type == "DELIM" and tokens[pos].value == delimiters[","] then
                        nextToken()
                    end
                until tokens[pos].type == "DELIM" and tokens[pos].value == delimiters[")"]
            end
            local _, err = expect("DELIM", ")")
            if err then
                return nil, err
            end
            local extends = nil
            local original = true
            if tokens[pos].type == "KEYWORD" and tokens[pos].value == keywords["extends"] then
                local _, err = expect("KEYWORD", "extends")
                if err then
                    return nil, err
                end
                extends = tokens[pos]
                local _, err = expect("IDENT")
                if err then
                    return nil, err
                end
                original = false
            end
            local values = parseExpression(level)
            local _, err = expect("DELIM", ",")
            if err then
                return nil, err
            end
            local metas = parseExpression(level)
            local _, err = expect("KEYWORD", "end")
            if err then
                return nil, err
            end
            local node = {
                type = "ClassDeclaration",
                name = name.value,
                values = values,
                isLocal = isLocal,
                constructor = parameters,
                extends = extends,
                metas = metas,
                original = original
            }
            return node
        elseif token.type == "KEYWORD" and token.value == keywords["for"] then
            nextToken()
            local var = expect("IDENT").value
            if tokens[pos] and tokens[pos].type == "SPECIAL" and tokens[pos].value == specials["="] then
                nextToken()
                local start, err = parseExpression(level)
                if err then
                    return nil, err
                end
                local _, err = expect("DELIM", ",")
                if err then
                    return nil, err
                end
                local finish, err = parseExpression(level)
                if err then
                    return nil, err
                end
                local step
                if tokens[pos] and tokens[pos].type == "DELIM" and tokens[pos].value == delimiters[","] then
                    nextToken()
                    step, err = parseExpression(level)
                    if err then
                        return nil, err
                    end
                end
                local _, err = expect("KEYWORD", "do")
                if err then
                    return nil, err
                end
                local body, err = parseBlock(level)
                if err then
                    return nil, err
                end
                local _, err = expect("KEYWORD", "end")
                if err then
                    return nil, err
                end
                local node = {
                    type = "ForNumericStatement",
                    var = var,
                    start = start,
                    finish = finish,
                    step = step,
                    body = body
                }

                return node
            elseif tokens[pos] and tokens[pos].type == "DELIM" and tokens[pos].value == delimiters[","] then
                nextToken()
                local var2 = expect("IDENT").value
                local _, err = expect("KEYWORD", "in")
                if err then
                    return nil, err
                end
                local iter, err = parseExpression(level)
                if err then
                    return nil, err
                end
                local _, err = expect("KEYWORD", "do")
                if err then
                    return nil, err
                end
                local body, err = parseBlock(level)
                if err then
                    return nil, err
                end
                local _, err = expect("KEYWORD", "end")
                if err then
                    return nil, err
                end
                local node = {
                    type = "ForGenericStatement",
                    vars = {var, var2},
                    iter = iter,
                    body = body
                }
                return node
            else
                return nil, {
                    type = "unexpected",
                    got = tokens[pos],
                    line = tokens[pos].line,
                    from = "for in parseStatement"
                }
            end

        elseif token.type == "KEYWORD" and (token.value == keywords["local"]) then
            nextToken()
            local vars = {}
            repeat
                local name, err = expect("IDENT")
                if err then
                    return nil, err
                end
                table.insert(vars, name.value)
                if tokens[pos] and tokens[pos].type == "DELIM" and tokens[pos].value == delimiters[","] then
                    nextToken()
                else
                    break
                end
            until false

            local inits = {}
            if tokens[pos] and tokens[pos].type == "SPECIAL" and tokens[pos].value == specials["="] then
                nextToken()
                repeat
                    local init, err = parseExpression(level)
                    if err then
                        return nil, err
                    end
                    table.insert(inits, init)
                    if tokens[pos] and tokens[pos].type == "DELIM" and tokens[pos].value == delimiters[","] then
                        nextToken()
                    else
                        break
                    end
                until false
            end

            local node = {
                type = "LocalDeclaration",
                names = vars,
                inits = inits
            }
            return node
        elseif token.type == "KEYWORD" and (token.value == keywords["ritual"]) then
            nextToken()
            local isLocal = false
            if tokens[pos].type == "KEYWORD" and tokens[pos].value == keywords["local"] then
                isLocal = true
                nextToken()
            end
            local name = tokens[pos].value
            local _, err = expect("IDENT")
            if err then
                return nil, err
            end

            local nameNode = {
                name = name,
                type = "Identifier"
            }

            local isMethod = false

            -- Handle nested table access with brackets and dots
            while tokens[pos] and tokens[pos].type == "DELIM" and
                (tokens[pos].value == delimiters["["] or tokens[pos].value == delimiters["."] or tokens[pos].value ==
                    delimiters[":"]) do
                if tokens[pos].value == delimiters["["] then
                    nextToken()
                    local index, err = parseExpression(level)
                    if err then
                        return nil, err
                    end
                    local _, err = expect("DELIM", "]")
                    if err then
                        return nil, err
                    end
                    nameNode = {
                        type = "TableAccess",
                        table = nameNode,
                        index = index
                    }
                elseif tokens[pos].value == delimiters["."] then
                    nextToken()
                    local index = expect("IDENT").value
                    nameNode = {
                        type = "TableAccess",
                        table = nameNode,
                        index = {
                            type = "StringLiteral",
                            value = index
                        }
                    }
                else
                    nextToken()
                    local index = expect("IDENT").value
                    nameNode = {
                        type = "TableAccess",
                        table = nameNode,
                        index = {
                            type = "StringLiteral",
                            value = index
                        }
                    }
                    isMethod = true
                    break
                end
            end

            local parameters = {}
            if tokens[pos].type == "DELIM" and tokens[pos].value == delimiters["!"] then
                local _, err = expect("DELIM", "!")
                if err then
                    return nil, err
                end
            else
                local _, err = expect("DELIM", "(")
                if err then
                    return nil, err
                end
                if tokens[pos] and tokens[pos].type ~= "DELIM" and tokens[pos].value ~= delimiters[")"] then
                    repeat
                        local param, err = expect("IDENT")
                        if err then
                            return nil, err
                        end
                        table.insert(parameters, param.value)
                        if tokens[pos].type == "DELIM" and tokens[pos].value == delimiters[","] then
                            nextToken()
                        end
                    until tokens[pos].type == "DELIM" and tokens[pos].value == delimiters[")"]
                end
                local _, err = expect("DELIM", ")")
                if err then
                    return nil, err
                end
            end

            local body, err = parseBlock(level)
            if err then
                return nil, err
            end
            local _, err = expect("KEYWORD", "end")
            if err then
                return nil, err
            end

            local node = {
                type = "FunctionDeclaration",
                name = nameNode,
                parameters = parameters,
                body = body,
                isLocal = isLocal,
                isMethod = isMethod
            }
            return node

        elseif token.type == "IDENT" then
            -- Handle identifiers, including function calls and table access
            local identifiers = {}
            repeat
                local node = {
                    type = "Identifier",
                    name = token.value
                }
                nextToken()

                -- Handle nested table access with brackets and dots
                while tokens[pos] and tokens[pos].type == "DELIM" and
                    (tokens[pos].value == delimiters["["] or tokens[pos].value == delimiters["."]) do
                    if tokens[pos].value == delimiters["["] then
                        nextToken()
                        local index, err = parseExpression(level)
                        if err then
                            return nil, err
                        end
                        local _, err = expect("DELIM", "]")
                        if err then
                            return nil, err
                        end
                        node = {
                            type = "TableAccess",
                            table = node,
                            index = index
                        }
                    elseif tokens[pos].value == delimiters["."] then
                        nextToken()
                        local index = expect("IDENT").value
                        node = {
                            type = "TableAccess",
                            table = node,
                            index = {
                                type = "StringLiteral",
                                value = index
                            }
                        }
                    end
                end

                table.insert(identifiers, node)
                token = tokens[pos]
                if token and token.type == "DELIM" and token.value == delimiters[","] then
                    nextToken()
                    token = tokens[pos]
                else
                    break
                end
            until false

            -- Check if the next token is '=' for assignment
            if token and token.type == "SPECIAL" and token.value == specials["="] then
                nextToken()
                local initValues = {}
                repeat
                    local init, err = parseExpression(level)
                    if err then
                        return nil, err
                    end
                    table.insert(initValues, init)
                    token = tokens[pos]
                    if token and token.type == "DELIM" and token.value == delimiters[","] then
                        nextToken()
                        token = tokens[pos]
                    else
                        break
                    end
                until false

                local assignmentNode = {
                    type = "VariableAssignation",
                    names = identifiers,
                    inits = initValues
                }
                return assignmentNode
            elseif tokens[pos] and tokens[pos].type == "DELIM" and
                (tokens[pos].value == delimiters["("] or tokens[pos].value == delimiters[":"] or tokens[pos].value ==
                    delimiters["!"]) then
                -- Handle function calls
                return parseFunctionCall(identifiers[1], level)
            else
                return nil, {
                    type = "unexpected",
                    got = tokens[pos],
                    line = tokens[pos].line,
                    from = "ident in parseStatement"
                }
            end
        elseif token.type == "KEYWORD" and token.value == keywords["reply"] then
            local expres = {}
            nextToken()
            local expr, err = parseExpression(level)
            if err then
                return nil, err
            end
            table.insert(expres, expr)
            while tokens[pos].type == "DELIM" and tokens[pos].value == delimiters[","] do
                nextToken()
                local expr, err = parseExpression(level)
                if err then
                    return nil, err
                end
                table.insert(expres, expr)
            end
            local node = {
                type = "ReplyStatement",
                values = expres
            }
            return node
        else
            table.print(keywords)
            return nil, {
                type = "unexpected",
                got = token,
                line = token.line,
                from = "base parseStatement"
            }
        end
    end

    parseBlock = function(level)
        level = level or -1
        level = level + 1
        local body = {}
        local s, b, e = pcall(function()
            while pos <= length and not (tokens[pos].type == "KEYWORD" and
                (tokens[pos].value == keywords["end"] or tokens[pos].value == keywords["else"] or tokens[pos].value ==
                    keywords["elseif"])) do
                local statement, err = parseStatement(level)
                if err then
                    return body, err
                end
                table.insert(body, statement)
            end

        end)
        local node = {
            type = "BlockStatement",
            body = body
        }
        if e then
            return b, e
        else
            return node, s and nil or b
        end
    end

    return parseBlock()
end

return function(code)
    params = params or {}
    local tokens = tokenize(code)
    local ast, err = parse(tokens)
    if err then
        return ast, tokens, err
    else
        return ast, tokens, false
    end
end
