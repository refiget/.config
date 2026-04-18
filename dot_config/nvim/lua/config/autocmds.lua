-- Autocmds are automatically loaded on the VeryLazy event
-- Add any additional autocmds here

-- CS61B helper: warm-index all Java files in src/tests
local function cs61b_warm_index_once()
  local root = vim.fn.getcwd()
  vim.g._cs61b_indexed_roots = vim.g._cs61b_indexed_roots or {}
  if vim.g._cs61b_indexed_roots[root] then
    return
  end

  local roots = { "src", "tests" }
  local files = {}
  for _, r in ipairs(roots) do
    local found = vim.fn.glob(r .. "/**/*.java", false, true)
    if type(found) == "table" then
      vim.list_extend(files, found)
    end
  end

  if #files == 0 then
    return
  end

  vim.g._cs61b_indexed_roots[root] = true

  -- single status message (no notify spam)
  vim.api.nvim_echo({ { "Index established", "ModeMsg" } }, false, {})

  -- warm buffers without changing current window
  for _, f in ipairs(files) do
    local b = vim.fn.bufadd(f)
    pcall(vim.fn.bufload, b)
  end

  -- ask jdtls to refresh project model/diagnostics
  for _, c in ipairs(vim.lsp.get_clients()) do
    if c.name == "jdtls" then
      pcall(c.request_sync, c, "workspace/executeCommand", { command = "java.project.import" }, 3000, 0)
      pcall(c.request_sync, c, "workspace/executeCommand", { command = "java.project.refreshDiagnostics" }, 3000, 0)
    end
  end

end

-- Manual command (still available)
vim.api.nvim_create_user_command("Cs61bIndex", function()
  -- clear current-root mark, then run once now
  local root = vim.fn.getcwd()
  vim.g._cs61b_indexed_roots = vim.g._cs61b_indexed_roots or {}
  vim.g._cs61b_indexed_roots[root] = nil
  cs61b_warm_index_once()
end, { desc = "Warm-index all Java files in src/tests" })

-- Auto-run once when jdtls attaches in a CS61B-style project
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if not client or client.name ~= "jdtls" then
      return
    end

    local has_src = vim.fn.isdirectory("src") == 1
    local has_tests = vim.fn.isdirectory("tests") == 1
    local has_marker = vim.fn.filereadable(".cs61b-root") == 1
    if not ((has_src and has_tests) or has_marker) then
      return
    end

    -- Defer slightly to let initial project import settle
    vim.defer_fn(function()
      pcall(cs61b_warm_index_once)
    end, 1200)
  end,
})

-- Markdown: disable conceal so md shows raw syntax (no "natural rendering")
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown", "md", "rmd", "quarto" },
  callback = function()
    vim.opt_local.conceallevel = 0
    vim.opt_local.concealcursor = ""
  end,
})

-- Force statusline background to match Normal background
local function sync_statusline_bg_to_normal()
  local n = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
  local s = vim.api.nvim_get_hl(0, { name = "StatusLine", link = false })
  local snc = vim.api.nvim_get_hl(0, { name = "StatusLineNC", link = false })
  if not n or not n.bg then
    return
  end
  vim.api.nvim_set_hl(0, "StatusLine", { fg = s and s.fg or nil, bg = n.bg, bold = s and s.bold or false })
  vim.api.nvim_set_hl(0, "StatusLineNC", { fg = snc and snc.fg or nil, bg = n.bg })
end

vim.api.nvim_create_autocmd({ "ColorScheme", "VimEnter" }, {
  callback = function()
    vim.schedule(sync_statusline_bg_to_normal)
  end,
})

-- Re-apply after lualine/theme finalizes
vim.api.nvim_create_autocmd({ "User" }, {
  pattern = "VeryLazy",
  callback = function()
    vim.defer_fn(function()
      local n = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
      local s = vim.api.nvim_get_hl(0, { name = "StatusLine", link = false })
      local snc = vim.api.nvim_get_hl(0, { name = "StatusLineNC", link = false })
      if n and n.bg then
        vim.api.nvim_set_hl(0, "StatusLine", { fg = s and s.fg or nil, bg = n.bg, bold = s and s.bold or false })
        vim.api.nvim_set_hl(0, "StatusLineNC", { fg = snc and snc.fg or nil, bg = n.bg })
      end
    end, 120)
  end,
})


-- Clean jdtls index/cache for current project and restart LSP
vim.api.nvim_create_user_command("JavaIndexClean", function()
  local data = vim.fn.stdpath("data")
  local root = vim.fn.getcwd()
  local ws = data .. "/jdtls-workspace/" .. vim.fn.fnamemodify(root, ":p:h:t")

  -- stop jdtls clients first (release files)
  for _, c in ipairs(vim.lsp.get_clients()) do
    if c.name == "jdtls" then
      pcall(vim.lsp.stop_client, c.id, true)
    end
  end

  -- clear warm-index memo for this root
  vim.g._cs61b_indexed_roots = vim.g._cs61b_indexed_roots or {}
  vim.g._cs61b_indexed_roots[root] = nil

  if vim.fn.isdirectory(ws) == 1 then
    vim.fn.delete(ws, "rf")
    vim.notify("Java index cache cleaned: " .. ws, vim.log.levels.INFO)
  else
    vim.notify("No Java index cache dir: " .. ws, vim.log.levels.INFO)
  end

  -- restart lsp so jdtls re-imports project
  vim.defer_fn(function()
    pcall(vim.cmd, "LspStart jdtls")
    vim.defer_fn(function()
      pcall(vim.cmd, "Cs61bIndex")
    end, 1200)
  end, 300)
end, { desc = "Clean jdtls workspace cache for current project and re-index" })


-- Auto-show diagnostics float on hover, normal mode only
vim.api.nvim_create_autocmd("CursorHold", {
  callback = function()
    if vim.api.nvim_get_mode().mode ~= "n" then
      return
    end
    vim.diagnostic.open_float(nil, {
      focus = false,
      scope = "cursor",
      close_events = { "CursorMoved", "CursorMovedI", "BufHidden", "InsertEnter", "WinLeave" },
    })
  end,
})

-- Java tests: run class and show bottom 12-line split panel (left summary, right details)
local java_test_panel = {
  left_buf = nil,
  right_buf = nil,
  left_win = nil,
  right_win = nil,
  tests_by_line = {},
}

vim.api.nvim_set_hl(0, "JavaTestPass", { fg = "#22c55e", bold = true })
vim.api.nvim_set_hl(0, "JavaTestFail", { fg = "#ef4444", bold = true })
vim.api.nvim_set_hl(0, "JavaTestTraceLine", { fg = "#ef4444", underline = true })
vim.api.nvim_set_hl(0, "JavaTestTitle", { fg = "#7aa2f7", bold = true })
vim.api.nvim_set_hl(0, "JavaTestKey", { fg = "#9d7cd8", bold = true })
vim.api.nvim_set_hl(0, "JavaTestStatusPass", { fg = "#9ece6a", bold = true })
vim.api.nvim_set_hl(0, "JavaTestStatusFail", { fg = "#f7768e", bold = true, underline = true })
vim.api.nvim_set_hl(0, "JavaTestSummary", { fg = "#7aa2f7", bold = true })
vim.api.nvim_set_hl(0, "JavaTestDivider", { fg = "#565f89" })
vim.api.nvim_set_hl(0, "JavaTestRowPass", { fg = "#9ece6a" })
vim.api.nvim_set_hl(0, "JavaTestRowFail", { fg = "#f7768e" })

local function panel_is_alive()
  return java_test_panel.left_win and vim.api.nvim_win_is_valid(java_test_panel.left_win)
    and java_test_panel.right_win and vim.api.nvim_win_is_valid(java_test_panel.right_win)
    and java_test_panel.left_buf and vim.api.nvim_buf_is_valid(java_test_panel.left_buf)
    and java_test_panel.right_buf and vim.api.nvim_buf_is_valid(java_test_panel.right_buf)
end

local function set_scratch(buf)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = "java-test-panel"
end

local function render_right(test)
  if not (java_test_panel.right_buf and vim.api.nvim_buf_is_valid(java_test_panel.right_buf)) then
    return
  end

  vim.bo[java_test_panel.right_buf].modifiable = true
  local lines = {}
  if not test then
    lines = { "No test selected." }
  else
    table.insert(lines, string.format("Test: %s", test.method or "<unknown>"))
    table.insert(lines, string.format("Class: %s", test.fq_class or "<unknown>"))
    table.insert(lines, string.format("Status: %s", test.failed and "FAILED" or "PASSED"))
    table.insert(lines, "")
    if test.failed and test.traces and #test.traces > 0 then
      vim.list_extend(lines, test.traces)
    elseif test.failed then
      table.insert(lines, "(No trace available)")
    else
      table.insert(lines, "No error. Test passed.")
    end
  end
  vim.api.nvim_buf_set_lines(java_test_panel.right_buf, 0, -1, false, lines)

  -- Highlight right-panel structure + stacktrace lines (TokyoNight tuned)
  local rns = vim.api.nvim_create_namespace("java-test-panel-right")
  vim.api.nvim_buf_clear_namespace(java_test_panel.right_buf, rns, 0, -1)

  for i, l in ipairs(lines) do
    if l:match("^Test:%s") then
      vim.api.nvim_buf_add_highlight(java_test_panel.right_buf, rns, "JavaTestTitle", i - 1, 0, -1)
      vim.api.nvim_buf_add_highlight(java_test_panel.right_buf, rns, "JavaTestKey", i - 1, 0, 5)
    elseif l:match("^Class:%s") then
      vim.api.nvim_buf_add_highlight(java_test_panel.right_buf, rns, "JavaTestTitle", i - 1, 0, -1)
      vim.api.nvim_buf_add_highlight(java_test_panel.right_buf, rns, "JavaTestKey", i - 1, 0, 6)
    elseif l:match("^Status:%s") then
      vim.api.nvim_buf_add_highlight(java_test_panel.right_buf, rns, "JavaTestTitle", i - 1, 0, -1)
      vim.api.nvim_buf_add_highlight(java_test_panel.right_buf, rns, "JavaTestKey", i - 1, 0, 7)
      local status = l:match("^Status:%s+(%w+)")
      if status == "FAILED" then
        local col = l:find("FAILED", 1, true)
        if col then vim.api.nvim_buf_add_highlight(java_test_panel.right_buf, rns, "JavaTestStatusFail", i - 1, col - 1, col - 1 + #"FAILED") end
      elseif status == "PASSED" then
        local col = l:find("PASSED", 1, true)
        if col then vim.api.nvim_buf_add_highlight(java_test_panel.right_buf, rns, "JavaTestStatusPass", i - 1, col - 1, col - 1 + #"PASSED") end
      end
    elseif l:match("^%s*at%s+[%w_%.%$]+%.[%w_%$<>]+%([^:]+:%d+%)") then
      vim.api.nvim_buf_add_highlight(java_test_panel.right_buf, rns, "JavaTestTraceLine", i - 1, 0, -1)
    end
  end

  vim.bo[java_test_panel.right_buf].modifiable = false
end

local function render_left_and_bind(tests)
  local passed, failed = 0, 0
  for _, t in ipairs(tests or {}) do
    if t.failed then failed = failed + 1 else passed = passed + 1 end
  end

  local width = 60
  if java_test_panel.left_win and vim.api.nvim_win_is_valid(java_test_panel.left_win) then
    width = math.max(20, vim.api.nvim_win_get_width(java_test_panel.left_win) - 2)
  end

  local lines = {
    string.format("Java Tests  total:%d  pass:%d  fail:%d", #(tests or {}), passed, failed),
    string.rep("─", width),
  }

  -- Resize left pane to just fit summary line + 3 cols, so right error pane stays wider.
  if java_test_panel.left_win and vim.api.nvim_win_is_valid(java_test_panel.left_win) then
    local summary_w = vim.fn.strdisplaywidth(lines[1])
    local target_w = math.max(24, summary_w + 3)
    pcall(vim.api.nvim_win_set_width, java_test_panel.left_win, target_w)
  end

  java_test_panel.tests_by_line = {}
  for _, t in ipairs(tests or {}) do
    local mark = t.failed and "✗" or "✓"
    table.insert(lines, string.format("%s %s", mark, t.method or (t.fq_class or "<unknown>")))
    java_test_panel.tests_by_line[#lines] = t
  end

  vim.bo[java_test_panel.left_buf].modifiable = true
  vim.api.nvim_buf_set_lines(java_test_panel.left_buf, 0, -1, false, lines)
  vim.bo[java_test_panel.left_buf].modifiable = false

  -- Left panel highlights (summary + rows)
  local ns = vim.api.nvim_create_namespace("java-test-panel")
  vim.api.nvim_buf_clear_namespace(java_test_panel.left_buf, ns, 0, -1)

  -- line 1 summary
  vim.api.nvim_buf_add_highlight(java_test_panel.left_buf, ns, "JavaTestSummary", 0, 0, -1)
  local summary = lines[1] or ""
  local function hi_token(tok, group)
    local c = summary:find(tok, 1, true)
    if c then
      vim.api.nvim_buf_add_highlight(java_test_panel.left_buf, ns, group, 0, c - 1, c - 1 + #tok)
    end
  end
  hi_token("pass:" .. tostring(passed), "JavaTestStatusPass")
  hi_token("fail:" .. tostring(failed), "JavaTestStatusFail")

  -- line 2 divider
  vim.api.nvim_buf_add_highlight(java_test_panel.left_buf, ns, "JavaTestDivider", 1, 0, -1)

  -- test rows
  for lnum = 3, #lines do
    local line = lines[lnum] or ""
    if vim.startswith(line, "✓") then
      vim.api.nvim_buf_add_highlight(java_test_panel.left_buf, ns, "JavaTestPass", lnum - 1, 0, 3)
      vim.api.nvim_buf_add_highlight(java_test_panel.left_buf, ns, "JavaTestRowPass", lnum - 1, 4, -1)
    elseif vim.startswith(line, "✗") then
      vim.api.nvim_buf_add_highlight(java_test_panel.left_buf, ns, "JavaTestFail", lnum - 1, 0, 3)
      vim.api.nvim_buf_add_highlight(java_test_panel.left_buf, ns, "JavaTestRowFail", lnum - 1, 4, -1)
    end
  end

  local function sync_from_cursor()
    if not (java_test_panel.left_win and vim.api.nvim_win_is_valid(java_test_panel.left_win)) then
      return
    end
    local lnum = vim.api.nvim_win_get_cursor(java_test_panel.left_win)[1]
    render_right(java_test_panel.tests_by_line[lnum])
  end

  vim.keymap.set("n", "<CR>", function()
    sync_from_cursor()

    if vim.fn.exists(":JavaTraceJump") ~= 2 then
      vim.notify("JavaTraceJump is not available yet", vim.log.levels.WARN)
      return
    end

    if not (java_test_panel.right_win and vim.api.nvim_win_is_valid(java_test_panel.right_win)) then
      vim.notify("Right test panel is not available", vim.log.levels.WARN)
      return
    end

    local lines = vim.api.nvim_buf_get_lines(java_test_panel.right_buf, 0, -1, false)
    local trace_lnum = nil
    for i, l in ipairs(lines) do
      if l:match("at%s+[%w_%.%$]+%.[%w_%$<>]+%([^:]+:%d+%)") then
        trace_lnum = i
        break
      end
    end

    if not trace_lnum then
      vim.notify("No stacktrace line found for selected test", vim.log.levels.INFO)
      return
    end

    vim.api.nvim_set_current_win(java_test_panel.right_win)
    vim.api.nvim_win_set_cursor(java_test_panel.right_win, { trace_lnum, 0 })
    vim.cmd("JavaTraceJump")
  end, {
    buffer = java_test_panel.left_buf,
    silent = true,
    desc = "Jump to selected test failure location",
  })

  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = java_test_panel.left_buf,
    callback = sync_from_cursor,
  })

  vim.keymap.set("n", "q", function()
    if java_test_panel.left_win and vim.api.nvim_win_is_valid(java_test_panel.left_win) then
      pcall(vim.api.nvim_win_close, java_test_panel.left_win, true)
    end
    if java_test_panel.right_win and vim.api.nvim_win_is_valid(java_test_panel.right_win) then
      pcall(vim.api.nvim_win_close, java_test_panel.right_win, true)
    end
  end, { buffer = java_test_panel.left_buf, silent = true, desc = "Close test panel" })

  local first_line = 3
  if java_test_panel.tests_by_line[first_line] then
    vim.api.nvim_set_current_win(java_test_panel.left_win)
    vim.api.nvim_win_set_cursor(java_test_panel.left_win, { first_line, 0 })
    sync_from_cursor()
  else
    render_right(nil)
  end
end

local function ensure_panel()
  if panel_is_alive() then
    vim.api.nvim_set_current_win(java_test_panel.left_win)
    return
  end

  vim.cmd("botright 12split")
  java_test_panel.left_win = vim.api.nvim_get_current_win()

  if java_test_panel.left_buf and vim.api.nvim_buf_is_valid(java_test_panel.left_buf) then
    vim.api.nvim_win_set_buf(java_test_panel.left_win, java_test_panel.left_buf)
  else
    java_test_panel.left_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(java_test_panel.left_win, java_test_panel.left_buf)
    set_scratch(java_test_panel.left_buf)
  end

  vim.cmd("vsplit")
  java_test_panel.right_win = vim.api.nvim_get_current_win()
  if java_test_panel.right_buf and vim.api.nvim_buf_is_valid(java_test_panel.right_buf) then
    vim.api.nvim_win_set_buf(java_test_panel.right_win, java_test_panel.right_buf)
  else
    java_test_panel.right_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(java_test_panel.right_win, java_test_panel.right_buf)
    set_scratch(java_test_panel.right_buf)
  end

  local target = math.max(24, math.floor(vim.o.columns * 0.26) - 8)
  pcall(vim.api.nvim_win_set_width, java_test_panel.left_win, target)

  -- panel windows: cleaner look (no line numbers/signcolumn)
  vim.wo[java_test_panel.left_win].number = false
  vim.wo[java_test_panel.left_win].relativenumber = false
  vim.wo[java_test_panel.left_win].signcolumn = "no"
  vim.wo[java_test_panel.left_win].cursorline = true

  vim.wo[java_test_panel.right_win].number = false
  vim.wo[java_test_panel.right_win].relativenumber = false
  vim.wo[java_test_panel.right_win].signcolumn = "no"

  vim.api.nvim_set_current_win(java_test_panel.left_win)
end

vim.api.nvim_create_user_command("JavaTestPanelClose", function()
  if java_test_panel.left_win and vim.api.nvim_win_is_valid(java_test_panel.left_win) then
    pcall(vim.api.nvim_win_close, java_test_panel.left_win, true)
  end
  if java_test_panel.right_win and vim.api.nvim_win_is_valid(java_test_panel.right_win) then
    pcall(vim.api.nvim_win_close, java_test_panel.right_win, true)
  end
end, { desc = "Close Java test panel" })

vim.api.nvim_create_user_command("JavaTestClassPanel", function()
  local ok, jdtls_dap = pcall(require, "jdtls.dap")
  if not ok then
    vim.notify("jdtls.dap not available", vim.log.levels.WARN)
    return
  end

  -- Guard: run tests only from a real java file buffer (avoid file:// invalid URI from panel buffers)
  local target_buf = nil
  local cur = vim.api.nvim_get_current_buf()
  local cur_name = vim.api.nvim_buf_get_name(cur)
  if vim.bo[cur].filetype == "java" and cur_name ~= "" then
    target_buf = cur
  else
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(b) and vim.bo[b].filetype == "java" and vim.api.nvim_buf_get_name(b) ~= "" then
        target_buf = b
        break
      end
    end
  end

  if not target_buf then
    vim.notify("JavaTestClassPanel: open a real .java file first", vim.log.levels.WARN)
    return
  end

  vim.g._dapui_suppress_next_open = true
  jdtls_dap.test_class({
    bufnr = target_buf,
    after_test = function(_, tests)
      vim.schedule(function()
        ensure_panel()
        render_left_and_bind(tests or {})
      end)
    end,
  })
end, { desc = "Run Java test class and open bottom summary panel" })
