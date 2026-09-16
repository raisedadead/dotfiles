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
          output = fixture.rows or '11|h_tiles\n22|floating\n33|v_accordion'
        else
          error('Unexpected read: ' .. command)
        end
        return {read = function() return output end, close = function() return true end}
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

local function plan_of(state)
  assert(#state.actions == 1, 'The whole plan must travel as one eval')
  local argv = words(state.actions[1])
  assert(argv[1] == 'eval', state.actions[1])
  return argv[2]
end

test('the plan travels as one eval and balances last', function()
  local ok, failure, state = run({}, {focus_after_lock = '33|2'})
  assert(ok, failure)
  assert(state.locks == 1)
  local plan = plan_of(state)
  assert(plan:match("balance%-sizes %-%-workspace '1'$"), plan)
  assert(plan:find('layout --window-id 22 tiling', 1, true), 'Floating primary was excluded')
  assert(plan:find('move left --window-id 22', 1, true), 'Focused window was not made primary')
  assert(not plan:find('999', 1, true), 'Stale callback window was used')
end)

test('the secondary column is tiled rather than stacked', function()
  local ok, failure, state = run({})
  assert(ok, failure)
  assert(plan_of(state):find('--root v_tiles', 1, true))
end)

test('a primary closed while waiting for the lock falls back to a present window', function()
  local ok, failure, state = run({}, {rows = '11|h_tiles\n33|h_tiles'})
  assert(ok, failure)
  assert(plan_of(state):find('move left --window-id 11', 1, true))
end)

test('an empty workspace does not issue window commands', function()
  local ok, failure, state = run({}, {focus = '', rows = ''})
  assert(ok, failure)
  assert(state.locks == 1 and #state.actions == 0)
end)

test('a failed lock prevents window commands', function()
  local ok, failure, state = run({}, {lock_fails = true})
  assert(not ok and tostring(failure):find('Command failed:', 1, true))
  assert(#state.actions == 0)
end)

test('a failed eval surfaces as a command failure', function()
  local ok, failure, state = run({}, {fail_action = 'eval '})
  assert(not ok and tostring(failure):find('Command failed:', 1, true))
  assert(state.actions[#state.actions]:match('^eval '))
end)

test('an explicit workspace survives the lock handoff', function()
  local ok, failure, state = run({'2'}, {focus = '22|2'})
  assert(ok, failure)
  assert(plan_of(state):match("balance%-sizes %-%-workspace '2'$"))
end)

test('a workspace name with whitespace survives the lock handoff', function()
  local ok, failure, state = run({'work space'}, {focus = '22|work space'})
  assert(ok, failure)
  assert(state.locks == 1)
  assert(plan_of(state):match("balance%-sizes %-%-workspace 'work space'$"))
end)

test('a workspace name with an apostrophe is rejected, not mangled', function()
  local ok, failure = run({"work's space"}, {focus = "22|work's space"})
  assert(not ok and tostring(failure):find('cannot quote an apostrophe', 1, true), failure)
end)
