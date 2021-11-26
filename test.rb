#!/usr/bin/env ruby

require 'optparse'
require 'curses'
require 'pry-remote'

require './window_manager'
require './request_queue'

# [20:44:47.238] [request_uuid:rake-e857b461] Rails schema is uncached. Reading from the database now data_sources/8c9fbaa08ae19d9ee9f298b7af242f11314ca04c}
# Helpful tutorial: https://www.2n.pl/blog/basics-of-curses-library-in-ruby-make-awesome-terminal-apps

# Getting input https://stackoverflow.com/questions/53809310/workaround-for-ncurses-multi-thread-read-and-write

# Ncurses docs: https://invisible-island.net/ncurses/ncurses.faq.html#multithread
# FAQ https://invisible-island.net/ncurses/ncurses.faq.html

# Ncurses tutorial: http://jbwyatt.com/ncurses.html#input

# TODO
# If you press up/down when on a request at the end, it shoots back to the top (or the other way around)
# Handle lines that don't have a uuid and stack traces

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
  @input = File.open(ARGV[-1], "r")
else
  @input = $stdin.clone
  fd = IO.sysopen('/dev/tty', 'r')
  $stdin.reopen(IO.new(fd))
end

if go_back_count
  stats = @input.stat
  buf_size = stats.blksize
  @input.seek(0, File::SEEK_END)

  while go_back_count > 0
    @input.seek(-buf_size, File::SEEK_CUR)
    buffer = @input.read(buf_size)
    go_back_count -= buffer.count("\n")

    # Go back to the same spot again after reading
    @input.seek(-buf_size, File::SEEK_CUR) if go_back_count > 0

    while go_back_count < 0
      _, _, buffer = buffer.partition("\n")
      go_back_count += 1
    end
  end
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
    request_queue.prevent_scrolling(win_manager.win.maxy)
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
  # Remove ansi shell colors
  # line.gsub!(/\e\[\d+m/, '')

  return if line.empty?

  match = line.match(/\[\d\d:\d\d:\d\d\.\d\d\d\] (\[request_uuid:[\w-]+\])\W+.*/)

  if match
    uuid = match[1]
    request_queue.add_request(uuid, line, win_manager.win.maxy, win_manager.win2&.maxy)
    win_manager.redraw = true
  end
end

request_queue = RequestQueue.new
win_manager = WindowManager.new(request_queue)

handle_lines(buffer, win_manager, request_queue) if buffer

raw_input = ""

begin
  while true
    begin
      raw_input += @input.read_nonblock(100)
    rescue IO::EAGAINWaitReadable, EOFError
      # No input to read yet
    end
    raw_input = handle_lines(raw_input, win_manager, request_queue)
    get_input(win_manager, request_queue)
    win_manager.render
  end
rescue Interrupt
  # Reset the terminal
  Curses.close_screen
end
