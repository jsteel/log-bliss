class WindowManager
  attr_reader :win
  attr_reader :win2
  attr_reader :screen_layout
  attr_accessor :redraw

  def initialize(request_queue)
    Curses.init_screen

    $logger.info("Screen #{Curses.lines.to_s}x#{Curses.cols.to_s}")

    setup_split_horizontal

    Curses.start_color
    Curses.curs_set(0) # Hide the cursor
    Curses.noecho # Do not echo characters typed by the user

    # List of colors: https://en.wikipedia.org/wiki/ANSI_escape_code#Colors
    Curses.init_pair(1, 15, 0)
    Curses.init_pair(2, 0, 15)

    @screen_layout = :split_horizontal
    @redraw = true

    @request_queue = request_queue
  end

  def screen_layout=(new_layout)
    @screen_layout = new_layout

    close_windows

    if new_layout == :split_horizontal
      setup_split_horizontal
    elsif new_layout == :full_request
      setup_full_request
    elsif new_layout == :full_index
      setup_full_index
    else
      raise "Invalid window layout #{new_layout}"
    end
  end

  def render
    redraw
    draw_request
    @redraw = false
  end

  private

  def close_windows
    @win.close
    @win = nil
    @win2&.close
    @win2 = nil
    @win3&.close
    @win3 = nil
  end

  def setup_split_horizontal
    half_lines = Curses.lines / 2
    # height, width, top, left
    @win = Curses::Window.new(half_lines.floor, 0, 0, 0)
    @win3 = Curses::Window.new(1, 0, half_lines.floor, 0)
    @win3.addstr("━" * @win3.maxx)
    @win3.refresh
    @win2 = Curses::Window.new(half_lines.ceil, 0, half_lines.floor + 1, 0)
    @win.nodelay = true
    @request_queue&.reset_scroll_position(@win.maxy)
  end

  def setup_full_request
    # height, width, top, left
    @win = Curses::Window.new(1, 0, 0, 0)
    @win2 = Curses::Window.new(Curses.lines - 1, 0, 1, 0)
    @win.nodelay = true
    @request_queue&.reset_scroll_position(@win.maxy)
  end

  def setup_full_index
    # height, width, top, left
    @win = Curses::Window.new(Curses.lines, 0, 0, 0)
    @win.nodelay = true
    @request_queue&.reset_scroll_position(@win.maxy)
  end

  def redraw
    return unless @win

    win = @win
    return unless @redraw

    win.attron(Curses.color_pair(1))

    @request_queue.get_lines do |request, selected, first_line, i|
      if selected
        win.attron(Curses.color_pair(2))
      else
        win.attron(Curses.color_pair(1))
      end

      win.setpos(i, 0)
      win.addstr(first_line[0..win.maxx - 1])
      win.clrtoeol()
    end

    win.setpos(win.cury + 1, 0)
    (win.maxy - win.cury - 1).times { win.deleteln }

    win.refresh
  end

  def draw_request
    return unless @win2

    win = @win2
    lines = @request_queue.current_request_lines(win.maxy)
    return if !lines
    lines[0..win.maxy].each_with_index do |line, i|
      win.attron(Curses.color_pair(1))
      win.setpos(i, 0)
      win.addstr(line[0..win.maxx - 1])
      win.clrtoeol()
    end

    (win.maxy - 2 - win.cury).times { win.deleteln }

    win.refresh
  end
end
