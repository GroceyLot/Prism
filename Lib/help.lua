-- Define the table.find function
function table.find(tbl, value)
    for index, val in pairs(tbl) do
        if val == value then
            return index
        end
    end
    return nil -- Return nil if the value is not found
end

function os.supportgoto()
    -- Try using a goto statement to see if it raises an error
    local status, result = pcall(function()
        ::label::
        return true
    end)
    return status and result
end

function table.tree(tbl, indent, cur)
    indent = indent or ""
    cur = cur or ""
    local isLast = function(t, idx)
        local keys = {}
        for k, _ in pairs(t) do
            table.insert(keys, k)
        end
        return idx == #keys
    end

    for key, value in pairs(tbl) do
        local lastElement = isLast(tbl, key)
        local line = indent .. (lastElement and "└── " or "├── ") .. tostring(key .. ":")
        cur = cur .. line .. "\n"

        if type(value) == "table" then
            local newIndent = indent .. (lastElement and "    " or "│   ")
            cur = table.tree(value, newIndent, cur)
        else
            local line = indent .. (lastElement and "    " or "│   ") .. tostring(value)
            cur = cur .. line .. "\n"
        end
    end

    return cur
end

function table.proxy(array)
    local result = {}
    for _, value in ipairs(array) do
        result[value] = true
    end
    return result
end

-- Define the function to print a table in a tree structure
function table.print(tbl)
    print(table.tree(tbl))
end

function io.file(filename)
    local file, err = io.open(filename, "r") -- Open the file in read mode
    if not file then
        return false, "Error opening file: " .. err -- Return an error message if the file cannot be opened
    end

    local contents = file:read("*a") -- Read the entire contents of the file
    file:close() -- Close the file
    return true, contents -- Return the contents
end

-- Function to organize command-line arguments
function io.args()
    local args = arg
    local flags = {}
    local parameters = {}

    local i = 1
    while i <= #args do
        if args[i]:sub(1, 2) == "--" then
            table.insert(flags, args[i])
        elseif args[i]:sub(1, 1) == "-" then
            if i + 1 <= #args then
                parameters[args[i]] = args[i + 1]
                i = i + 1
            else
                parameters[args[i]] = true -- In case there's a lone flag without a parameter
            end
        end
        i = i + 1
    end

    return flags, parameters
end

function io.pause(prompt)
    prompt = prompt or "Press enter to continue . . . "
    io.write(prompt)
    io.read(0)
end

function io.softExit(prompt)
    prompt = prompt or "Press enter to exit . . . "
    io.write(prompt)
    io.read(0)
    os.exit()
end

function string.fromNumber(number)
    local ones = {"Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine"}
    local teens = {"Ten", "Eleven", "Twelve", "Thirteen", "Fourteen", "Fifteen", "Sixteen", "Seventeen", "Eighteen",
                   "Nineteen"}
    local tens = {"", "", "Twenty", "Thirty", "Forty", "Fifty", "Sixty", "Seventy", "Eighty", "Ninety"}
    local thousands = {"", "Thousand", "Million", "Billion"}

    local function convert_hundreds(number)
        local result = ""
        if number >= 100 then
            local hundreds = math.floor(number / 100)
            result = result .. ones[hundreds + 1] .. "Hundred"
            number = number % 100
        end
        if number >= 10 and number < 20 then
            result = result .. teens[number - 9]
        else
            local tens_place = math.floor(number / 10)
            if tens_place > 0 then
                result = result .. tens[tens_place + 1]
            end
            local ones_place = number % 10
            if ones_place > 0 then
                result = result .. ones[ones_place + 1]
            end
        end
        return result
    end

    local function convert_integer_part(number)
        if number == 0 then
            return "Zero"
        end
        local result = ""
        local thousand_counter = 0

        while number > 0 do
            local hundreds = number % 1000
            if hundreds > 0 then
                result = convert_hundreds(hundreds) .. thousands[thousand_counter + 1] .. result
            end
            number = math.floor(number / 1000)
            thousand_counter = thousand_counter + 1
        end

        return result
    end

    local integer_part = math.floor(number)
    local decimal_part = number - integer_part

    local result = convert_integer_part(integer_part)

    if decimal_part > 0 then
        local decimal_str = tostring(decimal_part):sub(3) -- Remove "0."
        result = result .. "Point"
        for i = 1, #decimal_str do
            local digit = tonumber(decimal_str:sub(i, i))
            result = result .. ones[digit + 1]
        end
    end

    return result
end

require("Lib.json")
