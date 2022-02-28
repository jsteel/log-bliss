class RequestQueue
  def initialize
    @requests = {}
    @request_queue = []
  end

  # Add the line to the appropriate request and return the requset uuid and
  # whether it's a new request
  def add_line(line)
    match = line.match(/\[\d\d:\d\d:\d\d\.\d\d\d\] (\[request_uuid:[\w-]+\])\W*.*/)

    if match
      uuid = match[1]
      @previous_uuid = uuid

      if @requests[uuid].nil?
        @request_queue << uuid
        @requests[uuid] = [line]

        return { request_uuid: uuid, new_request: true }
      end

      @requests[uuid] << line
    elsif @previous_uuid
      # TODO
      # append_line(@previous_uuid, line, win_manager.win.maxy, win_manager.win2&.maxy)
    end

    { request_uuid: uuid, new_request: false }
  end

  def lines_for_request(request_num)
    @requests[@request_queue[request_num]]
  end

  private

  def append_line
    # @requests[uuid][-1] += "\n#{line}"
  end
end
