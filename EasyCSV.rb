class EasyCSV 

	def parse(str = "")
		temp = ""
		array = Array.new()
		for i in 0..str.size
			if (str[i] == ',' || i == str.size) then
				array << temp
				temp = ""
			else
				temp = temp + str[i].to_s
			end
		end

		return array
	end
end
