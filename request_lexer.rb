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
