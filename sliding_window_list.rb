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
  attr_writer :max_size
  attr_writer :height

  def initialize(height: 0, first: 0, last: 0, current: 0)
    @requests_first = first
    @requests_current = current
    @requests_last = last

    @requests_scrolling = true

    @max_size = @requests_last
    @height = height
  end

  def height=(new_height)
    if new_height > @height
      grow_amount = new_height - @height
      room_to_grow = @max_size - @requests_last
      grow_at_end = [grow_amount, room_to_grow].min
      grow_amount -= grow_at_end
      @requests_last += grow_at_end
      @requests_first = [@requests_first - grow_amount, 0].max
    else
      shrink_amount = @height - new_height
      # Use the free space at the end first
      shrink_amount -= (@height - (@requests_last - @requests_first)).clamp(0, shrink_amount)
      # Then shrink past entries at the end
      room_to_shrink_after = @requests_last - @requests_current - 1
      shrink_after = [shrink_amount, room_to_shrink_after].min
      shrink_amount -= shrink_after
      @requests_last -= shrink_after
      # Finally shrink in front the rest of the way
      @requests_first = @requests_first + shrink_amount
    end

    @height = new_height
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
    @requests_current = [@requests_current + 1, @max_size - 1].min
    if @requests_current >= @requests_last
      @requests_last += 1
      @requests_first += 1
    end
  end

  def move_cursor_up
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

  def reset_scroll_position(window_height, max_height, scroll_to_start = false)
    if scroll_to_start
      @requests_current = 0
    else
      @requests_current = [@requests_current, max_height].min
    end
    @max_size = max_height
    @requests_last = [@requests_current + window_height - 1, @max_size].min
    @requests_first = [@requests_last - window_height, 0].max
  end
end
