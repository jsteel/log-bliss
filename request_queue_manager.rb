require "./sliding_window_list"
require "./request_queue"
require "./request_window"

class RequestQueueManager
  def initialize
    @request_slide = SlidingWindowList.new
    @log_slide = SlidingWindowList.new
    @request_queue = RequestQueue.new
    @request_index_window = RequestWindow.new([])
    @line_wrap = false
  end

  def add_line(raw_line)
    line_info = @request_queue.add_line(raw_line)

    if line_info[:new_request]
      @request_index_window.add_one(raw_line)
    elsif line_info[:request_uuid] == @current_request_uuid
      # TODO If it's the first line, send that as a replacement to request_index_window
      #   first_line = lines.find { |line| line =~ /Processing/ } || lines.first
      # @request_log_window.add_one
    end
  end

  def get_lines(&block)
    @request_index_window.visible_lines(&block)
  end

  def current_request_lines(line_wrap, maxx)
    return []
    # lines = current_request
    # return unless lines

    # if line_wrap
    #   tree = RequestTree.new(lines, maxx)
    #   lines = tree.lines
    # end

    # last = [@log_slide.requests_last, lines.length].min

    # (@log_slide.requests_first..last).each_with_index do |line_index, i|
    #   line = lines[line_index]
    #   next unless line
    #   yield(line, i)
    # end
  end

  def move_cursor_down
    @request_index_window.move_cursor_down
  end

  def move_cursor_up
    @request_index_window.move_cursor_up
  end

  def set_dimensions(height, width = nil)
    @request_index_window.set_dimensions(height, @line_wrap ? width : Float::INFINITY)
  end

  def toggle_scrolling
    @request_index_window.toggle_scrolling
  end

  def toggle_line_wrap(height, width)
     @line_wrap = !@line_wrap
     @request_index_window.set_dimensions(height, @line_wrap ? width : Float::INFINITY)
  end

  def reset_scroll_position(index_height, log_window_height)
    # @index_height = index_height
    # @log_window_height = log_window_height
    # @request_slide.reset_scroll_position(index_height, @request_queue.length)
  end

  def reset_log_slide
    # return unless @log_window_height

    # @log_slide.reset_scroll_position(@log_window_height, current_request&.length || 0, true)
  end

  def move_log_down
    # @log_slide.slide_down
  end

  def move_log_up
    # @log_slide.slide_up
  end

  def copy_current_request
    File.open("/tmp/log_copy", "w") do |file|
     file.puts @lines_for_request.lines_for_request(@current_request_uuid).join("\n")
    end
    system("cat /tmp/log_copy | pbcopy")
  end
end
