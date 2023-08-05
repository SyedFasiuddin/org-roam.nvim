local default_args = require("default-args")

local function setup(args)
    -- args = args or default_args
    if args.org_roam_directory == nil then
        print("Error: Please provide org_roam_directory")
    end

    local dir = args.org_roam_directory
    local files = vim.fn.glob(dir .. "**", false, true)
    local filtered_files = {}

    for _, val in ipairs(files) do
        if string.match(val, "org$") then
            table.insert(filtered_files, val)
        end
    end
    print(vim.inspect(filtered_files))
end

return {
    setup = setup,
}
