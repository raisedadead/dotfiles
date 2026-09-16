local M = {}

function M.quote(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function evalArg(value)
  value = tostring(value)
  assert(not value:find("'", 1, true), 'AeroSpace eval cannot quote an apostrophe: ' .. value)
  return "'" .. value .. "'"
end

function M.includes(window_layout)
  return window_layout == 'h_tiles' or window_layout == 'v_tiles'
    or window_layout == 'h_accordion' or window_layout == 'v_accordion'
    or window_layout == 'floating'
end

function M.plan(ids, primary, workspace)
  if #ids == 0 then return {} end
  local ordered = {assert(primary)}
  for _, id in ipairs(ids) do
    if id ~= primary then ordered[#ordered + 1] = id end
  end
  assert(#ordered == #ids, 'Primary is outside the workspace')
  local commands = {}
  local function add(command) commands[#commands + 1] = command end
  for _, id in ipairs(ordered) do
    add('fullscreen off --window-id ' .. id)
    add('layout --window-id ' .. id .. ' tiling')
  end
  add('flatten-workspace-tree --workspace ' .. evalArg(workspace))
  add('layout --workspace ' .. evalArg(workspace) .. ' --root '
    .. (#ordered > 1 and 'v_tiles' or 'h_tiles'))
  if #ordered > 1 then
    -- Extracting from the vertical root creates the horizontal split in one move.
    add('move left --window-id ' .. primary .. ' --boundaries workspace --boundaries-action create-implicit-container')
    add('balance-sizes --workspace ' .. evalArg(workspace))
  end
  return commands
end

return M
