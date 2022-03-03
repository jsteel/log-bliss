#!/usr/bin/env ruby

require "optparse"
require "curses"
require "pry-remote"

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
# Request queue sliding

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
  str = win_manager.win.getstr.to_s.chomp
  $logger.info("INPUT: #{str}") unless str.empty?

  case str
  when 'j'
    request_queue_manager.move_cursor_down
  when 'k'
    request_queue_manager.move_cursor_up
  when 'm'
    request_queue_manager.move_log_down
  when ','
    request_queue_manager.move_log_up
  when 'i'
    request_queue_manager.toggle_scrolling
  when 'u'
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
  when 'c'
    # request_queue_manager.reset
  when 'x'
    request_queue_manager.copy_current_request
  when '1'
    # win_manager.toggle_collapse_column(1)
  when '2'
    # win_manager.toggle_collapse_column(2)
  when 'w'
    request_queue_manager.toggle_line_wrap(win_manager.win.maxy, win_manager.win.maxx)
  when 'a'
    win_manager.grow_index_window_size(-1)
    request_queue_manager.set_dimensions(win_manager.win.maxy, win_manager.win.maxx, win_manager.win2&.maxy, win_manager.win2&.maxy)
  when 's'
    win_manager.grow_index_window_size(1)
    request_queue_manager.set_dimensions(win_manager.win.maxy, win_manager.win.maxx, win_manager.win2&.maxy, win_manager.win2&.maxy)
  when 'q'
    exit 0
  when 'p'
    sleep 10
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
