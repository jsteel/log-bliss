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
# Key for full screen
# Print line at bottom with key legend
# TODO Ctrl-C signal handler

# LATER
# Button for line wrapping
# Handle requests that don't have a uuid
# Handle stack traces
# Collapse columns of the input by pressing 1, 2, 3.
# Colored output
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

@log = File.open("/tmp/log", "w+")

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
    @input.seek(-buf_size, File::SEEK_CUR)
  end
end

def init
  @currently_selected = 0
  @requests_first = 0
  @requests_current = 0
  @requests_last = 0

  @requests_scrolling = true

  @requests = {}
  @request_queue = []
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
    log("req #{@requests_current}, #{@requests_first}, #{@requests_last}")
    @requests_current = [@requests_current + 1, @requests.length].min
    if @requests_current > @requests_last
      @requests_last = @requests_current
      @requests_first += 1
      log("slide down")
    end
    log("ref #{@requests_current}, #{@requests_first}, #{@requests_last}")
    @redraw = true
  when 'k'
    @requests_current = [@requests_current - 1, 0].max
    log("req #{@requests_current}, #{@requests_first}, #{@requests_last}")
    if @requests_current < @requests_first
      @requests_first = @requests_current
      @requests_last -= 1
      log("slide up")
    end
    log("ref #{@requests_current}, #{@requests_first}, #{@requests_last}")
    @redraw = true
  when 'i'
    # Prevent scrolling on the top window
    @requests_scrolling = !@requests_scrolling

    if @requests_scrolling
      @requests_last = @requests.length
      @requests_current = @requests_last
      @requests_first = [0, @requests_last - win.maxy].max
    end
  when 'c'
    init
    @redraw = true
  when 'q'
    exit 0
  when 'p'
    sleep 10
  end
end

def handle_lines(raw_input, win)
  raw_input.gsub!(/\e\[\d+m/, '')

  while true
    line, sep, raw_input = raw_input.partition("\n")

    # If no match, then line contains the rest
    return line if raw_input.empty? && sep.empty?

    handle_line(line, win)

    return line if raw_input.empty?
  end
end

def handle_line(line, win)
  # Remove ansi shell colors
  line.gsub!(/\e\[\d+m/, '')

  return if line.empty?

  match = line.match(/(\[\d\d:\d\d:\d\d\.\d\d\d\]) (\[request_uuid:[\w-]+\])\W+(.*)/)

  if match
    uuid = match[2]
    if @requests[uuid].nil?
      @request_queue << uuid
      @requests[uuid] = []

      if @requests_scrolling
        @requests_last += 1
        if @requests_last - @requests_first > win.maxy
          log "#{@requests_first}, #{@requests_last}, #{@requests_current}"
          @requests_first += 1
          @requests_current = [@requests_current, @requests_first].max
        end
      end
    end
    @requests[uuid] << line
    @redraw = true
  end
end

def redraw(win)
  return unless @redraw

  win.attron(Curses.color_pair(1))
  (@requests_first..[@requests_last, @request_queue.length].min).each_with_index do |line_index, i|
    request = @request_queue[line_index]
    next unless request
    if line_index == @requests_current
      win.attron(Curses.color_pair(2))
    else
      win.attron(Curses.color_pair(1))
    end
    lines = @requests[request]
    # TODO This is super inefficient. Cache it.
    first_line = lines.find { |line| line =~ /Processing/ } || lines.first

    win.setpos(i, 0)
    win.addstr(first_line[0..win.maxx - 1])
    win.clrtoeol()
  end

  win.setpos(win.cury + 1, 0)
  (win.maxy - win.cury - 1).times { win.deleteln }

  win.refresh
end

def draw_request(win)
  selected_request = @request_queue.last(win.maxy)[@currently_selected]
  lines = @requests[selected_request]
  return if !lines
  lines[0..win.maxy].each_with_index do |line, i|
    win.attron(Curses.color_pair(1))
    win.setpos(i, 0)
    win.addstr(line[0..win.maxx - 1])
    win.clrtoeol()
  end

  (win.maxy - 2 - win.cury).times { win.deleteln }

  win.refresh
end

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

init

Curses.start_color
Curses.curs_set(0) # Hide the cursor
Curses.noecho # Do not echo characters typed by the user

# List of colors: https://en.wikipedia.org/wiki/ANSI_escape_code#Colors
Curses.init_pair(1, 15, 0)
Curses.init_pair(2, 0, 15)

@redraw = true

raw_input = ""

while true
  begin
    raw_input += @input.read_nonblock(100)
  rescue IO::EAGAINWaitReadable, EOFError
    # No input to read yet
  end
  raw_input = handle_lines(raw_input, win)
  get_input(win)
  redraw(win)
  draw_request(win2)
  @redraw = false
end

# Reset the terminal
Curses.close_screen
