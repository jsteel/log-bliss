#!/usr/bin/env ruby

require 'optparse'
require 'curses'
require 'pry-remote'

# [20:44:47.238] [request_uuid:rake-e857b461] Rails schema is uncached. Reading from the database now data_sources/8c9fbaa08ae19d9ee9f298b7af242f11314ca04c}
# Helpful tutorial: https://www.2n.pl/blog/basics-of-curses-library-in-ruby-make-awesome-terminal-apps

# Getting input https://stackoverflow.com/questions/53809310/workaround-for-ncurses-multi-thread-read-and-write

# Ncurses docs: https://invisible-island.net/ncurses/ncurses.faq.html#multithread
# FAQ https://invisible-island.net/ncurses/ncurses.faq.html

# Ncurses tutorial: http://jbwyatt.com/ncurses.html#input

# TODO
# The top and bottom one are out of sync when there has been scrolling. Indexes are off
# What is going on with the next line flashing? Check the TODO
# Figure out how scrolling works (scroll function)
# Key to stop scrolling the requests
# Key for full screen
# Print line at bottom with key legend
# Clear the screen key

# LATER
# Button for line wrapping
# Handle requests that don't have a uuid
# Handle stack traces
# Collapse columns of the input by pressing 1, 2, 3.
# Conver the ansi color codes to proper colors
# We go too far back with tail -n. Have to forward a bit when we overshoot.

go_back_count = nil

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: test.rb [-n line_count] file"

  opts.on("-n COUNT", "--tail=COUNT", "Start reading n lines from the end of the input file") do |count|
    go_back_count = count.to_i
  end
end.parse!

p options

@log = File.open("/tmp/log", "w+")

if ARGV[-1]
  @input = File.open(ARGV[-1], "r")
else
  @input = $stdin.clone
  fd = IO.sysopen('/dev/tty', 'r')
  $stdin.reopen(IO.new(fd))
end

# This doesn't work. It looks like curses opens it's own input manually instead
# of using stdin
# @input = IO.new($stdin.fileno)
# fd = IO.sysopen('/dev/tty', 'r')
# $stdin = IO.new(fd)
# STDIN = $stdin

if go_back_count
  stats = @input.stat
  buf_size = stats.blksize
  @input.seek(0, File::SEEK_END)

  while go_back_count > 0
    @input.seek(-buf_size, File::SEEK_CUR)
    buffer = @input.read(buf_size)
    go_back_count -= buffer.count("\n")
    @input.seek(-buf_size, File::SEEK_CUR)
  end
end

def log(msg)
  @log.puts(msg)
  @log.flush
end

def get_input(win)
  str = win.getstr.to_s.chomp
  log("INPUT: #{str}") unless str.empty?
  case str
  when 'j'
    @currently_selected = [@currently_selected + 1, win.maxy - 1, @requests.length - 1].min
    @redraw = true
  when 'k'
    @currently_selected = [@currently_selected - 1, 0].max
    @redraw = true
  when 'q'
    exit 0
  when 'p'
    sleep 40
  end
end

def handle_lines(raw_input)
  raw_input.gsub!(/\e\[\d+m/, '')

  while true
    line, sep, raw_input = raw_input.partition("\n")

    # If no match, then line contains the rest
    return line if raw_input.empty? && sep.empty?

    handle_line(line)

    return line if raw_input.empty?
  end
end

def handle_line(line)
  # Remove ansi shell colors
  line.gsub!(/\e\[\d+m/, '')
  # TODO It's definitely this. If I replace these in the file it works. But
  # this isn't getting the job done.
  line.gsub!(/\[0m/, '')
  # Try outputting the lines to a file and see if the character is still there
  # And it isn't... What the heck?
  # TODO I think it's really just the empty lines that is the issue
  line.gsub!('[0m', '')
  line.gsub!(/.\[0m/, '')

  return if line.empty?

  match = line.match(/(\[\d\d:\d\d:\d\d\.\d\d\d\]) (\[request_uuid:[\w-]+\])\W+(.*)/)

  if match
    uuid = match[2]
    if @requests[uuid].nil?
      @request_queue << uuid
      @requests[uuid] = []
      # log("NEW REQUEST-----------------------")
    end
    @requests[uuid] << line
    # log("Enqueuing '#{line}'") if @requests[uuid].length < 10
    @redraw = true
  end
end

def redraw(win)
  return unless @redraw

  #win.clear This works but makes for some really bad flashing
  win.attron(Curses.color_pair(1))
  @request_queue.last(win.maxy).each_with_index do |request, i|
    if i == @currently_selected
      win.attron(Curses.color_pair(2))
    else
      win.attron(Curses.color_pair(1))
    end
    lines = @requests[request]
    # TODO This is super inefficient. Cache it.
    first_line = lines.find { |line| line =~ /Processing/ } || lines.first
    # TODO Debugging
    # if first_line =~ /ba44/
      # $stop = true
      # binding.remote_pry
    # end
    win.setpos(i, 0)
    win.addstr(first_line[0..win.maxx - 1])
    # win.addstr("#{i}" * (win.maxx - 1)) # Debugging with line numbers
    win.clrtoeol()
  end

  win.setpos(win.cury + 1, 0)
  (win.maxy - win.cury - 1).times { win.deleteln }

  win.refresh
end

def draw_request(win)
  selected_request = @request_queue[@currently_selected]
  lines = @requests[selected_request]
  return if !lines
  # lines.last(win.maxy).each_with_index do |line, i|
  lines[0..win.maxy].each_with_index do |line, i|
    win.attron(Curses.color_pair(1))
    win.setpos(i, 0)
    win.addstr(line[0..win.maxx - 1])
    win.clrtoeol()
  end

  (win.maxy - 2 - win.cury).times { win.deleteln }

  win.refresh
end

@currently_selected = 0

Curses.init_screen

log("Screen #{Curses.lines.to_s}x#{Curses.cols.to_s}")
half_lines = Curses.lines / 2
# height, width, top, left
win = Curses::Window.new(half_lines.floor, 0, 0, 0)
win3 = Curses::Window.new(1, 0, half_lines.floor, 0)
win3.addstr("━" * win3.maxx)
win3.refresh
win2 = Curses::Window.new(half_lines.ceil, 0, half_lines.floor + 1, 0)
win.nodelay = true

log("Max xy #{win.maxx}x#{win.maxy}")

@requests = {}
@request_queue = []

Curses.start_color
Curses.curs_set(0) # Hide the cursor
Curses.noecho # Do not echo characters typed by the user

# List of colors: https://en.wikipedia.org/wiki/ANSI_escape_code#Colors
Curses.init_pair(1, 15, 0)
Curses.init_pair(2, 0, 15)

@redraw = false

raw_input = ""

while true
  begin
    raw_input += @input.read_nonblock(100)
  rescue IO::EAGAINWaitReadable, EOFError
    # No input to read yet
  end
  raw_input = handle_lines(raw_input) unless $stop
  get_input(win)
  redraw(win)
  draw_request(win2)
  @redraw = false
end

# Reset the terminal
Curses.close_screen
