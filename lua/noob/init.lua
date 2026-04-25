local M = {}
local panel_buf, panel_win

local defaults = {
    split = true,
    headers = {
        enable = true,
        highlights = true,
    },
    hints = {
        highlights = false,
        format = "  %-8s → %s",
    },
}

local function build(data, opts)
    local sorted = {}
    for _, cat in pairs(data) do
        table.insert(sorted, cat)
    end
    table.sort(sorted, function(a, b) return a.order < b.order end)

    local lines, highlights = {}, {}
    local line_nr = 0

    for _, cat in ipairs(sorted) do
        vim.api.nvim_set_hl(0, cat.header, { fg = cat.color, bold = true })

        if opts.headers.enable then
            table.insert(lines, cat.header)
            if opts.headers.highlights then
                table.insert(highlights, { line = line_nr, group = cat.header })
            end
            line_nr = line_nr + 1
        end

        for _, hint in ipairs(cat.hints) do
            table.insert(lines, string.format(
                opts.hints.format,
                hint[1], hint[2]
            ))
            if opts.hints.highlights then
                table.insert(highlights, { line = line_nr, group = cat.header })
            end
            line_nr = line_nr + 1
        end

        table.insert(lines, "")
        line_nr = line_nr + 1
    end

    return lines, highlights
end

local function open(data, opts)
    panel_buf = vim.api.nvim_create_buf(false, true)

    local lines, highlights = build(data, opts)
    vim.api.nvim_buf_set_lines(panel_buf, 0, -1, false, lines)

    local max_width = 0
    for _, line in ipairs(lines) do
        max_width = math.max(max_width, #line)
    end
    max_width = max_width + 2

    if opts.split then
        vim.cmd('botright ' .. max_width .. 'vsplit')
        panel_win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(panel_win, panel_buf)
        vim.wo[panel_win].number = false
        vim.wo[panel_win].relativenumber = false
        vim.wo[panel_win].signcolumn = "no"
        vim.wo[panel_win].wrap = false
        vim.wo[panel_win].winfixwidth = true
        vim.cmd('wincmd p')
    else
        panel_win = vim.api.nvim_open_win(panel_buf, false, {
            relative = "editor",
            width = max_width,
            height = vim.o.lines - 2,
            row = 0,
            col = vim.o.columns - max_width,
            style = "minimal",
            border = "rounded",
        })
    end

    for _, h in ipairs(highlights) do
        vim.api.nvim_buf_add_highlight(panel_buf, -1, h.group, h.line, 0, -1)
    end

    vim.bo[panel_buf].modifiable = false
    vim.bo[panel_buf].bufhidden = "wipe"

    vim.api.nvim_create_autocmd("WinClosed", {
        callback = function()
            local wins = vim.api.nvim_list_wins()
            if #wins == 1 and panel_win and vim.api.nvim_win_is_valid(panel_win) then
                vim.api.nvim_win_close(panel_win, true)
                panel_win = nil
                panel_buf = nil
            end
        end,
    })
end

function M.toggle(data, opts)
    if panel_win and vim.api.nvim_win_is_valid(panel_win) then
        vim.api.nvim_win_close(panel_win, true)
        panel_win = nil
        panel_buf = nil
    else
        open(data, opts)
    end
end

function M.setup(opts)
    opts = vim.tbl_deep_extend("force", defaults, opts or {})
    local data = opts.data or require('noob.data')
    vim.api.nvim_create_user_command("Noob", function()
        M.toggle(data, opts)
    end, {})
end

return M
