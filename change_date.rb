require 'sqlite3'
dir = File.expand_path("../",__FILE__)
dbname = dir + "/guns.db"
db = SQLite3::Database.new(dbname)



    sql = "drop table Burst0;"
    db.execute(sql)
    sql = "vacuum;"
    db.execute(sql)
    for i in 1..2
        sql="alter table Burst#{i} rename to Burst#{i - 1};"
        db.execute(sql)
    end

sql= <<SQL
    create table Burst2 (
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
    db.execute(sql)


db.close

