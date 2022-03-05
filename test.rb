#!/usr/bin/env ruby

require "optparse"
require "curses"

require "./window_manager"
require "./request_queue_manager"
require "./tail"

# [20:44:47.238] [request_uuid:rake-e857b461] Rails schema is uncached. Reading from the database now data_sources/8c9fbaa08ae19d9ee9f298b7af242f11314ca04c}
# Helpful tutorial: https://www.2n.pl/blog/basics-of-curses-library-in-ruby-make-awesome-terminal-apps

# Getting input https://stackoverflow.com/questions/53809310/workaround-for-ncurses-multi-thread-read-and-write

# Ncurses docs: https://invisible-island.net/ncurses/ncurses.faq.html#multithread
# FAQ https://invisible-island.net/ncurses/ncurses.faq.html

# Ncurses tutorial: http://jbwyatt.com/ncurses.html#input

# TODO
# Home and end
# Rakefile for curses
# Using on live file does not show the current request until you move

go_back_count = nil

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: test.rb [-n line_count] file"

  opts.on("-n COUNT", "--tail=COUNT", "Start reading n lines from the end of the input file") do |count|
    go_back_count = count.to_i
  end
end.parse!

require "logger"

$logger = Logger.new("/tmp/log")

if ARGV[-1]
  @input = FileTail.new(ARGV[-1])
  buffer = @input.get_previous(go_back_count) if go_back_count
else
  @input = PipeTail.new
end

def get_input(win_manager, request_queue_manager)
  win_manager.win.keypad = true
  str = win_manager.win.getch
  return if str.nil?

  case str.ord
  when 106 # j
    request_queue_manager.move_cursor_down
  when 107 # k
    request_queue_manager.move_cursor_up
  when 109 # m
    request_queue_manager.move_log_down
  when 44 # ,
    request_queue_manager.move_log_up
  when 105 # i
    request_queue_manager.toggle_scrolling
  when 117 # u
    if win_manager.screen_layout == :split_horizontal
      win_manager.screen_layout = :split_vertical
    elsif win_manager.screen_layout == :split_vertical
      win_manager.screen_layout = :full_request
    elsif win_manager.screen_layout == :full_request
      win_manager.screen_layout = :full_index
    else
      win_manager.screen_layout = :split_horizontal
    end
    request_queue_manager.set_dimensions(win_manager.win.maxy, win_manager.win.maxx, win_manager.win2&.maxy, win_manager.win2&.maxx)
  when 99 # c
    request_queue_manager.reset
  when 120 # x
    request_queue_manager.copy_current_request
  when 49 # 1
    request_queue_manager.toggle_column_collapse(1)
  when 50 # 2
    request_queue_manager.toggle_column_collapse(2)
  when 119 # w
    request_queue_manager.toggle_line_wrap(win_manager.win.maxy, win_manager.win.maxx, win_manager.win2&.maxy, win_manager.win2&.maxx)
  when 97 # a
    win_manager.grow_index_window_size(-1)
    request_queue_manager.set_dimensions(win_manager.win.maxy, win_manager.win.maxx, win_manager.win2&.maxy, win_manager.win2&.maxx)
  when 115 # s
    win_manager.grow_index_window_size(1)
    request_queue_manager.set_dimensions(win_manager.win.maxy, win_manager.win.maxx, win_manager.win2&.maxy, win_manager.win2&.maxx)
  when 113 # q
  when 27 # escape
    exit 0
  when 112 # p
    sleep 10
  when Curses::Key::NPAGE
    $logger.info("page next")
  when Curses::Key::PPAGE
  when Curses::Key::HOME
  when Curses::Key::END
  end
end

def handle_lines(raw_input, win_manager, request_queue_manager)
  while true
    line, sep, raw_input = raw_input.partition("\n")

    # If no match, then line contains the rest
    return line if raw_input.empty? && sep.empty?

    request_queue_manager.add_line(line)

    return line if raw_input.empty?
  end
end

request_queue_manager = RequestQueueManager.new
win_manager = WindowManager.new(request_queue_manager)

request_queue_manager.set_dimensions(win_manager.win.maxy, nil, win_manager.win2&.maxy, nil)

handle_lines(buffer, win_manager, request_queue_manager) if buffer

raw_input = ""

begin
  while true
    raw_input += @input.get_more
    raw_input = handle_lines(raw_input, win_manager, request_queue_manager)
    get_input(win_manager, request_queue_manager)
    win_manager.render
  end
rescue Interrupt
  # Reset the terminal
  Curses.close_screen
end
