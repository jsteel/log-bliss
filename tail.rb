class Tailer
  def get_more
    begin
      @input.read_nonblock(4096)
    rescue IO::EAGAINWaitReadable, EOFError
      # No input to read yet
      ""
    end
  end
end

class FileTail < Tailer
  def initialize(file)
    @input = File.open(file, "r")
  end

  def get_previous(go_back_count)
    stats = @input.stat
    buf_size = stats.blksize
    @input.seek(0, File::SEEK_END)

    buffer = ""

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

    buffer
  end
end

class PipeTail < Tailer
  def initialize
    @input = $stdin.clone
    fd = IO.sysopen('/dev/tty', 'r')
    $stdin.reopen(IO.new(fd))
  end
end
