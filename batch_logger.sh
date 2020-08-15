#!/bin/bash
FILE_STORAGE_DIR=/home/$(whoami)/batchfiles/
#Check for the /tmp/ dir.
test -d ${FILE_STORAGE_DIR} || mkdir -p ${FILE_STORAGE_DIR}

#Loop until forever:
while true  ; do
	find ${FILE_STORAGE_DIR} -type f -mtime +7 -exec rm {} \;
	killall rsync
	rsync -avz --remove-source-files -e "ssh " ${FILE_STORAGE_DIR} $HOSTNAME:batch_ship/ &
	sleep 3
	gpspipe -n 600 -w > ${FILE_STORAGE_DIR}/data_starting_$(date +%s)
	if [ $? -ne 0 ] ; then
		exit 1
	fi
done
