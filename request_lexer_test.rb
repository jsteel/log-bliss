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
    data = [[[:content, "123456789"]]]
    tree = RequestTree.new(data, 5)

    assert_equal tree.lines, [[[:content, "12345", 5, 0]], [[:content, "6789", 4, 0]]]

    tree.new_width(4)
    assert_equal tree.lines, [[[:content, "1234", 4, 0]], [[:content, "5", 1, 0], [:content, "678", 3, 0]], [[:content, "9", 1, 0]]]

    tree.new_width(6)
    assert_equal tree.lines, [[[:content, "1234", 4, 0], [:content, "5", 1, 0], [:content, "6", 1, 0]], [[:content, "78", 2, 0], [:content, "9", 1, 0]]]

    data = [[[:content, "123456789"]], [[:content, "abcd"], [:content, "efg"]]]
    tree = RequestTree.new(data, 8)
    assert_equal tree.lines, [[[:content, "12345678", 8, 0]], [[:content, "9", 1, 0]], [[:content, "abcd", 4, 1], [:content, "efg", 3, 1]]]

    tokens = RequestLexer.new('[02:35:40.369] [request_uuid:0] Creating scope :open1. Overwriting existing method AhaGlobal::AdminOpportunity.open. lsj lsjdfk slkskjfsdfslfsdk slsdksdks aaa bbb ccc ddd eee fff ggg hhh iii jjj kkk').tokens
    pp RequestTree.new([tokens], 167).lines
  end
end
