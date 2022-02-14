require "test/unit"
require "./sliding_window_list"

class SlidingWindowListTest < Test::Unit::TestCase
  def test_add_one
    slider = SlidingWindowList.new(height: 3, first: 1, last: 3, current: 1)
    # slider.add_one
    # assert_equal slider.requests_last, 4
    # assert_equal slider.requests_first, 2
    # assert_equal slider.requests_current, 2
  end

  def test_height
    slider = SlidingWindowList.new(height: 3, first: 1, last: 3, current: 1)
    slider.height = 4
    assert_equal slider.requests_first, 0
    assert_equal slider.requests_last, 3
    assert_equal slider.requests_current, 1

    slider = SlidingWindowList.new(height: 3, first: 1, last: 4, current: 1)
    slider.height = 2
    assert_equal slider.requests_first, 1
    assert_equal slider.requests_last, 3
    assert_equal slider.requests_current, 1

    slider = SlidingWindowList.new(height: 3, first: 2, last: 5, current: 3)
    slider.height = 1
    assert_equal slider.requests_first, 3
    assert_equal slider.requests_last, 4
    assert_equal slider.requests_current, 3

    slider = SlidingWindowList.new(height: 10, first: 2, last: 5, current: 3)
    slider.height = 9
    assert_equal slider.requests_first, 2
    assert_equal slider.requests_last, 5
    assert_equal slider.requests_current, 3
    slider.height = 4
    assert_equal slider.requests_first, 2
    assert_equal slider.requests_last, 5
    assert_equal slider.requests_current, 3
    slider.height = 3
    assert_equal slider.requests_first, 2
    assert_equal slider.requests_last, 5
    assert_equal slider.requests_current, 3
    slider.height = 2
    assert_equal slider.requests_first, 2
    assert_equal slider.requests_last, 4
    assert_equal slider.requests_current, 3
  end
end
