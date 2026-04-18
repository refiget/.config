-- Migrated basic keymaps from old config (plugin-agnostic)

local map = vim.keymap.set
local opts = { silent = true, noremap = true }

map("n", ";", ":", { desc = "Command mode" })
map("n", "Q", "<cmd>q<cr>", opts)
map("n", "Y", '"+yy', opts)
map("v", "Y", '"+y', opts)
map("n", "<leader><cr>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })

map("n", "J", "5j", opts)
map("n", "K", "5k", opts)
map("x", "J", "5j", opts)
map("x", "K", "5k", opts)

map("n", "<c-g>", "<cmd>echo line('.') col('.')<cr>", opts)

map("n", "<leader>(", "bi(<esc>ea)<esc>", opts)
map("n", "<leader>[", "bi[<esc>ea]<esc>", opts)
map("n", "<leader>{", "bi{<esc>ea}<esc>", opts)


map("n", "<leader>h", "<c-w>h", opts)
map("n", "<leader>j", "<c-w>j", opts)
map("n", "<leader>k", "<c-w>k", opts)
map("n", "<leader>l", "<c-w>l", opts)


local function open_run_term(cmd, cfg)
  cfg = cfg or {}
  local src_win = cfg.src_win

  vim.cmd("botright 12new")
  local term_win = vim.api.nvim_get_current_win()
  vim.bo.buflisted = false
  vim.bo.swapfile = false
  vim.bo.bufhidden = "wipe"

  vim.fn.termopen(cmd, {
    on_exit = function()
      if cfg.on_exit then
        vim.schedule(cfg.on_exit)
      end
    end,
  })

  if src_win and vim.api.nvim_win_is_valid(src_win) then
    vim.api.nvim_set_current_win(src_win)
  else
    vim.api.nvim_set_current_win(term_win)
  end
end

local function has_java_main()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  for _, l in ipairs(lines) do
    if l:match("public%s+static%s+void%s+main%s*%(") then
      return true
    end
  end
  return false
end

local function java_fqcn()
  local pkg
  local lines = vim.api.nvim_buf_get_lines(0, 0, math.min(80, vim.api.nvim_buf_line_count(0)), false)
  for _, l in ipairs(lines) do
    local p = l:match("^%s*package%s+([%w_%.]+)%s*;")
    if p then
      pkg = p
      break
    end
  end
  local cls = vim.fn.expand("%:t:r")
  return pkg and (pkg .. "." .. cls) or cls
end

local function parse_classpath(root, out_dir)
  local cp_file = root .. "/.classpath"
  local cp_parts = { out_dir }
  local src_dirs = { "src" }

  if vim.fn.filereadable(cp_file) == 1 then
    local lines = vim.fn.readfile(cp_file)
    local parsed_src = {}
    for _, l in ipairs(lines) do
      local kind = l:match('kind="([^"]+)"')
      local path = l:match('path="([^"]+)"')
      if kind == "lib" and path and path ~= "" then
        table.insert(cp_parts, path)
      elseif kind == "src" and path and path ~= "" then
        table.insert(parsed_src, path)
      end
    end
    if #parsed_src > 0 then
      src_dirs = parsed_src
    end
  else
    local home = vim.loop.os_homedir() or ""
    local fallback_glob = vim.env.CS61B_LIB_GLOB_ALL or (home .. "/cs61b/library-sp24/*")
    table.insert(cp_parts, vim.fn.expand(fallback_glob))
    if vim.fn.isdirectory(root .. "/tests") == 1 then
      table.insert(src_dirs, "tests")
    end
  end

  return table.concat(cp_parts, ":"), src_dirs
end

local function run_java_main()
  if not has_java_main() then
    vim.notify("No main method found in current file", vim.log.levels.WARN)
    return
  end

  vim.cmd("w")
  local root = vim.fn.getcwd()
  local out_dir = root .. "/out"
  local fqcn = java_fqcn()
  local cp, src_dirs = parse_classpath(root, out_dir)

  local compile_parts = {}
  for _, d in ipairs(src_dirs) do
    table.insert(compile_parts, "find " .. vim.fn.shellescape(d) .. " -name '*.java' -print0")
  end
  local find_cmd = table.concat(compile_parts, " ; ")

  local cmd = table.concat({
    "set -e",
    "OUT=" .. vim.fn.shellescape(out_dir),
    "CP=" .. vim.fn.shellescape(cp),
    "mkdir -p \"$OUT\"",
    "(" .. find_cmd .. ") | xargs -0 javac -proc:none -Xlint:-options -cp \"$CP\" -d \"$OUT\"",
    "java -cp \"$CP\" " .. vim.fn.shellescape(fqcn),
  }, " && ")

  local src_win = vim.api.nvim_get_current_win()
  local src_file = vim.api.nvim_buf_get_name(0)

  open_run_term({ "bash", "-lc", cmd }, {
    src_win = src_win,
    on_exit = function()
      if vim.api.nvim_win_is_valid(src_win) then
        vim.api.nvim_set_current_win(src_win)
      end
      if src_file ~= "" then
        pcall(vim.cmd, "edit " .. vim.fn.fnameescape(src_file))
      end

      local tries = 0
      local function wait_and_index()
        tries = tries + 1
        local attached = false
        local clients = vim.lsp.get_clients({ bufnr = 0 })
        for _, c in ipairs(clients) do
          if c.name == "jdtls" then
            attached = true
            break
          end
        end

        if attached or tries >= 20 then
          pcall(vim.cmd, "Cs61bIndex")
        else
          vim.defer_fn(wait_and_index, 120)
        end
      end
      vim.defer_fn(wait_and_index, 120)
    end,
  })
end

local function run_dispatch()
  local ft = vim.bo.filetype
  if ft == "java" then
    run_java_main()
  elseif ft == "python" then
    vim.cmd("w")
    open_run_term({ "python3", vim.fn.expand("%:p") })
  else
    vim.notify("R runner supports java/python for now", vim.log.levels.INFO)
  end
end

map("n", "R", run_dispatch, { desc = "Run current file (Java/Python)" })

-- Jump between failed test items in terminal / dap-repl output
local function jump_test_mark(mark, forward)
  mark = mark or "✗"
  local buf = vim.api.nvim_get_current_buf()
  local total = vim.api.nvim_buf_line_count(buf)
  if total == 0 then
    return
  end

  local row = vim.api.nvim_win_get_cursor(0)[1]
  local step = forward and 1 or -1

  for _ = 1, total do
    row = row + step
    if row > total then
      row = 1
    elseif row < 1 then
      row = total
    end

    local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
    if line:match("^%s*" .. mark) then
      vim.api.nvim_win_set_cursor(0, { row, 0 })
      vim.cmd("normal! zz")
      return
    end
  end

  vim.notify("No test line starting with " .. mark, vim.log.levels.INFO)
end

vim.api.nvim_create_user_command("TestNextFail", function()
  jump_test_mark("✗", true)
end, { desc = "Jump to next failed test line (✗)" })

vim.api.nvim_create_user_command("TestPrevFail", function()
  jump_test_mark("✗", false)
end, { desc = "Jump to previous failed test line (✗)" })

map("n", "<localleader>tf", function()
  jump_test_mark("✗", true)
end, { desc = "Next failed test (✗)" })

map("n", "<localleader>tF", function()
  jump_test_mark("✗", false)
end, { desc = "Prev failed test (✗)" })

-- Jump between any test items (success ✓ or fail ✗)
local function jump_any_test(forward)
  local buf = vim.api.nvim_get_current_buf()
  local total = vim.api.nvim_buf_line_count(buf)
  if total == 0 then
    return
  end

  local row = vim.api.nvim_win_get_cursor(0)[1]
  local step = forward and 1 or -1

  for _ = 1, total do
    row = row + step
    if row > total then
      row = 1
    elseif row < 1 then
      row = total
    end

    local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
    if line:match("^%s*[✓✗]") or line:match("[✓✗]%s*test") then
      vim.api.nvim_win_set_cursor(0, { row, 0 })
      vim.cmd("normal! zz")
      return
    end
  end

  vim.notify("No test line starting with ✓/✗", vim.log.levels.INFO)
end

vim.api.nvim_create_user_command("TestNext", function()
  jump_any_test(true)
end, { desc = "Jump to next test line (✓/✗)" })

vim.api.nvim_create_user_command("TestPrev", function()
  jump_any_test(false)
end, { desc = "Jump to previous test line (✓/✗)" })


-- DAP REPL friendly mappings: allow jump keys in n/i/t modes
local function jump_any_test_from_any_mode(forward)
  local mode = vim.api.nvim_get_mode().mode
  if mode:sub(1,1) == "t" then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "n", false)
  elseif mode:sub(1,1) == "i" then
    vim.cmd("stopinsert")
  end
  jump_any_test(forward)
end



-- Preferred leader mappings for test navigation
map({ "n", "i", "t" }, "<leader>tn", function()
  jump_any_test_from_any_mode(true)
end, { desc = "Next test (✓/✗)" })

map({ "n", "i", "t" }, "<leader>tp", function()
  jump_any_test_from_any_mode(false)
end, { desc = "Prev test (✓/✗)" })




-- Java: run test class and open bottom summary panel (uses jdtls after_test API)
map("n", "<leader>tj", function()
  vim.cmd("JavaTestClassPanel")
end, { desc = "Java test class panel" })

map("n", "<leader>tc", function()
  vim.cmd("JavaTestPanelClose")
end, { desc = "Close Java test panel" })
