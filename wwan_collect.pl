#!/usr/bin/perl

##### README IF YOU'RE HAVING TROUBLE
# If you're missing DBI, on debian do sudo apt install -y libdbi-perl libdbd-mysql libdbd-mysql-perl
# Set your database creds in here
# jrcichra 07-15-2020
#####
 
use strict;
use warnings;
use DBI;
use Data::Dumper;
use Scalar::Util qw(looks_like_number);

my $device = "/dev/cdc-wdm0";
my $table_name = "stats";
my $database_name = "wwan";
my $database_hostname = "raspberrypi";
my $database_username = "pi";
my $database_password = "raspberry";
my %stats;

# Connect to the database.
my $dbh = DBI->connect("DBI:mysql:database=$database_name;host=$database_hostname", "$database_username", "$database_password", {'RaiseError' => 1});


# Collect the operating data

# [/dev/cdc-wdm0] Operating mode retrieved:
#	Mode: 'online'
#	HW restricted: 'no'

my $operating_mode_output = `sudo qmicli -d $device --dms-get-operating-mode`;
($stats{operating_mode}) = $operating_mode_output =~ /Mode: '(.*)'/;
($stats{hw_restricted})  = $operating_mode_output =~ /HW restricted: '(.*)'/;





# Collect the signal strength data

#[/dev/cdc-wdm0] Successfully got signal strength
#Current:
#	Network 'lte': '-73 dBm'
#RSSI:
#	Network 'lte': '-73 dBm'
#ECIO:
#	Network 'lte': '-2.5 dBm'
#IO: '-106 dBm'
#SINR (8): '9.0 dB'
#RSRQ:
#	Network 'lte': '-20 dB'
#SNR:
#	Network 'lte': '-5.6 dB'
#RSRP:
#	Network 'lte': '-124 dBm'

my $signal_strength_output = `sudo qmicli -d $device --nas-get-signal-strength`;
($stats{current})         = $signal_strength_output =~ /Current:.*\n.*: '(.*) dBm'/;
($stats{current_network}) = $signal_strength_output =~ /Current:.*\n.*Network '(.*)':/;
($stats{rssi})            = $signal_strength_output =~ /RSSI:.*\n.*: '(.*) dBm'/;
($stats{rssi_network})    = $signal_strength_output =~ /RSSI:.*\n.*Network '(.*)':/;
($stats{ecio})            = $signal_strength_output =~ /ECIO:.*\n.*: '(.*) dBm'/;
($stats{ecio_network})    = $signal_strength_output =~ /ECIO:.*\n.*Network '(.*)':/;
($stats{rsrq})            = $signal_strength_output =~ /RSRQ:.*\n.*: '(.*) dB'/;
($stats{rsrq_network})    = $signal_strength_output =~ /RSRQ:.*\n.*Network '(.*)':/;
($stats{snr})             = $signal_strength_output =~ /SNR:.*\n.*: '(.*) dB'/;
($stats{snr_network})     = $signal_strength_output =~ /SNR:.*\n.*Network '(.*)':/;
($stats{rsrp})            = $signal_strength_output =~ /RSRP:.*\n.*: '(.*) dBm'/;
($stats{rsrp_network})    = $signal_strength_output =~ /RSRP:.*\n.*Network '(.*)':/;
($stats{io})              = $signal_strength_output =~ /IO:.*'(.*) dBm'/;
($stats{sinr})            = $signal_strength_output =~ /SINR.*'(.*) dB'/;

# Collect the home network data
#[/dev/cdc-wdm0] Successfully got home network:
#	Home network:
#		MCC: '310'
#		MNC: '260'
#		Description: 'T-Mobile'

my $home_network_output = `sudo qmicli -d /dev/cdc-wdm0 --nas-get-home-network`;
($stats{mcc})                 = $home_network_output =~ /MCC:.*'(.*)'/;
($stats{mnc})                 = $home_network_output =~ /MNC:.*'(.*)'/;
($stats{network_description}) = $home_network_output =~ /Description:.*'(.*)'/;


# Print what we found to stdout for debugging
print Dumper \%stats;

# Get the keys once so the order is deterministic
my @stats_keys = keys %stats;
# Convert into an insert statement
# This is a terrible way to build a sql statement
my $sql = "INSERT INTO $table_name ( ";
foreach my $key ( @stats_keys ) {
	$sql = $sql . $key . ', ';
}
# Replace the last comma with a paren and values
$sql =~ s/, $/ ) VALUES ( /;
# Loop again for values
foreach my $key ( @stats_keys ) {
	my $val = $stats{$key};
	if ( looks_like_number($val) ) {
		$sql = $sql . $val;
	} elsif (!defined($val) || $val eq '') {
		$sql = $sql . "NULL";
	} else {
		$sql = $sql . "'". $val . "'";
	}
	$sql = $sql . ', ';
}
# Replace the last comma with a paren
$sql =~ s/, $/)/;
# Print the insert statement
print "sql=$sql\n";
# Execute the insert statement
eval {
	$dbh->do($sql);
};
if ($@) {
	# Something went wrong
	die $@;
} else {
	print "Successfully inserted row into database\n";
}
