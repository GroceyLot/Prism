local function getOgFuncName(node)
    local curNode = node
    local name = ""
    while node.type ~= "Identifier" do
        if node.type ~= "TableAccess" then
            if debug then
                warn("Wrong node type in ogfunc, skipping")
            end
        end
        if node.index.type == "StringLiteral" then
            name = name .. node.index.value
        elseif node.index.type == "NumberLiteral" then
            name = name .. string.fromNumber(node.index.value)
        else
            if debug then
                warn("Unknown node type in table access from ogfunc, skipping")
            end
            return ""
        end
        node = node.table
    end
    return "ogFunc" .. name .. curNode.name
end

local function simpleHash(str)
    local hash = 0
    for i = 1, #str do
        hash = (hash * 31 + str:byte(i)) % (2 ^ 32 - 1)
    end
    return hash
end

local function generateUniqueID(content)
    local contentString = json.encode(content)
    local contentHash = simpleHash(contentString)
    math.randomseed(math.floor(contentHash + (os.clock() % 1) * os.time()))
    return "id_" ..
               tostring(math.floor(math.abs(math.random(1, 10 ^ 10) + os.time() - os.clock()) * (10 ^ 29) / 10 ^ 29))
end

local operators = {"+", "-", "*", "/", "<", ">", "==", "~=", "<=", ">=", "..", "&", "|", "~", "#", "%", "^"}
local luaOperators = {" + ", " - ", " * ", " / ", " < ", " > ", " == ", " ~= ", " <= ", " >= ", " .. ", " and ", " or ",
                      " not ", " #", " % ", " ^ "}
local metamethods = {"add", "sub", "mul", "div", "mod", "pow", "concat", "len", "eq", "lt", "le", "call", "tostring",
                     "pairs", "ipairs"}
local metamethodProxy = table.proxy(metamethods)
local gotoSupport = os.supportgoto()

local function generateCode(debug, node, id, list)
    id = id or "u_broke_it"
    local code = ""
    if not node then
        error("No node!")
    end

    if node.type == "BlockStatement" then
        local idr = list and generateUniqueID(node) or id
        for i, stmt in ipairs(node.body) do
            code = code .. (generateCode(debug, stmt, idr) or "") .. " \n"
        end
        if gotoSupport then
            code = list and code .. " ::" .. idr .. ":: " or code
        end
        return code
    elseif node.type == "LocalDeclaration" then
        code = "local " .. table.concat(node.names, ", ")
        if node.inits then
            local inits = {}
            for i, init in ipairs(node.inits) do
                table.insert(inits, generateCode(debug, init, id))
            end
            code = code .. " = " .. table.concat(inits, ", ")
        end
        return code
    elseif node.type == "FunctionDeclaration" then
        local params = table.concat(node.parameters, ", ")
        code = (node.isLocal and "local " or "") .. "function " ..
                   (node.name and generateCode(debug, node.name, id) or "") .. "(" ..
                   (node.isMethod and ("self " .. (#node.parameters ~= 0 and ", " or "")) or "") .. params .. ") " ..
                   generateCode(debug, node.body, id) .. "end"
        return code
    elseif node.type == "ClassDeclaration" then
        local className = node.name
        code = (node.isLocal and "local " or "") .. className .. " = " ..
                   (node.original and "{} " or "setmetatable({}, { __index = " .. node.extends .. " }) ")
        local function addCode(s)
            code = code .. s .. " "
        end
        addCode(className .. ".__index = " .. className)
        addCode(className .. ".mt = {}")
        addCode(className .. ".mt.__index = " .. className)
        for i, v in pairs(node.metas.fields) do
            if v.type ~= "FunctionDeclaration" then
                warn("Non-function meta, skipping")
            else
                addCode(className .. ".mt." .. (metamethodProxy[i] and "__" or "") .. i .. " = " ..
                            generateCode(debug, v, id))

            end
        end
        addCode("function " .. className .. ":new(" .. table.concat(node.constructor, ", ") .. ")")
        addCode("local obj = {}")
        addCode("setmetatable(obj, self.mt)")
        for i, v in pairs(node.values.fields) do
            addCode("obj[" .. (type(i) ~= "string" and i or ('"' .. i .. '"')) .. "] = " .. generateCode(debug, v, id))
        end
        addCode("return obj")
        addCode("end")
        return code
    elseif node.type == "FunctionCall" then
        local call = ""
        local curNode = node.name
        local method = node.isMethod
        local iter = 1
        while curNode.type ~= "Identifier" do
            if curNode.type == "TableAccess" then
                if iter == 1 and method then
                    if curNode.index.type ~= "StringLiteral" then
                        if debug then
                            warn("Non-String index type on method call, skipping")
                        end
                        return ""
                    end
                    call = ":" .. curNode.index.value .. call
                else
                    call = "[" .. generateCode(debug, curNode.index, id) .. "]" .. call
                end
                curNode = curNode.table
                iter = iter + 1
            else
                if debug then
                    warn("Unknown node type in function call, skipping")
                end
                return ""
            end
        end
        call = curNode.name .. call .. "("
        for i, v in pairs(node.arguments) do
            call = call .. " " .. generateCode(debug, v, id) .. " " .. (i ~= #node.arguments and ", " or "")
        end
        return call .. " )"
    elseif node.type == "StringLiteral" then
        return ' [[' .. node.value .. ']] '
    elseif node.type == "NumberLiteral" then
        return tostring(node.value)
    elseif node.type == "Identifier" then
        return node.name
    elseif node.type == "TableConstructor" then
        local fields = {}
        for i, field in ipairs(node.fields) do
            table.insert(fields, generateCode(debug, field, id))
        end
        return "{" .. table.concat(fields, ", ") .. "}"
    elseif node.type == "IfStatement" then
        code = "if " .. generateCode(debug, node.test, id) .. " then " .. generateCode(debug, node.consequent, id) ..
                   " "
        if node.alternate then
            code = code .. "else " .. generateCode(debug, node.alternate, id) .. " "
        end
        return code .. "end"
    elseif node.type == "BinaryExpression" then
        local index = table.find(operators, node.operator)
        local left = node.left and generateCode(debug, node.left, id) or ""
        local right = node.right and generateCode(debug, node.right, id) or ""
        if index then
            return " ( " .. left .. luaOperators[index] .. right .. " ) "
        else
            if debug then
                warn("Unsupported operator: " .. node.operator)
            end
            return ""
        end
    elseif node.type == "ForNumericStatement" then
        return "for " .. node.var .. " = " .. generateCode(debug, node.start, id) .. ", " ..
                   generateCode(debug, node.finish, id) ..
                   (node.step and (", " .. generateCode(debug, node.step, id)) or "") .. " do\n" ..
                   generateCode(debug, node.body, nil, true) .. "end"
    elseif node.type == "WhileStatement" then
        return "while " .. generateCode(debug, node.test, id) .. " do " .. generateCode(debug, node.body, nil, true) ..
                   "end"
    elseif node.type == "TableAccess" then
        local tableCode = generateCode(debug, node.table, id)
        if node.index.type == "StringLiteral" then
            if node.index.value:match("^[a-zA-Z_]*$") then
                return tableCode .. "." .. node.index.value
            else
                return tableCode .. "[" .. generateCode(debug, node.index, id) .. "]"
            end
        else
            return tableCode .. "[" .. generateCode(debug, node.index, id) .. "]"
        end
    elseif node.type == "VariableAssignation" then
        local names = {}
        for i, name in ipairs(node.names) do
            table.insert(names, generateCode(debug, name, id))
        end
        local inits = {}
        for i, init in ipairs(node.inits) do
            table.insert(inits, generateCode(debug, init, id))
        end
        return table.concat(names, ", ") .. " = " .. table.concat(inits, ", ")
    elseif node.type == "ForGenericStatement" then
        return "for " .. table.concat(node.vars, ", ") .. " in " .. generateCode(debug, node.iter, id) .. " do\n" ..
                   generateCode(debug, node.body, nil, true) .. "end"
    elseif node.type == "ReplyStatement" then
        local values = {}
        for i, value in ipairs(node.values) do
            table.insert(values, generateCode(debug, value, id))
        end
        return "return " .. table.concat(values, ", ")
    elseif node.type == "LoopSkipStatement" and gotoSupport then
        return "goto " .. id
    else
        if node.type == "LoopSkipStatement" then
            warn("Skip is not supported in 5.1")
        end
        if debug then
            if node.type ~= "LoopSkipStatement" then
                warn("Internal prism error: " .. node.type .. " unsupported")
            end
        end
        return ""
    end
end

local function addStarts(code)
    return [[
--[[
Code generated by the *amazing* prism transpiler
]] .. "]] " .. code
end

local function executeTable(table, debug)
    return addStarts(generateCode(debug, table, true))
end

return executeTable
