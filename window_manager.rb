require 'set'
require './help'

class WindowManager
  attr_reader :win
  attr_reader :win2
  attr_reader :screen_layout
  attr_accessor :redraw

  def initialize(request_queue_manager)
    Curses.init_screen

    $logger.info("Screen #{Curses.lines.to_s}x#{Curses.cols.to_s}")

    @request_queue_manager = request_queue_manager

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
  end

  def screen_layout=(new_layout)
    @screen_layout = new_layout

    close_windows

    if new_layout == :split_horizontal
      setup_split_horizontal
    elsif new_layout == :split_vertical
      setup_split_vertical
    elsif new_layout == :full_request
      setup_full_request
    elsif new_layout == :full_index
      setup_full_index
    elsif new_layout == :help
      render_help
    else
      raise "Invalid window layout #{new_layout}"
    end
  end

  def render
    return if screen_layout == :help
    redraw_index
    draw_request
  end

  def grow_index_window_size(grow_amount)
    if @screen_layout == :split_horizontal
      @horizontal_index_window_size = (@horizontal_index_window_size + grow_amount).clamp(1, Curses.lines - 2)
    elsif @screen_layout == :split_vertical
      @vertical_index_window_size = (@vertical_index_window_size + grow_amount).clamp(50, Curses.cols - 5)
    end

    self.screen_layout = @screen_layout
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
    half_lines = Curses.lines.to_f / 2

    @horizontal_index_window_size ||= half_lines.ceil
    @horizontal_index_window_size = [@horizontal_index_window_size, Curses.lines - 1].min

    # height, width, top, left
    @win = Curses::Window.new(@horizontal_index_window_size, 0, 0, 0)
    @win3 = Curses::Window.new(1, 0, @horizontal_index_window_size, 0)
    @win3.addstr("━" * @win3.maxx)
    @win3.refresh
    @win2 = Curses::Window.new(Curses.lines - @horizontal_index_window_size - 1, 0, @horizontal_index_window_size + 1, 0)
    @win.nodelay = true
  end

  def setup_split_vertical
    half_width = Curses.cols.to_f / 2

    @vertical_index_window_size ||= half_width.ceil
    @vertical_index_window_size = [@vertical_index_window_size, Curses.cols - 5].min

    # height, width, top, left
    @win = Curses::Window.new(0, @vertical_index_window_size, 0, 0)
    @win3 = Curses::Window.new(0, 1, 0, @vertical_index_window_size)
    @win3.addstr("┃" * @win3.maxy)
    @win3.refresh
    @win2 = Curses::Window.new(0, Curses.cols - @vertical_index_window_size - 1, 0, @vertical_index_window_size + 1)
    @win.nodelay = true
  end

  def setup_full_request
    # height, width, top, left
    @win = Curses::Window.new(1, 0, 0, 0)
    @win2 = Curses::Window.new(Curses.lines - 2, 0, 2, 0)
    @win3 = Curses::Window.new(1, 0, 1, 0)
    @win3.addstr("━" * @win3.maxx)
    @win3.refresh
    @win.nodelay = true
  end

  def setup_full_index
    # height, width, top, left
    @win = Curses::Window.new(Curses.lines, 0, 0, 0)
    @win.nodelay = true
  end

  def redraw_index
    return unless @win

    win = @win
    win.setpos(0, 0)
    # Clear in case the results are empty
    win.clrtoeol()

    @request_queue_manager.index_lines do |selected, line, i|
      win.setpos(i, 0)
      print_line(line, win, selected ? Curses.color_pair(2) : Curses.color_pair(1))
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
    # Clear in case the results are empty
    win.clrtoeol()

    @request_queue_manager.request_lines do |selected, line, i|
      win.setpos(i, 0)
      print_line(line, win)
      win.clrtoeol()
    end

    win.setpos(win.cury + 1, 0)
    (win.maxy - win.cury - 1).times { win.deleteln }

    win.refresh
  end

  def print_line(line, win, default_color = Curses.color_pair(1))
    win.attron(default_color)
    print_with_color(line, win)
  end

  def print_with_color(line, win)
    space_left = true

    line.each do |token|
      if token[0] == :timestamp
        column = @request_queue_manager.collapsed_columns.include?(1) ? "[]" : token[1]
        space_left = print_up_to_max(column, win) if space_left
      elsif token[0] == :request_uuid
        column = @request_queue_manager.collapsed_columns.include?(2) ? "[]" : token[1]
        space_left = print_up_to_max(column, win) if space_left
      elsif token[0] == :content
        space_left = print_up_to_max(token[1], win) if space_left
      elsif token[0] == :color
        win.attron(ansii_to_curses_pair(token[1]))
      end
    end
  end

  def print_up_to_max(line, win)
    space_remaining = win.maxx - win.curx - 1
    fragment = line[0..space_remaining]
    win.addstr(fragment)
    # Return false when we have printed something and ended up on the next line.
    # That means we shouldn't print anymore.
    !(line.length > 0 && win.curx == 0)
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

  def render_help
    help_text = "\n\n\n#{HELP_TEXT}"
    @win = Curses::Window.new(0, 0, 0, 0)
    @win.addstr(help_text)
    @win.refresh
    @win.nodelay = true
  end
end
