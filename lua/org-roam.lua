local sqlite = require("sqlite.db")

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local default_args = require("default-args")
local user_config = {}

local function setup(args)
    user_config = args or default_args
    if user_config.org_roam_directory == nil then
        print("Org Roam Error: Please provide `org_roam_directory`")
    end
end

local function org_roam_capture(title)
    if title == nil then
        title = vim.fn.input("Enter the title: ")
    end
    local filename = os.date("%Y%m%d%H%M%S") .. "_" .. title:gsub("%A", "_")
    if filename:len() > 251 then
        filename = filename:sub(1, 251) .. ".org"
    else
        filename = filename .. ".org"
    end

    -- Credits: https://github.com/TrevorS/uuid-nvim
    math.randomseed(os.time())
    local uuid = string.gsub("xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx",
    "[xy]", function(c)
        local r = math.random()
        local v = c == "x" and math.floor(r * 0x10) or (math.floor(r * 0x4) + 8)
        return string.format("%x", v)
    end):upper()

    local node_head = ":PROPERTIES:\n:ID:        " .. uuid ..
                      "\n:END:\n#+title: " .. title .. "\n"

    local file_path = user_config.org_roam_directory .. filename
    local fp, err = io.open(file_path, "w")
    if fp == nil then
        print("Error: " .. err)
    else
        fp:write(node_head)
        fp:close()

        vim.cmd.edit(file_path)
    end
end

local function org_roam_node_find()
    local nodes = sqlite.with_open(user_config.org_roam_database_file, function (db)
        local nodes = db:eval([[SELECT file, title, pos FROM nodes;]])
        local node_aliases = db:eval([[
            SELECT aliases.alias AS title, nodes.file, nodes.pos
              FROM aliases, nodes
             WHERE aliases.node_id = nodes.id;
          ]])

        for _, val in ipairs(node_aliases) do
            table.insert(nodes, val)
        end

        return nodes
    end)

    local telescope_picker = function(opts)
        opts = opts or {}
        pickers.new(opts, {
            prompt_title = "Find Node",
            finder = finders.new_table {
                results = nodes,
                entry_maker = function(entry)
                    -- because of the way org-roam stores these in database
                    entry.title = string.sub(entry.title, 2, -2)
                    entry.file  = string.sub(entry.file, 2, -2)

                    return {
                        value   = entry,
                        display = entry.title,
                        ordinal = entry.title
                    }
                end
            },

            attach_mappings = function(prompt_bufnr, _)
                actions.select_default:replace(function()
                    actions.close(prompt_bufnr)
                    local selection = action_state.get_selected_entry()
                    if selection == nil then
                        local title = action_state.get_current_line()
                        org_roam_capture(title)
                        -- TODO:
                        -- Create a new node with this title
                    else
                        local file = selection.value.file
                        local pos = selection.value.pos
                        local row = 0;

                        for line in io.lines(file) do
                            if (pos < line:len()) then break else
                                pos = pos - line:len()
                            end
                            row = row + 1
                        end

                        vim.cmd.edit(selection.value.file)
                        vim.api.nvim_win_set_cursor(0, { row, 0 })
                    end
                end)
                return true
            end,
            sorter = conf.generic_sorter(opts),
        }):find()
    end
    telescope_picker()
end

return {
    setup = setup,
    org_roam_capture = org_roam_capture,
    org_roam_node_find = org_roam_node_find,
}
