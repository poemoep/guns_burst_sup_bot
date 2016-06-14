require 'MeCab'
class MeCabInterface 
	
	def initialize(str = "")
		@model = MeCab::Model.new(str)
		@tagger =  @model.createTagger()
	end

	def parse(str = "")
		 return @tagger.parseToNode(str)
	end

end

