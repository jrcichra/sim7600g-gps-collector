#!/usr/bin/perl

use strict;
use warnings;
use threads;
use threads::shared;
use IO::Handle;

my $sleep_sec = 3;

sub println {
    my $string = shift;
    my $dt     = time();
    print("[$dt]: $string\n");
}

sub write_reboot {
    my $name = shift;
    open( my $reboots_file, '>>', "/home/pi/reboots.log" );
    my $t = time();
    print $reboots_file "$t - $name restarted.\n";
    close $reboots_file;
}

sub connect_data {
    println("Entering connect_data()...");
    while (1) {
        println("Connecting Data...");
        sleep $sleep_sec;
        system("qmicli -d /dev/cdc-wdm0 --dms-set-operating-mode='online'");
        next if $? >> 8 != 0;
        sleep $sleep_sec;
        system("ip link set wwan0 down");
        next if $? >> 8 != 0;
        sleep $sleep_sec;
        system("echo 'Y' | tee /sys/class/net/wwan0/qmi/raw_ip");
        next if $? >> 8 != 0;
        sleep $sleep_sec;
        system("ip link set wwan0 up");
        next if $? >> 8 != 0;
        sleep $sleep_sec;
        system(
"qmicli -p -d /dev/cdc-wdm0 --device-open-net='net-raw-ip|net-no-qos-header' --wds-start-network='ip-type=4' --client-no-release-cid"
        );
        next if $? >> 8 != 0;
        sleep $sleep_sec;
        system("timeout 20 udhcpc -i wwan0");
        next if $? >> 8 != 0;
        sleep $sleep_sec;
        sleep $sleep_sec;
        sleep $sleep_sec;

        # try a ping
        system("ping 8.8.8.8 -I wwan0 -c1 -W2");
        next if $? >> 8 != 0;
        sleep $sleep_sec;
        println("Connected Data!");
        last;
    }
}

sub connect_gps {
    println("Entering connect_gps()...");
    while (1) {
        println("Connecting GPS...");
        println(
"Checking if /dev/ttyUSB1 exists. If it doesn't, we need to reboot the pi."
        );
        if ( !-e "/dev/ttyUSB1" ) {
            println(
"/dev/ttyUSB1 does not exist. I would have done a reboot just now."
            );

            # write_reboot("system");
            # system("reboot");
            next;
        }
        sleep $sleep_sec;
        system(
            "stty -F /dev/ttyS0 115200 raw -echo -echoe -echok -echoctl -echoke"
        );
        next if $? >> 8 != 0;
        sleep $sleep_sec;
        my $filename = "/dev/ttyUSB2";
        open( my $tty, '>>', $filename ) or die "Could not open file $filename";
        print $tty "AT+CGPS=0\r";
        $tty->autoflush;
        sleep $sleep_sec;
        print $tty "AT+CGPSDEL\r";
        $tty->autoflush;
        sleep $sleep_sec;
        print $tty "AT+CGPSAUTO=1\r";
        $tty->autoflush;
        sleep $sleep_sec;
        print $tty "AT+CGPS=1\r";
        $tty->autoflush;
        sleep $sleep_sec;
        system("systemctl restart gpsd");
        next if $? >> 8 != 0;
        println("Connected GPS!");
        close $tty;
        last;
    }
}

sub handle_data {

    connect_data();

    # make sure ping works
    while (1) {
        my $count = 0;
        while ( $count < 10 ) {
            sleep 1;
            system("ping -c 1 -I wwan0 8.8.8.8");

            # increment count if the ping failed, reset if passed
            $? >> 8 == 0 ? $count = 0 : $count++;
            println("data count = $count");
        }

        # reconnect data
        write_reboot("data");
        connect_data();
    }
}

sub handle_gps {
    connect_gps();

    # make sure gps works
    while (1) {
        my $count = 0;
        while ( $count < 5 ) {
            sleep 1;
            my $gpspipe_output = `timeout 10 gpspipe -w`;

            # increment count if no TPV data, reset if passed
            index( $gpspipe_output, "TPV" ) != -1 ? $count = 0 : $count++;
            println("gps count = $count");
        }

        # reconnect gps
        write_reboot("gps");
        connect_gps();
    }
}

## MAIN ##

sleep $sleep_sec;
my $data_thread = threads->create('handle_data');
my $gps_thread  = threads->create('handle_gps');
$data_thread->join();
$gps_thread->join();
