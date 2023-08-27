local M = {}

-- Credits: https://github.com/kkharji/sqlite.lua
-- MIT License
-- Copyright (c) 2021 kkharji
M.expand_file_name = function(path)
    local expanded
    if string.find(path, "~") then
        expanded = string.gsub(path, "^~", os.getenv "HOME")
    elseif string.find(path, "^%.") then
        expanded = luv.fs_realpath(path)
        if expanded == nil then
            error "Path not valid"
        end
    elseif string.find(path, "%$") then
        local rep = string.match(path, "([^%$][^/]*)")
        local val = os.getenv(string.upper(rep))
        if val then
            expanded = string.gsub(string.gsub(path, rep, val), "%$", "")
        else
            expanded = nil
        end
    else
        expanded = path
    end
    return expanded and expanded or error "Path not valid"
end

-- Credits: https://github.com/TrevorS/uuid-nvim
-- No Licence (as of Aug 27, 2023)
M.get_uuid = function()
    math.randomseed(os.time())
    return string.gsub("xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx",
    "[xy]", function(c)
        local r = math.random()
        local v = c == "x" and math.floor(r * 0x10) or (math.floor(r * 0x4) + 8)
        return string.format("%x", v)
    end):upper()
end

return M
