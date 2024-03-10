require "./lib/log_bliss/renderers/split_renderer"

class SplitHorizontalRenderer < SplitRenderer
  def initialize(request_queue_manager)
    @request_queue_manager = request_queue_manager

    half_lines = Curses.lines.to_f / 2

    @horizontal_index_window_size ||= half_lines.ceil
    @horizontal_index_window_size = [@horizontal_index_window_size, Curses.lines - 1].min

    build_windows
  end

  def grow_index_window_size(grow_amount)
    @horizontal_index_window_size = (@horizontal_index_window_size + grow_amount).clamp(1, Curses.lines - 2)
    close_windows
    build_windows
  end

  private

  def build_windows
    # height, width, top, left
    @win = Curses::Window.new(@horizontal_index_window_size, 0, 0, 0)

    @win_divider = Curses::Window.new(1, 0, @horizontal_index_window_size, 0)
    @win_divider.addstr("━" * @win_divider.maxx)
    @win_divider.refresh

    @win2 = Curses::Window.new(Curses.lines - @horizontal_index_window_size - 1, 0, @horizontal_index_window_size + 1, 0)

    @win.nodelay = true
  end
end
