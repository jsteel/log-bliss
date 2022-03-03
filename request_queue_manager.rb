require "./sliding_window_list"
require "./request_queue"
require "./request_window"

class RequestQueueManager
  attr_reader :collapsed_columns

  def initialize
    reset
    @line_wrap = false
    @collapsed_columns = Set.new
  end

  def add_line(raw_line)
    line_info = @request_queue.add_line(raw_line)

    if line_info[:new_request]
      @request_index_window.add_one(raw_line)
      change_request
    elsif line_info[:request_uuid] == @current_request_uuid
      # TODO If it's the first line, send that as a replacement to request_index_window
      #   first_line = lines.find { |line| line =~ /Processing/ } || lines.first
      # @request_log_window.add_one
    end
  end

  def index_lines(&block)
    @request_index_window.visible_lines(&block)
  end

  def request_lines(&block)
    @request_window.visible_lines(&block)
  end

  def move_cursor_down
    @request_index_window.move_cursor_down
    change_request
  end

  def move_cursor_up
    @request_index_window.move_cursor_up
    change_request
  end

  def move_log_down
    @request_window.slide_cursor_down
  end

  def move_log_up
    @request_window.slide_cursor_up
  end

  def toggle_column_collapse(column_num)
    if @collapsed_columns.include?(column_num)
      @collapsed_columns.delete(column_num)
      collumn_collapsed = false
    else
      @collapsed_columns.add(column_num)
      collumn_collapsed = true
    end

    @request_index_window.toggle_column_collapse(column_num, collumn_collapsed)
    @request_window.toggle_column_collapse(column_num, collumn_collapsed)
  end

  def set_dimensions(height, width, request_height, request_width)
    @request_index_window.set_dimensions(height, @line_wrap ? width : Float::INFINITY)
    @request_window.set_dimensions(request_height, @line_wrap ? width : Float::INFINITY) if request_height
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

  def reset
    @request_slide = SlidingWindowList.new
    @log_slide = SlidingWindowList.new
    @request_queue = RequestQueue.new
    @request_index_window = RequestWindow.new([])
    @request_window = RequestWindow.new([])
  end

  def copy_current_request
    File.open("/tmp/log_copy", "w") do |file|
     file.puts current_request_lines.join("\n")
    end
    system("cat /tmp/log_copy | pbcopy")
  end

  private

  def current_request_lines
    @request_queue.lines_for_request(@request_index_window.requests_current) || []
  end

  def change_request
    $logger.info("Change request height #{@request_window.height}")
    @request_window = RequestWindow.new(current_request_lines, @request_window.height)
  end
end
