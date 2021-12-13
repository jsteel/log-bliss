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

  def initialize
    @requests_first = 0
    @requests_current = 0
    @requests_last = 0

    @requests_scrolling = true

    @max_size = 0
  end

  def add_one(maxy)
    @max_size += 1

    if @requests_scrolling
      @requests_last += 1
      if @requests_last - @requests_first > maxy
        @requests_first += 1
        @requests_current = [@requests_current, @requests_first].max
      end
    elsif @requests_last < maxy
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

  def prevent_scrolling(maxy)
    # Prevent scrolling on the top window
    @requests_scrolling = !@requests_scrolling

    if @requests_scrolling
      @requests_last = @max_size - 1
      @requests_current = @requests_last
      @requests_first = [0, @requests_last - maxy].max
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
