# sim7600g-gps-collector
+ A GPS collection package to monitor Pis in the wild
+ Tested on Raspbian using a Rasperry Pi 4B with this hat: https://www.waveshare.com/wiki/SIM7600G-H_4G_HAT
+ Running kernel `5.4.79-v7l+`
# Known issues
+ This is still a WIP that is actively being tested. Don't use this in critical applications!!!
+ The GPS will stop responding at times
+ The celluar data will lose signal

For V2, I've ripped out the `reset` logic in an attempt to let the sim7600g driver prove itself. If the sim7600g never resets, please refer to `wwan_keep_alive.sh` in the `version1` folder. Replace the contents of `wwan_setup.sh` with the contents of `wwan_keep_alive.sh`. Then `make install`.

# Setup
## Server-side 
+ Create a new database in mysql for this project: i.e `create database gps`
+ See `sim7600g.sql`. Create a table with these columns
+ Create a database user for the next step: `create user ingest@'%' identified by a_password`
+ Grant insert privs on the gps database.table you made earlier `grant insert on gps.gps to ingest@'%'`
+ See https://github.com/jrcichra/ingestd. Spin up this docker container on your server, specifying your mysql database as described. This tool ingests data from HTTP POSTS into a database
+ `ingestd` should start up and be listening for data
## Client-side
+ Modify constants at the top of `gps_collector/gps_collector.go` to point to the appropriate URL/database/table
+ I've included some simple `make` targets to help installation
+ (You'll need a recent version of the Go compiler)
+ `sudo make install` compiles the Go code, places binaries/scripts in `/usr/local/bin`, and enables the systemd targets
+ `sudo make uninstall` removes what was added to `/usr/local/bin` and instantly disables the systemd targets.