require "./unit_test"
require "./sliding_window_list"

class SlidingWindowListTest < Test::Unit::TestCase
  def test_add_one
    slider = SlidingWindowList.new(height: 3, first: 1, last: 3, current: 1)
    # slider.add_one
    # assert_equal slider.last, 4
    # assert_equal slider.first, 2
    # assert_equal slider.current, 2
  end

  def test_height
    slider = SlidingWindowList.new(height: 3, first: 1, last: 3, current: 1)
    slider.new_height(4)
    assert_equal slider.first, 0
    assert_equal slider.last, 3
    assert_equal slider.current, 1

    slider = SlidingWindowList.new(height: 3, first: 1, last: 4, current: 1)
    slider.new_height(2)
    assert_equal slider.first, 1
    assert_equal slider.last, 3
    assert_equal slider.current, 1

    slider = SlidingWindowList.new(height: 3, first: 2, last: 5, current: 3)
    slider.new_height(1)
    assert_equal slider.first, 3
    assert_equal slider.last, 4
    assert_equal slider.current, 3

    slider = SlidingWindowList.new(height: 10, first: 2, last: 5, current: 3)
    slider.new_height(9)
    assert_equal slider.first, 2
    assert_equal slider.last, 5
    assert_equal slider.current, 3
    slider.new_height(4)
    assert_equal slider.first, 2
    assert_equal slider.last, 5
    assert_equal slider.current, 3
    slider.new_height(3)
    assert_equal slider.first, 2
    assert_equal slider.last, 5
    assert_equal slider.current, 3
    slider.new_height(2)
    assert_equal slider.first, 2
    assert_equal slider.last, 4
    assert_equal slider.current, 3
  end

  def assert_slider(slider, first, current, last, max_size)
    assert_equal(slider.first, first)
    assert_equal(slider.current, current)
    assert_equal(slider.last, last)
    assert_equal(slider.max_size, max_size)
  end
end
