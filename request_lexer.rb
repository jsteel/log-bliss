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
      if scanner.scan(/(\W)*\[(request_uuid:[\w-]+)?\]/)
        tokens << [:content, scanner.captures.first] if scanner.captures.first
        tokens << [:request_uuid, scanner.captures.last]
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

  def initialize(lines, width = Float::INFINITY)
    @lines = lines.collect { |line| RequestLexer.new(line).tokens }
    @lines[0].unshift([:cursor, nil]) unless @lines.empty?
    @width = width

    @lines.each_with_index do |line, i|
      line.each do |token|
        token[3] = i
      end
    end

    @columns_collapsed = []

    tokens_from_lines
    add_token_lengths(@tokens)
    fit_width
  end

  def add_line(raw_line)
    line = tokens_from_raw_line(raw_line)
    last_line = @lines[-1]

    if last_line
      last_token = last_line[-1]
      last_line_num = last_token[3] + 1
    else
      last_line_num = 0
      line.unshift([:cursor, nil])
    end

    line.each do |token|
      token[3] = last_line_num
    end

    add_token_lengths(line)
    lines << line
    tokens_from_lines
    fit_width
  end

  def replace_line(request_uuid, raw_line)
    request_uuid =~ /(request_uuid:[\w-]+)/
    request_uuid = $1

    new_line = tokens_from_raw_line(raw_line)

    @lines.each_with_index do |line, i|
      line.each do |token|
        if token[0] == :request_uuid && token[1] == request_uuid
          if cursor = line.find { |token| token[0] == :cursor }
            new_line.unshift(cursor)
          end
          # Add the line number
          new_line.each do |new_token|
            new_token[3] = token[3]
          end
          @lines[i] = new_line
          return
        end
      end
    end
  end

  def new_width(width)
    @width = width
    tokens_from_lines
    fit_width
  end

  def move_cursor(new_position)
    cursor = nil

    @lines.each do |line|
      line.each do |token|
        cursor = token if token[0] == :cursor
        line.delete(cursor)
      end
    end

    return unless cursor

    line = @lines[new_position]
    cursor[3] = line[0][3]
    line.unshift(cursor)
  end

  def cursor_parent_line_number
    @lines.each do |line|
      line.each do |token|
        return token[3] if token[0] == :cursor
      end
    end

    nil
  end

  def cursor_line_number
    @lines.each_with_index do |line, line_number|
      line.each do |token|
        return line_number if token[0] == :cursor
      end
    end

    nil
  end

  def toggle_column(column_num, collumn_collapsed)
    @columns_collapsed[column_num] = collumn_collapsed
    new_width(@width)
  end

  private

  def add_token_lengths(tokens)
    # Add the length to each token
    tokens.each do |token|
      token[2] =
        case token[0]
        when :content
          token[1].length
        when :timestamp
          @columns_collapsed[1] ? 2 : token[1].length
        when :request_uuid
          @columns_collapsed[2] ? 2 : token[1].length
        when :color, :cursor
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

    return if @tokens.empty?

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
      elsif token[2] > 0 && cur_line_spare_room == 0
        cur_line = []
        cur_line_spare_room = @width
        @lines << cur_line
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
    end
  end

  def tokens_from_raw_line(raw_line)
    new_line = RequestLexer.new(raw_line).tokens
    add_token_lengths(new_line)
  end
end
