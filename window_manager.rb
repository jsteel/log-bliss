require 'set'
require './help'
require './lib/log_bliss/renderers'

class WindowManager
  attr_reader :screen_layout
  attr_accessor :redraw

  def initialize(request_queue_manager)
    Curses.init_screen

    $logger.info("Screen #{Curses.lines.to_s}x#{Curses.cols.to_s}")

    @request_queue_manager = request_queue_manager

    setup_colors
    Curses.curs_set(0) # Hide the cursor
    Curses.noecho # Do not echo characters typed by the user

    split_horizontal_mode
  end

  def win
    @screen_renderer.win
  end

  def win2
    @screen_renderer.win
  end

  def split_horizontal_mode
    @screen_renderer = SplitHorizontalRenderer.new(@request_queue_manager)
  end

  def split_vertical_mode
    @screen_renderer = SplitVerticalRenderer.new(@request_queue_manager)
  end

  def full_request_mode
    @screen_renderer = FullRequestRenderer.new(@request_queue_manager)
  end

  def full_index_mode
    @screen_renderer = FullIndexRenderer.new(@request_queue_manager)
  end

  def help_mode
    @old_screen_renderer = @screen_renderer
    @screen_renderer = HelpRenderer.new
  end

  def close_help
    if @old_screen_renderer.is_a?(SplitHorizontalRenderer)
      split_horizontal_mode
    elsif @old_screen_renderer.is_a?(SplitVerticalRenderer)
      split_vertical_mode
    elsif @old_screen_renderer.is_a?(FullRequestRenderer)
      full_request_mode
    elsif @old_screen_renderer.is_a?(FullIndexRenderer)
      full_index_mode
    end
    @old_screen_renderer = nil
  end

  def split_horizontal_mode?
    @screen_renderer.is_a?(SplitHorizontalRenderer)
  end

  def split_vertical_mode?
    @screen_renderer.is_a?(SplitVerticalRenderer)
  end

  def full_request_mode?
    @screen_renderer.is_a?(FullRequestRenderer)
  end

  def full_index_mode?
    @screen_renderer.is_a?(FullIndexRenderer)
  end

  def help_mode?
    @screen_renderer.is_a?(HelpRenderer)
  end

  def render
    @screen_renderer.render
  end

  def grow_index_window_size(grow_amount)
    if split_horizontal_mode? || split_vertical_mode?
      @screen_renderer.grow_index_window_size(grow_amount)
    end
  end

  private

  def setup_colors
    Curses.start_color

    # List of colors: https://en.wikipedia.org/wiki/ANSI_escape_code#Colors
    Curses.init_pair(1, 15, 0)
    Curses.init_pair(2, 0, 15)
    Curses.init_pair(3, Curses::COLOR_BLUE, 0)
    Curses.init_pair(4, Curses::COLOR_RED, 0)
    Curses.init_pair(5, Curses::COLOR_CYAN, 0)
    Curses.init_pair(6, Curses::COLOR_MAGENTA, 0)
    Curses.init_pair(7, Curses::COLOR_GREEN, 0)
  end
end
