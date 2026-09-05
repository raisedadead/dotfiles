-- Run with: lua dot_config/aerospace/scripts/test_layout_run.lua [scripts-directory]
local directory = arg[1] or assert(arg[0]:match('^(.*)/'))
local runner = directory .. '/layout-run.lua'

-- Parse only the shell quoting used by the runner's lockf invocation.
local function words(command)
  local result, word, quoted, escaped = {}, '', false, false
  for character in command:gmatch('.') do
    if escaped then
      word, escaped = word .. character, false
    elseif character == '\\' and not quoted then
      escaped = true
    elseif character == "'" then
      quoted = not quoted
    elseif character:match('%s') and not quoted then
      if word ~= '' then result[#result + 1], word = word, '' end
    else
      word = word .. character
    end
  end
  assert(not quoted and not escaped, 'Unclosed shell word')
  if word ~= '' then result[#result + 1] = word end
  return result
end

local function run(arguments, fixture)
  fixture = fixture or {}
  local state = {actions = {}, reads = {}, locks = 0}
  local function invoke(argv)
    local env = setmetatable({arg = argv}, {__index = _G})
    env.os = {
      getenv = function(key)
        return ({HOME = '/fixture/home', AEROSPACE_WINDOW_ID = '999', AEROSPACE_WORKSPACE = '9'})[key]
      end,
      execute = function(command)
        if command:match('^/bin/mkdir %-p ') then return true end
        if command:match('^/usr/bin/lockf ') then
          state.locks = state.locks + 1
          assert(state.locks == 1, 'Recursive lock acquisition')
          if fixture.lock_fails then return nil, 'exit', 1 end
          local tokens = words(command)
          local child = {}
          for i, token in ipairs(tokens) do
            if token == '/opt/homebrew/bin/lua' then
              for j = i + 1, #tokens do child[j - i - 1] = tokens[j] end
              break
            end
          end
          assert(child[0] == runner, 'Lock must invoke the real runner')
          invoke(child)
          return true
        end
        assert(command:find('/usr/bin/env -u AEROSPACE_WINDOW_ID -u AEROSPACE_WORKSPACE ', 1, true) == 1,
          'Window commands must ignore callback context')
        state.actions[#state.actions + 1] = assert(command:match('/opt/homebrew/bin/aerospace (.+)$'))
        if fixture.fail_action and state.actions[#state.actions]:find(fixture.fail_action, 1, true) == 1 then
          return nil, 'exit', 1
        end
        return true
      end,
    }
    env.io = {
      popen = function(command)
        state.reads[#state.reads + 1] = command
        local output
        if command:find('list-windows --focused', 1, true) then
          output = state.locks > 0 and fixture.focus_after_lock or fixture.focus
          output = output or '22|1'
        elseif command:find('list-workspaces --focused', 1, true) then
          output = fixture.workspace or '1'
        elseif command:find('list-windows --workspace', 1, true) then
          output = fixture.rows or '11|1|h_tiles\n22|1|floating\n33|1|v_accordion'
        elseif command:find('config --config-path', 1, true) then
          output = '/fixture/aerospace.toml'
        elseif command:match('^/usr/bin/osascript ') then
          output = '1000'
        else
          error('Unexpected read: ' .. command)
        end
        return {read = function() return output end, close = function() return true end}
      end,
      open = function(path)
        assert(path == '/fixture/aerospace.toml', 'Unexpected file read')
        return {
          read = function() return '[gaps]\nouter.left = 15\nouter.right = 15\ninner.horizontal = 10\n' end,
          close = function() end,
        }
      end,
    }
    env.dofile = function(path) return assert(loadfile(path, 't', env))() end
    assert(loadfile(runner, 't', env))()
  end
  arguments[0] = runner
  local ok, failure = pcall(invoke, arguments)
  return ok, failure, state
end

local function test(name, body)
  body()
  print('PASS: ' .. name)
end

test('default is rejected before querying or changing window state', function()
  local ok, failure, state = run({'default'})
  assert(not ok and tostring(failure):find('Usage:', 1, true), 'default must fail with usage')
  assert(#state.reads == 0 and #state.actions == 0 and state.locks == 0)
end)

test('50:50 includes floating windows and keeps the primary captured before locking', function()
  local ok, failure, state = run({'50'}, {focus_after_lock = '33|2'})
  assert(ok, failure)
  assert(state.locks == 1)
  assert(state.actions[#state.actions] == 'resize width 485 --window-id 22')
  local actions = table.concat(state.actions, '\n')
  assert(actions:find('layout --window-id 22 tiling', 1, true), 'Floating primary was excluded')
  assert(not actions:find('999', 1, true), 'Stale callback window was used')
end)

test('60:40 sizes the focused primary using the monitor and configured gaps', function()
  local ok, failure, state = run({'60'})
  assert(ok, failure)
  assert(state.actions[#state.actions] == 'resize width 581 --window-id 22')
end)

test('a primary closed while waiting for the lock falls back to a present window', function()
  local ok, failure, state = run({'50'}, {rows = '11|1|h_tiles\n33|1|h_tiles'})
  assert(ok, failure)
  assert(state.actions[#state.actions] == 'resize width 485 --window-id 11')
end)

test('an empty workspace does not issue window commands', function()
  local ok, failure, state = run({'50'}, {focus = '', rows = ''})
  assert(ok, failure)
  assert(state.locks == 1 and #state.actions == 0)
end)

test('a failed lock prevents window commands', function()
  local ok, failure, state = run({'50'}, {lock_fails = true})
  assert(not ok and tostring(failure):find('Command failed:', 1, true))
  assert(#state.actions == 0)
end)

test('a failed movement prevents subsequent balancing and resizing', function()
  local ok, failure, state = run({'50'}, {fail_action = 'move '})
  assert(not ok and tostring(failure):find('Command failed:', 1, true))
  assert(state.actions[#state.actions]:match('^move '))
end)

test('a quoted workspace name survives the lock handoff', function()
  local ok, failure, state = run({'50', "work's space"}, {focus = "22|work's space"})
  assert(ok, failure)
  assert(state.actions[#state.actions] == 'resize width 485 --window-id 22')
  assert(table.concat(state.actions, '\n'):find("--workspace 'work'\\''s space'", 1, true))
end)
