local function optimizeAST(ast, debug)
    local function evaluateBinaryExpression(exp)
        local left = exp.left
        local right = exp.right

        if left and right then
            if left.type == "NumberLiteral" and right.type == "NumberLiteral" then
                if exp.operator == "+" then
                    return {
                        value = left.value + right.value,
                        type = "NumberLiteral"
                    }
                elseif exp.operator == "-" then
                    return {
                        value = left.value - right.value,
                        type = "NumberLiteral"
                    }
                elseif exp.operator == "*" then
                    return {
                        value = left.value * right.value,
                        type = "NumberLiteral"
                    }
                elseif exp.operator == "/" then
                    return {
                        value = left.value / right.value,
                        type = "NumberLiteral"
                    }
                elseif exp.operator == "^" then
                    return {
                        value = left.value ^ right.value,
                        type = "NumberLiteral"
                    }
                elseif exp.operator == "==" then
                    return {
                        value = left.value == right.value,
                        type = "BooleanLiteral"
                    }
                elseif exp.operator == "~=" then
                    return {
                        value = left.value ~= right.value,
                        type = "BooleanLiteral"
                    }
                elseif exp.operator == ">=" then
                    return {
                        value = left.value >= right.value,
                        type = "BooleanLiteral"
                    }
                elseif exp.operator == "<=" then
                    return {
                        value = left.value <= right.value,
                        type = "BooleanLiteral"
                    }
                elseif exp.operator == ">" then
                    return {
                        value = left.value > right.value,
                        type = "BooleanLiteral"
                    }
                elseif exp.operator == "<" then
                    return {
                        value = left.value < right.value,
                        type = "BooleanLiteral"
                    }
                end
            elseif left.type == "StringLiteral" and right.type == "StringLiteral" then
                if exp.operator == ".." then
                    return {
                        value = left.value .. right.value,
                        type = "StringLiteral"
                    }
                elseif exp.operator == "==" then
                    return {
                        value = left.value == right.value,
                        type = "BooleanLiteral"
                    }
                elseif exp.operator == "~=" then
                    return {
                        value = left.value ~= right.value,
                        type = "BooleanLiteral"
                    }
                end
            elseif left.type == "BooleanLiteral" and right.type == "BooleanLiteral" then
                if exp.operator == "&" then
                    return {
                        value = left.value and right.value,
                        type = "BooleanLiteral"
                    }
                elseif exp.operator == "|" then
                    return {
                        value = left.value or right.value,
                        type = "BooleanLiteral"
                    }
                elseif exp.operator == "==" then
                    return {
                        value = left.value == right.value,
                        type = "BooleanLiteral"
                    }
                elseif exp.operator == "~=" then
                    return {
                        value = left.value ~= right.value,
                        type = "BooleanLiteral"
                    }
                end
            end
        elseif right then
            if right.type == "StringLiteral" and exp.operator == "#" then
                return {
                    value = right.value:len(),
                    type = "NumberLiteral"
                }
            elseif right.type == "BooleanLiteral" and exp.operator == "~" then
                return {
                    value = not right.value,
                    type = "BooleanLiteral"
                }
            elseif right.type == "NumberLiteral" and exp.operator == "-" then
                return {
                    value = -right.value,
                    type = "NumberLiteral"
                }
            end
        end

        return exp
    end

    local optimizeBlock

    local function optimizeNode(node)
        if node.type == "LocalDeclaration" then
            for i, v in pairs(node.inits) do
                node.inits[i] = optimizeNode(v)
            end
        elseif node.type == "FunctionDeclaration" then
            node.body = optimizeBlock(node.body)
        elseif node.type == "BlockStatement" then
            node = optimizeBlock(node)
        elseif node.type == "BinaryExpression" then
            node = evaluateBinaryExpression(node)
        elseif node.type == "FunctionCall" then
            for i, v in pairs(node.arguments) do
                node.arguments[i] = optimizeNode(v)
            end
        elseif node.type == "TableConstructor" then
            for i, v in pairs(node.fields) do
                node.fields[i] = optimizeNode(v)
            end
        elseif node.type == "NumberLiteral" then
        elseif node.type == "StringLiteral" then
        elseif node.type == "IfStatement" then
            node.consequent = optimizeBlock(node.consequent)
            if node.alternate then
                node.alternate = optimizeBlock(node.alternate)
            end
        elseif node.type == "ForNumericStatement" then
            node.body = optimizeBlock(node.body)
        elseif node.type == "LoopSkipStatement" then
        elseif node.type == "VariableAssignation" then
            for i, v in pairs(node.inits) do
                node.inits[i] = optimizeNode(v)
            end
        elseif node.type == "WhileStatement" then
            node.body = optimizeBlock(node.body)
        elseif node.type == "ForGenericStatement" then
            node.body = optimizeBlock(node.body)
        elseif node.type == "ReplyStatement" then
            for i, v in pairs(node.values) do
                node.values[i] = optimizeNode(v)
            end
        elseif node.type == "Identifier" then
        elseif node.type == "TableAccess" then
            node.index = optimizeNode(node.index)
        elseif node.type == "ClassDeclaration" then
            node.metas = optimizeNode(node.metas)
            node.values = optimizeNode(node.values)
        elseif debug then
            warn("Unknown node type: "..node.type..", ignoring (OPTIM)")
        end
        return node
    end

    -- Optimize a block statement
    optimizeBlock = function(block)
        if not block.body then
            if debug then
                warn("No body in block, type: " .. block.type .. ", ignoring (OPTIM)")
            end
            return block
        end
        local optimizedBody = {}

        for i, stmt in ipairs(block.body) do
            optimizedBody[i] = optimizeNode(stmt)
        end

        return {
            body = optimizedBody,
            type = "BlockStatement"
        }
    end

    ast = optimizeBlock(ast)

    return ast
end

return optimizeAST
