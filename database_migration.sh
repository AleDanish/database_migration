#!/bin/bash 
Tstart=$(date +%s%6N)

if [ "$1" == "" ]; then
   oldfloatingip=$(<../influxdb_oldip)
else oldfloatingip=$1
fi
echo $oldfloatingip

#remove old archive if present
#sudo rm /home/ubuntu/influxdb.backup.tar.gz

timestamp=$(date +%s%6N)

#send data
Tmove_start=$(date +%s%6N)
#ssh -oStrictHostKeyChecking=no -i /home/ubuntu/key/mcn-key.pem ubuntu@$oldfloatingip 'cd /var/lib/influxdb; sudo tar zcf - data hh wal meta' > /home/ubuntu/influxdb.backup.tar.gz
Tmove_end=$(date +%s%6N)

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

#get databases
databases_json=$(curl -G "http://localhost:8086/query" --data-urlencode  "q=show databases")
echo $databases_json
databases=$(python - << END 
print $databases_json["results"][0]["series"][0]["values"] 
END)
for database in $databases; do
set -- "$database" 
IFS="'"; declare -a Array=($*) 
db="${Array[1]}"
echo db: $db
measurements=$(curl -G "http://localhost:8086/query" --data-urlencode "db="$db --data-urlencode  "q=show measurements")
echo $measurements
#  query1="q=CREATE DATABASE "$database
#  address2="http://$1:8086/write?db="$database
#  $curl $args1 $address1 $options1 "$query1"
done


#get data newer of the timestamp
#sudo curl -o newerdata_migration.json -G 'http://'$oldfloatingip':8086/query' --data-urlencode "db=" --data-urlencode "q=SELECT * FROM  WHERE time>"$timestamp

#converti il file json in LineProtocol
#python convertInfluxDB_JsonToTxt.py newerdata_migration.json

#importa i dati
#curl -i -XPOST 'http://localhost:8086/write?db=mydb' --data-binary @newerdata_migration.txt

#restart servizio
#sudo service influxdb restart

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

