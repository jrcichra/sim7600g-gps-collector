default: install

_build:
	cd gps_collector && go build -o gps_collector
_install:
	sudo cp wwan_keep_alive.pl /usr/local/bin/wwan_keep_alive.pl
	sudo cp wwan_keep_alive.service /etc/systemd/system/
	sudo systemctl disable --now wwan_keep_alive
	sudo systemctl daemon-reload
	sudo systemctl enable --now wwan_keep_alive
	sudo cp gps_collector/gps_collector /usr/local/bin/gps_collector
	sudo cp gps_collector.service /etc/systemd/system/
	sudo systemctl disable --now gps_collector
	sudo systemctl daemon-reload
	sudo systemctl enable --now gps_collector
_uninstall:
	sudo systemctl disable --now wwan_keep_alive
	sudo rm /etc/systemd/system/wwan_keep_alive.service
	sudo rm /usr/local/bin/wwan_keep_alive.pl
	sudo rm /usr/local/bin/gps_collector
	sudo systemctl disable --now gps_collector
	sudo rm /etc/systemd/system/gps_collector.service
build: _build
install: _build _install
uninstall: _uninstall
