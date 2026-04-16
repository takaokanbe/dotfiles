local wezterm = require("wezterm")
local act = wezterm.action
local mux = wezterm.mux
local config = wezterm.config_builder()


-- Helper: get directory choices (zoxide history + scan of ~/dev)
local function get_dir_choices()
	local choices = {}
	local seen = {}

	-- zoxide history (frequently used dirs first)
	local success, stdout = wezterm.run_child_process({ os.getenv("SHELL"), "-l", "-c", "zoxide query -l" })
	if success then
		for _, path in ipairs(wezterm.split_by_newlines(stdout)) do
			if not seen[path] then
				seen[path] = true
				local label = string.gsub(path, wezterm.home_dir, "~")
				table.insert(choices, { id = path, label = label })
			end
		end
	end

	-- Scan ~/dev up to 3 levels deep for directories not already in zoxide
	local scan_success, scan_stdout = wezterm.run_child_process({
		os.getenv("SHELL"), "-l", "-c",
		"find " .. wezterm.home_dir .. "/dev -maxdepth 2 -type d -not -path '*/.*' 2>/dev/null",
	})
	if scan_success then
		for _, path in ipairs(wezterm.split_by_newlines(scan_stdout)) do
			if not seen[path] then
				seen[path] = true
				local label = string.gsub(path, wezterm.home_dir, "~")
				table.insert(choices, { id = path, label = label })
			end
		end
	end

	return choices
end

-- Helper: create 3x3 grid in a tab
local function create_grid(first_pane)
	local row2 = first_pane:split({ direction = "Bottom", size = 0.67 })
	local row3 = row2:split({ direction = "Bottom", size = 0.5 })
	first_pane:split({ direction = "Right", size = 0.67 }):split({ direction = "Right", size = 0.5 })
	row2:split({ direction = "Right", size = 0.67 }):split({ direction = "Right", size = 0.5 })
	row3:split({ direction = "Right", size = 0.67 }):split({ direction = "Right", size = 0.5 })
end

-- Color scheme
config.color_scheme = "Catppuccin Mocha"

-- Font
config.font = wezterm.font("FiraMono Nerd Font Mono")
config.font_size = 15
config.harfbuzz_features = { "calt=0", "liga=0", "dlig=0" }

-- Window
config.window_padding = {
	left = 20,
	right = 20,
	top = 20,
	bottom = 20,
}
config.window_background_opacity = 0.9
config.macos_window_background_blur = 5
config.window_decorations = "RESIZE"
config.window_frame = {
	border_left_width = "1.5",
	border_right_width = "1.5",
	border_bottom_height = "1.5",
	border_top_height = "1.5",
	border_left_color = "#585b70",
	border_right_color = "#585b70",
	border_bottom_color = "#585b70",
	border_top_color = "#585b70",
}
config.enable_tab_bar = false
config.colors = {
	split = "#585b70",
}

-- Cursor
config.default_cursor_style = "BlinkingBlock"

-- IME
config.use_ime = true

-- Leader
config.leader = { key = "b", mods = "CTRL", timeout_milliseconds = 1000 }

-- Keys
config.send_composed_key_when_left_alt_is_pressed = true
config.send_composed_key_when_right_alt_is_pressed = true

-- Helper: equalize pane sizes in a tab
-- Based on curbol's binary-tree reconstruction + probe-and-discover approach
-- https://gist.github.com/curbol/8347b6726b0d988e94cf080f7eacabc0
local function equalize_panes(window)
	local tab = window:active_tab()
	local initial_panes = tab:panes_with_info()
	if #initial_panes <= 1 then
		return
	end

	local active_idx = 0
	for _, pi in ipairs(initial_panes) do
		if pi.is_active then
			active_idx = pi.index
		end
	end

	local function build_tree(ps)
		if #ps == 1 then
			return { type = "pane", pane = ps[1], width = ps[1].width, height = ps[1].height }
		end
		local xs = {}
		for _, p in ipairs(ps) do
			xs[p.left + p.width] = true
		end
		local xs_sorted = {}
		for x in pairs(xs) do
			table.insert(xs_sorted, x)
		end
		table.sort(xs_sorted)
		for _, x in ipairs(xs_sorted) do
			local left_ps, right_ps = {}, {}
			for _, p in ipairs(ps) do
				if p.left + p.width <= x then
					table.insert(left_ps, p)
				elseif p.left >= x then
					table.insert(right_ps, p)
				end
			end
			if #left_ps + #right_ps == #ps and #left_ps > 0 and #right_ps > 0 then
				local lc = build_tree(left_ps)
				local rc = build_tree(right_ps)
				return {
					type = "vsplit",
					left_child = lc,
					right_child = rc,
					width = lc.width + rc.width,
					height = lc.height,
				}
			end
		end
		local ys = {}
		for _, p in ipairs(ps) do
			ys[p.top + p.height] = true
		end
		local ys_sorted = {}
		for y in pairs(ys) do
			table.insert(ys_sorted, y)
		end
		table.sort(ys_sorted)
		for _, y in ipairs(ys_sorted) do
			local top_ps, bot_ps = {}, {}
			for _, p in ipairs(ps) do
				if p.top + p.height <= y then
					table.insert(top_ps, p)
				elseif p.top >= y then
					table.insert(bot_ps, p)
				end
			end
			if #top_ps + #bot_ps == #ps and #top_ps > 0 and #bot_ps > 0 then
				local tc = build_tree(top_ps)
				local bc = build_tree(bot_ps)
				return {
					type = "hsplit",
					top_child = tc,
					bot_child = bc,
					width = tc.width,
					height = tc.height + bc.height,
				}
			end
		end
		return { type = "pane", pane = ps[1], width = ps[1].width, height = ps[1].height }
	end

	local function far_pane(node)
		if node.type == "pane" then
			return node.pane
		end
		if node.type == "vsplit" then
			return far_pane(node.right_child)
		end
		return far_pane(node.bot_child)
	end

	local function collect_panes(node, out)
		out = out or {}
		if node.type == "pane" then
			table.insert(out, node.pane)
		elseif node.type == "vsplit" then
			collect_panes(node.left_child, out)
			collect_panes(node.right_child, out)
		elseif node.type == "hsplit" then
			collect_panes(node.top_child, out)
			collect_panes(node.bot_child, out)
		end
		return out
	end

	local function count_columns(node)
		if node.type == "vsplit" then
			return count_columns(node.left_child) + count_columns(node.right_child)
		end
		return 1
	end

	local function count_rows(node)
		if node.type == "hsplit" then
			return count_rows(node.top_child) + count_rows(node.bot_child)
		end
		return 1
	end

	local function snapshot()
		local s = {}
		for _, pi in ipairs(tab:panes_with_info()) do
			s[pi.index] = { width = pi.width, height = pi.height }
		end
		return s
	end

	local function probe(candidate_idx, pos_dir, neg_dir, prop, verify_idx)
		local before = snapshot()
		window:perform_action(act.ActivatePaneByIndex(candidate_idx), tab:active_pane())
		window:perform_action(act.AdjustPaneSize({ pos_dir, 1 }), tab:active_pane())
		local after = snapshot()
		local cand_delta = after[candidate_idx][prop] - before[candidate_idx][prop]
		local verify_delta = after[verify_idx][prop] - before[verify_idx][prop]
		window:perform_action(act.AdjustPaneSize({ neg_dir, 1 }), tab:active_pane())
		if cand_delta ~= 0 and verify_delta ~= 0 and cand_delta ~= verify_delta then
			return cand_delta > 0 and "grow" or "shrink"
		end
		return nil
	end

	local function try_adjust(candidates, delta, pos_dir, neg_dir, prop)
		for _, c in ipairs(candidates) do
			local result = probe(c.index, pos_dir, neg_dir, prop, c.verify)
			if result then
				window:perform_action(act.ActivatePaneByIndex(c.index), tab:active_pane())
				local grow = (c.side == "left") == (result == "grow")
				if grow then
					if delta > 0 then
						window:perform_action(act.AdjustPaneSize({ pos_dir, delta }), tab:active_pane())
					else
						window:perform_action(act.AdjustPaneSize({ neg_dir, -delta }), tab:active_pane())
					end
				else
					if delta > 0 then
						window:perform_action(act.AdjustPaneSize({ neg_dir, delta }), tab:active_pane())
					else
						window:perform_action(act.AdjustPaneSize({ pos_dir, -delta }), tab:active_pane())
					end
				end
				return true
			end
		end
		return false
	end

	for _ = 1, #initial_panes - 1 do
		local ps = tab:panes_with_info()
		local tree = build_tree(ps)
		local queue = { tree }
		local adjusted = false
		while #queue > 0 and not adjusted do
			local node = table.remove(queue, 1)
			if node.type == "vsplit" then
				local lc, rc = node.left_child, node.right_child
				local l_cols = count_columns(lc)
				local r_cols = count_columns(rc)
				local total = lc.width + rc.width
				local target_l = math.floor(total * l_cols / (l_cols + r_cols))
				local delta = target_l - lc.width
				if delta ~= 0 then
					local left_panes = collect_panes(lc)
					local right_panes = collect_panes(rc)
					local right_far = far_pane(rc)
					local left_far = far_pane(lc)
					local candidates = {}
					for _, p in ipairs(left_panes) do
						table.insert(candidates, { index = p.index, side = "left", verify = right_far.index })
					end
					for _, p in ipairs(right_panes) do
						table.insert(candidates, { index = p.index, side = "right", verify = left_far.index })
					end
					adjusted = try_adjust(candidates, delta, "Right", "Left", "width")
				end
				if not adjusted then
					table.insert(queue, lc)
					table.insert(queue, rc)
				end
			elseif node.type == "hsplit" then
				local tc, bc = node.top_child, node.bot_child
				local t_rows = count_rows(tc)
				local b_rows = count_rows(bc)
				local total = tc.height + bc.height
				local target_t = math.floor(total * t_rows / (t_rows + b_rows))
				local delta = target_t - tc.height
				if delta ~= 0 then
					local top_panes = collect_panes(tc)
					local bot_panes = collect_panes(bc)
					local bot_far = far_pane(bc)
					local top_far = far_pane(tc)
					local candidates = {}
					for _, p in ipairs(top_panes) do
						table.insert(candidates, { index = p.index, side = "left", verify = bot_far.index })
					end
					for _, p in ipairs(bot_panes) do
						table.insert(candidates, { index = p.index, side = "right", verify = top_far.index })
					end
					adjusted = try_adjust(candidates, delta, "Down", "Up", "height")
				end
				if not adjusted then
					table.insert(queue, tc)
					table.insert(queue, bc)
				end
			end
		end
		if not adjusted then
			break
		end
	end

	window:perform_action(act.ActivatePaneByIndex(active_idx), tab:active_pane())
end

-- Helper: move between panes while keeping zoom state
local function move_and_zoom(direction)
	return wezterm.action_callback(function(window, pane)
		local tab = window:active_tab()
		local was_zoomed = tab:set_zoomed(false)
		window:perform_action(act.ActivatePaneDirection(direction), pane)
		if was_zoomed then
			tab:set_zoomed(true)
		end
	end)
end

config.keys = {
	-- Pane navigation: Shift+Arrow (no leader, like tmux config)
	{ key = "LeftArrow", mods = "SHIFT", action = move_and_zoom("Left") },
	{ key = "DownArrow", mods = "SHIFT", action = move_and_zoom("Down") },
	{ key = "UpArrow", mods = "SHIFT", action = move_and_zoom("Up") },
	{ key = "RightArrow", mods = "SHIFT", action = move_and_zoom("Right") },
	-- Pane navigation: Alt+number to jump to pane directly (1-9)
	{ key = "1", mods = "ALT", action = act.ActivatePaneByIndex(0) },
	{ key = "2", mods = "ALT", action = act.ActivatePaneByIndex(1) },
	{ key = "3", mods = "ALT", action = act.ActivatePaneByIndex(2) },
	{ key = "4", mods = "ALT", action = act.ActivatePaneByIndex(3) },
	{ key = "5", mods = "ALT", action = act.ActivatePaneByIndex(4) },
	{ key = "6", mods = "ALT", action = act.ActivatePaneByIndex(5) },
	{ key = "7", mods = "ALT", action = act.ActivatePaneByIndex(6) },
	{ key = "8", mods = "ALT", action = act.ActivatePaneByIndex(7) },
	{ key = "9", mods = "ALT", action = act.ActivatePaneByIndex(8) },
	-- Pane: equalize sizes
	{
		key = "=",
		mods = "LEADER",
		action = wezterm.action_callback(function(window)
			equalize_panes(window)
		end),
	},
	-- Pane zoom toggle
	{ key = "z", mods = "LEADER", action = act.TogglePaneZoomState },
	-- Pane split
	{ key = '"', mods = "LEADER|SHIFT", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
	{ key = "%", mods = "LEADER|SHIFT", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
	-- Pane close
	{ key = "x", mods = "LEADER", action = act.CloseCurrentPane({ confirm = true }) },
	-- Open Claude Code in a right pane
	{
		key = "a",
		mods = "LEADER",
		action = wezterm.action_callback(function(_, pane)
			local new_pane = pane:split({ direction = "Right" })
			new_pane:send_text("claude\n")
		end),
	},
	-- Tab: pick directory from zoxide, then create 3x3 grid
	{
		key = "c",
		mods = "LEADER",
		action = wezterm.action_callback(function(window, pane)
			local choices = get_dir_choices()
			table.insert(choices, 1, { id = "__input__", label = "  Enter path manually..." })
			window:perform_action(
				act.InputSelector({
					title = "New Tab - Choose Directory",
					fuzzy_description = "Directory: ",
					choices = choices,
					fuzzy = true,
					action = wezterm.action_callback(function(inner_window, inner_pane, id)
						if not id then
							return
						end
						if id == "__input__" then
							inner_window:perform_action(
								act.PromptInputLine({
									description = "Enter directory path (e.g. ~/dev/my-repo):",
									action = wezterm.action_callback(function(w, p, line)
										if line and line ~= "" then
											local path = string.gsub(line, "^~", wezterm.home_dir)
											local _, first_pane = w:mux_window():spawn_tab({ cwd = path })
											create_grid(first_pane)
										end
									end),
								}),
								inner_pane
							)
						else
							local _, first_pane = inner_window:mux_window():spawn_tab({ cwd = id })
							create_grid(first_pane)
						end
					end),
				}),
				pane
			)
		end),
	},
	{ key = "n", mods = "LEADER", action = act.ActivateTabRelative(1) },
	{ key = "p", mods = "LEADER", action = act.ActivateTabRelative(-1) },
	{ key = "w", mods = "LEADER", action = act.ShowTabNavigator },
	-- Workspace: switch/create with manual naming
	{
		key = "s",
		mods = "LEADER",
		action = wezterm.action_callback(function(window, pane)
			local workspaces = mux.get_workspace_names()
			local current = mux.get_active_workspace()
			local choices = {}
			for _, name in ipairs(workspaces) do
				local label = name == current and "* " .. name .. " (current)" or "  " .. name
				table.insert(choices, { id = name, label = label })
			end
			table.insert(choices, { id = "__new__", label = "+ Create new workspace" })
			window:perform_action(
				act.InputSelector({
					title = "Switch Workspace",
					choices = choices,
					fuzzy = true,
					action = wezterm.action_callback(function(inner_window, inner_pane, id)
						if not id then
							return
						end
						if id == "__new__" then
							inner_window:perform_action(
								act.PromptInputLine({
									description = "New workspace name:",
									action = wezterm.action_callback(function(w, p, line)
										if line and line ~= "" then
											w:perform_action(act.SwitchToWorkspace({ name = line }), p)
										end
									end),
								}),
								inner_pane
							)
						else
							inner_window:perform_action(act.SwitchToWorkspace({ name = id }), inner_pane)
						end
					end),
				}),
				pane
			)
		end),
	},
	-- Workspace: rename
	{
		key = "$",
		mods = "LEADER|SHIFT",
		action = act.PromptInputLine({
			description = "Rename workspace:",
			action = wezterm.action_callback(function(_, pane, line)
				if line then
					mux.rename_workspace(mux.get_active_workspace(), line)
				end
			end),
		}),
	},
	-- Copy mode
	{ key = "[", mods = "LEADER", action = act.ActivateCopyMode },
}

-- Auto-equalize panes on window resize (e.g. display move)
wezterm.on("window-resized", function(window)
	equalize_panes(window)
end)

-- Startup (single pane — use LEADER+a / LEADER+" / LEADER+% to add panes as needed)
wezterm.on("gui-startup", function(cmd)
	mux.spawn_window(cmd or {})
end)

return config
