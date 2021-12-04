require './sliding_window_list'

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

  def append_line(uuid, line, maxy, log_maxy)
    @requests[uuid][-1] += "\n#{line}"
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
