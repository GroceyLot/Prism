require("Lib.help")

-- Custom require function to handle .psm files
local originalRequire = require

-- Modify the function to handle .psm files
local function transpileAndLoad(code, params)
    params = params or {}

    local success, ast, tokens, err = pcall(originalRequire("Lib.ast"), code)
    if not success then
        print("Failed on compilation:")
        print(ast)
        return ast, {
            code = nil,
            ast = ast,
            optimAst = optimAst,
            tokens = tokens or nil
        }
    elseif err then
        print("Failed on compilation:")
        if type(err) == "table" then
            table.print(err)
        else
            print(err)
        end
        return err, {
            code = nil,
            ast = ast,
            optimAst = optimAst,
            tokens = tokens or nil
        }
    else
        local optimAst
        if params.optim ~= false then
            success, optimAst = pcall(originalRequire("Lib.optim"), ast, params.debug)
            if not success then
                print("Failed on optimization:")
                print(optimAst)
                return err, {
                    code = nil,
                    ast = ast,
                    optimAst = nil,
                    tokens = tokens
                }
            end
        else
            optimAst = ast
        end
        local success, codeTrans = pcall(originalRequire("Lib.lua"), ast, params.debug)
        if not success then
            print("Failed on code generation:")
            print(codeTrans)
            return err, {
                code = nil,
                ast = ast,
                optimAst = optimAst,
                tokens = tokens
            }
        else
            return false, {
                code = codeTrans,
                ast = ast,
                optimAst = optimAst,
                tokens = tokens
            }
        end
    end
end

function output(moduleName, location, params)
    local filePath = moduleName:gsub("%.", "/"):sub(1, moduleName:len() - 4) .. ".psm"
    local file = io.open(filePath, "r")

    if not file then
        error("Psm file not found")
    end

    local code = file:read("*a")
    file:close()

    local err, result = transpileAndLoad(code, params)
    if err then
        error("Failed to load .psm module: " .. moduleName .. " with error: " .. err)
    end

    file = io.open(location, "w+")

    if not file then
        error("Output path not found")
    end

    file:write(result.code)
    file:close()
end

-- Function to load .psm files
local function loadPsmFile(moduleName, params)
    local filePath = moduleName:gsub("%.", "/"):sub(1, moduleName:len() - 4) .. ".psm"
    local file = io.open(filePath, "r")

    if not file then
        error("Psm file not found")
    end

    local code = file:read("*a")
    file:close()

    -- Transpile and execute the .psm code
    local err, result = transpileAndLoad(code, params)
    if err then
        error("Failed to load .psm module: " .. moduleName .. " with error: " .. err)
    end

    local func, loadErr = load(result.code, moduleName)
    if not func then
        error("Failed to load .psm module: " .. moduleName .. " with error: " .. loadErr)
    end

    return func()
end

-- Override the require function
require = function(moduleName)
    if moduleName:match("%.psm$") then
        return loadPsmFile(moduleName)
    else
        return originalRequire(moduleName)
    end
end
