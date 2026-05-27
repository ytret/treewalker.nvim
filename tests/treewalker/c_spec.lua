local load_fixture = require "tests.load_fixture"
local assert = require "luassert"
local tw = require 'treewalker'
local h = require 'tests.treewalker.helpers'
local lines = require 'treewalker.lines'

describe("In a c file:", function()
  before_each(function()
    load_fixture("/c.c")
  end)

  h.ensure_has_parser("c")

  it("Moves around", function()
    vim.fn.cursor(46, 1)
    tw.move_down()
    h.assert_cursor_at(50, 1, "int main")
    tw.move_down()
    h.assert_cursor_at(64, 1)
    tw.move_down()
    h.assert_cursor_at(69, 1)
  end)

  it("swaps right, when cursor is inside a string, the whole string", function()
    vim.fn.cursor(14, 17) -- the o in one
    assert.same('        printf("one\\n", "two\\n");', lines.get_line(14))
    tw.swap_right()
    assert.same('        printf("two\\n", "one\\n");', lines.get_line(14))
  end)

  it("swaps left, when cursor is inside a string, the whole string", function()
    vim.fn.cursor(17, 28) -- the t in two
    assert.same('        printf("one\\n", "\\ntwo\\n");', lines.get_line(17))
    tw.swap_left()
    assert.same('        printf("\\ntwo\\n", "one\\n");', lines.get_line(17))
  end)

  it("swaps down on next line bracket structured functions", function()
    local first_block = lines.get_lines(63, 67)
    local second_block = lines.get_lines(69, 72)
    vim.fn.cursor(64, 1)
    tw.swap_down()
    assert.same(first_block, lines.get_lines(68, 72))
    assert.same(second_block, lines.get_lines(63, 66))
  end)

  it("swaps up on next line bracket structured functions", function()
    local first_block = lines.get_lines(63, 67)
    local second_block = lines.get_lines(69, 72)
    vim.fn.cursor(69, 1)
    tw.swap_up()
    assert.same(first_block, lines.get_lines(68, 72))
    assert.same(second_block, lines.get_lines(63, 66))
  end)

  it("highlights the whole node on move_out", function()
    vim.fn.cursor(26, 1)
    tw.move_out()
    h.assert_highlighted(26, 1, 33, 1)
  end)

  it("highlights the whole node on move_down", function()
    vim.fn.cursor(11, 1)
    tw.move_down()
    h.assert_highlighted(26, 1, 33, 1)
  end)

  it("highlights the whole node on move_up", function()
    vim.fn.cursor(36, 1)
    tw.move_up()
    h.assert_highlighted(26, 1, 33, 1)
  end)
  describe("scope_confined", function()
    before_each(function()
      tw.setup({ scope_confined = true })
    end)

    it("confines move_down", function()
      h.assert_confined_by_parent(23, 1, 'down')
    end)

    it("confines move_up", function()
      h.assert_confined_by_parent(10, 1, 'up')
    end)

    it("confines swap_down", function()
      h.assert_swap_confined_by_parent(23, 1, 'down')
    end)

    it("confines swap_up", function()
      h.assert_swap_confined_by_parent(10, 1, 'up')
    end)

    it("confines swap_right", function()
      h.assert_swap_confined_by_parent(23, 1, 'right')
    end)

    it("confines swap_left", function()
      h.assert_swap_confined_by_parent(10, 1, 'left')
    end)
  end)

  it("moves right between string arguments in a function call", function()
    vim.fn.cursor(14, 17) -- the 'o' in "one"
    tw.move_right_sibling()
    h.assert_cursor_at(14, 25) -- start of "two"
  end)

  it("moves left between string arguments in a function call", function()
    vim.fn.cursor(14, 26) -- the 't' in "two"
    tw.move_left_sibling()
    h.assert_cursor_at(14, 16) -- start of "one"
  end)

  it("moves right between numeric arguments in a function call", function()
    vim.fn.cursor(51, 40) -- the '3' in 12345
    tw.move_right_sibling()
    h.assert_cursor_at(51, 45) -- start of 1000.00f
  end)

  it("moves left between numeric arguments in a function call", function()
    vim.fn.cursor(51, 47) -- the '0' in 1000.00f
    tw.move_left_sibling()
    h.assert_cursor_at(51, 38) -- start of 12345
  end)

  it("does not move right from the last argument", function()
    vim.fn.cursor(14, 26) -- the 't' in "two"
    tw.move_right_sibling()
    h.assert_cursor_at(14, 26) -- stays at "two"
  end)

  it("does not move left from the first argument", function()
    vim.fn.cursor(14, 17) -- the 'o' in "one"
    tw.move_left_sibling()
    h.assert_cursor_at(14, 17) -- stays at "one"
  end)
end)
