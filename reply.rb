require 'twitter'
require 'sqlite3'
dir = File.expand_path("../",__FILE__)
require "#{dir}/LoadKey.rb"
require "#{dir}/MeCabInterface.rb"
require "#{dir}/EasyCSV.rb"

l = LoadKey.new
l.set("#{dir}/Key")

db = SQLite3::Database.new("#{dir}/guns.db")

rest = Twitter::REST::Client.new do |c|
    c.consumer_key = l.consumer_key
    c.consumer_secret = l.consumer_secret
    c.access_token = l.access_token
    c.access_token_secret = l.access_token_secret
end

stream = Twitter::Streaming::Client.new do |c|
    c.consumer_key = l.consumer_key
    c.consumer_secret = l.consumer_secret
    c.access_token = l.access_token
    c.access_token_secret = l.access_token_secret
end

mecabarg ="-u " + `ls #{dir}/mecabDIC/*.dic`.gsub("\n",",").chop
mecab = MeCabInterface.new(mecabarg)
csv = EasyCSV.new()

#puts "Client setup finished"

#dbClose
begin
stream.user do |obj|
#    puts obj.class
    if (obj.is_a?(Twitter::Tweet)) then
#        puts obj.text
        
        if(obj.text.index("@guns_burst_sup") == 0) then
            text = String.new(obj.text)
            tweet = obj
            if(tweet.hashtags?) then
                for j in 0..(tweet.hashtags.size - 1)
                    text.slice!("#"+ tweet.hashtags[j].text)
                end
            end
            if(tweet.user_mentions?)
                for j in 0..(tweet.user_mentions.size - 1)
                    text.slice!("@" + tweet.user_mentions[j].screen_name)
                end
            end
        
            text.tr!('０-９ ａ-ｚ Ａ-Ｚ','0-9 a-z A-Z')
            text = text.gsub("'","''").gsub("\n","").gsub("\\","\\\\\\").gsub("_","$_").gsub("%","$%")
            
            n = mecab.parse(text)

            hash = {:day => [],:time => [], :chara => [],:wp  => [],:rank  => [],:position => [],:other  => []}
            
            while n do
                if(n.surface == "," || n.surface == "") then
                    n = n.next
                    next
                end
                fe = csv.parse(n.feature)
                    if(fe[1] == "ガンスト名詞") then
                        case fe[2]
                        when "日時" then
                            case fe[3]
                            when "代名詞","月","日","月日" then
                                hash[:day] << fe.last
                            when "時間" then
                                hash[:time] << fe.last
                            else
                                hash[:other] << n.surface
                            end

                        when "キャラクター名" then
                            if(csv.parse(n.prev.feature)[1] == "数") then
                                hash[:chara] << n.prev.surface + fe.last
                            else
                                hash[:chara] << fe.last
                            end

                        when "WP名" then
                            if(csv.parse(n.prev.feature)[1] == "数") then
                                hash[:wp] << n.prev.surface + fe.last
                            else
                                hash[:wp] << fe.last
                            end

                        when "ランク" then
                            hash[:rank] << fe.last
    
                        when "ポジション" then
                            hash[:position] << fe.last
                        else
			                hash[:other] << n.surface
		                end
                    else
                        hash[:other] << n.surface
                    end
                n = n.next
            #while End
            end
            num = []
            if(hash[:day].size == 0) then
                num = ["0","1","2","N"]
            else

                for j in 0..(hash[:day].size - 1)
                    case hash[:day][j].to_s
                    when "本日","今から","今日" then
                        num << "0"
                    when "明日" then
                        num << "1"
                    when "明後日" then
                        num << "2"
                    when "" then
                        break
                    else
                        num << "N"
                    end
                end
            end
#            puts num

            listID = Hash.new(0)
	    result = []
            hash.each_key do |key| 
#                print key,"\t=>\t",hash[key],"\n"
                if(key != :day) then
                    for i in 0..(num.size - 1)
                        for j in 0..(hash[key].size - 1)
                            sql = "select TwID from Burst#{num[i]} where #{key} like '%#{hash[key][j]}%' escape '$';"
#                            puts sql
                            result = db.execute(sql)
#                            puts result
                            for k in 0..(result.size - 1)
                                listID[result[k][0].to_s] += 1
                            end
                        end
                    end
                else
		    for j in 0..(hash[key].size - 1)
                        sql = "select TwID from BurstN where #{key} like '%#{hash[key][j]}%' escape '$';"
			result = db.execute(sql)
			for k in 0..(result.size - 1)
				listID[result[k][0].to_s] += 1
			end
		    end
		end                        
            end

            if(listID.empty?) then
                for i in 0..(num.size - 1)
                    sql = "select TwID from Burst#{num[i]};"
                    result = db.execute(sql)
                    for k in 0..(result.size - 1)
                        listID[result[k][0].to_s] += 1
                    end
                end
            end
            

            ids =  listID.sort {|a,b| a[1] <=> b[1]}.reverse
#            puts ids.to_s
            updateString = ""
            returnMaxNum = 5
            j = 0
            while j < ids.size  && returnMaxNum > 0 do
                tempArray = []
                endpoint = nil
                for k in j..(ids.size - 1)
#                    print j,"\t",k,"\n"
                    if(!(ids[j][1].to_i == ids[k][1].to_i)) then
                        endpoint = k - 1
                        break
                    end
                end
#                puts "end search"
#                print j,"\t",endpoint,"\n"
                endpoint = ids.size - 1 if (endpoint == nil) 
                for l in j..endpoint
                          tempArray << ids[l]
                end
                
                tempArray = tempArray.sample(returnMaxNum)
                break if(tempArray.empty?)

                for l in 0..(tempArray.size - 1)
                begin
#                    puts tempArray[l][0].to_s
                    searched_tweet = rest.status(tempArray[l][0].to_s)
                rescue
#                    puts searched_tweet
                    next
                end
                    returnMaxNum = returnMaxNum - 1

#                    puts searched_tweet.url
                    updateString << (searched_tweet.url.to_s + " \n")
                    break if(returnMaxNum == 0)
                end
                
                j = endpoint + 1
            end
            updateString = "該当するツイートがありません。"if (updateString.empty?)
            myID = "@#{tweet.user.screen_name.to_s} \n"
	    if(updateString.size + myID.size > 140) then
		    tempArr = updateString.split("\n")
		    str = ""
		    for i in 0..(tempArr.size - 2)
                        str << (tempArr[i].to_s + "\n")
                    end
                    updateString = String.new(str)
	    end
	    updateString = myID + updateString
#            puts updateString
	rest.update(updateString,{:in_reply_to_status_id => tweet.id})
        #reply End    
        end 

    #is_a? End0
    end

#user End
end

rescue Exception => e
	if (e.message =~ /execution expired/) || (e.message =~ /end of file reached/)
		sleep 5
		retry
	end

	db.close
	t = Time.new
	s = t.to_s + "-reply" + ": " +  e.class.to_s + "-" + e.message
	err = ""
	eb = e.backtrace
	for i in 0..(eb.size - 1)
		err << "\t" + eb[i] + "\n"
	end
	fp = File.open("#{dir}/errlog-reply.txt","a")
	fp.puts s
	fp.puts err
	fp.close
#rescue Interrupt,SignalException => e
#	db.close
#	s = e.to_s
#	s = `date -I`.chomp + "-reply: " + s
#	system("echo '#{s}' >> #{dir}/errlog.txt")
end
