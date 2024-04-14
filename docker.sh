INSTALL_DIR="install_dir"
MIRRORS="https://gh.ddlc.top/ https://hub.gitmirror.com/ https://mirror.ghproxy.com/ https://ghps.cc/"
github_download(){
	for MIRROR in $MIRRORS;do
		curl --connect-timeout 3 -#Lko /tmp/$1 "$MIRROR$2"
		if [ "$?" = 0 ];then
			[ $(wc -c < /tmp/$1) -lt 594 ] && rm -f /tmp/$1 || break
		else
			rm -f /tmp/$1
		fi
	done
	[ -f /tmp/$1 ] && return 0 || return 1
}

echo -e "\n\e[1;33mDownloading Docker files....\e[0m" && curl -#kLo /tmp/docker.tgz https://download.docker.com/linux/static/stable/aarch64/$(curl -sk https://download.docker.com/linux/static/stable/aarch64/ | grep docker-[0-9] | tail -1 | awk -F \> '{print $1}' | grep -oE 'd.*z')
if [ "$?" = 0 ];then
	swapon -a 2> /dev/null
	[ "$?" != 0 ] && {
		echo -e "\n\e[1;33mDownloading block-mount....\e[0m" && github_download block-mount.zip https://raw.githubusercontent.com/xilaochengv/BuildKernelSU/main/block-mount.zip
		[ "$?" != 0 ] && rm -f /tmp/docker.tgz /tmp/block-mount.zip && echo -e "\e[0;31mDownload block-mount failed!\e[0m" && return 1
	}

	[ "$(uci get /usr/share/xiaoqiang/xiaoqiang_version.version.HARDWARE 2> /dev/null)" = "RA70" -a ! -f /lib/modules/$(uname -r)/veth.ko ] && {
		echo -e "\n\e[1;33mDownloading veth....\e[0m" && github_download veth.zip https://raw.githubusercontent.com/xilaochengv/BuildKernelSU/main/veth.zip
		[ "$?" != 0 ] && rm -f /tmp/docker.tgz /tmp/block-mount.zip /tmp/veth.zip && echo -e "\e[0;31mDownload veth failed!\e[0m" && return 1
	}

	[ "$(file /etc/localtime | grep broken)" ] && {
		echo -e "\n\e[1;33mDownloading timezone file....\e[0m" && github_download localtime.zip https://raw.githubusercontent.com/xilaochengv/BuildKernelSU/main/localtime.zip
		[ "$?" != 0 ] && rm -f /tmp/docker.tgz /tmp/block-mount.zip /tmp/veth.zip && localtime.zip && echo -e "\e[0;31mDownload timezone file failed!\e[0m" && return 1
	}

	[ -f "/tmp/block-mount.zip" ] && echo -e "\n\e[1;33mInstalling block-mount....\e[0m" && mkdir -p /tmp/block-mount && unzip -P "mkqhnwekjio@!#!%" -oq /tmp/block-mount.zip -d /tmp/block-mount && chmod -R 777 /tmp/block-mount && cp -fpR /tmp/block-mount/* / && rm -rf /tmp/block-mount/ && uci set system.@system[0].zonename=Asia/Shanghai && uci commit && /etc/init.d/system restart && ln -sf /sbin/block /usr/bin/swapon && ln -sf /sbin/block /usr/bin/swapoff && \
	ln -sf /usr/lib/libjson-c.so.5.2.0 /usr/lib/libjson-c.so.5 && ln -sf /tmp/localtime /etc/localtime && rm -f /tmp/block-mount.zip

	[ -f "/tmp/veth.zip" ] && echo -e "\n\e[1;33mInstalling veth....\e[0m" && unzip -P "jqwjioqwwqio@!&^" -oq /tmp/veth.zip -d /lib/modules/$(uname -r) && rm -f /tmp/veth.zip

	[ -f "/tmp/localtime.zip" ] && echo -e "\n\e[1;33mExtracting timezone file....\e[0m" && unzip -P "klakjeqw^&^@!" -oq /tmp/localtime.zip -d /etc && rm -f /tmp/localtime.zip

	echo -e "\n\e[1;33mInstalling Docker....\e[0m" && tar -zxf /tmp/docker.tgz -C $INSTALL_DIR && rm -rf /tmp/docker.tgz && sed -i '/\/docker:$PATH/d' /etc/profile && echo -e "\nexport PATH=$INSTALL_DIR/docker:\$PATH" >> /etc/profile && sed -i '/./,/^$/!d' /etc/profile && . /etc/profile &> /dev/null
	mount -t tmpfs -o uid=0,gid=0,mode=0755 cgroup /sys/fs/cgroup
	cd /sys/fs/cgroup;for tmp in $(awk '!/^#/ { if ($4 == 1) print $1 }' /proc/cgroups);do mkdir -p $tmp;chmod 777 $tmp;mount -n -t cgroup -o $tmp cgroup $tmp;done;cd ~
	echo -e "#!/bin/sh /etc/rc.common\n\nSTART=95\n\nstart() {\n\tstop\n\t[ -f $INSTALL_DIR/docker/swapfile ] && {\n\t\tswapon $INSTALL_DIR/docker/swapfile && sysctl -w vm.swappiness=60 &> /dev/null && insmod veth &> /dev/null\n\t\tmount -t tmpfs -o uid=0,gid=0,mode=0755 cgroup /sys/fs/cgroup\n\t\tcd /sys/fs/cgroup;for tmp in \$(awk '!/^#/ { if (\$4 == 1) print \$1 }' /proc/cgroups);do mkdir -p \$tmp;chmod 777 \$tmp;mount -n -t cgroup -o \$tmp cgroup \$tmp;done;cd ~\n\t\t\
exec dockerd --data-root $INSTALL_DIR/docker/lib --dns 223.6.6.6 --dns 119.29.29.29 --dns 101.226.4.6 --registry-mirror https://docker.mirrors.sjtug.sjtu.edu.cn &> /dev/null &\n\t\techo \"Please wait while Docker is starting up....\"\n\t\twhile [ ! \"\$(netstat -lnWp | grep libnetwork)\" ];do sleep 1;done\n\t\tfor tmp in \$(docker ps -a | sed -n '1!p' | awk '{print \$1}');do docker start \$tmp &> /dev/null;done\n\t}\n}\n\n\
stop() {\n\techo \"Please wait while Docker is stoping....\"\n\tfor tmp in \$(docker ps 2> /dev/null | sed -n '1!p' | awk '{print \$1}');do docker stop \$tmp &> /dev/null;done\n\tservice_stop $INSTALL_DIR/docker/dockerd\n\t\
while [ \"\$(ps | grep /docker/ | grep -v grep)\" ];do killpid \$(ps | grep /docker/ | grep -v grep | awk '{print \$1}' | head -1);done\n\t\
while [ \"\$(mount | grep cgroup | awk '{print \$3}')\" ];do umount \$(mount | grep cgroup | awk '{print \$3}' | tail -1);done\n\t[ \"\$(df -h | grep overlay2 | awk '{print \$6}')\" ] && umount \$(df -h | grep overlay2 | awk '{print \$6}')\n\tumount $INSTALL_DIR/docker/lib 2> /dev/null\n\tumount /tmp/run/docker/netns/default 2> /dev/null\n\t\
swapoff -a && ifconfig \$(ifconfig | awk '{print \$1}' | grep docker) down 2> /dev/null\n\twhile [ \"\$(iptables -S | grep '\-A' | grep -E 'docker|DOCKER' | grep FORWARD)\" ];do eval iptables \$(iptables -S | grep '\-A' | grep -E 'docker|DOCKER' | grep FORWARD | head -1 | sed 's/-A/-D/');done\n\t\
iptables -F DOCKER-ISOLATION-STAGE-1 2> /dev/null && iptables -F DOCKER-ISOLATION-STAGE-2 && iptables -F DOCKER-USER && iptables -F DOCKER\n\tiptables -X DOCKER-ISOLATION-STAGE-1 2> /dev/null && iptables -X DOCKER-ISOLATION-STAGE-2 && iptables -X DOCKER-USER && iptables -X DOCKER\n\t\
while [ \"\$(iptables -t nat -S | grep -E 'docker|DOCKER' | grep -E 'PREROUTING|OUTPUT|POSTROUTING')\" ];do eval iptables -t nat \$(iptables -t nat -S | grep -E 'docker|DOCKER' | grep -E 'PREROUTING|OUTPUT|POSTROUTING' | head -1 | sed 's/-A/-D/');done\n\tiptables -t nat -F DOCKER 2> /dev/null && iptables -t nat -X DOCKER\n}" > /etc/init.d/docker && chmod 755 /etc/init.d/docker
	exec dockerd --data-root $INSTALL_DIR/docker/lib --dns 223.6.6.6 --dns 119.29.29.29 --dns 101.226.4.6 --registry-mirror https://docker.mirrors.sjtug.sjtu.edu.cn &> /dev/null &

	echo -e "\n\e[1;33mMaking swap file....\e[0m" && swapoff -a && dd if=/dev/zero of=$INSTALL_DIR/docker/swapfile bs=1M count=1024 &> /dev/null
	chmod 0600 $INSTALL_DIR/docker/swapfile && mkswap -L Docker $INSTALL_DIR/docker/swapfile
	swapon $INSTALL_DIR/docker/swapfile && sysctl -w vm.swappiness=60 &> /dev/null && insmod veth &> /dev/null
	while [ ! "$(netstat -lnWp | grep libnetwork)" ];do sleep 1;done
	[ ! "$(docker ps -a | grep portainer)" ] && {
		echo -e "\n\e[1;33mPulling Portainer image....\e[0m" && docker pull 6053537/portainer-ce
		echo -e "\n\e[1;33mRunning Portainer....\e[0m" && docker run -d --name portainer --restart=always --privileged -p 8000:8000 -p 9000:9000 -p 9443:9443 -v /etc/localtime:/etc/localtime:ro -v /var/run/docker.sock:/var/run/docker.sock -v $INSTALL_DIR/docker/portainer:/data 6053537/portainer-ce &> /dev/null
	}
	docker start portainer &> /dev/null
	rm -f $0 && return 0
else
	rm -f /tmp/docker.tgz && rm -f $0 && return 1
fi
