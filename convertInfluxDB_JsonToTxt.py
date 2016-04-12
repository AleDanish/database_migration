#     Author: Alessandro Zanni
#     URL: https://github.com/AleDanish

import json
import sys
from time import mktime
import datetime

def getFileData(file_name):
    try:
        with open(file_name) as myfile:
            return myfile.read()
    except IOError:
        print "The specified file doesn't exists. Check the Json file"
        sys.exit(1)

def parseJson(data):
    tables_name=[]
    values=[]
    columns=[]
    for key1, val1 in data.iteritems(): # results object
        for key2, val2 in val1[0].iteritems(): # series object
            for val2_iter in val2:
                for key3, val3 in val2_iter.iteritems(): # values object
                    if key3 == 'name':
                        tables_name.append(val3)
                    elif key3 == 'values':
                        values.append(val3)
                    elif key3 == 'columns':
                        columns.append(val3)
    return tables_name, values, columns

def getJsonData(file_name):
    data_raw=json.loads(getFileData(file_name))
    tables_name, data, columns=parseJson(data_raw)
    if len(tables_name) == 0 or len(data) == 0  or len(columns) == 0:
        print "No table or data found. Check the Json file specified."
        sys.exit(1)
    if len(tables_name) != len (data) or len(tables_name) != len(columns):
        print "Incorrect parse. Check the Json file specified."
        sys.exit(1)
    return tables_name, data, columns

def timedateToTimestamp(date_time):
    print repr(date_time)
    dt=date_time.split('T')
    date=dt[0].split('-')
    year=int(date[0])
    month=int(date[1])
    day=int(date[2])
    time=dt[1].split('Z')[0].split(':')
    hours=int(time[0])
    minutes=int(time[1])
    sec=time[2].split('.')
    seconds=int(sec[0])
    timestamp=str(int(mktime(datetime.datetime(year, month, day, hours, minutes, seconds).timetuple())))
    if len(sec) > 1:
        ms=sec[1]
    else:
        ms = '000000000'
    return timestamp + str(ms)

def writeFile(file_name, tables_name, data, columns):
    f = open(file_name_output, 'w+')
    for table_name, values, columns_record in zip(tables_name, data, columns):
        for record in values:
            f.write(table_name)
            time=''
            for field, column in zip(record, columns_record):
                if column != "time":
                    conj = ',' if column != "value" else ' '
                    f.write(conj + str(column) + "=" + str(field))
                else:
                    time=timedateToTimestamp(field)
            f.write(' ' + time + '\n')
    f.close

if len(sys.argv) <= 1 or sys.argv[1].endswith('.json') != True:
    print "Specify a file json to parse"
    sys.exit(1)
file_name_input = sys.argv[1]
table_names, data, columns=getJsonData(file_name_input)
file_name_output = file_name_input.split(".")[0]+".txt"
writeFile(file_name_output, table_names, data, columns)

print "File input: %s"%file_name_input
print "File output: %s"%file_name_output
