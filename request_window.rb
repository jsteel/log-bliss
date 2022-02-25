require "./request_lexer"

class RequestWindow
  def initialize(raw_lines)
    @request_tree = RequestTree.new(raw_lines)
    # TODO Initialize sliding window. I wasn't using a sliding window list for the request window
    # before. Should I be? Or should it just be a simple size? Could pass the windowing function into
    # here (strategy pattern?).
    @request_slide = SlidingWindowList.new
  end

  def add_one(raw_line)
    @request_slide.add_one
    @request_tree.add_line(raw_line)
    @request_tree.move_cursor(@request_slide.requests_current)
  end

  extend Forwardable
  def_delegators :@request_slide, :toggle_scrolling

  def move_cursor_up
    @request_slide.move_cursor_up
    @request_tree.move_cursor(@request_slide.requests_current)
  end

  def move_cursor_down
    @request_slide.move_cursor_down
    @request_tree.move_cursor(@request_slide.requests_current)
  end

  def set_dimensions(height, width)
    $logger.info("set dimensions #{height}, #{width}")
    @request_tree.new_width(width) if width
    @request_slide.new_height(height)

    current_line =
      if width
        @request_tree.cursor_line_number
      else
        @request_tree.cursor_parent_line_number
      end
    $logger.info("current line #{current_line} - #{@request_tree.lines}")
    # @request_slide.move_cursor(current_line) if current_line
    height_diff = @request_slide.requests_current - @request_slide.requests_first
    # @request_slide.max_size = @request_tree.lines.length
    @request_slide = SlidingWindowList.new(
      height: height,
      first: current_line ? current_line - height_diff : 0,
      current: current_line || 0,
      max_size: @request_tree.lines.count
    )
  end

  def visible_lines
    # $logger.info("visible lines ----------------")
    (@request_slide.requests_first...@request_slide.requests_last).each_with_index do |line_index, i|
      line = @request_tree.lines[line_index]
      next unless line
      # $logger.info("line #{line}")
      yield(line_index == @request_slide.requests_current, line, i)
    end
  end
end
