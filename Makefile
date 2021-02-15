
_build:
	cd gps_collector && go build -o gps_collector
_install:
	sudo cp wwan_keep_alive.pl /usr/local/bin/wwan_keep_alive.pl
	sudo cp wwan_setup.service /etc/systemd/system/
	sudo systemctl enable wwan_setup
	sudo cp gps_collector/gps_collector /usr/local/bin/gps_collector
	sudo cp gps_collector.service /etc/systemd/system/
	sudo systemctl enable gps_collector
_uninstall:
	sudo systemctl disable --now wwan_setup
	sudo rm /etc/systemd/system/wwan_setup.service
	sudo rm /usr/local/bin/wwan_keep_alive.pl
	sudo rm /usr/local/bin/gps_collector
	sudo systemctl disable --now gps_collector
	sudo rm /etc/systemd/system/gps_collector.service
build: _build
install: _build _install
uninstall: _uninstall