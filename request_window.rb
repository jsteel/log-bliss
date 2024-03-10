require "./request_tree"
require 'forwardable'

class RequestWindow
  def initialize(raw_lines, height = 0, scroll_strategy = nil)
    @request_tree = RequestTree.new(raw_lines)
    $logger.info("New sliding window list #{height}")
    @request_slide = SlidingWindowList.new(height: height, max_size: @request_tree.lines.count, scroll_strategy: scroll_strategy)
  end

  def add_one(request_uuid, raw_line)
    $logger.info("Add one #{@request_slide.current} #{@request_slide.first}")
    start_line = @request_slide.current
    @request_slide.add_one
    changed_line = start_line != @request_slide.current
    @request_tree.add_line(raw_line)
    # Why is this 2?!!?!?!!? The above line it was 0
    $logger.info("XAdd one #{@request_slide.current}")
    @request_tree.move_cursor(@request_slide.current) if changed_line
    # Return true ff we changed lines or this is the first line that was added
    # changed_line is false when we add the first line because the request slide
    # starts at 0 when empty, and stays at 0 when you add 1 line.
    return changed_line || @request_tree.lines.length == 1
  end

  def replace_line(request_uuid, raw_line)
    # XXX: Drilling the request uuid down into the tree and then down into the lexer is not a good idea.
    @request_tree.replace_line(request_uuid, raw_line)
    @request_tree
  end

  extend Forwardable
  def_delegators :@request_slide, :toggle_scrolling, :current, :height

  def move_cursor_up
    lines_to_move_up = @request_tree.prev_line_number
    @request_slide.move_cursor_up(lines_to_move_up) if lines_to_move_up
    @request_tree.move_cursor(@request_slide.current)
    $logger.info("xxx ------> #{@request_tree.lines}")
  end

  def move_cursor_down
    lines_to_move_down = @request_tree.next_line_number
$logger.info("moving #{lines_to_move_down}")
    @request_slide.move_cursor_down(lines_to_move_down) if lines_to_move_down
    @request_tree.move_cursor(@request_slide.current)

    $logger.info("xxx ----->. #{@request_slide.current} ---  #{@request_tree.lines}")
  end

  def toggle_column_collapse(column_num, collumn_collapsed)
    @request_tree.toggle_column(column_num, collumn_collapsed)
  end

  def set_dimensions(height, width)
    @request_tree.new_width(width) if width

    current_line =
      if width
        @request_tree.cursor_line_number
      else
        @request_tree.cursor_parent_line_number
      end

    @request_slide = SlidingWindowList.new(
      height: height,
      first: @request_slide.first || 0,
      current: current_line ? current_line : 0,
      max_size: @request_tree.lines.count
    )
  end

  def visible_lines
    # XXX This is where we need to get the correct lines. We need to ask the tree for it.
    $logger.info("SLIDE WANTS #{@request_slide.first} - #{@request_slide.last}")
    (@request_slide.first...@request_slide.last).each_with_index do |line_index, i|
      line = @request_tree.lines[line_index]
      next unless line
      yield(line_index == @request_slide.current, line, i)
    end
  end
end
