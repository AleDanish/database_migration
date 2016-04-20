#!/bin/bash 
Tstart=$(date +%s%6N)

if [ "$1" == "" ]; then
   oldfloatingip=$(<../influxdb_oldip)
else oldfloatingip=$1
fi
echo $oldfloatingip

#remove old archive if present
sudo rm /home/ubuntu/influxdb.backup.tar.gz

#send data
Tmove_start=$(date +%s%6N)
ssh -oStrictHostKeyChecking=no -i /home/ubuntu/key/mcn-key.pem ubuntu@$oldfloatingip 'cd /var/lib/influxdb; sudo tar zcf - data hh wal meta' > /home/ubuntu/influxdb.backup.tar.gz
Tmove_end=$(date +%s%6N)

#get databases
Tdelete_start=$(date +%s%6N)

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

Ttest_start=$(date +%s%6N)
#TODO: to remove, only for test purpose!
#$curl -i -XPOST "http://"$oldfloatingip":8086/write?db=a3" --data-binary "table3,host=server02,region=us-est value=10.01 1334055561000000000"
#$curl -i -XPOST "http://"$oldfloatingip":8086/write?db=a3" --data-binary "table3,host=server03,region=us-est value=10.01 1334055562000000000"
#$curl -i -XPOST "http://"$oldfloatingip":8086/write?db=a4" --data-binary "table4,host=server02,region=us-est value=10.01 1334055561000000000"
#$curl -i -XPOST "http://"$oldfloatingip":8086/write?db=a4" --data-binary "table3,host=server02,region=us-est value=20.02 1334055562000000000"
#$curl -i -XPOST "http://"$oldfloatingip":8086/write?db=a5" --data-binary "table3,host=server02,region=us-est value=30.03 1334055512000000000"
#$curl -i -XPOST "http://"$oldfloatingip":8086/write?db=a5" --data-binary "table4,host=server03,region=us-est value=30.03 1334055511000000000"
Ttest_end=$(date +%s%6N)

fi
done
Tdelete_end=$(date +%s%6N)

#remove data folders
echo "cancello i dati"
sudo rm -rf /var/lib/influxdb/*

#extract data
Textract_start=$(date +%s%6N)
echo "estraggo i dati"
sudo tar -zxf /home/ubuntu/influxdb.backup.tar.gz -C /var/lib/influxdb
Textract_end=$(date +%s%6N)

#restart database
Trestart_start=$(date +%s%6N)
echo "database restart"
sudo service influxdb restart
Trestart_end=$(date +%s%6N)

Tdbunaval_start=$(date +%s%6N)
for database in  ${dbs[@]}; do
echo "database1: "$database
while true; do
sudo rm error.txt
$curl -G "http://localhost:8086/query" --data-urlencode "db="$database --data-urlencode  "q=show measurements" 2>>error.txt
error=$(<error.txt)
if [[ $error == *"curl: (7) Failed to connect to"* ]]; then
echo "Database not available"
sudo rm error.txt
sleep 2
else
echo "Database ready"
sudo rm error.txt
break
fi
done
Tdbunaval_end=$(date +%s%6N)

Tmeasurements_start=$(date +%s%6N)
measurements=$($curl -G "http://"$oldfloatingip":8086/query" --data-urlencode "db="$database --data-urlencode  "q=show measurements")
tables=$(python - << END
try:
    measures = $measurements["results"][0]["series"][0]["values"]
    str = ""
    for i in measures:
        str += i[0] + ","
    print str
except KeyError:
    pass
END)
echo "measurements prova: " $measurements
echo "tables prova: "$tables
Tmeasurements_end=$(date +%s%6N)

if [[ "$tables" == "" ]]; then
echo "No new data found for database "$database
else
for table_raw in $tables; do
set -- "$table_raw"
IFS=","; declare -a Array=($*)
table="${Array[0]}"
echo "table parse: " $table
if [[ "$table" != *"["* ]] && [[ "$table" != *"]"* ]]; then
echo "database2: "$database
echo "table2: " $table

#get data newer of the timestamp
file_name="newerdata_"$database"_"$table
file_name_json=$file_name".json"
file_name_txt=$file_name".txt"

Tselectnewdata_start=$(date +%s%6N)
$curl -o $file_name_json -G 'http://'$oldfloatingip':8086/query' --data-urlencode "db="$database --data-urlencode "q=SELECT * FROM $table"
python convertInfluxDB_JsonToTxt.py $file_name_json
Tselectnewdata_end=$(date +%s%6N)

Tinsertnewdata_start=$(date +%s%6N)
$curl -i -XPOST 'http://localhost:8086/write?db='$database --data-binary '@'$file_name_txt
Tinsertnewdata_end=$(date +%s%6N)
sudo rm $file_name_json $file_name_txt
fi
done
fi
done
Tend=$(date +%s%6N)

Tmove=$(((Tmove_end-Tmove_start)/1000))
Textract=$(((Textract_end-Textract_start)/1000))
Trestart=$(((Trestart_end-Trestart_start)/1000))
Tdelete=$(((Tdelete_end-Tdelete_start)/1000))
Tdbunaval=$(((Tdbunaval_end-Tdbunaval_start)/1000))
Tmeasurements=$(((Tmeasurements_end-Tmeasurements_start)/1000))
Tselectnewdata=$(((Tselectnewdata_end-Tselectnewdata_start)/1000))
Tinsertnewdata=$(((Tinsertnewdata_end-Tinsertnewdata_start)/1000))
Ttotal=$(((Tend-Tstart)/1000))

Ttest=$(((Ttest_end-Ttest_start)/1000))

sudo rm /home/ubuntu/times_influxdb
sudo echo "Time to move data: " $Tmove >> /home/ubuntu/times_influxdb
sudo echo "Time to extract data: " $Textract >> /home/ubuntu/times_influxdb
sudo echo "Time to restart data: " $Trestart >> /home/ubuntu/times_influxdb
sudo echo "Time to delete data: " $Tdelete >> /home/ubuntu/times_influxdb
sudo echo "Time db unavailability: " $Tdbunaval >> /home/ubuntu/times_influxdb
sudo echo "Time to get measurements data: " $Tmeasurements >> /home/ubuntu/times_influxdb
sudo echo "Time to select the new records: " $Tselectnewdata >> /home/ubuntu/times_influxdb
sudo echo "Time to insert the new records: " $Tinsertnewdata >> /home/ubuntu/times_influxdb
sudo echo "Time total: " $Ttotal >> /home/ubuntu/times_influxdb
sudo echo "Time to insert the test record: " $Ttest >> /home/ubuntu/times_influxdb
