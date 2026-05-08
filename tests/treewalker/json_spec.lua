local load_fixture = require "tests.load_fixture"
local assert = require "luassert"
local lines = require 'treewalker.lines'
local tw = require 'treewalker'
local h = require 'tests.treewalker.helpers'

describe("Movement in a JSON file:", function()
  before_each(function()
    load_fixture("/json.json")
  end)

  h.ensure_has_parser("json")

  it("moves in", function()
    vim.fn.cursor(1, 1)
    tw.move_in()
    h.assert_cursor_at(2, 3)
    tw.move_in()
    h.assert_cursor_at(3, 5)
  end)

  it("moves down on keys", function()
    vim.fn.cursor(3, 5) -- "name": "SampleApp"
    tw.move_down()
    h.assert_cursor_at(4, 5)
    tw.move_down()
    h.assert_cursor_at(5, 5)
    tw.move_down()
    h.assert_cursor_at(6, 5)
    tw.move_down()
    h.assert_cursor_at(7, 5)
    tw.move_down()
    h.assert_cursor_at(12, 5)
    tw.move_down()
    h.assert_cursor_at(22, 5)
    tw.move_down()
    h.assert_cursor_at(23, 5)
    tw.move_down()
    h.assert_cursor_at(24, 5)
  end)

  it("moves up on keys", function()
    vim.fn.cursor(24, 5) -- "colors": {
    tw.move_up()
    h.assert_cursor_at(23, 5)
    tw.move_up()
    h.assert_cursor_at(22, 5)
    tw.move_up()
    h.assert_cursor_at(12, 5)
    tw.move_up()
    h.assert_cursor_at(7, 5)
    tw.move_up()
    h.assert_cursor_at(6, 5)
    tw.move_up()
    h.assert_cursor_at(5, 5)
    tw.move_up()
    h.assert_cursor_at(4, 5)
    tw.move_up()
    h.assert_cursor_at(3, 5)
  end)

  it("moves out within nested objects", function()
    vim.fn.cursor(39, 11) -- "notifications": true
    tw.move_out()
    h.assert_cursor_at(37, 9)
    tw.move_out()
    h.assert_cursor_at(35, 7)
    tw.move_out()
    h.assert_cursor_at(31, 5)
    tw.move_out()
    h.assert_cursor_at(30, 3)
  end)

  it("moves down in array", function()
    vim.fn.cursor(8, 7) -- "authentication"
    tw.move_down()
    h.assert_cursor_at(9, 7)
    tw.move_down()
    h.assert_cursor_at(10, 7)
  end)

  it("moves up in array", function()
    vim.fn.cursor(10, 7) -- "notifications"
    tw.move_up()
    h.assert_cursor_at(9, 7)
    tw.move_up()
    h.assert_cursor_at(8, 7)
  end)

  it("navigates mixedList part", function()
    vim.fn.cursor(71, 3) -- "mixedList": [
    tw.move_in()
    h.assert_cursor_at(72, 5)
    tw.move_down()
    h.assert_cursor_at(73, 5)
    tw.move_down()
    h.assert_cursor_at(74, 5)
    tw.move_down()
    h.assert_cursor_at(75, 5)
    tw.move_down()
    h.assert_cursor_at(76, 5)
    tw.move_in()
    h.assert_cursor_at(77, 7)
    tw.move_out()
    h.assert_cursor_at(76, 5)
    tw.move_out()
    h.assert_cursor_at(71, 3)
  end)

  it("navigates complexKeys part", function()
    vim.fn.cursor(58, 3) -- "complexKeys": {
    tw.move_in()
    h.assert_cursor_at(59, 5)
    tw.move_down()
    h.assert_cursor_at(60, 5)
    tw.move_down()
    h.assert_cursor_at(61, 5)
    tw.move_out()
    h.assert_cursor_at(58, 3)
  end)

  it("moves down across top-level keys", function()
    vim.fn.cursor(2, 3) -- "appConfig": {
    tw.move_down()
    h.assert_cursor_at(30, 3)
    tw.move_down()
    h.assert_cursor_at(58, 3)
    tw.move_down()
    h.assert_cursor_at(63, 3)
    tw.move_down()
    h.assert_cursor_at(71, 3)
  end)

  it("moves up across top-level keys", function()
    vim.fn.cursor(71, 3) -- "mixedList": [
    tw.move_up()
    h.assert_cursor_at(63, 3)
    tw.move_up()
    h.assert_cursor_at(58, 3)
    tw.move_up()
    h.assert_cursor_at(30, 3)
    tw.move_up()
    h.assert_cursor_at(2, 3)
  end)

  it("swaps a top-level key up", function()
    vim.fn.cursor(30, 3) -- "users": [
    local app_config_before = lines.get_lines(2, 29)
    local users_before = lines.get_lines(30, 57)

    tw.swap_up()

    h.assert_cursor_at(2, 3)
    assert.same(users_before, lines.get_lines(2, 29))
    assert.same(app_config_before, lines.get_lines(30, 57))
  end)

  it("swaps a top-level key down", function()
    vim.fn.cursor(30, 3) -- "users": [
    local users_before = lines.get_lines(30, 57)
    local complex_keys_before = lines.get_lines(58, 62)

    tw.swap_down()

    h.assert_cursor_at(35, 3)
    assert.same(complex_keys_before, lines.get_lines(30, 34))
    assert.same(users_before, lines.get_lines(35, 62))
  end)

  it("swaps a json array item", function()
    vim.fn.cursor(8, 7) -- "authentication"
    local first_feature = lines.get_line(8)
    local second_feature = lines.get_line(9)

    tw.swap_down()

    h.assert_cursor_at(9, 7)
    assert.same(second_feature, lines.get_line(8))
    assert.same(first_feature, lines.get_line(9))
  end)

  it("swaps a key within a json object without moving the whole object", function()
    vim.fn.cursor(33, 7) -- "name": "Alice"
    local first_user_before = lines.get_lines(31, 42)

    tw.swap_down()

    h.assert_cursor_at(34, 7)
    assert.same({
      first_user_before[1],
      first_user_before[2],
      first_user_before[4],
      first_user_before[3],
      first_user_before[5],
      first_user_before[6],
      first_user_before[7],
      first_user_before[8],
      first_user_before[9],
      first_user_before[10],
      first_user_before[11],
      first_user_before[12],
    }, lines.get_lines(31, 42))
  end)

  it("swaps up nested json keys with their child block", function()
    vim.fn.cursor(66, 5) -- "nestedEmpty": {
    local empty_map_before = lines.get_lines(65, 65)
    local nested_empty_before = lines.get_lines(66, 69)

    tw.swap_up()

    h.assert_cursor_at(65, 5)
    assert.same(nested_empty_before, lines.get_lines(65, 68))
    assert.same(empty_map_before, lines.get_lines(69, 69))
  end)

  describe("scope_confined", function()
    before_each(function()
      tw.setup({ scope_confined = true })
    end)

    it("confines move_down", function()
      h.assert_confined_by_parent(45, 7, 'down')
    end)

    it("confines move_up", function()
      h.assert_confined_by_parent(46, 7, 'up')
    end)

    it("confines swap_down", function()
      h.assert_swap_confined_by_parent(45, 7, 'down')
    end)

    it("confines swap_up", function()
      h.assert_swap_confined_by_parent(46, 7, 'up')
    end)

    it("confines swap_right", function()
      h.assert_swap_confined_by_parent(45, 7, 'right')
    end)

    it("confines swap_left", function()
      h.assert_swap_confined_by_parent(46, 7, 'left')
    end)

    it("stays within the current json parent on move_down", function()
      vim.fn.cursor(39, 11) -- "notifications": true

      tw.move_down()

      h.assert_cursor_at(39, 11)
    end)

    it("stays within the current json parent on swap_down", function()
      vim.fn.cursor(39, 11) -- "notifications": true
      local before = lines.get_lines(35, 41)

      tw.swap_down()

      h.assert_cursor_at(39, 11)
      assert.same(before, lines.get_lines(35, 41))
    end)
  end)
end)
