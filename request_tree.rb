require "./request_lexer"

class RequestTree
  attr_reader :lines

  def initialize(lines, width = Float::INFINITY)
    @raw_lines = lines
    @width = width

    setup
  end

  def add_line(raw_line)
    @raw_lines << raw_line

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

  # NOTE: This doesn't work at small sizes because the tokens have been broken up.
  # In order to do this, each line would have to know the uuid it's associated with.
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

    # Line is empty
    $logger.info("line is -- #{new_position} -- #{@lines.length} -- #{@lines} -- #{line}")
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

  def prev_line_number
    current_parent_line_num = nil
    num_lines_to_move = 0

    @lines.reverse.each_with_index do |line, line_number|
      num_lines_to_move += 1 if current_parent_line_num
      $logger.info("moving inc") if current_parent_line_num
      line.each do |token|
        if !current_parent_line_num
          if token[0] == :cursor
            current_parent_line_num = token[3]
            $logger.info("moving a #{token}")
          end
        else
          $logger.info("moving b #{token}")
          if token[3] != current_parent_line_num
            return num_lines_to_move
          end
        end
      end
    end

    return nil
  end

  def next_line_number
    current_parent_line_num = nil
    num_lines_to_move = 0

    @lines.each_with_index do |line, line_number|
      num_lines_to_move += 1 if current_parent_line_num
      $logger.info("moving inc") if current_parent_line_num
      line.each do |token|
        if !current_parent_line_num
          if token[0] == :cursor
            current_parent_line_num = token[3]
            $logger.info("moving a #{token}")
          end
        else
          $logger.info("moving b #{token}")
          if token[3] != current_parent_line_num
            return num_lines_to_move
          end
        end
      end
    end

    return nil
  end

  private

  def setup
    @lines = @raw_lines.collect { |line| RequestLexer.new(line).tokens }
    @lines[0].unshift([:cursor, nil]) unless @lines.empty?

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
