local M = {}

M.mod = "SUPER"
M.hyper = "SUPER + CTRL + ALT + SHIFT"

function M.combo(prefix, key)
	if prefix == nil or prefix == "" then
		return key
	end

	return prefix .. " + " .. key
end

function M.bind(keys, action, opts)
	if opts then
		hl.bind(keys, action, opts)
	else
		hl.bind(keys, action)
	end
end

function M.bind_combo(prefix, key, action, opts)
	M.bind(M.combo(prefix, key), action, opts)
end

function M.combo_binds(prefix, bindings)
	for _, binding in ipairs(bindings) do
		M.bind_combo(prefix, binding[1], binding[2], binding[3])
	end
end

function M.binds(bindings)
	for _, binding in ipairs(bindings) do
		M.bind(binding[1], binding[2], binding[3])
	end
end

function M.exec_combo_binds(prefix, bindings)
	for _, binding in ipairs(bindings) do
		M.bind_combo(prefix, binding[1], hl.dsp.exec_cmd(binding[2]), binding[3])
	end
end

function M.exec_once(commands)
	for _, command in ipairs(commands) do
		hl.exec_cmd(command)
	end
end

function M.window_rules(rules)
	for _, rule in ipairs(rules) do
		hl.window_rule(rule)
	end
end

function M.layer_rules(rules)
	for _, rule in ipairs(rules) do
		hl.layer_rule(rule)
	end
end

function M.workspace_rules(rules)
	for _, rule in ipairs(rules) do
		hl.workspace_rule(rule)
	end
end

return M
