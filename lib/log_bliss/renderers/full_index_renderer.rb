require "./lib/log_bliss/renderers/split_renderer"

class FullIndexRenderer < SplitRenderer
  def initialize(request_queue_manager)
    @request_queue_manager = request_queue_manager

    # height, width, top, left
    @win = Curses::Window.new(Curses.lines, 0, 0, 0)
    @win.nodelay = true
  end
end
