require "test/unit"
require "./request_lexer"

class RequestLexerTest < Test::Unit::TestCase
  def test_lexer_run
    no_uuid = <<~DATA.chomp
      [02:35:39.175]  [1m[36mLifecycleEmail::ApplicationSegment Load (0.6ms)[0m  [1m[34mSELECT  "lifecycle_email_segments".* FROM "lifecycle_email_segments" WHERE "lifecycle_email_segments"."type" IN ('LifecycleEmail::ApplicationSegment') AND "lifecycle_email_segments"."segment_key" = $1 ORDER BY "lifecycle_email_segments"."id" ASC LIMIT $2[0m  [["segment_key", "marketing_workspace"], ["LIMIT", 1]]
    DATA

    all_things = <<~DATA.chomp
      [02:35:46.764] [request_uuid:931ef140-88b0]   [1m[36mFeatureFlag Load (0.3ms)[0m  [1m[34mSELECT  "feature_flags".* FROM "feature_flags" WHERE "feature_flags"."name" = $1 LIMIT $2[0m  [["name", "Workspace templates"], ["LIMIT", 1]]
    DATA

    parser = RequestLexer.new(all_things)
    tokens = parser.tokens

    assert_equal tokens.length, 11

    assert_equal RequestLexer.new(no_uuid).tokens.length, 10
  end
end

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
