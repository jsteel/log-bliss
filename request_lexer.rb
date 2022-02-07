require 'strscan'

class RequestLexer
  attr_reader :tokens

  def initialize(request_data)
    @data = request_data

    @tokens = tokenize
  end

  private

  def tokenize
    scanner = StringScanner.new(@data)
    tokens = []

    if scanner.scan(/\[(\d\d:\d\d:\d\d\.\d\d\d)?\]/)
      tokens << [:timestamp, scanner.captures.first]
      if scanner.scan(/\W*\[(request_uuid:[\w-]+)?\]/)
        tokens << [:request_uuid, scanner.captures.first]
      end
    end

    line = scanner.rest

    # Pull out the colour codes from the rest of the content
    while line != ""
      line_part, sep, line = line.partition(/\e\[\dm(\e\[\d\d?m)?/)
      tokens << [:content, line_part]
      tokens << [:color, sep] unless sep.empty?
    end

    tokens
  end
end

class RequestTree
  attr_reader :lines

  def initialize(lines, width)
    @lines = lines
    @width = width

    @lines.each_with_index do |line, i|
      line.each do |token|
        token[3] = i
      end
    end

    tokens_from_lines
    add_token_lengths_and_line
    fit_width
  end

  def new_width(width)
    @width = width
    tokens_from_lines
    fit_width
  end

  private

  def add_token_lengths_and_line
    # Add the length to each token
    @tokens.each do |token|
      token[2] =
        case token[0]
        when :content, :timestamp, :request_uuid
          token[1].length
        when :color
          0
        end
    end
  end

  def tokens_from_lines
    @tokens = []

    @lines.each do |line|
      @tokens += line
    end
  end

  def fit_width
    @lines = []
    cur_line_spare_room = @width
    cur_line = []
    cur_line_index = 0
    @lines << cur_line

    until @tokens.empty?
      token = @tokens.shift

      # If we get to the next parent line, start a fresh new line
      if cur_line_index != token[3]
        cur_line = []
        cur_line_spare_room = @width
        @lines << cur_line
        cur_line_index = token[3]
      end

      if token[2] <= cur_line_spare_room
        cur_line << token
        cur_line_spare_room -= token[2]
      else
        token1 = [token[0], token[1][0...cur_line_spare_room], cur_line_spare_room, token[3]]
        cur_line << token1
        remaining = token[1][cur_line_spare_room..-1]
        token2 = [token[0], remaining, remaining.length, token[3]]
        @tokens.unshift(token2)
        cur_line_spare_room = 0
      end

      if cur_line_spare_room == 0
        cur_line = []
        cur_line_spare_room = @width
        @lines << cur_line
      end
    end
  end
end
