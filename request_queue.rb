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

  def prevent_scrolling(maxy)
    # Prevent scrolling on the top window
    @requests_scrolling = !@requests_scrolling

    if @requests_scrolling
      @requests_last = @max_size - 1
      @requests_current = @requests_last
      @requests_first = [0, @requests_last - maxy].max
    end
  end

  def reset_scroll_position(height)
    @requests_last = [@requests_current + height, @max_size].min
    @requests_first = [@requests_last - height + 1, 0].max
  end
end

class RequestQueue
  def initialize
    @request_slide = SlidingWindowList.new
    @log_slide = SlidingWindowList.new
    reset
  end

  def reset
    @requests = {}
    @request_queue = []
  end

  def add_request(uuid, line, maxy, log_maxy)
    if @requests[uuid].nil?
      @request_queue << uuid
      @requests[uuid] = []
      @request_slide.add_one(maxy)
    end

    if uuid == current_uuid
      # The sliding windows should have a more elegant way of getting their
      # height. Best would be to have a setter for their height. Then the window
      # manager can somehow pass the heights to the sliding windows when they
      # change. Probably via the request queue grabbing and passing it.
      @log_slide.add_one(log_maxy) if log_maxy
    end

    @requests[uuid] << line
  end

  def get_lines
    last = [@request_slide.requests_last - 1, @request_queue.length].min

    (@request_slide.requests_first..last).each_with_index do |line_index, i|
      request = @request_queue[line_index]
      next unless request

      lines = @requests[request]
      first_line = lines.find { |line| line =~ /Processing/ } || lines.first

      yield(line_index == @request_slide.requests_current, first_line, i)
    end
  end

  def current_request_lines(maxy)
    selected_request = @request_queue[current_uuid]
    lines = @requests[selected_request]
  end

  def move_cursor_down
    @request_slide.move_cursor_down
  end

  def move_cursor_up
    @request_slide.move_cursor_up
  end

  def prevent_scrolling(maxy)
    @request_slide.prevent_scrolling(maxy)
  end

  def reset_scroll_position(height)
    @request_slide.reset_scroll_position(height)
  end

  private

  def current_uuid
    @request_slide.requests_current
  end
end
