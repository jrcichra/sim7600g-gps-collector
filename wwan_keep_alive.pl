#!/usr/bin/perl
#!/bin/bash

use strict;
use warnings;
use Data::Dumper;
use POSIX qw(strftime);
use threads;
use threads::shared;

my $sleep_sec = 3;

sub println {
    my $string = shift;
    my $dt     = strftime("%c");
    print("[$dt]: $string\n");
}

sub write_reboot {
    my $name = shift;

    # Write out the date that we get to the top of this script
    my $whoami = `whoami`;
    chomp;
    open( my $reboots_file, '>>', "/home/$whoami/reboots.log" );
    my $t = time();
    print $reboots_file "$t - $name restarted.\n";
}

sub connect_cell {
    println("Entering connect_cell()...");
    while (1) {
        println("Connecting Cell...");
        sleep $sleep_sec;
        system(
            "sudo qmicli -d /dev/cdc -wdm0 --dms-set-operating-mode = 'online'"
        );
        next if $? >> 8 != 0;
        sleep $sleep_sec;
        system("sudo ip link set wwan0 down");
        next if $? >> 8 != 0;
        sleep $sleep_sec;
        system("echo 'Y' | sudo tee /sys/class/net/wwan0/qmi/raw_ip");
        next if $? >> 8 != 0;
        sleep $sleep_sec;
        system("sudo ip link set wwan0 up");
        next if $? >> 8 != 0;
        sleep $sleep_sec;
        system(
"sudo qmicli -p -d /dev/cdc-wdm0 --device-open-net='net-raw-ip|net-no-qos-header' --wds-start-network='ip-type=4' --client-no-release-cid"
        );
        next if $? >> 8 != 0;
        sleep $sleep_sec;
        system("sudo timeout 20 udhcpc -i wwan0");
        next if $? >> 8 != 0;
        sleep $sleep_sec;
        sleep $sleep_sec;
        sleep $sleep_sec;

        # try a ping
        system("ping 8.8.8.8 -I wwan0 -c1 -W2");
        next if $? >> 8 != 0;
        sleep $sleep_sec;
        println("Connected Cell!");
        last;
    }
}

sub connect_gps {
    println("Entering connect_gps()...");
    while (1) {
        println("Connecting GPS...");
        sleep $sleep_sec;
        system(
            "stty -F /dev/ttyS0 115200 raw -echo -echoe -echok -echoctl -echoke"
        );
        next if $? >> 8 != 0;
        sleep $sleep_sec;
        system("echo -en 'AT+CGPS=0\r' > /dev/ttyS0");
        next if $? >> 8 != 0;
        sleep $sleep_sec;
        system("echo -en 'AT+CVAUXV=3050\r' > /dev/ttyS0");
        next if $? >> 8 != 0;
        sleep $sleep_sec;
        system("echo -en 'AT+CVAUXS=1\r' > /dev/ttyS0");
        next if $? >> 8 != 0;
        sleep $sleep_sec;
        system("echo -en 'AT+CGPS=1,1\r' > /dev/ttyS0");
        next if $? >> 8 != 0;
        sleep $sleep_sec;
        system("sudo systemctl restart gpsd");
        next if $? >> 8 != 0;
        sleep $sleep_sec;
    }
}

sub handle_data {

    connect_data();

    # make sure ping works
    while (1) {
        my $count = 0;
        while ( $count <= 20 ) {
            sleep $sleep_sec;
            system("ping -c 1 -I wwan0 8.8.8.8");

            # increment count if the ping failed, reset if passed
            $? >> 8 != 0 ? $count += 1 : $count = 0;
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
        while ( $count <= 20 ) {
            sleep $sleep_sec;
            my $gpspipe_output = `sudo timeout 10 gpspipe -w`;

            # increment count if no TPV data, reset if passed
            !( $gpspipe_output =~ /TPV/ ) ? $count += 1 : $count = 0;
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
