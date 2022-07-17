# sim7600g-gps-collector

- A GPS collection package to monitor Pis in the wild
- Tested on Raspbian using a Raspberry Pi 4B and Raspberry Pi Zero W with this hat: https://www.waveshare.com/wiki/SIM7600G-H_4G_HAT
- Sometimes you lose /dev/ttyUSB1 which is needed for GPS. This program will restart if it detects that /dev/ttyUSB1 is missing.
  V3 runs two perl threads - one that monitors the data connection with a ping to Google, and the other checks for `TPV` data in calls to `gpspipe -w`. Each issue will be addressed separately by the responsible thread

# Setup

## Server-side

- Create a new database in mysql for this project: i.e `create database gps`
- See `sim7600g.sql`. Create a table with these columns
- Create a database user for the next step: `create user ingest@'%' identified by a_password`
- Grant insert privs on the gps database.table you made earlier `grant insert on gps.gps to ingest@'%'`
- See https://github.com/jrcichra/ingestd. Spin up this docker container on your server, specifying your mysql database as described. This tool ingests data from HTTP POSTS into a database
- `ingestd` should start up and be listening for data

## Client-side

- Modify constants at the top of `gps_collector/gps_collector.go` to point to the appropriate URL/database/table
- I've included some simple `make` targets to help installation
- (You'll need a recent version of the Go compiler)
- `sudo make install` compiles the Go code, places binaries/scripts in `/usr/local/bin`, and enables the systemd targets
- `sudo make uninstall` removes what was added to `/usr/local/bin` and instantly disables the systemd targets.
- Modify `/etc/default/gpsd` and set `DEVICES="/dev/ttyUSB1"`
- `sudo systemctl daemon-reload`
- `sudo systemctl restart gpsd`
