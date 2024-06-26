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
  attr_reader :current
  attr_reader :first
  attr_reader :last
  attr_accessor :height

  SCROLL_STRATEGY_DEFAULT = :default
  SCROLL_STRATEGY_SLIDE = :slide

  def initialize(height: 0, first: 0, last: nil, current: 0, max_size: nil, scroll_strategy: SCROLL_STRATEGY_DEFAULT)
    @scroll_strategy = scroll_strategy
    @first = [first, 0].max
    @current = current
    @last = last || @first + height

    @scrolling = true

    @max_size = max_size || @last
    @last = [@last, @max_size].min
    @height = height

    cur_height = @last - @first
    $logger.info("call change_height #{@height} -- #{current}")
    change_height(cur_height, @height)
  end

  def move_cursor(new_line_number)
    @current = new_line_number

    if @current < @first
      diff = @first - @current
      @first = @current
      @last -= diff
    elsif @current >= @last
      diff = @current - @last + 1
      @last = @current + 1
      @first += diff
    end
  end

# ### # ## The problem is here. We are calling add_one on the first line
# which bumps up current and first. But really there is only one line
# so they should both still point at 0.
  def add_one
    @max_size += 1

    if @scrolling
      @last += 1
      if @last - @first > @height
        @first += 1
        @current = [@current, @first].max
      end
    elsif @last < @height
      @last += 1
    end
  end

  def move_cursor_down(num_lines = 1)
    num_lines.times do
      return slide_down if @scroll_strategy == SCROLL_STRATEGY_SLIDE

      @current = [@current + 1, @max_size - 1].min
      if @current >= @last
        @last += 1
        @first += 1
      end
    end
  end

  def move_cursor_up(num_lines = 1)
    num_lines.times do
      return slide_up if @scroll_strategy == SCROLL_STRATEGY_SLIDE

      @current = [@current - 1, 0].max
      if @current < @first
        @first -= 1
        @last -= 1
      end
    end
  end

  def slide_down
    return if @last == @max_size

    @current += 1
    @last += 1
    @first += 1
  end

  def slide_up
    return if @first == 0

    @current -= 1
    @last -= 1
    @first -= 1
  end

  def toggle_scrolling
    @scrolling = !@scrolling

    if @scrolling
      @last = @max_size - 1
      @current = @last
      @first = [0, @last - @height].max
      $logger.info("Set first1 #{@first}")
    end
  end

  private

  def change_height(current_height, new_height)
    $logger.info("change_height #{current_height} #{new_height}")
    if new_height > current_height
      grow_amount = new_height - current_height
      room_to_grow = @max_size - @last
      grow_at_end = [grow_amount, room_to_grow].min
      grow_amount -= grow_at_end
      @last += grow_at_end
      @first = [@first - grow_amount, 0].max
      $logger.info("Set first2 #{@first}")
    elsif new_height > current_height
      shrink_amount = current_height - new_height
      # Use the free space at the end first
      shrink_amount -= (current_height - (@last - @first)).clamp(0, shrink_amount)
      # Then shrink past entries at the end
      room_to_shrink_after = @last - @current - 1
      shrink_after = [shrink_amount, room_to_shrink_after].min
      shrink_amount -= shrink_after
      @last -= shrink_after
      # Finally shrink in front the rest of the way
      #### # ## # # ## #
      #
      #
      ##
      #
# => # # This is the problem. On initialization it's saying shrink 1, and setting that to the first. First should be set to 0
#        Why doesn't this blow up when I first start?
      ##
      #

      $logger.info("First or shrink #{@first} #{shrink_amount}")
      @first = @first + shrink_amount
      $logger.info("Set first3 #{current_height} #{new_height} #{@first}")
    end
  end
end
