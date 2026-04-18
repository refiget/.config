local function tmux_active_pane()
	if not vim.env.TMUX or vim.env.TMUX == "" then
		return nil
	end
	local out = vim.fn.system({ "tmux", "display-message", "-p", "#{pane_id}" })
	if vim.v.shell_error ~= 0 then
		return nil
	end
	return vim.trim(out)
end

local function focus_yabai(direction)
	vim.fn.system({ "/opt/homebrew/bin/yabai", "-m", "window", "--focus", direction })
end

local function navigate(cmd, direction)
	local win_before = vim.api.nvim_get_current_win()
	local pane_before = tmux_active_pane()

	vim.cmd(cmd)

	local win_after = vim.api.nvim_get_current_win()
	local pane_after = tmux_active_pane()
	if win_after ~= win_before then
		return
	end

	if pane_before then
		if pane_after == pane_before then
			focus_yabai(direction)
		end
		return
	end

	focus_yabai(direction)
end

return {
	"christoomey/vim-tmux-navigator",
	init = function()
		vim.g.tmux_navigator_no_mappings = 1
		vim.g.tmux_navigator_no_wrap = 1
	end,
	keys = {
		{ "<M-h>", function() navigate("TmuxNavigateLeft", "west") end, desc = "Tmux navigate left (alt)" },
		{ "<M-j>", function() navigate("TmuxNavigateDown", "south") end, desc = "Tmux navigate down (alt)" },
		{ "<M-k>", function() navigate("TmuxNavigateUp", "north") end, desc = "Tmux navigate up (alt)" },
		{ "<M-l>", function() navigate("TmuxNavigateRight", "east") end, desc = "Tmux navigate right (alt)" },
		{ "<M-\\>", "<cmd>TmuxNavigatePrevious<cr>", desc = "Tmux navigate previous (alt)" },
	},
}
