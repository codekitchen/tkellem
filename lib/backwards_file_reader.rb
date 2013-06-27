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
    @offset = 0

    @read_size = [read_size, @pos].min
    @line_buffer = []
  end

  def readline
    if @line_buffer.size > 2 || @pos == 0
      line = @line_buffer.pop
      if line
        @offset += line.length
      end
      return line
    end

    @read_size = [@read_size, @pos].min
    @pos -= @read_size
    @stream.seek(@pos, IO::SEEK_SET)
    @offset = -@line_buffer.reduce(0) { |n,l| n + l.length }

    @line_buffer[0] = "#{@stream.read(@read_size)}#{@line_buffer[0]}"
    @line_buffer[0] = @line_buffer[0].scan(%r{.*\n})
    @line_buffer.flatten!

    readline
  end

  def sync
    if @offset > 0
      @stream.seek(-@offset, IO::SEEK_CUR)
    end
    @offset = 0
    @stream
  end
end
