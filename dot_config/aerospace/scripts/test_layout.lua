-- Run with: lua dot_config/aerospace/scripts/test_layout.lua [scripts-directory]
local directory = arg[1] or assert(arg[0]:match('^(.*)/'))
local layout = dofile(directory .. '/layout.lua')

local function test(name, body)
  body()
  print('PASS: ' .. name)
end

local function leaves(node, result)
  result = result or {}
  if type(node) == 'string' then result[#result + 1] = node
  else for _, child in ipairs(node.children) do leaves(child, result) end end
  return result
end

local function locate(node, id)
  for index, child in ipairs(node.children) do
    if child == id then return node, index end
    if type(child) == 'table' then
      local parent, position = locate(child, id)
      if parent then return parent, position end
    end
  end
end

-- Small independent tree interpreter: no AeroSpace, shell, or GUI calls.
-- Boundary extraction follows AeroSpace's MoveCommand.swift at
-- d56e1637c3a1ed660d0cadd7534e94fb3218d1c3 (createImplicitContainerAndMoveWindow).
local function apply(root, commands)
  for _, command in ipairs(commands) do
    local id = command:match('%-%-window%-id (%d+)')
    if command:match('^flatten%-workspace%-tree ') then
      root.children = leaves(root)
    elseif command:find('--root ', 1, true) then
      root.layout = assert(command:match('%-%-root ([%w_]+)'))
    elseif command:match('^move ') then
      local parent, index = locate(root, id)
      assert(parent, 'Moving a window outside the tree')
      local direction = assert(command:match('^move (%w+)'))
      local offset = direction == 'left' and -1 or 1
      local sibling = parent.layout:match('^h_') and parent.children[index + offset]
      if sibling then
        if type(sibling) == 'string' then
          parent.children[index], parent.children[index + offset] = sibling, id
        else
          table.remove(parent.children, index)
          sibling.children[#sibling.children + 1] = id
        end
      elseif command:find('--boundaries-action create-implicit-container', 1, true) then
        assert(parent == root and direction == 'left')
        table.remove(parent.children, index)
        root = {layout = 'h_tiles', children = {id, parent}}
      else
        assert(command:find('--boundaries-action stop', 1, true), 'Unexpected boundary behavior')
      end
    elseif command:match('^join%-with left ') then
      local parent, index = locate(root, id)
      assert(parent and index > 1)
      local sibling = table.remove(parent.children, index - 1)
      parent.children[index - 1] = {layout = 'v_tiles', children = {sibling, id}}
    elseif command:match('^layout %-%-window%-id ') then
      local style = assert(command:match(' ([%w_]+)$'))
      if style ~= 'tiling' then
        local parent = assert(locate(root, id))
        parent.layout = style
      end
    else
      assert(command:match('^fullscreen off ') or command:match('^balance%-sizes '), command)
    end
  end
  return root
end

local function assert_shape(root, ids, primary)
  assert(root.layout == 'h_tiles' and root.children[1] == primary, 'Primary must be left')
  assert(#root.children == math.min(#ids, 2), 'Expected one primary and at most one secondary column')
  if #ids > 2 then
    assert(root.children[2].layout == 'v_accordion', 'Secondary column must be a vertical accordion')
  end
  local actual, expected = leaves(root), {table.unpack(ids)}
  table.sort(actual)
  table.sort(expected)
  assert(table.concat(actual, ',') == table.concat(expected, ','), 'Lost or duplicated windows')
end

test('empty workspaces issue no commands', function()
  assert(#layout.plan({}, nil, '1') == 0)
end)

test('one and two windows keep the primary left', function()
  for _, ids in ipairs({{'11'}, {'11', '22'}}) do
    local primary = ids[#ids]
    local root = {layout = 'v_tiles', children = {table.unpack(ids)}}
    assert_shape(apply(root, layout.plan(ids, primary, '1')), ids, primary)
  end
end)

test('the planner rejects a primary outside the workspace', function()
  assert(not pcall(layout.plan, {'11', '22'}, '99', '1'))
end)

test('all four-window permutations and primary choices produce the intended columns', function()
  local ids = {'11', '22', '33', '44'}
  local function permute(order, remaining)
    if #remaining == 0 then
      for _, primary in ipairs(ids) do
        local root = {layout = 'h_tiles', children = {
          order[1], {layout = 'v_tiles', children = {order[2], order[3]}}, order[4],
        }}
        assert_shape(apply(root, layout.plan(ids, primary, '1')), ids, primary)
      end
      return
    end
    for index, id in ipairs(remaining) do
      local rest = {table.unpack(remaining)}
      table.remove(rest, index)
      order[#order + 1] = id
      permute(order, rest)
      table.remove(order)
    end
  end
  permute({}, ids)
end)

test('the secondary column retains its existing tree order', function()
  local ids = {'11', '22', '33', '44'}
  local root = {layout = 'h_tiles', children = {'44', '11', '33', '22'}}
  local result = apply(root, layout.plan(ids, '33', '1'))
  assert(table.concat(leaves(result.children[2]), ',') == '44,11,22')
end)

test('manual layouts include floating and tiled windows but not unsupported states', function()
  for _, style in ipairs({'floating', 'h_tiles', 'v_tiles', 'h_accordion', 'v_accordion'}) do
    assert(layout.includes(style), style)
  end
  assert(not layout.includes('unsupported'))
end)

test('a ten-window layout needs fewer than thirty commands', function()
  local ids = {}
  for i = 1, 10 do ids[i] = tostring(i) end
  local commands = layout.plan(ids, '5', '1')
  assert(#commands < 30, 'Expected fewer than 30 commands, got ' .. #commands)
end)
