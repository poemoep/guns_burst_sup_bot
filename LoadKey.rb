class LoadKey < Array
	def initialize()
		super()
		@filepath = String.new()
	end

	def set(str = "")
		@filepath = String.new(str)
		File::open(@filepath,"r") { |f|
			f.each { |line| self << line.chomp}
		}
	end
	
	def consumer_key
		return self[0]
	end

	def consumer_secret
		return self[1]
	end

	def access_token
		return self[2]
	end

	def access_token_secret
		return self[3]
	end
end
