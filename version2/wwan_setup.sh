#!/bin/bash
echo "Sleeping for a bit after systemd tells us to start just in case!"
while true; do
	# Write out the date that we get to the top of this script
	date '+%s' >> /home/$(whoami)/reboots.log
	# Sometimes this doesn't work on the first try
	while true
	do
		sleep 4
		sudo qmicli -d /dev/cdc-wdm0 --dms-set-operating-mode='online'
		RC=$?
		if [ $RC != 0 ];then
			sleep 3
		       continue
	        else
                sleep 22
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
	sudo timeout 10 udhcpc -i wwan0
	RC=$?
	if [ $RC != 0 ];then
	       continue
	fi	       
	sleep 2

	# Set up the GPS

	# Kill any existing gpsd if there is one
	stty -F /dev/ttyS0 115200 raw -echo -echoe -echok -echoctl -echoke
	RC=$?
	if [ $RC != 0 ];then
	       continue
	fi	       
	sleep 2
	echo -en 'AT+CGPS=0\r' > /dev/ttyS0
	RC=$?
	if [ $RC != 0 ];then
	       continue
	fi	       
	sleep 2
	echo -en 'AT+CVAUXV=3050\r' > /dev/ttyS0
	RC=$?
	if [ $RC != 0 ];then
	       continue
	fi	       
	sleep 2
	echo -en 'AT+CVAUXS=1\r' > /dev/ttyS0
	RC=$?
	if [ $RC != 0 ];then
	       continue
	fi	       
	sleep 2
	echo -en 'AT+CGPS=1,1\r' > /dev/ttyS0
	RC=$?
	if [ $RC != 0 ];then
	       continue
	fi	       
	sleep 2
	#sudo gpsd /dev/ttyUSB1 -F /var/run/gpsd.sock
	RC=$?
	if [ $RC != 0 ];then
	       continue
	fi	       
	sleep 2

	# GPS should be working for anyone doing gpspipe

	sleep 10
	sudo systemctl restart gpsd
	# Ping forever and reset see if we lose it
    COUNT=0
	while [ $COUNT -lt 20 ]
	do
		ping -c 1 -I wwan0 8.8.8.8
		RC=$?
		if [ $RC != 0 ];then
		       COUNT=$((COUNT+1))
                else
                       COUNT=0
		fi	       
		sleep 1
	done
done
