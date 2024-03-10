#!/usr/bin/env ruby

require "optparse"
require "curses"

require "./window_manager"
require "./request_queue_manager"
require "./tail"

go_back_count = nil

options = {}
OptionParser.new do |opts|
  opts.banner = "Read and display Rails log files from a file or STDIN"
  opts.banner += "\n\nUsage: test.rb [-n line_count] file\n"

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

@previous_screen_layout = nil

def get_user_input(win_manager, request_queue_manager)
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
    if win_manager.split_horizontal_mode?
      win_manager.split_vertical_mode
    elsif win_manager.split_vertical_mode?
      win_manager.full_request_mode
    elsif win_manager.full_request_mode?
      win_manager.full_index_mode
    else
      win_manager.split_horizontal_mode
    end
    request_queue_manager.set_dimensions(win_manager.win.maxy, win_manager.win.maxx, win_manager.win2&.maxy, win_manager.win2&.maxx)
  when 99 # c
    $logger.info("clear")
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
  when 113, 27 # q, escape
    exit 0
  when 112 # p
    sleep 10
  when 63, 104 # ?, h
    show_help(win_manager)
  when Curses::Key::NPAGE
    $logger.info("page next")
  when Curses::Key::PPAGE
  when Curses::Key::HOME
  when Curses::Key::END
  end
end

def show_help(win_manager)
  if win_manager.help_mode?
    win_manager.close_help
  else
    win_manager.help_mode
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

# Process the amount we were supposed to go back before handling any new input
handle_lines(buffer, win_manager, request_queue_manager) if buffer

raw_input = ""

begin
  while true
    raw_input += @input.get_more
    raw_input = handle_lines(raw_input, win_manager, request_queue_manager)
    get_user_input(win_manager, request_queue_manager)
    win_manager.render
  end
rescue Interrupt
  # Reset the terminal
  Curses.close_screen
end
