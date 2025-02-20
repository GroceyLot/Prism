--[[
    Lexer and Parser Module
    ------------------------
    This module tokenizes input source code and parses it into an Abstract Syntax Tree (AST).
    It supports keywords, operators, numbers, strings, table constructors, function calls, etc.
    Note: The output (AST, tokens, errors) remains unchanged.
--]]

-- Define language tokens: keywords, operators, specials, string delimiters, and other delimiters.
local keywords = {
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

local operators = {
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

local specials = {
    ["="] = "=",
    ["..."] = "..."
}

local strings = {
    ["`"] = "`",
    ["'"] = "'",
    ['"'] = '"'
}

local delimiters = {
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

-- Utility function: Check if a value exists in a table.
local function tableContains(tbl, value)
    for _, v in pairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

-------------------------------------------------
-- Tokenizer: Convert source code into tokens --
-------------------------------------------------
local function tokenize(sourceCode)
    local tokens = {}
    local currentIndex = 1
    local codeLength = #sourceCode
    local currentLine = 1

    -- Helper: Append a new token.
    local function addToken(tokenType, tokenValue, lineNumber)
        table.insert(tokens, {
            type = tokenType,
            value = tokenValue,
            line = lineNumber
        })
    end

    -- Helper: Advance one character.
    local function advance()
        currentIndex = currentIndex + 1
    end

    -- Helper: Peek ahead by a given offset (default is 1).
    local function peek(offset)
        offset = offset or 1
        return sourceCode:sub(currentIndex + offset, currentIndex + offset)
    end

    while currentIndex <= codeLength do
        local char = sourceCode:sub(currentIndex, currentIndex)

        -- Skip whitespace (track newlines)
        if char:match("%s") then
            if char == "\n" then
                currentLine = currentLine + 1
            end
            advance()

        -- Handle keyword setting syntax: @<keyword>=<value>@
        elseif char == "@" then
            advance()
            local keywordStr = ""
            local iter = 0
            repeat
                keywordStr = keywordStr .. sourceCode:sub(currentIndex, currentIndex)
                advance()
                iter = iter + 1
            until sourceCode:sub(currentIndex, currentIndex) == "=" or iter > 20
            if sourceCode:sub(currentIndex, currentIndex) == "=" and keywords[keywordStr] then
                advance()  -- skip "="
                local setValue = ""
                iter = 0
                repeat
                    setValue = setValue .. sourceCode:sub(currentIndex, currentIndex)
                    advance()
                    iter = iter + 1
                until sourceCode:sub(currentIndex, currentIndex) == "@" or iter > 20
                if sourceCode:sub(currentIndex, currentIndex) == "@" then
                    keywords[keywordStr] = setValue
                    advance()  -- skip closing "@"
                else
                    error("Error tokenizing: keyword set trailing")
                end
            else
                error("Error tokenizing: keyword set")
            end

        -- Handle comments starting with "--"
        elseif sourceCode:sub(currentIndex, currentIndex+1) == "--" then
            advance()
            if peek() == "[" then
                advance()  -- skip "["
                advance()  -- skip marker character
                while currentIndex <= codeLength and sourceCode:sub(currentIndex, currentIndex) ~= "]" do
                    if sourceCode:sub(currentIndex, currentIndex) == "\n" then
                        currentLine = currentLine + 1
                    end
                    advance()
                end
                advance()
                advance()
            else
                while currentIndex <= codeLength and sourceCode:sub(currentIndex, currentIndex) ~= "\n" do
                    advance()
                end
                currentLine = currentLine + 1
                advance()
            end

        -- Handle the "..." special token
        elseif sourceCode:sub(currentIndex, currentIndex+2) == specials["..."] then
            addToken("IDENT", "...", currentLine)
            advance() advance() advance()

        -- Handle numeric literals (integers and floats)
        elseif char:match("%d") or (char == "-" and currentIndex + 1 <= codeLength and sourceCode:sub(currentIndex+1, currentIndex+1):match("%d")) then
            local numberStr = char
            advance()
            while currentIndex <= codeLength and sourceCode:sub(currentIndex, currentIndex):match("%d") do
                numberStr = numberStr .. sourceCode:sub(currentIndex, currentIndex)
                advance()
            end
            if currentIndex <= codeLength and sourceCode:sub(currentIndex, currentIndex) == "." then
                numberStr = numberStr .. "."
                advance()
                while currentIndex <= codeLength and sourceCode:sub(currentIndex, currentIndex):match("%d") do
                    numberStr = numberStr .. sourceCode:sub(currentIndex, currentIndex)
                    advance()
                end
            end
            addToken("NUMBER", tonumber(numberStr), currentLine)

        -- Skip semicolons completely
        elseif char == ";" then
            advance()

        -- Handle string literals delimited by `, ', or "
        elseif tableContains(strings, char) then
            local quoteType = char
            local stringContent = ""
            advance()
            while currentIndex <= codeLength and sourceCode:sub(currentIndex, currentIndex) ~= quoteType do
                stringContent = stringContent .. sourceCode:sub(currentIndex, currentIndex)
                if sourceCode:sub(currentIndex, currentIndex) == "\n" then
                    currentLine = currentLine + 1
                end
                advance()
            end
            advance()  -- skip closing quote
            addToken("STRING", stringContent, currentLine)

        -- Handle identifiers and keywords
        elseif char:match("[A-Za-z_]") then
            local identifierStr = char
            advance()
            while currentIndex <= codeLength and sourceCode:sub(currentIndex, currentIndex):match("[%w_]") do
                identifierStr = identifierStr .. sourceCode:sub(currentIndex, currentIndex)
                advance()
            end
            if tableContains(keywords, identifierStr) then
                addToken("KEYWORD", identifierStr, currentLine)
            else
                addToken("IDENT", identifierStr, currentLine)
            end

        -- Handle two-character operators (e.g. "==", "<=")
        elseif tableContains(operators, char .. peek()) then
            local op = char .. peek()
            advance() advance()
            addToken("OP", op, currentLine)

        -- Handle single-character operators
        elseif tableContains(operators, char) then
            local op = char
            advance()
            addToken("OP", op, currentLine)

        -- Handle specials (like "=")
        elseif tableContains(specials, char) then
            addToken("SPECIAL", char, currentLine)
            advance()

        -- Handle delimiters (parentheses, brackets, etc.)
        elseif tableContains(delimiters, char) then
            addToken("DELIM", char, currentLine)
            advance()

        -- Log and skip any unexpected characters
        else
            print("Unexpected character at line " .. currentLine .. ": " .. char .. " skipping ...")
            advance()
        end
    end

    return tokens
end

-------------------------------------------------
-- Parser: Convert tokens into an AST structure --
-------------------------------------------------
local function parse(tokens)
    local currentPosition = 1
    local tokensLength = #tokens

    -- Helper: Peek at the current token (with optional offset).
    local function peek(offset)
        offset = offset or 0
        return tokens[currentPosition + offset]
    end

    -- Helper: Move to the next token.
    local function nextToken()
        currentPosition = currentPosition + 1
    end

    -- Mapping for token type checks (keywords, operators, etc.).
    local tokenCategories = {
        ["KEYWORD"] = keywords,
        ["OP"] = operators,
        ["SPECIAL"] = specials,
        ["DELIM"] = delimiters
    }

    -- Expect a token of a specific type (and optionally a specific value).
    local function expect(expectedType, expectedValue)
        local token = tokens[currentPosition]
        expectedValue = expectedValue or token.value
        if tokenCategories[expectedType] then
            expectedValue = tokenCategories[expectedType][expectedValue]
        end
        if not token or token.type ~= expectedType or (expectedValue and token.value ~= expectedValue) then
            return nil, {
                type = "expect",
                expect = {
                    type = expectedType,
                    value = expectedValue
                },
                got = { token },
                line = token and token.line or "unknown"
            }
        end
        nextToken()
        return token
    end

    -- Forward declarations for recursive parsing functions.
    local parseFunctionCall, parseExpression, parseBlock, parsePrimary, parseBinaryExpression, parseStatement

    -----------------------------
    -- Primary Expression Parser
    -----------------------------
    parsePrimary = function(nestingLevel)
        local token = tokens[currentPosition]
        if token.type == "NUMBER" then
            nextToken()
            return { type = "NumberLiteral", value = token.value }
        elseif token.type == "STRING" then
            nextToken()
            return { type = "StringLiteral", value = token.value }
        elseif token.type == "IDENT" then
            local identifierName = token.value
            nextToken()
            local node = { type = "Identifier", name = identifierName }

            -- Support nested table accesses (using [ ] or .)
            while tokens[currentPosition] and tokens[currentPosition].type == "DELIM" and
                  (tokens[currentPosition].value == delimiters["["] or tokens[currentPosition].value == delimiters["."] or tokens[currentPosition].value == delimiters["@"]) do
                if tokens[currentPosition].value == delimiters["["] then
                    nextToken()
                    local indexExpr, err = parseExpression(nestingLevel)
                    if err then return nil, err end
                    local _, err2 = expect("DELIM", "]")
                    if err2 then return nil, err2 end
                    node = { type = "TableAccess", table = node, index = indexExpr }
                elseif tokens[currentPosition].value == delimiters["."] then
                    nextToken()
                    local indexToken, err = expect("IDENT")
                    if err then return nil, err end
                    node = {
                        type = "TableAccess",
                        table = node,
                        index = { type = "StringLiteral", value = indexToken.value }
                    }
                end
            end

            -- Handle function call immediately following the identifier
            if tokens[currentPosition] and tokens[currentPosition].type == "DELIM" and
               (tokens[currentPosition].value == delimiters["("] or tokens[currentPosition].value == delimiters[":"] or tokens[currentPosition].value == delimiters["!"]) then
                return parseFunctionCall(node, nestingLevel)
            end

            return node

        elseif token.type == "KEYWORD" and token.value == keywords["true"] then
            nextToken()
            return { type = "BooleanLiteral", value = true }
        elseif token.type == "KEYWORD" and token.value == keywords["false"] then
            nextToken()
            return { type = "BooleanLiteral", value = false }
        elseif token.type == "KEYWORD" and token.value == keywords["nil"] then
            nextToken()
            return { type = "NilLiteral" }
        elseif token.type == "KEYWORD" and token.value == keywords["ritual"] then
            nextToken()
            local parameters = {}
            if tokens[currentPosition].type == "DELIM" and tokens[currentPosition].value == delimiters["!"] then
                local _, err = expect("DELIM", "!")
                if err then return nil, err end
            else
                local _, err = expect("DELIM", "(")
                if err then return nil, err end
                if tokens[currentPosition] and not (tokens[currentPosition].type == "DELIM" and tokens[currentPosition].value == delimiters[")"]) then
                    repeat
                        local paramToken, err = expect("IDENT")
                        if err then return nil, err end
                        table.insert(parameters, paramToken.value)
                        if tokens[currentPosition].type == "DELIM" and tokens[currentPosition].value == delimiters[","] then
                            nextToken()
                        end
                    until tokens[currentPosition].type == "DELIM" and tokens[currentPosition].value == delimiters[")"]
                end
                local _, err = expect("DELIM", ")")
                if err then return nil, err end
            end
            local bodyNode, err = parseBlock(nestingLevel)
            if err then return nil, err end
            local _, err2 = expect("KEYWORD", "end")
            if err2 then return nil, err2 end
            return {
                type = "FunctionDeclaration",
                parameters = parameters,
                body = bodyNode
            }

        elseif token.type == "DELIM" and token.value == delimiters["{"] then
            nextToken()
            local fields = {}
            local isArray = nil
            local arrayIndex = 1

            local function parseKeyValuePair()
                local key, value, err
                if tokens[currentPosition].type == "IDENT" then
                    key = tokens[currentPosition].value
                    nextToken()
                    if tokens[currentPosition].value == specials["="] then
                        isArray = false
                        nextToken()
                        value, err = parseExpression(nestingLevel)
                        if err then return nil, err end
                    elseif isArray == nil or isArray then
                        isArray = true
                        key = arrayIndex
                        arrayIndex = arrayIndex + 1
                        value, err = parseExpression(nestingLevel)
                        if err then return nil, err end
                    else
                        return nil, { type = "specific", line = tokens[currentPosition].line, string = "Dynamic arrays are not allowed." }
                    end
                elseif tokens[currentPosition].type == "DELIM" and tokens[currentPosition].value == delimiters["["] then
                    isArray = false
                    nextToken()
                    key, err = parseExpression(nestingLevel)
                    if err then return nil, err end
                    err = expect("DELIM", "]")
                    if err then return nil, err end
                    err = expect("SPECIAL", "=")
                    if err then return nil, err end
                    value, err = parseExpression(nestingLevel)
                    if err then return nil, err end
                elseif isArray == nil or isArray then
                    isArray = true
                    key = arrayIndex
                    arrayIndex = arrayIndex + 1
                    value, err = parseExpression(nestingLevel)
                    if err then return nil, err end
                else
                    return nil, { type = "specific", line = tokens[currentPosition].line, string = "Dynamic arrays are not allowed." }
                end
                return key, value
            end

            while tokens[currentPosition] and not (tokens[currentPosition].type == "DELIM" and tokens[currentPosition].value == delimiters["}"]) do
                local key, value, err = parseKeyValuePair()
                if err then return nil, err end
                fields[key] = value

                if tokens[currentPosition] and tokens[currentPosition].type == "DELIM" and tokens[currentPosition].value == delimiters[","] then
                    nextToken()
                elseif tokens[currentPosition] and tokens[currentPosition].type == "DELIM" and tokens[currentPosition].value == delimiters["}"] then
                    break
                end
            end

            if not isArray then isArray = false end

            local _, err = expect("DELIM", "}")
            if err then return nil, err end

            return {
                type = "TableConstructor",
                fields = fields,
                isArray = isArray
            }

        elseif token.type == "DELIM" and token.value == delimiters["("] then
            nextToken()
            local expr, err = parseExpression(nestingLevel)
            if err then return nil, err end
            local _, err2 = expect("DELIM", ")")
            if err2 then return nil, err2 end
            return expr

        else
            return nil, { type = "unexpected", got = token, line = token.line, from = "parsePrimary" }
        end
    end

    -----------------------------
    -- Function Call Parser
    -----------------------------
    parseFunctionCall = function(calleeNode, nestingLevel)
        local isMethod = false
        if tokens[currentPosition] and tokens[currentPosition].type == "DELIM" and tokens[currentPosition].value == delimiters[":"] then
            isMethod = true
            nextToken()
            local methodName = tokens[currentPosition].value
            local _, err = expect("IDENT")
            if err then return nil, err end
            calleeNode = {
                type = "TableAccess",
                table = calleeNode,
                index = { type = "StringLiteral", value = methodName }
            }
        end

        if tokens[currentPosition] and tokens[currentPosition].type == "DELIM" and tokens[currentPosition].value == delimiters["!"] then
            local _, err = expect("DELIM", "!")
            if err then return nil, err end
            return {
                type = "FunctionCall",
                name = calleeNode,
                isMethod = isMethod,
                arguments = {}
            }
        end

        local _, err = expect("DELIM", "(")
        if err then return nil, err end

        local arguments = {}
        if tokens[currentPosition] and not (tokens[currentPosition].type == "DELIM" and tokens[currentPosition].value == delimiters[")"]) then
            repeat
                local argExpr, err = parseExpression(nestingLevel)
                if err then return nil, err end
                table.insert(arguments, argExpr)
                if tokens[currentPosition] and tokens[currentPosition].type == "DELIM" then
                    if tokens[currentPosition].value == delimiters[")"] then
                        break
                    elseif tokens[currentPosition].value == delimiters[","] then
                        nextToken()
                    else
                        return nil, { type = "unexpected", got = tokens[currentPosition], line = tokens[currentPosition].line, from = "parseFunctionCall" }
                    end
                else
                    local _, err = expect("DELIM")
                    return nil, err
                end
            until false
        end

        local _, err2 = expect("DELIM", ")")
        if err2 then return nil, err2 end

        return {
            type = "FunctionCall",
            name = calleeNode,
            isMethod = isMethod,
            arguments = arguments
        }
    end

    -----------------------------
    -- Binary Expression Parser
    -----------------------------
    parseBinaryExpression = function(leftExpr, minPrecedence, nestingLevel)
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
            local token = tokens[currentPosition]
            if not token or token.type ~= "OP" or getPrecedence(operators[token.value]) < minPrecedence then
                return leftExpr
            end

            local operatorValue = operators[token.value]
            nextToken()

            local rightExpr, err = parsePrimary(nestingLevel)
            if err then return nil, err end
            while true do
                local nextTokenData = tokens[currentPosition]
                if not nextTokenData or nextTokenData.type ~= "OP" or getPrecedence(operators[nextTokenData.value]) <= getPrecedence(operatorValue) then
                    break
                end
                rightExpr, err = parseBinaryExpression(rightExpr, getPrecedence(operators[nextTokenData.value]), nestingLevel)
                if err then return nil, err end
            end

            leftExpr = {
                type = "BinaryExpression",
                operator = operatorValue,
                left = leftExpr,
                right = rightExpr
            }
        end
    end

    -----------------------------
    -- Expression Parser
    -----------------------------
    parseExpression = function(nestingLevel)
        local primaryExpr, err = parsePrimary(nestingLevel)
        if err then return nil, err end
        return parseBinaryExpression(primaryExpr, 0, nestingLevel)
    end

    -----------------------------
    -- Statement Parser
    -----------------------------
    parseStatement = function(nestingLevel)
        local token = tokens[currentPosition]

        if token.type == "KEYWORD" and token.value == keywords["if"] then
            nextToken()
            local testExpr, err = parseExpression(nestingLevel)
            if err then return nil, err end
            local _, err2 = expect("KEYWORD", "then")
            if err2 then return nil, err2 end
            local consequentBlock, err3 = parseBlock(nestingLevel)
            if err3 then return nil, err3 end

            local ifNode = {
                type = "IfStatement",
                test = testExpr,
                consequent = consequentBlock,
                alternate = nil
            }

            local currentIf = ifNode
            while tokens[currentPosition] and tokens[currentPosition].type == "KEYWORD" do
                if tokens[currentPosition].value == keywords["elseif"] then
                    nextToken()
                    local elseifTest, err = parseExpression(nestingLevel)
                    if err then return nil, err end
                    local _, err = expect("KEYWORD", "then")
                    if err then return nil, err end
                    local elseifBlock, err = parseBlock(nestingLevel)
                    if err then return nil, err end
                    local elseifNode = {
                        type = "IfStatement",
                        test = elseifTest,
                        consequent = elseifBlock,
                        alternate = nil
                    }
                    currentIf.alternate = elseifNode
                    currentIf = elseifNode
                elseif tokens[currentPosition].value == keywords["else"] then
                    nextToken()
                    local elseBlock, err = parseBlock(nestingLevel)
                    if err then return nil, err end
                    currentIf.alternate = elseBlock
                    break
                else
                    break
                end
            end

            local _, errFinal = expect("KEYWORD", "end")
            if errFinal then return nil, errFinal end
            return ifNode

        elseif token.type == "KEYWORD" and token.value == keywords["while"] then
            nextToken()
            local testExpr, err = parseExpression(nestingLevel)
            if err then return nil, err end
            local _, err2 = expect("KEYWORD", "do")
            if err2 then return nil, err2 end
            local bodyBlock, err = parseBlock(nestingLevel)
            if err then return nil, err end
            local _, err3 = expect("KEYWORD", "end")
            if err3 then return nil, err3 end
            return { type = "WhileStatement", test = testExpr, body = bodyBlock }

        elseif tokens[currentPosition] and tokens[currentPosition].type == "KEYWORD" and tokens[currentPosition].value == keywords["skip"] then
            nextToken()
            return { type = "LoopSkipStatement" }

        elseif tokens[currentPosition] and tokens[currentPosition].type == "KEYWORD" and tokens[currentPosition].value == keywords["class"] then
            nextToken()
            local isLocal = false
            if tokens[currentPosition].type == "KEYWORD" and tokens[currentPosition].value == keywords["local"] then
                isLocal = true
                nextToken()
            end
            local nameToken, err = expect("IDENT")
            if err then return nil, err end
            local _, err = expect("DELIM", "(")
            if err then return nil, err end
            local parameters = {}
            if tokens[currentPosition] and not (tokens[currentPosition].type == "DELIM" and tokens[currentPosition].value == delimiters[")"]) then
                repeat
                    local paramToken, err = expect("IDENT")
                    if err then return nil, err end
                    table.insert(parameters, paramToken.value)
                    if tokens[currentPosition].type == "DELIM" and tokens[currentPosition].value == delimiters[","] then
                        nextToken()
                    else
                        break
                    end
                until tokens[currentPosition].type == "DELIM" and tokens[currentPosition].value == delimiters[")"]
            end
            local _, err = expect("DELIM", ")")
            if err then return nil, err end
            local extends = nil
            local original = true
            if tokens[currentPosition].type == "KEYWORD" and tokens[currentPosition].value == keywords["extends"] then
                local _, err = expect("KEYWORD", "extends")
                if err then return nil, err end
                extends = tokens[currentPosition]
                local _, err = expect("IDENT")
                if err then return nil, err end
                original = false
            end
            local valuesExpr = parseExpression(nestingLevel)
            local _, err = expect("DELIM", ",")
            if err then return nil, err end
            local metasExpr = parseExpression(nestingLevel)
            local _, err2 = expect("KEYWORD", "end")
            if err2 then return nil, err2 end
            return {
                type = "ClassDeclaration",
                name = nameToken.value,
                values = valuesExpr,
                isLocal = isLocal,
                constructor = parameters,
                extends = extends,
                metas = metasExpr,
                original = original
            }

        elseif token.type == "KEYWORD" and token.value == keywords["for"] then
            nextToken()
            local varName = expect("IDENT").value
            if tokens[currentPosition] and tokens[currentPosition].type == "SPECIAL" and tokens[currentPosition].value == specials["="] then
                nextToken()
                local startExpr, err = parseExpression(nestingLevel)
                if err then return nil, err end
                local _, err = expect("DELIM", ",")
                if err then return nil, err end
                local finishExpr, err = parseExpression(nestingLevel)
                if err then return nil, err end
                local stepExpr = nil
                if tokens[currentPosition] and tokens[currentPosition].type == "DELIM" and tokens[currentPosition].value == delimiters[","] then
                    nextToken()
                    stepExpr, err = parseExpression(nestingLevel)
                    if err then return nil, err end
                end
                local _, err = expect("KEYWORD", "do")
                if err then return nil, err end
                local bodyBlock, err = parseBlock(nestingLevel)
                if err then return nil, err end
                local _, err2 = expect("KEYWORD", "end")
                if err2 then return nil, err2 end
                return {
                    type = "ForNumericStatement",
                    var = varName,
                    start = startExpr,
                    finish = finishExpr,
                    step = stepExpr,
                    body = bodyBlock
                }
            elseif tokens[currentPosition] and tokens[currentPosition].type == "DELIM" and tokens[currentPosition].value == delimiters[","] then
                nextToken()
                local varName2 = expect("IDENT").value
                local _, err = expect("KEYWORD", "in")
                if err then return nil, err end
                local iterExpr, err = parseExpression(nestingLevel)
                if err then return nil, err end
                local _, err = expect("KEYWORD", "do")
                if err then return nil, err end
                local bodyBlock, err = parseBlock(nestingLevel)
                if err then return nil, err end
                local _, err2 = expect("KEYWORD", "end")
                if err2 then return nil, err2 end
                return {
                    type = "ForGenericStatement",
                    vars = { varName, varName2 },
                    iter = iterExpr,
                    body = bodyBlock
                }
            else
                return nil, { type = "unexpected", got = tokens[currentPosition], line = tokens[currentPosition].line, from = "for in parseStatement" }
            end

        elseif token.type == "KEYWORD" and token.value == keywords["local"] then
            nextToken()
            local varNames = {}
            repeat
                local nameToken, err = expect("IDENT")
                if err then return nil, err end
                table.insert(varNames, nameToken.value)
                if tokens[currentPosition] and tokens[currentPosition].type == "DELIM" and tokens[currentPosition].value == delimiters[","] then
                    nextToken()
                else
                    break
                end
            until false

            local initExpressions = {}
            if tokens[currentPosition] and tokens[currentPosition].type == "SPECIAL" and tokens[currentPosition].value == specials["="] then
                nextToken()
                repeat
                    local initExpr, err = parseExpression(nestingLevel)
                    if err then return nil, err end
                    table.insert(initExpressions, initExpr)
                    if tokens[currentPosition] and tokens[currentPosition].type == "DELIM" and tokens[currentPosition].value == delimiters[","] then
                        nextToken()
                    else
                        break
                    end
                until false
            end

            return {
                type = "LocalDeclaration",
                names = varNames,
                inits = initExpressions
            }

        elseif token.type == "KEYWORD" and token.value == keywords["ritual"] then
            nextToken()
            local isLocal = false
            if tokens[currentPosition].type == "KEYWORD" and tokens[currentPosition].value == keywords["local"] then
                isLocal = true
                nextToken()
            end
            local nameToken = tokens[currentPosition]
            local _, err = expect("IDENT")
            if err then return nil, err end

            local nameNode = { type = "Identifier", name = nameToken.value }
            local isMethod = false

            while tokens[currentPosition] and tokens[currentPosition].type == "DELIM" and
                  (tokens[currentPosition].value == delimiters["["] or tokens[currentPosition].value == delimiters["."] or tokens[currentPosition].value == delimiters[":"]) do
                if tokens[currentPosition].value == delimiters["["] then
                    nextToken()
                    local indexExpr, err = parseExpression(nestingLevel)
                    if err then return nil, err end
                    local _, err = expect("DELIM", "]")
                    if err then return nil, err end
                    nameNode = { type = "TableAccess", table = nameNode, index = indexExpr }
                elseif tokens[currentPosition].value == delimiters["."] then
                    nextToken()
                    local indexToken = expect("IDENT")
                    nameNode = {
                        type = "TableAccess",
                        table = nameNode,
                        index = { type = "StringLiteral", value = indexToken.value }
                    }
                else
                    nextToken()
                    local indexToken = expect("IDENT")
                    nameNode = {
                        type = "TableAccess",
                        table = nameNode,
                        index = { type = "StringLiteral", value = indexToken.value }
                    }
                    isMethod = true
                    break
                end
            end

            local parameters = {}
            if tokens[currentPosition].type == "DELIM" and tokens[currentPosition].value == delimiters["!"] then
                local _, err = expect("DELIM", "!")
                if err then return nil, err end
            else
                local _, err = expect("DELIM", "(")
                if err then return nil, err end
                if tokens[currentPosition] and not (tokens[currentPosition].type == "DELIM" and tokens[currentPosition].value == delimiters[")"]) then
                    repeat
                        local paramToken, err = expect("IDENT")
                        if err then return nil, err end
                        table.insert(parameters, paramToken.value)
                        if tokens[currentPosition].type == "DELIM" and tokens[currentPosition].value == delimiters[","] then
                            nextToken()
                        end
                    until tokens[currentPosition].type == "DELIM" and tokens[currentPosition].value == delimiters[")"]
                end
                local _, err = expect("DELIM", ")")
                if err then return nil, err end
            end

            local bodyBlock, err = parseBlock(nestingLevel)
            if err then return nil, err end
            local _, err2 = expect("KEYWORD", "end")
            if err2 then return nil, err2 end

            return {
                type = "FunctionDeclaration",
                name = nameNode,
                parameters = parameters,
                body = bodyBlock,
                isLocal = isLocal,
                isMethod = isMethod
            }

        elseif token.type == "IDENT" then
            local identifierNodes = {}
            repeat
                local node = { type = "Identifier", name = token.value }
                nextToken()

                while tokens[currentPosition] and tokens[currentPosition].type == "DELIM" and
                      (tokens[currentPosition].value == delimiters["["] or tokens[currentPosition].value == delimiters["."]) do
                    if tokens[currentPosition].value == delimiters["["] then
                        nextToken()
                        local indexExpr, err = parseExpression(nestingLevel)
                        if err then return nil, err end
                        local _, err = expect("DELIM", "]")
                        if err then return nil, err end
                        node = { type = "TableAccess", table = node, index = indexExpr }
                    elseif tokens[currentPosition].value == delimiters["."] then
                        nextToken()
                        local indexToken = expect("IDENT")
                        node = {
                            type = "TableAccess",
                            table = node,
                            index = { type = "StringLiteral", value = indexToken.value }
                        }
                    end
                end

                table.insert(identifierNodes, node)
                token = tokens[currentPosition]
                if token and token.type == "DELIM" and token.value == delimiters[","] then
                    nextToken()
                    token = tokens[currentPosition]
                else
                    break
                end
            until false

            if token and token.type == "SPECIAL" and token.value == specials["="] then
                nextToken()
                local initExpressions = {}
                repeat
                    local initExpr, err = parseExpression(nestingLevel)
                    if err then return nil, err end
                    table.insert(initExpressions, initExpr)
                    token = tokens[currentPosition]
                    if token and token.type == "DELIM" and token.value == delimiters[","] then
                        nextToken()
                        token = tokens[currentPosition]
                    else
                        break
                    end
                until false

                return {
                    type = "VariableAssignation",
                    names = identifierNodes,
                    inits = initExpressions
                }
            elseif tokens[currentPosition] and tokens[currentPosition].type == "DELIM" and
                   (tokens[currentPosition].value == delimiters["("] or tokens[currentPosition].value == delimiters[":"] or tokens[currentPosition].value == delimiters["!"]) then
                return parseFunctionCall(identifierNodes[1], nestingLevel)
            else
                return nil, { type = "unexpected", got = tokens[currentPosition], line = tokens[currentPosition].line, from = "ident in parseStatement" }
            end

        elseif token.type == "KEYWORD" and token.value == keywords["reply"] then
            local expressions = {}
            nextToken()
            local expr, err = parseExpression(nestingLevel)
            if err then return nil, err end
            table.insert(expressions, expr)
            while tokens[currentPosition].type == "DELIM" and tokens[currentPosition].value == delimiters[","] do
                nextToken()
                local expr, err = parseExpression(nestingLevel)
                if err then return nil, err end
                table.insert(expressions, expr)
            end
            return {
                type = "ReplyStatement",
                values = expressions
            }
        else
            print("Unexpected token in parseStatement; current keywords:", keywords)
            return nil, { type = "unexpected", got = token, line = token.line, from = "base parseStatement" }
        end
    end

    -----------------------------
    -- Block Parser (multiple statements)
    -----------------------------
    parseBlock = function(nestingLevel)
        nestingLevel = (nestingLevel or -1) + 1
        local statements = {}
        local success, err = pcall(function()
            while currentPosition <= tokensLength and not (tokens[currentPosition].type == "KEYWORD" and
                  (tokens[currentPosition].value == keywords["end"] or tokens[currentPosition].value == keywords["else"] or tokens[currentPosition].value == keywords["elseif"])) do
                local statement, err = parseStatement(nestingLevel)
                if err then
                    return statements, err
                end
                table.insert(statements, statement)
            end
        end)
        local blockNode = { type = "BlockStatement", body = statements }
        if err then
            return statements, err
        else
            return blockNode, success and nil or err
        end
    end

    return parseBlock()
end

-------------------------------------------------
-- Main entry point: Tokenize and parse input code
-------------------------------------------------
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