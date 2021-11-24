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
    $logger.info("RESET max #{max_height} window height #{window_height}")

    if scroll_to_start
      @requests_current = 0
    else
      @requests_current = [@requests_current, max_height].min
    end
    @max_size = max_height
    @requests_last = [@requests_current + window_height, @max_size].min
    @requests_first = [@requests_last - window_height + 1, 0].max
    $logger.info("RESET to #{@requests_first} #{@requests_current} #{@requests_last} #{@max_size}")
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

  def current_request_lines
    lines = current_request
    return unless lines

    last = [@log_slide.requests_last - 1, lines.length].min

    (@log_slide.requests_first..last).each_with_index do |line_index, i|
      line = lines[line_index]
      next unless line
      yield(line, i)
    end
  end

  def move_cursor_down
    @request_slide.move_cursor_down
    reset_log_slide
  end

  def move_cursor_up
    @request_slide.move_cursor_up
    reset_log_slide
  end

  def prevent_scrolling(maxy)
    @request_slide.prevent_scrolling(maxy)
  end

  def reset_scroll_position(index_height, log_window_height)
    @index_height = index_height
    @log_window_height = log_window_height
    @request_slide.reset_scroll_position(index_height, @request_queue.length)
  end

  def reset_log_slide
    return unless @log_window_height

    @log_slide.reset_scroll_position(@log_window_height, current_request&.length || 0, true)
  end

  def move_log_down
    @log_slide.slide_down
  end

  def move_log_up
    @log_slide.slide_up
  end

  def copy_current_request
    File.open("/tmp/log_copy", "w") do |file|
      file.puts current_request.join("\n")
    end
    system("cat /tmp/log_copy | pbcopy")
  end

  private

  def current_request
    @requests[current_uuid]
  end

  def current_uuid
    @request_queue[@request_slide.requests_current]
  end
end
