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
    @request_tree.add_line(raw_line)
    @request_slide.add_one
  end

  extend Forwardable
  def_delegators :@request_slide, :move_cursor_down, :move_cursor_up, :toggle_scrolling

  def set_dimensions(height, width)
    @request_slide.height = height
  end

  def visible_lines(max_count)
    $logger.info("slide #{@request_slide.requests_first} #{@request_slide.requests_last} #{@request_slide.requests_current}")
    (@request_slide.requests_first...@request_slide.requests_last).each_with_index do |line_index, i|
      line = @request_tree.lines[line_index]
      next unless line
      yield(line_index == @request_slide.requests_current, line, i)
    end
  end
end
