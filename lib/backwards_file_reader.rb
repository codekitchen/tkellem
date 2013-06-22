class BackwardsFileReader
	def self.scan(stream)
		scanner = new(stream)
		while line = scanner.readline
			break unless yield(line)
		end
		scanner.sync
	end

	def initialize(stream)
		@stream = stream
		@stream.seek 0, IO::SEEK_END
		@pos = @stream.pos
		@offset = 0

		@read_size = [4096, @pos].min
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

		@pos -= @read_size
		@stream.seek(@pos, IO::SEEK_SET)
		@offset = 0

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
