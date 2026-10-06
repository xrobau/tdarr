SHELL=/bin/bash
ZTNET=8bebd2d4b3f4e550
VPNNET=172.20.24
MNTSRC=//172.20.24.3/pool3
DEST=/thearchive/pool3
UPDATER=https://storage.tdarr.io/versions/2.81.01/linux_x64/Tdarr_Updater.zip

FSTABLINE=$(MNTSRC) $(DEST) cifs password=null 0 0

ZTFILE=/var/lib/zerotier-one/networks.d/$(ZTNET).conf
VIMDEFAULTS=$(wildcard /usr/share/vim/*/defaults.vim)

.PHONY: setup
setup: /usr/bin/ffmpeg /root/.gitconfig /etc/bashrc.local /root/.ssh/authorized_keys /etc/tdarr.name $(ZTFILE)
	@for x in $(VIMDEFAULTS); do sed -i 's/\ set mouse=/\ \"set mouse=/' $$x; done;
	@IP=$$(ip addr | grep $(VPNNET)); if [ ! "$$IP" ]; then echo "Ask xrobau to approve this zerotier endpoint called $$(cat /etc/tdarr.name)"; /usr/sbin/zerotier-cli status; exit 1; else echo "VPN IP is $$(echo $$IP | cut -d\  -f2), mount should now work"; fi
	@echo "Run 'make node' to install Tdarr_Node"

.PHONY: name
name /etc/tdarr.name:
	@if [ ! -e /etc/tdarr.name ]; then echo $(shell hostname) > /etc/tdarr.name; fi; \
		C=$$(cat /etc/tdarr.name); echo "Current name '$$C'"; read -e -p "Set name (blank to not change): " h; if [ "$$h" ]; then echo $$h > /etc/tdarr.name; fi

.PHONY: /etc/tdarr_node.name
/etc/tdarr_node.name: /etc/tdarr.name
	@RAM="$$(awk '/MemTotal:/ { print ($$2 / 1024 / 1024) + 0 }' /proc/meminfo)GB";CPUS=$$(grep ^processor /proc/cpuinfo | wc -l); CTYPE=$$(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2-); echo "$$(cat /etc/tdarr.name) - $$CPUS$$CTYPE $$RAM" > /etc/tdarr_node.name

.PHONY: node_config configs/Tdarr_Node_Config.json
node_config configs/Tdarr_Node_Config.json: node_conf.template /etc/tdarr_node.name
	@mkdir -p configs
	@NODENAME="$$(cat /etc/tdarr_node.name)"; sed "s/__NODENAME__/$$NODENAME/" < node_conf.template > configs/Tdarr_Node_Config.json

.PHONY: mount
mount:
	@mkdir -p $(DEST)
	sed '/$(shell echo $(DEST) | sed 's@/@\\/@g')/d' -i /etc/fstab
	echo "$(FSTABLINE)" >> /etc/fstab

.PHONY: service
service: /etc/systemd/system/tdarr_node.service configs/Tdarr_Node_Config.json
	@echo nodename is "$$(cat /etc/tdarr_node.name)"
	@echo "$< is in place, run 'systemctl enable tdarr_node'"

.PHONY: bash
bash /etc/bashrc.local: bashrc.local
	cp bashrc.local /etc/bashrc.local
	if ! grep -q bashrc.local /etc/bash.bashrc; then echo '[ -e /etc/bashrc.local ] && . /etc/bashrc.local' >> /etc/bash.bashrc; fi

.PHONY: git
git /root/.gitconfig: gitconfig
	cp gitconfig /root/.gitconfig

/etc/systemd/system/tdarr_node.service: tdarr_node.service /etc/tdarr_node.name
	@NODENAME="$$(cat /etc/tdarr_node.name)"; sed -e "s/__NODENAME__/$$NODENAME/" -e "s@__NODEPATH__@$(shell pwd)/Tdarr_Node/Tdarr_Node@" < $< > $@

.PHONY: node
node: configs/Tdarr_Node_Config.json | Tdarr_Node/Tdarr_Node
	@echo 'Node config is ready. Run this, or run "make service" to install the service'
	@echo '/usr/bin/screen -dmS tdarr-node $(shell pwd)/Tdarr_Node/Tdarr_Node'

Tdarr_Node/Tdarr_Node: Tdarr_Updater
	@ls -al $@

Tdarr_Updater:
	wget $(UPDATER) -O Tdarr_Updater.zip
	unzip -o Tdarr_Updater.zip
	./Tdarr_Updater

.PHONY: packages
/usr/bin/ffmpeg packages:
	apt-get update
	apt-get install wget curl mkvtoolnix libtesseract-dev handbrake-cli ffmpeg zip vim nfs-common cifs-utils smbclient screen git

$(ZTFILE): /usr/sbin/zerotier-cli
	zerotier-cli join $(ZTNET)

/usr/sbin/zerotier-cli:
	curl -s https://install.zerotier.com | bash

/root/.ssh/authorized_keys: authorized_keys
	mkdir -p $(@D)
	cp $< $@

