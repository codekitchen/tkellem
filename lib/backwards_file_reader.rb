class BackwardsFileReader
  def self.scan(stream, *init_args)
    scanner = new(stream, *init_args)
    while line = scanner.readline
      break unless yield(line)
    end
    scanner.sync
  end

  DEFAULT_READ_SIZE = 4096

  def initialize(stream, read_size = DEFAULT_READ_SIZE)
    @stream = stream
    @stream.seek 0, IO::SEEK_END
    @pos = @stream.pos

    @read_size = [read_size, @pos].min
    @line_buffer = []
  end

  def readline
    while @line_buffer.size < 2 && @pos > 0
      @read_size = [@read_size, @pos].min
      @pos -= @read_size
      @stream.seek(@pos, IO::SEEK_SET)

      @line_buffer[0] = "#{@stream.read(@read_size)}#{@line_buffer[0]}"
      @line_buffer[0] = @line_buffer[0].scan(%r{.*\n})
      @line_buffer.flatten!
    end

    @line_buffer.pop
  end

  def sync
    offset = @read_size - @line_buffer.inject(0) { |n, l| n + l.size }
    @stream.seek(-offset, IO::SEEK_CUR) if offset != 0
    @stream
  end
end
