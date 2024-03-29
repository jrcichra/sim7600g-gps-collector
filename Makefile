default: install

_build:
	cd gps_collector && go build -v -o gps_collector
_install:
	sudo cp wwan_keep_alive.py /usr/local/bin/wwan_keep_alive.py
	sudo mkdir -p /etc/gps_collector/
	sudo cp gps_collector/config.yaml /etc/gps_collector/config.yaml
	sudo cp wwan_keep_alive.service /etc/systemd/system/
	sudo systemctl disable --now wwan_keep_alive
	sudo systemctl daemon-reload
	sudo systemctl enable --now wwan_keep_alive
	sudo cp gps_collector.service /etc/systemd/system/
	sudo systemctl disable --now gps_collector
	sudo systemctl daemon-reload
	sudo cp gps_collector/gps_collector /usr/local/bin/gps_collector
	sudo systemctl enable --now gps_collector
_uninstall:
	sudo systemctl disable --now wwan_keep_alive
	sudo rm /etc/systemd/system/wwan_keep_alive.service
	sudo rm /usr/local/bin/wwan_keep_alive.py
	sudo systemctl disable --now gps_collector
	sudo rm /etc/systemd/system/gps_collector.service
	sudo rm /usr/local/bin/gps_collector
	sudo rm -r /etc/gps_collector
build: _build
install: _build _install
uninstall: _uninstall
