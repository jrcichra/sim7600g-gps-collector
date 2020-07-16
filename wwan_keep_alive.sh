#!/bin/bash
set -x
echo "Sleeping for a bit after systemd tells us to start just in case!"
sleep 18
while true
do
	sudo qmicli -d /dev/cdc-wdm0 --dms-set-operating-mode='offline'
	RC=$?
	if [ $RC != 0 ];then
	       continue
	fi	       
	sleep 2
	sudo qmicli -d /dev/cdc-wdm0 --dms-set-operating-mode='reset'
	RC=$?
	if [ $RC != 0 ];then
	       continue
	fi	       
	sleep 2
	# Sometimes this doesn't work on the first try
	while true
	do
		sudo qmicli -d /dev/cdc-wdm0 --dms-set-operating-mode='online'
		RC=$?
		if [ $RC != 0 ];then
			sleep 3
		       continue
	        else
			break
		fi	       
	done
	sleep 2
	sudo ip link set wwan0 down
	RC=$?
	if [ $RC != 0 ];then
	       continue
	fi	       
	echo 'Y' | sudo tee /sys/class/net/wwan0/qmi/raw_ip
	RC=$?
	if [ $RC != 0 ];then
	       continue
	fi	       
	sudo ip link set wwan0 up
	RC=$?
	if [ $RC != 0 ];then
	       continue
	fi	       
	sleep 2
	sudo qmicli -p -d /dev/cdc-wdm0 --device-open-net='net-raw-ip|net-no-qos-header' --wds-start-network="ip-type=4" --client-no-release-cid
	RC=$?
	if [ $RC != 0 ];then
	       continue
	fi	       
	sleep 2
	sudo udhcpc -i wwan0
	RC=$?
	if [ $RC != 0 ];then
	       continue
	fi	       
	# Ping forever and reset see if we lose it
	while true
	do
		ping -c 1 -I wwan0 8.8.8.8
		RC=$?
		if [ $RC != 0 ];then
		       break
		fi	       
		sleep 1
	done
done
