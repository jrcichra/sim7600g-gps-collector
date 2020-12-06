while true ; do
	echo "Loop Start:$(date)"
	gpspipe -w -n 60 | timeout -k 10 50  ssh $HOSTNAME /home/$(whoami)/load_json_v01.py
done
