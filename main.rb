# -*- coding: utf-8 -*-
require "twitter"
require 'sqlite3'
dir = File.expand_path("../",__FILE__)
require "#{dir}/LoadKey.rb"
require "#{dir}/MeCabInterface.rb"
require "#{dir}/EasyCSV.rb"

keys = LoadKey.new()
keys.set("#{dir}/Key")

con_key = keys[0]
con_sec = keys[1] 
acc_tok = keys[2]
acc_tok_sec = keys[3]

dbFilename = dir + "/guns.db"

sqdb = Object.new

if(File.exist?(dbFilename)) then
	sqdb = SQLite3::Database.new(dbFilename)
else
	sqdb = SQLite3::Database.new(dbFilename)

    sqdb.transaction do
        for i in 0..2 do	
sql = <<SQL
    create table Burst#{i} (
        day varchar(20),
		time varchar(40),
		chara  varchar(40),
		wp varchar(20),
		rank varchar(20),
		position varchar(20),
		other varchar(100),
		TwID varchar(30)
	);
SQL
	        sqdb.execute(sql)
        end

sql = <<SQL
    create table BurstN (
        day varchar(20),
		time varchar(40),
		chara  varchar(40),
		wp varchar(20),
		rank varchar(20),
		position varchar(20),
		other varchar(100),
		TwID varchar(30)
	);
SQL
	    sqdb.execute(sql)
    end
end

rest = Twitter::REST::Client.new do |c|
	c.consumer_key = con_key
	c.consumer_secret = con_sec
	c.access_token = acc_tok
	c.access_token_secret = acc_tok_sec
end

stream = Twitter::Streaming::Client.new do |c|
	c.consumer_key = con_key
	c.consumer_secret = con_sec
	c.access_token = acc_tok
	c.access_token_secret = acc_tok_sec
end

mecabarg = "-u " + `ls #{dir}/mecabDIC/*.dic`.gsub("\n",",").chop
mecab = MeCabInterface.new(mecabarg)
csv = EasyCSV.new()

#puts "Client Setup finished"

topics = ["#ガンスト3遠距離バースト"]
#topics = ["#bunkai_bot_test"]

begin

stream.filter(track: topics.join(",")) do |tweet|
    if tweet.is_a?(Twitter::Tweet) then
#        if (!tweet.retweeted_tweet? && !(tweet.reply?)) then
	if(!tweet.retweeted_tweet? && tweet.text.index('@') != 0) then
#	if(tweet.text.index("RT") != 0) then
#           puts tweet.text

            rest.retweet(tweet.id)
		
            text = String.new(tweet.text)
	
		    if(tweet.entities?) then
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
            end

            text.tr!('０-９ ａ-ｚ Ａ-Ｚ','0-9 a-z A-Z')
            text = text.gsub("'","''").gsub("\n","").gsub("\\","\\\\\\").gsub("_","$_").gsub("%","$%")
            
            hash = {:day => "",:time => "",:chara => "",:wp => "",:rank => "",:position => "",:other => ""}
            
            n = mecab.parse(text)

		    while n do
			    fe = csv.parse(n.feature)
			    if(fe[1] == "ガンスト名詞") then
                    case fe[2]
                    when "日時" then
                        case fe[3]
                        when "代名詞","月","日" then
                            hash[:day] << fe.last
                        when "時間","月日" then
                            hash[:time] << (fe.last + ",")
                        else
                            hash[:other] << n.surface
                        end

                    when "キャラクター名" then
                        if(csv.parse(n.prev.feature)[1] == "数") then
                            hash[:chara] << (n.prev.surface + fe.last + ",")
                        else
                            hash[:chara] << (fe.last + ",")
                        end

                    when "WP名" then
                        if(csv.parse(n.prev.feature)[1] == "数") then
                            hash[:wp] << (n.prev.surface + fe.last + ",")
                        else
                            hash[:wp] << (fe.last + ",")
                        end

                    when "ランク" then
                        if(csv.parse(n.next.feature)[2] == "ランク") then
                            hash[:rank] << (fe.last)
                        else
                            hash[:rank] << (fe.last + ",")
                        end

                    when "ポジション" then
                        hash[:position] << (fe.last + ",")
                    else
			hash[:other] << n.surface
		    end
                else
                    hash[:other] << n.surface
                end
                n = n.next
            end
		
            hash.each_key {|key| hash[key].chomp!(",")}

#            print "day:\t",hash[:day],"\n"
#            print "time:\t",hash[:time],"\n"
#            print "chara:\t",hash[:chara],"\n"
#            print "wp:\t",hash[:wp],"\n"
#            print "rank:\t",hash[:rank],"\n"
#            print "pos:\t",hash[:position],"\n"
#            print "other:\t",hash[:other],"\n"
		    
            num = []
            hd = hash[:day]
            num << "0" if(hd.include?("本日") || hd.include?("今日") || hd.include?("今から") || hd == "" )
            num << "1" if(hd.include?("明日"))
            num << "2" if (hd.include?("明後日"))
            num << "N" if(num.empty?)
            
        sqdb.transaction do
        for j in 0..(num.size - 1)
            sql = "insert into Burst#{num[j]} values ('#{hash[:day]}','#{hash[:time]}','#{hash[:chara]}','#{hash[:wp]}','#{hash[:rank]}','#{hash[:position]}','#{hash[:other]}','#{tweet.id}');"
            
#            puts sql
            sqdb.execute(sql)
        end
        end

	    end
    end
end

rescue Exception => e
	if (e.message =~ /execution expired/) || (e.message =~/end of file reached/)
		sleep 5
		retry
	end
		
	sqdb.close
	t = Time.new
	s = t.to_s + "-main" + ": " + e.class.to_s + "-" + e.message
	err = ""
	eb = e.backtrace
	for i in 0..(eb.size - 1)
		err << "\t" + eb[i] + "\n"
	end
	fp = File.open("#{dir}/errlog-main.txt","a")
	fp.puts s
	fp.puts err
	fp.close
#rescue Interrupt, SignalException => e
#	sqdb.close
#	s = e.to_s
#	s = `date -I`.chomp + "-main: " + s
#	system("echo '#{s}' >> #{dir}/errlog.txt")
#	puts "End Program"
end

