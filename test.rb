#!/usr/bin/env ruby

require 'optparse'
require 'curses'
require 'pry-remote'

require './window_manager'
require './request_queue'
require './tail'

# [20:44:47.238] [request_uuid:rake-e857b461] Rails schema is uncached. Reading from the database now data_sources/8c9fbaa08ae19d9ee9f298b7af242f11314ca04c}
# Helpful tutorial: https://www.2n.pl/blog/basics-of-curses-library-in-ruby-make-awesome-terminal-apps

# Getting input https://stackoverflow.com/questions/53809310/workaround-for-ncurses-multi-thread-read-and-write

# Ncurses docs: https://invisible-island.net/ncurses/ncurses.faq.html#multithread
# FAQ https://invisible-island.net/ncurses/ncurses.faq.html

# Ncurses tutorial: http://jbwyatt.com/ncurses.html#input

# TODO
# Word wraping working. Now fix the toggle between the two modes. In toggle_line_wrap
# call down to reuqest queue, rebuild the log_slide, and figure out how to
# position the current element.

go_back_count = nil

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: test.rb [-n line_count] file"

  opts.on("-n COUNT", "--tail=COUNT", "Start reading n lines from the end of the input file") do |count|
    go_back_count = count.to_i
  end
end.parse!

require 'logger'

$logger = Logger.new("/tmp/log")

if ARGV[-1]
  @input = FileTail.new(ARGV[-1])
  buffer = @input.get_previous(go_back_count) if go_back_count
else
  @input = PipeTail.new
end

def get_input(win_manager, request_queue)
  str = win_manager.win.getstr.to_s.chomp
  $logger.info("INPUT: #{str}") unless str.empty?

  case str
  when 'j'
    request_queue.move_cursor_down
    win_manager.redraw = true
  when 'k'
    request_queue.move_cursor_up
    win_manager.redraw = true
  when 'm'
    request_queue.move_log_down
  when ','
    request_queue.move_log_up
  when 'i'
    request_queue.toggle_scrolling(win_manager.win.maxy)
  when 'u'
    # Split windows
    if win_manager.screen_layout == :split_horizontal
      win_manager.screen_layout = :split_vertical
    elsif win_manager.screen_layout == :split_vertical
      win_manager.screen_layout = :full_request
    elsif win_manager.screen_layout == :full_request
      win_manager.screen_layout = :full_index
    else
      win_manager.screen_layout = :split_horizontal
    end
  when 'c'
    request_queue.reset
    win_manager = true
  when 'x'
    request_queue.copy_current_request
  when '1'
    win_manager.toggle_collapse_column(1)
  when '2'
    win_manager.toggle_collapse_column(2)
  when 'w'
    win_manager.toggle_line_wrap
  when 'a'
    win_manager.grow_index_window_size(-1)
  when 's'
    win_manager.grow_index_window_size(1)
  when 'q'
    exit 0
  when 'p'
    sleep 10
  end
end

def handle_lines(raw_input, win_manager, request_queue)
  while true
    line, sep, raw_input = raw_input.partition("\n")

    # If no match, then line contains the rest
    return line if raw_input.empty? && sep.empty?

    handle_line(line, win_manager, request_queue)

    return line if raw_input.empty?
  end
end

def handle_line(line, win_manager, request_queue)
  match = line.match(/\[\d\d:\d\d:\d\d\.\d\d\d\] (\[request_uuid:[\w-]+\])\W*.*/)

  if match
    uuid = match[1]
    @previous_uuid = uuid
    request_queue.add_request(uuid, line, win_manager.win.maxy, win_manager.win2&.maxy)
    win_manager.redraw = true
  elsif @previous_uuid
    request_queue.append_line(@previous_uuid, line, win_manager.win.maxy, win_manager.win2&.maxy)
    win_manager.redraw = true
  end
end

request_queue = RequestQueue.new
win_manager = WindowManager.new(request_queue)

handle_lines(buffer, win_manager, request_queue) if buffer

raw_input = ""

begin
  while true
    raw_input += @input.get_more
    raw_input = handle_lines(raw_input, win_manager, request_queue)
    get_input(win_manager, request_queue)
    win_manager.render
  end
rescue Interrupt
  # Reset the terminal
  Curses.close_screen
end
