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
    request_uuid = line_info[:request_uuid]

    if line_info[:new_request]
      if @request_index_window.add_one(request_uuid, raw_line)
        change_request
      end
    elsif raw_line =~ /Processing by/
      # When we get the "Processing by" line, we want to replace the original line
      # in the index window with it because it is much more descriptive.
      @request_index_window.replace_line(request_uuid, raw_line)
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
    @request_window.move_cursor_down
  end

  def move_log_up
    @request_window.move_cursor_up
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

  # TODO This should be able to ask for the width and height instead of passed as args
  def toggle_line_wrap(height, width, request_height, request_width)
    @line_wrap = !@line_wrap
    @request_index_window.set_dimensions(height, @line_wrap ? width : Float::INFINITY)
    @request_window.set_dimensions(request_height, @line_wrap ? request_width : Float::INFINITY)
  end

  def reset
    @request_slide = SlidingWindowList.new
    @log_slide = SlidingWindowList.new
    @request_queue = RequestQueue.new
    @request_index_window = RequestWindow.new([], 0, SlidingWindowList::SCROLL_STRATEGY_DEFAULT)
    @request_window = RequestWindow.new([], 0, SlidingWindowList::SCROLL_STRATEGY_SLIDE)
  end

  def copy_current_request
    File.open("/tmp/log_copy", "w") do |file|
     file.puts current_request_lines.join("\n")
    end
    system("cat /tmp/log_copy | pbcopy")
  end

  private

  def current_request_lines
    @request_queue.lines_for_request(@request_index_window.current) || []
  end

  def change_request
    @request_window = RequestWindow.new(current_request_lines, @request_window.height, SlidingWindowList::SCROLL_STRATEGY_SLIDE)
  end
end
