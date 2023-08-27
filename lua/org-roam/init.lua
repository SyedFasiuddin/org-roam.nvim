local utils = require("org-roam.utils")
local default_args = require("org-roam.default-args")

local luv = require("luv")
local sqlite = require("sqlite.db")
local sha1 = require("sha1")

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local user_config = {}

local function setup(args)
    user_config = args or default_args
    if user_config.org_roam_directory == nil then
        print("Org Roam Error: Please provide `org_roam_directory`")
    end

    user_config.org_roam_directory =
        luv.fs_realpath(utils.expand_file_name(user_config.org_roam_directory)) .. '/'
   -- Why concatenate '/' ?
   -- Because `fs_realpath' return something like `/path/to/dir'
   -- And when creating new nodes(files) we concatenate file name with it like:
   --   /path/to/dir .. file_name
   -- Which is not what we assume there, what we assume is:
   --   /path/to/dir/ .. file_name
   -- And so concatenate '/' at the end
end

local function org_roam_capture(title)
    if title == nil then
        title = vim.fn.input("Enter the title: ")
    end

    local filename = os.date("%Y%m%d%H%M%S") .. "_" .. title:gsub("%A", "_")
    local category = ""
    if filename:len() > 251 then
        category = filename:sub(1, 251)
        filename = category .. ".org"
    else
        category = filename
        filename = category .. ".org"
    end

    local uuid = utils.get_uuid()
    local node_head = ":PROPERTIES:\n:ID:        " .. uuid ..
                      "\n:END:\n#+title: " .. title .. "\n"

    local file_path = user_config.org_roam_directory .. filename
    local fp, err = io.open(file_path, "w")
    if fp == nil then
        print("Error: " .. err)
    else
        fp:write(node_head)
        fp:close()

        -- Do we need to update the hash when file changes?
        -- Is this verified in any way?
        local hash = sha1.sha1(node_head)

        local stat = luv.fs_stat(file_path)
        if not stat then
            print("ERROR: unable to get file stats")
        end

        -- Source: emacs-29.1/src/timefns.c:582
        local s = stat.atime.sec
        local ns = stat.atime.nsec
        local atime = '(' ..
        bit.rshift(s, 16) .. ' ' ..
        bit.band(s, bit.lshift(1, 16) - 1) .. ' ' ..
        math.floor(ns / 1000) .. ' ' ..
        ns % 1000 * 1000 ..
        ')'

        s = stat.mtime.sec
        ns = stat.atime.nsec
        local mtime = '(' ..
        bit.rshift(s, 16) .. ' ' ..
        bit.band(s, bit.lshift(1, 16) - 1) .. ' ' ..
        math.floor(ns / 1000) .. ' ' ..
        ns % 1000 * 1000 ..
        ')'

        -- File nodes have level 0
        -- Heading nodes have their heading level as level
        local level = 0

        -- Position of the node
        -- File nodes at pos 1
        -- Heading nodes have different position at file depending on where the
        -- first character is of that heading
        local pos = 1

        -- Why so complicated?
        local properties = "((\"CATEGORY . \"" ..
        category ..
        "\") (\"ID\" . \"" ..
        uuid ..
        "\") (\"BLOCKED\" . \"\") (\"FILE\" . \"" ..
        filename ..
        "\") (\"PRIORITY\" . \"B\"))"

        sqlite.with_open(user_config.org_roam_database_file, function (db)
            local ok = db:eval(
                "INSERT INTO files(file, title, hash, atime, mtime) " ..
                "VALUES(:file, :title, :hash, :atime, :mtime);", {
                file = file_path,
                title = title,
                hash = hash,
                atime = atime,
                mtime = mtime,
            })
            if not ok then
                print("ERROR: Something went wrong with inserting data into `files' table")
            end
            ok = db:eval(
                "INSERT INTO nodes(id, level, pos, file, title, properties) " ..
                "VALUES(:id, :level, :pos, :file, :title, :properties);", {
                id = uuid,
                level = level,
                pos = pos,
                file = file_path,
                title = title,
                properties = properties,
            })
            if not ok then
                print("ERROR: Something went wrong with inserting data into `nodes' table")
            end
        end)

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
                    else
                        local file = selection.value.file
                        local pos = selection.value.pos
                        local row = 1;

                        for line in io.lines(file) do
                            if (pos < line:len()) then break else
                                pos = pos - line:len()
                            end
                            row = row + 1
                        end

                        vim.cmd.edit(selection.value.file)
                        -- TODO Set the cursor in correct place
                        -- aka mimic emacs `goto-char' function
                        -- vim.api.nvim_win_set_cursor(0, { row, 0 })
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
