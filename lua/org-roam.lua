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

local function org_roam_node_find()

    local db = sqlite.new(user_config.org_roam_database_file)
    local nodes = {}
    db:with_open(function (database)
        nodes = database:select("files", { keys = { "file", "title" } })
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
                    vim.cmd.edit(selection.value.file)
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
    org_roam_node_find = org_roam_node_find
}
