require "test/unit"
require "./request_lexer"

class RequestLexerTest < Test::Unit::TestCase
  def test_lexer_run
    all_things = <<~DATA.chomp
      [02:35:46.764] [request_uuid:931ef140-88b0]   [1m[36mFeatureFlag Load (0.3ms)[0m  [1m[34mSELECT  "feature_flags".* FROM "feature_flags" WHERE "feature_flags"."name" = $1 LIMIT $2[0m  [["name", "Workspace templates"], ["LIMIT", 1]]
    DATA

    assert_equal RequestLexer.new(all_things).tokens.length, 12

    no_uuid = <<~DATA.chomp
      [02:35:39.175]  [1m[36mLifecycleEmail::ApplicationSegment Load (0.6ms)[0m  [1m[34mSELECT  "lifecycle_email_segments".* FROM "lifecycle_email_segments" WHERE "lifecycle_email_segments"."type" IN ('LifecycleEmail::ApplicationSegment') AND "lifecycle_email_segments"."segment_key" = $1 ORDER BY "lifecycle_email_segments"."id" ASC LIMIT $2[0m  [["segment_key", "marketing_workspace"], ["LIMIT", 1]]
    DATA

    assert_equal RequestLexer.new(no_uuid).tokens.length, 10
  end
end
