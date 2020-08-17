#! /usr/bin/python -u
import sys
import json
import mysql.connector
import datetime
import logging
import socket



#from datetime import datetime

mydb = mysql.connector.connect(host="localhost"
        ,user="PYTHON_LOADER"
        ,passwd="PYTHON1234"
        ,database="GPS_TRACKING"
        ,time_zone='+00:00'
)

myhostname = "BIKEPI"

selsql = """SELECT RECORD_TIMESTAMP FROM GPS_TRACKING.GPS_DATA
WHERE HOSTNAME = %s
AND   RECORD_TIMESTAMP = %s """

inssql = """INSERT INTO GPS_TRACKING.GPS_DATA
(RECORD_TIMESTAMP    , HOSTNAME, JSON_DOC         , GPS_TIMESTAMP)
VALUES
(CURRENT_TIMESTAMP   , %s      , %s               , %s)"""

mycursor = mydb.cursor() 

while 1:
    line  = sys.stdin.readline()

    if not line:
        break

    try:
        event = json.loads(line)
    except:
        continue
    
    #Check that this is a TPV message.
    if event["class"] == "TPV":
        #print "TPV"
        pass
    else:
        #print "not TPV"
        continue

    #print "full json: " + str(json.dumps(event))
    #print "converting to python timestamp"
    try:
        v_gps_time = datetime.datetime.strptime(str(event["time"]),"%Y-%m-%dT%H:%M:%S.%fZ")
    except:
        print "bad time"
        continue

    #print " timestamp converted : " + str(v_gps_time)


    #print "get current record"

    #print selsql

    val = (myhostname, v_gps_time,)
    #val = (myhostname, event["time"])

    mycursor.execute(selsql, val)

    result=mycursor.fetchall()

    if not result:
        #print "no record found"
        #This is how we load
        val = (                      myhostname, json.dumps(event), v_gps_time,)
        try:
            mycursor.execute(inssql,val)
        except mysql.connector.IntegrityError as err:
            print("Unique Contstraint error.")
            pass
        mydb.commit();
        
