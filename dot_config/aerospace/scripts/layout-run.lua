local directory = assert(arg[0]:match('^(.*)/'))
local layout = dofile(directory .. '/layout.lua')
local quote = layout.quote
local aerospace = '/usr/bin/env -u AEROSPACE_WINDOW_ID -u AEROSPACE_WORKSPACE /opt/homebrew/bin/aerospace '

local function read(command, optional)
  local pipe = assert(io.popen(command .. (optional and ' 2>/dev/null' or ''), 'r'))
  local output = pipe:read('*a'):gsub('%s+$', '')
  local ok = pipe:close()
  if not ok and not optional then error('Command failed: ' .. command, 0) end
  return output
end

local function run(command)
  assert(os.execute(command), 'Command failed: ' .. command)
end

local ratio = tonumber(arg[1])
assert(ratio == 50 or ratio == 60, 'Usage: layout-run.lua <50|60> [workspace]')
local focused = read(aerospace .. "list-windows --focused --format '%{window-id}|%{workspace}'", true)
local focused_id, focused_workspace = focused:match('^(%d+)|(.+)$')
local workspace = arg[2] or focused_workspace or read(aerospace .. 'list-workspaces --focused')
local primary = focused_workspace == workspace and focused_id or nil

if arg[3] ~= 'locked' then
  local state = (os.getenv('XDG_STATE_HOME') or (assert(os.getenv('HOME')) .. '/.local/state')) .. '/aerospace'
  run('/bin/mkdir -p ' .. quote(state))
  run('/usr/bin/lockf -k -t 10 ' .. quote(state .. '/layout.lock') .. ' /opt/homebrew/bin/lua '
    .. quote(arg[0]) .. ' ' .. quote(arg[1]) .. ' ' .. quote(workspace) .. ' locked '
    .. quote(primary or ''))
  return
end
primary = arg[4] ~= '' and arg[4] or nil
local rows = {}
local output = read(aerospace .. 'list-windows --workspace ' .. quote(workspace)
  .. " --format '%{window-id}|%{monitor-appkit-nsscreen-screens-id}|%{window-layout}'")
for id, screen, window_layout in output:gmatch('(%d+)|(%d+)|([^\n]+)') do
  if layout.includes(window_layout) then
    rows[#rows + 1] = {id = id, screen = screen}
  end
end
if #rows == 0 then return end
local ids, present = {}, {}
for _, row in ipairs(rows) do
  ids[#ids + 1] = row.id
  present[row.id] = true
end
primary = present[primary] and primary or ids[1]
local weight
if #ids > 1 then
  local config_path = read(aerospace .. 'config --config-path')
  local file = assert(io.open(config_path))
  local config = file:read('*a')
  file:close()
  local gaps = {}
  local in_gaps = false
  for line in config:gmatch('[^\n]+') do
    local section = line:match('^%s*%[([^%]]+)%]')
    if section then in_gaps = section == 'gaps' end
    if in_gaps then
      local key, value = line:match('^%s*([%w_.]+)%s*=%s*(%d+)%s*$')
      if key then gaps[key] = tonumber(value) end
    end
  end
  local script = 'ObjC.import("AppKit"); const screens = $.NSScreen.screens; '
    .. 'const index = ' .. rows[1].screen .. ' - 1; '
    .. 'if (index < 0 || index >= screens.count) throw Error("Monitor disappeared"); '
    .. 'String(screens.objectAtIndex(index).visibleFrame.size.width);'
  local width = assert(tonumber(read('/usr/bin/osascript -l JavaScript -e ' .. quote(script))))
  weight = layout.weight(width, assert(gaps['outer.left']), assert(gaps['outer.right']),
    assert(gaps['inner.horizontal']), ratio)
end
for _, command in ipairs(layout.plan(ids, primary, workspace)) do run(aerospace .. command) end
if weight then run(aerospace .. 'resize width ' .. weight .. ' --window-id ' .. primary) end
