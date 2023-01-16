#!/usr/bin/python3 -u

import subprocess
import logging
import threading
import time
import os
import serial

logging.basicConfig(
    format="%(asctime)s - %(message)s", datefmt="%d-%b-%y %H:%M:%S", level=logging.INFO
)


DEFAULT_SLEEP_SECONDS = 3


def sleep(seconds=DEFAULT_SLEEP_SECONDS):
    logging.info(f"I should be sleeping for {seconds} seconds")
    time.sleep(seconds)


def system(command: str) -> bool:
    return os.system(command) == 0


def system_and_sleep(command: str) -> bool:
    logging.info(f"Running command: {command}")
    code = system(command)
    sleep()
    return code


def write_reboot(name: str):
    logging.info("Writing entry to reboots.log...")
    with open("a", "/home/pi/reboots.log") as f:
        now = int(time.time)
        f.write(f"{now} - {str} restarted.")


def connect_data():
    logging.info("Entering connect_data()...")
    while True:
        logging.info("Connecting Data...")
        if not system_and_sleep(
            "qmicli -d /dev/cdc-wdm0 --dms-set-operating-mode='online'"
        ):
            continue
        if not system_and_sleep("ip link set wwan0 down"):
            continue
        if not system_and_sleep("echo 'Y' | tee /sys/class/net/wwan0/qmi/raw_ip"):
            continue
        if not system_and_sleep("ip link set wwan0 up"):
            continue
        if not system_and_sleep(
            "qmicli -p -d /dev/cdc-wdm0 --device-open-net='net-raw-ip|net-no-qos-header' --wds-start-network='ip-type=4' --client-no-release-cid"
        ):
            continue
        if not system_and_sleep("timeout 20 udhcpc -i wwan0"):
            continue
        sleep(10)
        if not system_and_sleep("ping 8.8.8.8 -I wwan0 -c1 -W2"):
            continue
        logging.info("Connected Data!")
        break


def connect_gps():
    logging.info("Entering connect_gps()...")
    while True:
        logging.info("Connecting GPS...")
        logging.info(
            "Checking if /dev/ttyUSB1 exists. If it doesn't, we need to reboot the pi."
        )
        if not os.path.exists("/dev/ttyUSB1"):
            logging.info("/dev/ttyUSB1 does not exist. Rebooting the system")
            # write_reboot("system")
            # if not system_and_sleep("reboot"):
            #     logging.info("Could not reboot the system!!!")
        else:
            sleep()
            if not system_and_sleep(
                "stty -F /dev/ttyS0 115200 raw -echo -echoe -echok -echoctl -echoke"
            ):
                continue
            ser = serial.Serial("/dev/ttyUSB2", 115200)
            ser.write("AT+CGPS=0\r")
            sleep()
            ser.write("AT+CGPSDEL\r")
            sleep()
            ser.write("AT+CGPSAUTO=1\r")
            sleep()
            ser.write("AT+CGPS=1\r")
            sleep()
            if not system_and_sleep("systemctl restart gpsd"):
                continue
            logging.info("Connected GPS!")
            break


def handle_data():
    connect_data()
    while True:
        count = 0
        while count < 10:
            sleep(1)
            if system("ping -c 1 -I wwan0 1.1.1.1"):
                count = 0
            else:
                count += 1
        # reconnect data
        write_reboot("data")
        connect_data()


def handle_gps():
    connect_gps()
    while True:
        count = 0
        while count < 5:
            sleep(1)
            output = subprocess.check_output("timeout 10 gpspipe -w")
            if "TPV" in output:
                count = 0
            else:
                count += 1
            logging.info(f"gps count = {count}")
        # reconnect gps
        write_reboot("gps")
        connect_gps()


def main():
    sleep()
    data_thread = threading.Thread(target=handle_data)
    data_thread.start()
    gps_thread = threading.Thread(target=handle_gps)
    gps_thread.start()
    data_thread.join()
    gps_thread.join()


main()
