require "./request_lexer"

class RequestWindow
  def initialize(raw_lines, height = 0)
    @request_tree = RequestTree.new(raw_lines)
    # TODO Initialize sliding window. I wasn't using a sliding window list for the request window
    # before. Should I be? Or should it just be a simple size? Could pass the windowing function into
    # here (strategy pattern?).
    @request_slide = SlidingWindowList.new(height: height)
  end

  def add_one(raw_line)
    @request_slide.add_one
    @request_tree.add_line(raw_line)
    @request_tree.move_cursor(@request_slide.requests_current)
  end

  extend Forwardable
  def_delegators :@request_slide, :toggle_scrolling, :requests_current, :height

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

    current_line =
      if width
        @request_tree.cursor_line_number
      else
        @request_tree.cursor_parent_line_number
      end

    @request_slide = SlidingWindowList.new(
      height: height,
      first: @request_slide.requests_first || 0,
      current: current_line ? [@request_slide.requests_first + height - 1, current_line].min : 0,
      max_size: @request_tree.lines.count
    )
  end

  def visible_lines
    (@request_slide.requests_first...@request_slide.requests_last).each_with_index do |line_index, i|
      line = @request_tree.lines[line_index]
      next unless line
      # $logger.info("line #{line}")
      yield(line_index == @request_slide.requests_current, line, i)
    end
  end
end
