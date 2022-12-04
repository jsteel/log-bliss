require "test/unit"
require "./request_tree"

class RequestTreeTest < Test::Unit::TestCase
  def test_run
    data = ["123456789"]
    tree = RequestTree.new(data, 5)

    assert_equal tree.lines, [[[:cursor, nil, 0, 0], [:content, "12345", 5, 0]], [[:content, "6789", 4, 0]]]

    tree.new_width(4)
    assert_equal tree.lines, [[[:cursor, nil, 0, 0], [:content, "1234", 4, 0]], [[:content, "5", 1, 0], [:content, "678", 3, 0]], [[:content, "9", 1, 0]]]

    tree.new_width(6)
    assert_equal tree.lines, [[[:cursor, nil, 0, 0], [:content, "1234", 4, 0], [:content, "5", 1, 0], [:content, "6", 1, 0]], [[:content, "78", 2, 0], [:content, "9", 1, 0]]]

    data = ["123456789", "abcdefg"]
    tree = RequestTree.new(data, 8)
    assert_equal tree.lines, [[[:cursor, nil, 0, 0], [:content, "12345678", 8, 0]], [[:content, "9", 1, 0]], [[:content, "abcdefg", 7, 1]]]

    # Exact width of the line
    tree = RequestTree.new(["12345678"], 8)
    assert_equal tree.lines, [[[:cursor, nil, 0, 0], [:content, "12345678", 8, 0]]]
  end

  def test_empty_tree
    tree = RequestTree.new([])
    tree.add_line("12345678")
    assert_equal tree.lines, [[[:cursor, nil, 0, 0], [:content, "12345678", 8, 0]]]
  end

  def test_add_line
    data = ["123456789"]
    tree = RequestTree.new(data, 5)
    tree.add_line("abcdefg")
    assert_equal tree.lines, [[[:cursor, nil, 0, 0], [:content, "12345", 5, 0]], [[:content, "6789", 4, 0]], [[:content, "abcde", 5, 1]], [[:content, "fg", 2, 1]]]
  end
end
