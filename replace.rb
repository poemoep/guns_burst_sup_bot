require 'sqlite3'

#key: 移動させたい関連ワード
#hash[key] : 移動先
list = Hash.new("N")
list = {"本日" => "0"}

db = SQLite3::Database.new(File.expand_path("../guns.db",__FILE__))

t = Time.new

db.transaction do
    for i in 0..2
	day = (t + (24 * 60 * 60 * i)).day
        sql = "insert into Burst#{i} select * from BurstN where day like '%#{day.to_s + "日"}%' escape '$';"
        db.execute(sql)
        sql = "delete from BurstN where day like '%#{day.to_s + "日"}%' escape '$';"
        db.execute(sql)
    end


    list.each_key do |key|
        sql = "insert into Burst#{list[key]} select * from BurstN where day like '%#{key}%' escape '$';"
        db.execute(sql)
        sql = "delete from BurstN where day like '%#{key}%' escape '$';"
        db.execute(sql)
    end
end
