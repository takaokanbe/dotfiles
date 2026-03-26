local wezterm = require("wezterm")
local config = wezterm.config_builder()

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
config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = false
config.show_new_tab_button_in_tab_bar = false
config.colors = {
	split = "#585b70",
	tab_bar = {
		background = "#1e1e2e",
	},
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
config.keys = {
	-- Pane navigation
	{ key = "h", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Left") },
	{ key = "j", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Down") },
	{ key = "k", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Up") },
	{ key = "l", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Right") },
	-- Pane split
	{ key = '"', mods = "LEADER|SHIFT", action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }) },
	{ key = "%", mods = "LEADER|SHIFT", action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
	-- Pane close
	{ key = "x", mods = "LEADER", action = wezterm.action.CloseCurrentPane({ confirm = true }) },
	-- Tab
	{ key = "c", mods = "LEADER", action = wezterm.action.SpawnTab("CurrentPaneDomain") },
	{ key = "n", mods = "LEADER", action = wezterm.action.ActivateTabRelative(1) },
	{ key = "p", mods = "LEADER", action = wezterm.action.ActivateTabRelative(-1) },
	{ key = "w", mods = "LEADER", action = wezterm.action.ShowTabNavigator },
	-- Workspace
	{
		key = "s",
		mods = "LEADER",
		action = wezterm.action_callback(function(window, pane)
			local workspaces = wezterm.mux.get_workspace_names()
			local current = wezterm.mux.get_active_workspace()
			local choices = {}
			for _, name in ipairs(workspaces) do
				local label = name == current and "* " .. name .. " (current)" or "  " .. name
				table.insert(choices, { id = name, label = label })
			end
			table.insert(choices, { id = "__new__", label = "+ Create new workspace" })
			window:perform_action(
				wezterm.action.InputSelector({
					title = "Switch Workspace",
					choices = choices,
					fuzzy = true,
					action = wezterm.action_callback(function(inner_window, inner_pane, id, label)
						if not id then
							return
						end
						if id == "__new__" then
							inner_window:perform_action(
								wezterm.action.PromptInputLine({
									description = "New workspace name:",
									action = wezterm.action_callback(function(w, p, line)
										if line then
											w:perform_action(wezterm.action.SwitchToWorkspace({ name = line }), p)
										end
									end),
								}),
								inner_pane
							)
						else
							inner_window:perform_action(wezterm.action.SwitchToWorkspace({ name = id }), inner_pane)
						end
					end),
				}),
				pane
			)
		end),
	},
	{
		key = "$",
		mods = "LEADER|SHIFT",
		action = wezterm.action.PromptInputLine({
			description = "Rename workspace:",
			action = wezterm.action_callback(function(window, pane, line)
				if line then
					wezterm.mux.rename_workspace(wezterm.mux.get_active_workspace(), line)
				end
			end),
		}),
	},
	-- Copy mode
	{ key = "[", mods = "LEADER", action = wezterm.action.ActivateCopyMode },
}

-- Startup
wezterm.on("gui-startup", function(cmd)
	local tab, pane, window = wezterm.mux.spawn_window(cmd or {})
	pane:split({ direction = "Right" })
end)

return config
