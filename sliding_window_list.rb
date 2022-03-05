class SlidingWindowList
  # Size 2 list
  #
  # first
  # |_|_|_|
  #  ^
  #
  # last is beyond the window
  # |_|_|_|
  #      ^
  # Actually rendered
  # |_|_|
  attr_reader :requests_current
  attr_reader :requests_first
  attr_reader :requests_last
  attr_accessor :height

  SCROLL_STRATEGY_DEFAULT = :default
  SCROLL_STRATEGY_SLIDE = :slide

  def initialize(height: 0, first: 0, last: nil, current: 0, max_size: nil, scroll_strategy: SCROLL_STRATEGY_DEFAULT)
    @scroll_strategy = scroll_strategy
    @requests_first = [first, 0].max
    @requests_current = current
    @requests_last = last || @requests_first + height

    @requests_scrolling = true

    @max_size = max_size || @requests_last
    @requests_last = [@requests_last, @max_size].min
    @height = height

    cur_height = @requests_last - @requests_first
    change_height(cur_height, @height)
  end

  def move_cursor(new_line_number)
    @requests_current = new_line_number

    if @requests_current < @requests_first
      diff = @requests_first - @requests_current
      @requests_first = @requests_current
      @requests_last -= diff
    elsif @requests_current >= @requests_last
      diff = @requests_current - @requests_last + 1
      @requests_last = @requests_current + 1
      @requests_first += diff
    end
  end

  def add_one
    @max_size += 1

    if @requests_scrolling
      @requests_last += 1
      if @requests_last - @requests_first > @height
        @requests_first += 1
        @requests_current = [@requests_current, @requests_first].max
      end
    elsif @requests_last < @height
      @requests_last += 1
    end
  end

  def move_cursor_down
    return slide_down if @scroll_strategy == SCROLL_STRATEGY_SLIDE

    @requests_current = [@requests_current + 1, @max_size - 1].min
    if @requests_current >= @requests_last
      @requests_last += 1
      @requests_first += 1
    end
  end

  def move_cursor_up
    return slide_up if @scroll_strategy == SCROLL_STRATEGY_SLIDE

    @requests_current = [@requests_current - 1, 0].max
    if @requests_current < @requests_first
      @requests_first -= 1
      @requests_last -= 1
    end
  end

  def slide_down
    return if @requests_last == @max_size

    @requests_current += 1
    @requests_last += 1
    @requests_first += 1
  end

  def slide_up
    return if @requests_first == 0

    @requests_current -= 1
    @requests_last -= 1
    @requests_first -= 1
  end

  def toggle_scrolling
    @requests_scrolling = !@requests_scrolling

    if @requests_scrolling
      @requests_last = @max_size - 1
      @requests_current = @requests_last
      @requests_first = [0, @requests_last - @height].max
    end
  end

  private

  def change_height(current_height, new_height)
    if new_height > current_height
      grow_amount = new_height - current_height
      room_to_grow = @max_size - @requests_last
      grow_at_end = [grow_amount, room_to_grow].min
      grow_amount -= grow_at_end
      @requests_last += grow_at_end
      @requests_first = [@requests_first - grow_amount, 0].max
    else
      shrink_amount = current_height - new_height
      # Use the free space at the end first
      shrink_amount -= (current_height - (@requests_last - @requests_first)).clamp(0, shrink_amount)
      # Then shrink past entries at the end
      room_to_shrink_after = @requests_last - @requests_current - 1
      shrink_after = [shrink_amount, room_to_shrink_after].min
      shrink_amount -= shrink_after
      @requests_last -= shrink_after
      # Finally shrink in front the rest of the way
      @requests_first = @requests_first + shrink_amount
    end
  end
end
