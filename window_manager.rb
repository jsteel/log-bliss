require 'set'

class WindowManager
  attr_reader :win
  attr_reader :win2
  attr_reader :screen_layout
  attr_accessor :redraw

  def initialize(request_queue)
    Curses.init_screen

    $logger.info("Screen #{Curses.lines.to_s}x#{Curses.cols.to_s}")

    @request_queue = request_queue

    setup_split_horizontal

    Curses.start_color
    Curses.curs_set(0) # Hide the cursor
    Curses.noecho # Do not echo characters typed by the user

    # List of colors: https://en.wikipedia.org/wiki/ANSI_escape_code#Colors
    Curses.init_pair(1, 15, 0)
    Curses.init_pair(2, 0, 15)
    Curses.init_pair(3, Curses::COLOR_BLUE, 0)
    Curses.init_pair(4, Curses::COLOR_RED, 0)
    Curses.init_pair(5, Curses::COLOR_CYAN, 0)
    Curses.init_pair(6, Curses::COLOR_MAGENTA, 0)
    Curses.init_pair(7, Curses::COLOR_GREEN, 0)

    @screen_layout = :split_horizontal
    @redraw = true

    @collapsed_columns = Set.new
    @line_wrap = false
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

  def toggle_collapse_column(column_num)
    if @collapsed_columns.include?(column_num)
      @collapsed_columns.delete(column_num)
    else
      @collapsed_columns.add(column_num)
    end
  end

  def toggle_line_wrap
    @line_wrap = !@line_wrap
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
    @request_queue.reset_scroll_position(@win.maxy, @win2&.maxy)
  end

  def setup_full_request
    # height, width, top, left
    @win = Curses::Window.new(1, 0, 0, 0)
    @win2 = Curses::Window.new(Curses.lines - 1, 0, 1, 0)
    @win.nodelay = true
    @request_queue.reset_scroll_position(@win.maxy, @win2&.maxy)
  end

  def setup_full_index
    # height, width, top, left
    @win = Curses::Window.new(Curses.lines, 0, 0, 0)
    @win.nodelay = true
    @request_queue.reset_scroll_position(@win.maxy, @win2&.maxy)
  end

  def redraw
    return unless @win

    win = @win
    return unless @redraw

    @request_queue.get_lines do |selected, first_line, i|
      win.setpos(i, 0)
      print_line(first_line, win, selected ? Curses.color_pair(2) : Curses.color_pair(1))
      win.clrtoeol()
    end

    win.setpos(win.cury + 1, 0)
    (win.maxy - win.cury - 1).times { win.deleteln }

    win.refresh
  end

  def draw_request
    return unless @win2

    win = @win2
    win.setpos(0, 0)

    lines = @request_queue.current_request_lines do |line, i|
      next if win.cury >= win.maxy
      print_line(line, win)
      win.clrtoeol()
      win.setpos(win.cury + 1, 0) unless win.curx == 0
    end

    (win.maxy - 2 - win.cury).times { win.deleteln }

    win.refresh
  end

  def print_line(line, win, default_color = Curses.color_pair(1))
    match = line.match(/\[(\d\d:\d\d:\d\d\.\d\d\d)\] \[(request_uuid:[\w-]+)\](\W+.*)/)
    col1 = match[1] unless @collapsed_columns.include?(1)
    col2 = match[2] unless @collapsed_columns.include?(2)
    line = "[#{col1}] [#{col2}]#{match[3]}"

    line = line[0..win.maxx - 1] unless @line_wrap

    match = line.match(/\[(\d\d:\d\d:\d\d\.\d\d\d)?\] \[(request_uuid:[\w-]+)?\](\W+.*)/)
    win.attron(default_color)
    win.addstr("[")
    unless @collapsed_columns.include?(1)
      win.attron(Curses.color_pair(3))
      win.addstr(match[1])
      win.attron(default_color)
    end
    win.addstr("] ")

    win.addstr("[")
    unless @collapsed_columns.include?(2)
      win.attron(Curses.color_pair(4))
      win.addstr(match[2])
      win.attron(default_color)
    end
    print_with_color("]#{match[3]}", win)
  end

  def print_with_color(line, win)
    while line != ""
      line_part, sep, line = line.partition(/\e\[\dm(\e\[\d\d?m)?/)
      win.attron(ansii_to_curses_pair(sep)) unless sep.empty?
      win.addstr(line_part)
    end
  end

  def ansii_to_curses_pair(ansii_code)
    case ansii_code
    when '[1m[35m'
      Curses.color_pair(6)
    when '[1m[36m'
      Curses.color_pair(5)
    when '[1m[34m'
      Curses.color_pair(7)
    else
      Curses.color_pair(0)
    end
  end
end
