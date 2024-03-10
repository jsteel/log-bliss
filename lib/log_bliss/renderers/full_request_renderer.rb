require "./lib/log_bliss/renderers/split_renderer"

class FullRequestRenderer < SplitRenderer
  def initialize(request_queue_manager)
    @request_queue_manager = request_queue_manager

    # height, width, top, left
    @win = Curses::Window.new(1, 0, 0, 0)
    @win2 = Curses::Window.new(Curses.lines - 2, 0, 2, 0)

    @win_divider = Curses::Window.new(1, 0, 1, 0)
    @win_divider.addstr("━" * @win_divider.maxx)
    @win_divider.refresh

    @win.nodelay = true
  end
end
