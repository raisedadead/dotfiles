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

local focused = read(aerospace .. "list-windows --focused --format '%{window-id}|%{workspace}'", true)
local focused_id, focused_workspace = focused:match('^(%d+)|(.+)$')
local workspace = arg[1] or focused_workspace or read(aerospace .. 'list-workspaces --focused')
local primary = focused_workspace == workspace and focused_id or nil

if arg[2] ~= 'locked' then
  local state = (os.getenv('XDG_STATE_HOME') or (assert(os.getenv('HOME')) .. '/.local/state')) .. '/aerospace'
  run('/bin/mkdir -p ' .. quote(state))
  run('/usr/bin/lockf -k -t 10 ' .. quote(state .. '/layout.lock') .. ' /opt/homebrew/bin/lua '
    .. quote(arg[0]) .. ' ' .. quote(workspace) .. ' locked ' .. quote(primary or ''))
  return
end
primary = arg[3] ~= '' and arg[3] or nil
local ids, present = {}, {}
local output = read(aerospace .. 'list-windows --workspace ' .. quote(workspace)
  .. " --format '%{window-id}|%{window-layout}'")
for id, window_layout in output:gmatch('(%d+)|([^\n]+)') do
  if layout.includes(window_layout) then
    ids[#ids + 1] = id
    present[id] = true
  end
end
if #ids == 0 then return end
primary = present[primary] and primary or ids[1]
run(aerospace .. 'eval ' .. quote(table.concat(layout.plan(ids, primary, workspace), ' && ')))
