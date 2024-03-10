require "./lib/log_bliss/renderers/split_renderer"

class SplitVerticalRenderer < SplitRenderer
  def initialize(request_queue_manager)
    @request_queue_manager = request_queue_manager

    half_width = Curses.cols.to_f / 2

    @vertical_index_window_size ||= half_width.ceil
    @vertical_index_window_size = [@vertical_index_window_size, Curses.cols - 5].min

    build_windows
  end

  def grow_index_window_size(grow_amount)
    @vertical_index_window_size = (@vertical_index_window_size + grow_amount).clamp(50, Curses.cols - 5)
    close_windows
    build_windows
  end

  private

  def build_windows
    # height, width, top, left
    @win = Curses::Window.new(0, @vertical_index_window_size, 0, 0)

    @win_divider = Curses::Window.new(0, 1, 0, @vertical_index_window_size)
    @win_divider.addstr("┃" * @win_divider.maxy)
    @win_divider.refresh

    @win2 = Curses::Window.new(0, Curses.cols - @vertical_index_window_size - 1, 0, @vertical_index_window_size + 1)

    @win.nodelay = true
  end
end
