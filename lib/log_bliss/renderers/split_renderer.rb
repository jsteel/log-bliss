class SplitRenderer
  attr_reader :win
  attr_reader :win2

  def render
    redraw_index
    draw_request
  end

  private

  def close_windows
    # TODO Switch to array of windows
    @win.close
    @win = nil
    @win2&.close
    @win2 = nil
    @win_divider&.close
    @win_divider = nil
  end

  def redraw_index
    return unless @win

    win = @win
    win.setpos(0, 0)
    # Clear in case the results are empty
    win.clrtoeol

    @request_queue_manager.index_lines do |selected, line, i|
      win.setpos(i, 0)
      print_line(line, win, selected ? Curses.color_pair(2) : Curses.color_pair(1))
      win.clrtoeol
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
    win.clrtoeol

    @request_queue_manager.request_lines do |selected, line, i|
      win.setpos(i, 0)
      print_line(line, win)
      win.clrtoeol
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
end
