#!/bin/bash 
Tstart=$(date +%s%6N)

if [ "$1" == "" ]; then
   oldfloatingip=$(<../influxdb_oldip)
else oldfloatingip=$1
fi
echo $oldfloatingip

#remove old archive if present
#sudo rm /home/ubuntu/influxdb.backup.tar.gz

timestamp=$(date +%s)
timestamp='1132005588999700000'

#send data
Tmove_start=$(date +%s%6N)
#ssh -oStrictHostKeyChecking=no -i /home/ubuntu/key/mcn-key.pem ubuntu@$oldfloatingip 'cd /var/lib/influxdb; sudo tar zcf - data hh wal meta' > /home/ubuntu/influxdb.backup.tar.gz
Tmove_end=$(date +%s%6N)

#get databases
databases_json=$(curl -G "http://"$oldfloatingip":8086/query" --data-urlencode  "q=show databases")
databases=$(python - << END 
print $databases_json["results"][0]["series"][0]["values"] 
END)

curl='/usr/bin/curl'
dbs=()
#delete and recreate all databases
for database_row in $databases; do
set -- "$database_row" 
IFS="'"; declare -a Array=($*)
database="${Array[1]}"
if [[ "$database" != "_internal" ]]; then
echo "cancello database: "$database
dbs=(${dbs[@]} $database)
query="q=drop database "$database
$curl -G "http://"$oldfloatingip":8086/query" --data-urlencode  "$query"
query="q=create database "$database
$curl -G "http://"$oldfloatingip":8086/query" --data-urlencode  "$query"
fi
done

#remove data folders
echo "cancello i dati"
#sudo rm -rf /var/lib/influxdb/*

#extract data
Textract_start=$(date +%s%6N)
echo "estraggo i dati"
#sudo tar -zxf /home/ubuntu/influxdb.backup.tar.gz -C /var/lib/influxdb
Textract_end=$(date +%s%6N)

#restart database
Trestart_start=$(date +%s%6N)
echo "database restart"
#sudo service influxdb restart
Trestart_end=$(date +%s%6N)

sleep 30
#dbs=('mydb')
for database in  ${dbs[@]}; do
echo db: $database

while true; do
sudo rm error.txt
#measurements=$(curl -G "http://"$oldfloatingip":8086/query" --data-urlencode "db="$database --data-urlencode  "q=show measurements")>> error.txt
#var=$( { $curl -G "http://"$oldfloatingip":8086/query" --data-urlencode "db="$database --data-urlencode  "q=show measurements"; } 2>&1 )
measurements=$($curl -G "http://"$oldfloatingip":8086/query" --data-urlencode "db="$database --data-urlencode  "q=show measurements" 2>>error.txt)
error=$(<error.txt)
echo "measurements: " $measurements
echo "error: " $error
if [[ "$measurements" == "" ]] && [[ $error == *"curl: (7) Failed to connect to"* ]]; then
echo "Database not available"
sleep 5
else
echo "Database ready"
break
fi
done

tables=$(python - << END 
try:
    print $measurements["results"][0]["series"][0]["values"]
except KeyError:
    pass
END)
echo "tables: " $tables
if [[ "$tables" == "" ]]; then
    echo "No new data found for database "$database
else
for table_raw in $tables; do
set -- "$table_raw"
IFS=" "; declare -a Array=($*)
table="${Array[0]}"
if [[ "$table" != *"["* ]] && [[ "$table" != *"]"* ]]; then
echo $table

#get data newer of the timestamp
file_name="newerdata_"$database"_"$table
file_name_json=$file_name".json"
file_name_txt=$file_name".txt"
$curl -o $file_name_json -G 'http://'$oldfloatingip':8086/query' --data-urlencode "db="$database --data-urlencode "q=SELECT * FROM $table"
python convertInfluxDB_JsonToTxt.py $file_name_json

$curl -i -XPOST 'http://'$oldfloatingip':8086/write?db='$database --data-binary '@'$file_name_txt
#$curl -i -XPOST 'http://localhost:8086/write?db='$database --data-binary '@'$file_name_txt
#sudo rm $file_name_json $file_name_txt
fi
done
fi
done
Tend=$(date +%s%6N)

Tmove=$(((Tmove_end-Tmove_start)/1000))
Textract=$(((Textract_end-Textract_start)/1000))
Trestart=$(((Trestart_end-Trestart_start)/1000))
Ttotal=$(((Tend-Tstart)/1000))

#sudo rm /home/ubuntu/times_influxdb
#sudo echo "Time to move data: " $Tmove >> /home/ubuntu/times_influxdb
#sudo echo "Time to extract data: " $Textract >> /home/ubuntu/times_influxdb
#sudo echo "Time to restart data: " $Trestart >> /home/ubuntu/times_influxdb
#sudo echo "Time total: " $Ttotal >> /home/ubuntu/times_influxdb
