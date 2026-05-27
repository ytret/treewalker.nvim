local anchor = require "treewalker.anchor"
local markdown_anchor = require "treewalker.markdown.anchor"
local nodes = require "treewalker.nodes"
local operations = require "treewalker.operations"
local confinement = require "treewalker.confinement"
local util = require "treewalker.util"

local M = {}

---@param current TreewalkerAnchor | MarkdownAnchor
---@param direction "find_up" | "find_down" | "find_in" | "find_out"
---@return TreewalkerAnchor | MarkdownAnchor | nil
local function find_target(current, direction)
  if util.is_markdown_file() then
    return markdown_anchor[direction](current)
  end

  return anchor[direction](current)
end

---@param target TreewalkerAnchor | { node: TSNode, row: integer }
local function jump_to(target)
  operations.jump(target.node, target.row)
end

---@param current TreewalkerAnchor | MarkdownAnchor
---@param target TreewalkerAnchor | MarkdownAnchor
---@return boolean
local function is_neighbor(current, target)
  return math.abs(current.row - target.row) == 1
end

local function should_add_jumplist(command)
  local opts = require('treewalker').opts
  local jumplist = opts.jumplist

  if jumplist == false then return false end

  -- Only 'move_out' (left) jumps get jumplist in 'left' mode
  if jumplist == 'left' then
    return command == 'move_out'
  end

  return true
end

local function add_jumplist_for_move(command)
  if should_add_jumplist(command) then
    vim.cmd("normal! m'")
  end
end

---@return TreewalkerAnchor | MarkdownAnchor
local function current_anchor()
  if util.is_markdown_file() then
    local current = markdown_anchor.current(vim.fn.line('.'))
    assert(current, "Treewalker: Markdown heading not found under cursor")
    return current
  end

  return anchor.current()
end

---@return nil
function M.move_out()
  -- Add to jumplist at original cursor position before normalizing
  add_jumplist_for_move('move_out')

  local current = current_anchor()
  local target = find_target(current, "find_out")
  if not target then
    operations.jump(current.node, current.row)
    return
  end

  jump_to(target)
  add_jumplist_for_move('move_out') -- for easy Ctrl-o/Ctrl-i navigation
end

---@return nil
function M.move_in()
  local current = current_anchor()
  local target = find_target(current, "find_in")
  if not target then return end

  add_jumplist_for_move('move_in')
  jump_to(target)
  add_jumplist_for_move('move_in')
end

---@return nil
function M.move_up()
  local current = current_anchor()
  local target = find_target(current, "find_up")
  if not target then return end

  if confinement.should_confine(current, target) then
    return
  end

  if not is_neighbor(current, target) then
    add_jumplist_for_move('move_up')
  end

  jump_to(target)
end

---@return nil
function M.move_down()
  local current = current_anchor()
  local target = find_target(current, "find_down")
  if not target then return end

  if confinement.should_confine(current, target) then
    return
  end

  local neighbor = is_neighbor(current, target)

  if not neighbor then
    add_jumplist_for_move('move_down')
  end

  jump_to(target)

  if not neighbor then
    add_jumplist_for_move('move_down')
  end
end

-- Node types that act as list containers. When walking up to find a sibling,
-- we stop at these boundaries to avoid escaping the current list.
local LIST_CONTAINER_TYPES = {
  argument_list = true,
  parameter_list = true,
  template_argument_list = true,
  template_parameter_list = true,
  parameters = true,
}

--- Walk down into a node's subtree to find a list container and return
--- its first named child. This handles the case where cursor is on a
--- function name (e.g. "printf") and we want to jump to the first argument.
---@param node TSNode
---@return TSNode | nil
local function find_first_list_item(node)
  local function dfs(n)
    if not n then return nil end
    if LIST_CONTAINER_TYPES[n:type()] then
      return n:named_child(0)
    end
    for i = 0, n:named_child_count() - 1, 1 do
      local result = dfs(n:named_child(i))
      if result then return result end
    end
  end
  return dfs(node)
end

--- Walk down into a node's subtree to find a list container and return
--- its last named child. Handles move_left_sibling from a function name.
---@param node TSNode
---@return TSNode | nil
local function find_last_list_item(node)
  local function dfs(n)
    if not n then return nil end
    if LIST_CONTAINER_TYPES[n:type()] then
      local count = n:named_child_count()
      if count == 0 then return nil end
      return n:named_child(count - 1)
    end
    for i = n:named_child_count() - 1, 0, -1 do
      local result = dfs(n:named_child(i))
      if result then return result end
    end
  end
  return dfs(node)
end

--- Walk up the parent chain (bounded to the same row) to find a node
--- that has a named sibling. This handles nested structures like C
--- parameter_declarations where the cursor lands on an identifier nested
--- several levels deep without crossing list boundaries.
---@param node TSNode
---@param direction "next" | "prev"
---@return TSNode | nil
local function find_sibling_upwards(node, direction)
  local iter = node:parent()
  while iter and nodes.have_same_srow(node, iter) do
    if LIST_CONTAINER_TYPES[iter:type()] then
      break
    end
    local sibling = direction == "next"
      and anchor.next_sibling(iter)
      or anchor.prev_sibling(iter)
    if sibling then
      return sibling
    end
    iter = iter:parent()
  end
end

--- Jump to a node at its start column (for same-line sibling navigation)
--- rather than the first non-whitespace of the row.
---@param node TSNode
local function jump_to_node(node)
  local row = nodes.get_srow(node)
  local col = nodes.get_scol(node)
  vim.fn.cursor(row, col)

  local opts = require("treewalker").opts
  local range = nodes.range(node)

  if opts.select then
    operations.select(range)
  elseif opts.highlight then
    operations.highlight(range, opts.highlight_duration, opts.highlight_group)
  end
end

-- Node types where lateral navigation should descend into their
-- argument/parameter list rather than looking for siblings.
local CALL_EXPR_TYPES = {
  call_expression = true,
  function_declarator = true,
}

---@return nil
function M.move_right_sibling()
  local current_node = anchor.current_lateral_node()
  if not current_node then return end

  local target_node
  if CALL_EXPR_TYPES[current_node:type()] then
    target_node = find_first_list_item(current_node)
  end
  target_node = target_node
    or anchor.next_sibling(current_node)
    or find_sibling_upwards(current_node, "next")
  if not target_node then return end

  if confinement.should_confine(current_node, target_node) then
    return
  end

  add_jumplist_for_move('move_right_sibling')
  jump_to_node(target_node)
  add_jumplist_for_move('move_right_sibling')
end

---@return nil
function M.move_left_sibling()
  local current_node = anchor.current_lateral_node()
  if not current_node then return end

  local target_node
  if CALL_EXPR_TYPES[current_node:type()] then
    target_node = find_last_list_item(current_node)
  end
  target_node = target_node
    or anchor.prev_sibling(current_node)
    or find_sibling_upwards(current_node, "prev")
  if not target_node then return end

  if confinement.should_confine(current_node, target_node) then
    return
  end

  add_jumplist_for_move('move_left_sibling')
  jump_to_node(target_node)
  add_jumplist_for_move('move_left_sibling')
end

return M
