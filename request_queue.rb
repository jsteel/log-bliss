class RequestQueue
  def initialize
    reset
  end

  def reset
    @requests_first = 0
    @requests_current = 0
    @requests_last = 0

    @requests_scrolling = true

    @requests = {}
    @request_queue = []

    @trace_start = 0
    @trace_end = 0
  end

  def add_request(uuid, line, maxy)
    if @requests[uuid].nil?
      @request_queue << uuid
      @requests[uuid] = []

      if @requests_scrolling
        @requests_last += 1
        if @requests_last - @requests_first > maxy
          @requests_first += 1
          @requests_current = [@requests_current, @requests_first].max
        end
      end
    end

    @requests[uuid] << line
  end

  def get_lines
    last = [@requests_last - 1, @request_queue.length].min

    (@requests_first..last).each_with_index do |line_index, i|
      request = @request_queue[line_index]
      next unless request

      lines = @requests[request]
      # TODO This is super inefficient. Cache it.
      first_line = lines.find { |line| line =~ /Processing/ } || lines.first

      yield(request, line_index == @requests_current, first_line, i)
    end
  end

  def current_request_lines(maxy)
    selected_request = @request_queue[@requests_current]
    lines = @requests[selected_request]
  end

  def move_cursor_down
    @requests_current = [@requests_current + 1, @requests.length].min
    if @requests_current > @requests_last
      @requests_last = @requests_current
      @requests_first += 1
    end
  end

  def move_cursor_up
    @requests_current = [@requests_current - 1, 0].max
    if @requests_current < @requests_first
      @requests_first = @requests_current
      @requests_last -= 1
    end
  end

  def prevent_scrolling(maxy)
    # Prevent scrolling on the top window
    @requests_scrolling = !@requests_scrolling

    if @requests_scrolling
      @requests_last = @requests.length
      @requests_current = @requests_last
      @requests_first = [0, @requests_last - maxy].max
    end
  end

  def reset_scroll_position(height)
    @requests_last = [@requests_current + height, @requests.length].min
    @requests_first = [@requests_last - height + 1, 0].max
  end
end
