version=v1.0.7r
RED='\e[0;31m';GREEN='\e[1;32m';YELLOW='\e[1;33m';BLUE='\e[1;34m';PINK='\e[1;35m';SKYBLUE='\e[1;36m';UNDERLINE='\e[4m';BLINK='\e[5m';RESET='\e[0m';changlogshowed=false
export PATH=/data/unzip:$PATH
hardware_release=$(cat /etc/openwrt_release 2> /dev/null | grep RELEASE | grep -oE [.0-9]{1,10})
hardware_target=$(cat /etc/openwrt_release 2> /dev/null | grep TARGET | awk -F / '{print $2}' | sed 's/_.*//')
hardware_arch=$(cat /etc/openwrt_release 2> /dev/null | grep ARCH | awk -F "'" '{print $2}')
hostip=$(uci get network.lan.ipaddr 2> /dev/null)
wanifname=$(uci get network.wan.ifname 2> /dev/null)
[ -d /usr/share/xiaoqiang -a "$(uname -m)" = "aarch64" ] && miAARCH64=true
[ "$(df | grep -E '/data/etc/config|/etc/config')" ] && autorestore=true
MIRRORS="
https://ghp.ci/
https://ghproxy.net/
https://gh-proxy.com/
https://github.moeyy.xyz/
https://mirror.ghproxy.com/
"
log(){
	echo "[ $(date '+%F %T') ] $1" >> ${0%/*}/XiaomiSimpleInstallBox.log
}
opkg_test_install(){
	[ "$1" = "unzip" ] && [ "$(which unzip)" ] && return 0
	[ "$1" = "aria2" ] && [ "$(which aria2c)" ] && return 0
	[ "$1" = "ariang" ] && [ -d $sdadir/ariang ] && return 0
	[ "$1" = "transmission-web" ] && [ -d $sdadir/web ] && return 0
	[ "$(echo $1 | grep ^lib)" ] && [ -f $sdadir/$1 ] && return 0
	[ ! "$(opkg list-installed | grep $1 2> /dev/null)" ] && {
		[ ! "$(echo $1 | grep -E 'vsftpd|transmission-daemon-openssl|etherwake')" -o "$1" = "vsftpd" -a ! "$(which vsftpd)" -o "$1" = "transmission-daemon-openssl" -a ! "$(which transmission-daemon)" -o "$1" = "etherwake" -a ! "$(which etherwake)" ] && {
			echo -e "\n本次操作需要使用到 $YELLOW$1$RESET" && sleep 1
			echo -e "\n本机还$RED没有安装 $YELLOW$1$RESET ！即将尝试下载安装\n" && sleep 1
			[ "$1" = "aria2" ] && rm -f /usr/bin/aria2c && opkg remove aria2 &> /dev/null
			[ "$1" = "ariang" ] && rm -rf /www/ariang && opkg remove ariang &> /dev/null
			[ "$1" = "vsftpd" ] && rm -rf /etc/vsftpd.conf /data/vsftpd /usr/sbin/vsftpd && opkg remove vsftpd &> /dev/null
			[ "$1" = "transmission" ] && rm -rf /etc/config/transmission /usr/share/transmission /usr/bin/transmission-daemon && opkg remove transmission-web transmission-daemon-openssl transmission-daemon-mbedtls libnatpmp libminiupnpc &> /dev/null
			[ "$1" = "etherwake" ] && rm -f /usr/bin/etherwake && opkg remove etherwake &> /dev/null
			[ ! -f /tmp/opkg-lists/openwrt_packages.sig ] && {
				opkg update
				[ "$?" != 0 ] && {
					[ ! -f /etc/opkg/distfeeds.conf.backup ] && mv /etc/opkg/distfeeds.conf /etc/opkg/distfeeds.conf.backup && log "文件/etc/opkg/distfeeds.conf改名为distfeeds.conf.backup"
					echo -e "\n更新源$RED连接失败$RESET，将尝试根据获取的机型信息 $PINK$hardware_release-$hardware_arch$RESET 进行重试\n" && sleep 2
					echo "src/gz openwrt_core http://downloads.openwrt.org/snapshots/targets/$hardware_target/generic/packages" > /etc/opkg/distfeeds.conf
					echo "src/gz openwrt_base http://downloads.openwrt.org/releases/packages-$hardware_release/$hardware_arch/base" >> /etc/opkg/distfeeds.conf
					echo "src/gz openwrt_packages http://downloads.openwrt.org/releases/packages-$hardware_release/$hardware_arch/packages" >> /etc/opkg/distfeeds.conf
					echo "src/gz openwrt_routing http://downloads.openwrt.org/releases/packages-$hardware_release/$hardware_arch/routing" >> /etc/opkg/distfeeds.conf && log "新建文件/etc/opkg/distfeeds.conf"
					opkg update
					[ "$?" != 0 ] && echo -e "\n更新源$RED连接失败$RESET！请检查 $BLUE/etc/opkg/distfeeds.conf$RESET 中的地址是否正确并有效！" && sleep 2 && main
				}
			}
			if [ "$autorestore" ];then
				opkgpackagesurl=$(cat /etc/opkg/distfeeds.conf | grep openwrt_packages | awk '{print $3}')
				echo -e "即将尝试下载 $YELLOW$1$RESET ······ \c" && sleep 2
				http_code=$(curl --connect-timeout 3 -sLko /tmp/$1.ipk -w "%{http_code}" $opkgpackagesurl/$(opkg info $1 | grep name | awk '{print $2}'))
				if [ $? = 0 -a $http_code = 200 ];then
					echo -e "$GREEN下载成功！$RESET" && sleep 2
					[ "$1" = "unzip" -o "$1" = "etherwake" ] && {
						mkdir -p /data/$1 /tmp/$1
						tar -zxf /tmp/$1.ipk ./data.tar.gz -C /tmp/$1
						tar -zxf /tmp/$1/data.tar.gz ./usr/bin/$1 -C /tmp/$1
						mv -f /tmp/$1/usr/bin/$1 /data/$1/$1
						[ $? != 0 ] && echo -e "\n$BLUE/data $RED文件夹空间不足，安装失败！$RESET" && rm -rf /tmp/$1 /tmp/$1.ipk /data/$1 && sleep 2 && main
						[ "$1" = "etherwake" ] && {
							ln -sf /data/$1/$1 /usr/bin/$1
							echo -e "#!/bin/sh /etc/rc.common\n\nSTART=95\n\nwhile [ \"\$(cat /proc/xiaoqiang/boot_status)\" != 3 ];do sleep 1;done\nln -sf /data/etherwake/etherwake /usr/bin/etherwake\n\nstart() {\n\t[ -s /data/etherwake/etherwake_list ] && while read LINE;do [ ! \"\$(grep -F \"\$LINE\" /etc/crontabs/root)\" ] && echo \"\$LINE\" >> /etc/crontabs/root;done < /data/etherwake/etherwake_list\n\t/etc/init.d/cron restart\n}" > /data/$1/service_$1 && chmod 755 /data/$1/service_$1 && sed -i "/$1/d;/exit 0/i/data/$1/service_$1 restart &" /data/start_service_by_firewall
						}
					}
					[ "$1" = "aria2" ] && {
						mkdir -p $sdadir /tmp/$1
						tar -zxf /tmp/$1.ipk ./data.tar.gz -C /tmp/$1
						tar -zxf /tmp/$1/data.tar.gz ./usr/bin/aria2c -C /tmp/$1
						mv -f /tmp/$1/usr/bin/aria2c $sdadir/aria2c
						[ $? != 0 ] && echo -e "\n$BLUE$sdadir $RED文件夹空间不足，安装失败！$RESET" && rm -rf /tmp/$1 /tmp/$1.ipk $sdadir && sleep 2 && main
					}
					[ "$1" = "ariang" ] && {
						mkdir -p $sdadir /tmp/$1
						tar -zxf /tmp/$1.ipk ./data.tar.gz -C /tmp/$1
						tar -zxf /tmp/$1/data.tar.gz ./www/$1 -C /tmp/$1
						mv -f /tmp/$1/www/$1 $sdadir/$1
						[ $? != 0 ] && echo -e "\n$BLUE$sdadir $RED文件夹空间不足，安装失败！$RESET" && rm -rf /tmp/$1 /tmp/$1.ipk $sdadir && sleep 2 && main
					}
					[ "$1" = "vsftpd" ] && {
						mkdir -p /data/$1 /tmp/$1
						tar -zxf /tmp/$1.ipk ./data.tar.gz -C /tmp/$1
						tar -zxf /tmp/$1/data.tar.gz ./usr/sbin/$1 -C /tmp/$1
						mv -f /tmp/$1/usr/sbin/$1 /data/$1/$1
						[ $? != 0 ] && echo -e "\n$BLUE/data $RED文件夹空间不足，安装失败！$RESET" && rm -rf /tmp/$1 /tmp/$1.ipk /data/$1 && sleep 2 && main
						ln -sf /data/$1/$1 /usr/sbin/$1
						echo -e "#!/bin/sh /etc/rc.common\n\nSTART=50\n\nwhile [ \"\$(cat /proc/xiaoqiang/boot_status)\" != 3 ];do sleep 1;done\nln -sf /data/$1/service_$1 /etc/init.d/$1\n\nstart() {\n\texistedpid=\$(ps | grep -v grep | grep $1 | awk '{print \$1}');for pid in \$existedpid;do [ \$pid != \$\$ ] && killpid \$pid;done\n\t. /data/vsftpd/vsftpd.conf && [ ! \"\$(grep \"^ftp\\\t.*\$listen_port/tcp$\" /etc/services)\" ] && sed -i \"s/^ftp\\\t.*tcp\$/ftp\\\t\\\t\$listen_port\/tcp/\" /etc/services\n\tln -sf /data/vsftpd/vsftpd /usr/sbin/vsftpd\n\tln -sf /data/vsftpd/vsftpd.conf /etc/vsftpd.conf\n\tsed -i 's#/root#/#;s#^ftp:.*#ftp:*:55:55:ftp:/:/bin/false#' /etc/passwd\n\t[ -s /data/vsftpd/users ] && while read LINE;do\n\t\t[ ! \"\$(grep \$(echo \$LINE | awk '{print \$1}') /etc/passwd)\" ] && {\n\t\t\techo \"\$(echo \"\$LINE\" | awk '{print \$1}'):x:0:0:root:/:/bin/ash\" >> /etc/passwd\n\t\t\techo -e \"\$(echo \"\$LINE\" | awk '{print \$2}')\\\n\$(echo \"\$LINE\" | awk '{print \$2}')\" | passwd \$(echo \"\$LINE\" | awk '{print \$1}') &> /dev/null\n\t\t}\n\tdone < /data/vsftpd/users\n\tmkdir -m 0755 -p /var/run/vsftpd\n\tservice_start /usr/sbin/vsftpd\n}\n\nstop() {\n\tservice_stop /usr/sbin/vsftpd\n}" > /data/$1/service_$1 && chmod 755 /data/$1/service_$1 && ln -sf /data/$1/service_$1 $autostartfileinit && newuser=1
					}
					[ "$1" = "transmission-web" ] && {
						mkdir -p $sdadir /tmp/$1
						tar -zxf /tmp/$1.ipk ./data.tar.gz -C /tmp/$1
						tar -zxf /tmp/$1/data.tar.gz ./usr/share/transmission -C /tmp/$1
						mv -f /tmp/$1/usr/share/transmission/web $sdadir/web
						[ $? != 0 ] && echo -e "\n$BLUE$sdadir $RED文件夹空间不足，安装失败！$RESET" && rm -rf /tmp/$1 /tmp/$1.ipk $sdadir && sleep 2 && main
					}
					[ "$1" = "transmission-daemon-openssl" ] && {
						mkdir -p $sdadir/config /tmp/$1
						tar -zxf /tmp/$1.ipk ./data.tar.gz -C /tmp/$1
						tar -zxf /tmp/$1/data.tar.gz ./etc/init.d/transmission -C /tmp/$1
						tar -zxf /tmp/$1/data.tar.gz ./etc/config/transmission -C /tmp/$1
						tar -zxf /tmp/$1/data.tar.gz ./usr/bin/transmission-daemon -C /tmp/$1
						mv -f /tmp/$1/etc/config/transmission $sdadir/config/transmission
						mv -f /tmp/$1/etc/init.d/transmission $sdadir/service_transmission
						mv -f /tmp/$1/usr/bin/transmission-daemon $sdadir/transmission-daemon
						[ $? != 0 ] && echo -e "\n$BLUE$sdadir $RED文件夹空间不足，安装失败！$RESET" && rm -rf /tmp/$1 /tmp/$1.ipk $sdadir && sleep 2 && main
						sed -i "/PROG=/a\\\nwhile [ \"\$(cat /proc/xiaoqiang/boot_status)\" != 3 ];do sleep 1;done\nln -sf $sdadir/service_transmission /etc/init.d/transmission\nln -sf $sdadir/config/transmission /etc/config/transmission\nln -sf $sdadir/transmission-daemon /usr/bin/transmission-daemon" $sdadir/service_transmission
						sed -i "/start_service()/a\\\tfor lib in \$(ls -l $sdadir | awk '{print \$NF}' | grep ^lib);do ln -sf $sdadir/\$lib /usr/lib/\$lib;done\n\tsysctl -w net.core.wmem_max=1048576 &> /dev/null\n\tsysctl -w net.core.rmem_max=4194304 &> /dev/null\n\tsysctl -w net.ipv4.tcp_adv_win_scale=4 &> /dev/null" $sdadir/service_transmission
						ln -sf $sdadir/service_transmission /etc/init.d/transmission
					}
					[ "$(echo $1 | grep ^lib)" ] && {
						mkdir -p $sdadir /tmp/$1
						tar -zxf /tmp/$1.ipk ./data.tar.gz -C /tmp/$1
						tar -zxf /tmp/$1/data.tar.gz ./usr/lib -C /tmp/$1
						mv -f /tmp/$1/usr/lib/* $sdadir
						[ $? != 0 ] && echo -e "\n$BLUE$sdadir $RED文件夹空间不足，安装失败！$RESET" && rm -rf /tmp/$1 /tmp/$1.ipk $sdadir && sleep 2 && main
					}
					rm -rf /tmp/$1 /tmp/$1.ipk
				else
					rm -f /tmp/$1.ipk && echo -e "$RED下载失败！$RESET请检查 $BLUE/etc/opkg/distfeeds.conf$RESET 中的地址是否正确！" && sleep 2 && main
				fi
			else
				opkg install $1
				[ "$?" != 0 ] && echo -e "\n安装 ${YELLOW}$1$RED 失败！$RESET请检查 $BLUE/etc/opkg/distfeeds.conf$RESET 中的地址是否正确或 ${SKYBLUE}/overlay$RESET 空间是否足够后重试！" && sleep 2 && main
				[ "$1" = "ariang" ] && mkdir -p $sdadir && ln -sf /usr/bin/aria2c $sdadir/aria2c
				echo -e "\n$GREEN安装 $YELLOW$1$GREEN 成功$RESET" && sleep 2 && [ "$1" = "vsftpd" ] && newuser=1
			fi
		}
		[ "$1" = "transmission-daemon-openssl" ] && for depends in $($sdadir/transmission-daemon -v 2>&1 | grep lib | awk '{print $5}' | grep -oE 'lib[a-z]{1,20}');do opkg_test_install "$depends";done
	}
	[ "$1" = "vsftpd" ] && {
		[ ! "$newuser" ] && {
			echo -e "\n$PINK是否需要重新配置参数？$RESET" && num="$2"
			echo "---------------------------------------------------------"
			echo "1. 重新配置"
			echo "---------------------------------------------------------"
			echo "0. 返回主页面"
			while [ ! "$num" ];do
				echo -ne "\n"
				read -p "请输入对应选项的数字 > " num
				[ "$(echo $num | sed 's/[0-9]//g')" -o ! "$num" ] && num="" && continue
				[ "$num" -gt 1 ] && num="" && continue
				[ "$num" -eq 0 ] && main
			done
		}
		echo -e "\n$PINK请输入要设置的 FTP 监听端口$RESET" && ftpnum="$3"
		echo "---------------------------------------------------------"
		echo -e "1. 使用默认端口（${YELLOW}21$RESET）"
		echo "---------------------------------------------------------"
		echo "0. 返回上一页"
		while [ ! "$ftpnum" ];do
			echo -ne "\n"
			read -p "请输入要设置的 FTP 监听端口 > " ftpnum
			[ "$(echo $ftpnum | sed 's/[0-9]//g')" -o ! "$ftpnum" ] && ftpnum="" && continue
			[ "$ftpnum" -gt 65535 ] && ftpnum="" && continue
			[ "$ftpnum" -eq 0 ] && opkg_test_install "vsftpd"
			if [ "$ftpnum" != 1 ];then
				echo -e "\n当前设置的 FTP 监听端口为：$PINK$ftpnum$RESET" && cnum=""
				while [ ! "$cnum" ];do
					echo -ne "\n"
					read -p "确认请输入 1 ，返回修改请输入 0 > " cnum
					[ "$(echo $cnum | sed 's/[0-9]//g')" -o ! "$cnum" ] && cnum="" && continue
					[ "$cnum" -gt 1 ] && cnum="" && continue
					[ "$cnum" -eq 0 ] && ftpnum=""
				done
				process=$(netstat -lnWp | grep tcp | grep ":$ftpnum " | awk '{print $NF}' | sed 's/.*\///' | head -1)
				[ "$process" -a "$process" != "$1" ] && echo -e "\n$RED检测到 $PINK$ftpnum $RED端口已被 $YELLOW$process $RED占用！请重新设置！$RESET" && ftpnum="" && sleep 1
			else
				ftpnum=21
			fi
		done
		echo -e "\n$PINK是否允许匿名登陆？$RESET" && anonymous="$4" && anonymousdir="$5"
		echo "---------------------------------------------------------"
		echo "1. 允许匿名登陆"
		echo "2. 禁止匿名登陆"
		echo "---------------------------------------------------------"
		echo "0. 返回上一页"
		while [ ! "$anonymous" ];do
			echo -ne "\n"
			read -p "请输入对应选项的数字 > " anonymous
			[ "$(echo $anonymous | sed 's/[0-9]//g')" -o ! "$anonymous" ] && anonymous="" && continue
			[ "$anonymous" -gt 2 ] && anonymous="" && continue
			[ "$anonymous" -eq 0 ] && opkg_test_install "vsftpd" "$num"
			[ "$anonymous" = 1 ] && anonymous="YES" || anonymous="NO"
		done
		[ "$anonymous" = "YES" -a ! "$anonymousdir" ] && {
			echo -e "\n$PINK请输入匿名登陆默认路径：$RESET"
			echo "---------------------------------------------------------"
			echo "0. 返回上一页"
			echo "---------------------------------------------------------"
			while [ ! -d "$anonymousdir" -o "${anonymousdir:0:1}" != / ];do
				echo -ne "\n"
				read -p "请输入以 '/' 开头的路径地址（完整路径） > " anonymousdir
				[ "$anonymousdir" = 0 ] && opkg_test_install "vsftpd" "$num" "$ftpnum"
				[ ! -d "$anonymousdir" -o "${anonymousdir:0:1}" != / ] && echo -e "\n路径 $BLUE$anonymousdir $RED不存在！$RESET"
			done
			echo -e "\n$YELLOW$1$RESET 的匿名登陆默认路径已设置为：$BLUE$anonymousdir$RESET" && sleep 1
		}
		echo -e "\n$PINK是否允许用户名登陆？$RESET" && locals="" && localsdir="" && localswriteable="" && username=""
		echo "---------------------------------------------------------"
		echo "1. 允许用户名登陆"
		echo "2. 禁止用户名登陆"
		echo "---------------------------------------------------------"
		echo "0. 返回上一页"
		while [ ! "$locals" ];do
			echo -ne "\n"
			read -p "请输入对应选项的数字 > " locals
			[ "$(echo $locals | sed 's/[0-9]//g')" -o ! "$locals" ] && locals="" && continue
			[ "$locals" -gt 2 ] && locals="" && continue
			[ "$locals" -eq 0 ] && opkg_test_install "vsftpd" "$num" "$ftpnum"
			[ "$locals" = 1 ] && locals="YES" || locals="NO"
		done
		[ "$locals" = "YES" ] && {
			echo -e "\n$PINK请设置登陆用户名（以前有设置过的可跳过）：$RESET"
			sed -i 's#/root#/#;s#^ftp:.*#ftp:*:55:55:ftp:/:/bin/false#' /etc/passwd
			echo "---------------------------------------------------------"
			echo "0. 跳过设置"
			echo "---------------------------------------------------------"
			while [ ! "$username" ];do
				echo -ne "\n"
				read -p "请设置登陆用户名（不可带标点符号或空格） > " username
				[ "$(echo $username | sed 's/[0-9a-zA-Z]//g')" -o "$(echo $username | grep ' ')" -o ! "$username" ] && username="" && continue
				for tmp in $(cat /etc/passwd | awk -F ':' '{print $1}') $(cat /data/$1/users 2> /dev/null | awk '{print $1}');do
					[ "$username" = "$tmp" ] && echo -e "\n用户名 $PINK$username$RESET 已存在！$RED请重新设置！$RESET" && username="" && break
				done
			done
			[ ! "$(echo $username | sed 's/[0-9]//g')" ] && [ "$username" -eq 0 ] && username=""
			[ "$username" ] && {
				echo -e "\n$PINK请设置登陆密码：$RESET" && password=""
				echo "---------------------------------------------------------"
				echo "0. 返回上一页"
				echo "---------------------------------------------------------"
				while [ ! "$password" ];do
					echo -ne "\n"
					read -p "请设置登陆密码（不可有空格） > " password
					[ "$(echo "$password" | grep ' ')" -o ! "$password" ] && password="" && continue
				done
				[ ! "$(echo $password | sed 's/[0-9]//g')" ] && [ "$password" -eq 0 ] && opkg_test_install "vsftpd" "$num" "$ftpnum" "$anonymous" "$anonymousdir"
				echo -e "\n登录密码已设置为：$PINK$password$RESET" && sleep 1
			}
			echo -e "\n$PINK请输入用户名登陆默认路径：$RESET"
			echo "---------------------------------------------------------"
			echo "0. 返回上一页"
			echo "---------------------------------------------------------"
			while [ ! -d "$localsdir" -o "${localsdir:0:1}" != / ];do
				echo -ne "\n"
				read -p "请输入以 '/' 开头的路径地址（完整路径） > " localsdir
				[ "$localsdir" = 0 ] && opkg_test_install "vsftpd" "$num" "$ftpnum" "$anonymous" "$anonymousdir"
				[ ! -d "$localsdir" -o "${localsdir:0:1}" != / ] && echo -e "\n路径 $BLUE$localsdir $RED不存在！$RESET"
			done
			echo -e "\n$YELLOW$1$RESET 的用户名登陆默认路径已设置为：$BLUE$localsdir$RESET" && sleep 1
		}
		[ ! "$(grep "^ftp\t.*$ftpnum/tcp$" /etc/services)" ] && {
			[ ! -f /etc/services.backup ] && cp -f /etc/services /etc/services.backup && log "备份/etc/services文件并改名为services.backup"
			sed -i "s/^ftp\t.*tcp$/ftp\t\t$ftpnum\/tcp/" /etc/services && log "/etc/services文件ftp端口修改为$ftpnum"
		}
		[ "$autorestore" ] && echo -e "listen=NO\nlisten_ipv6=YES\nlisten_port=$ftpnum\nbackground=YES\ncheck_shell=NO\nwrite_enable=YES\nsession_support=YES\ntext_userdb_names=YES\nanonymous_enable=$anonymous\nanon_root=$anonymousdir\nlocal_enable=$locals\nlocal_root=$localsdir\nchroot_local_user=YES\nallow_writeable_chroot=YES\nlocal_umask=080\nfile_open_mode=0777\nuser_config_dir=/data/vsftpd/cfg/" > /data/vsftpd/vsftpd.conf || echo -e "listen=NO\nlisten_ipv6=YES\nlisten_port=$ftpnum\nbackground=YES\ncheck_shell=NO\nwrite_enable=YES\nsession_support=YES\ntext_userdb_names=YES\nanonymous_enable=$anonymous\nanon_root=$anonymousdir\nlocal_enable=$locals\nlocal_root=$localsdir\nchroot_local_user=YES\nallow_writeable_chroot=YES\nlocal_umask=080\nfile_open_mode=0777\nuser_config_dir=/cfg/vsftpd/" > /etc/vsftpd.conf
		while [ "$(pidof $1)" ];do killpid $(pidof $1 | awk '{print $1}');done && firewalllog "del" "$1" && runtimecount=0 && /etc/init.d/$1 restart &> /dev/null && /etc/init.d/$1 enable
		while [ ! "$(pidof $1)" -a "$runtimecount" -lt 5 ];do let runtimecount++;sleep 1;done
		if [ "$(pidof $1)" ];then
			firewalllog "add" "$1" "wan${ftpnum}rdr1" "tcp" "1" "wan" "$ftpnum" "$ftpnum"
			echo -e "\n$YELLOW$1$RESET 端口转发规则 $GREEN已全部更新$RESET，即将重启防火墙 ······" && sleep 2 && /etc/init.d/firewall restart &> /dev/null
			echo -e "\n配置完成！ $YELLOW$1 $GREEN已运行$RESET并设置为$YELLOW开机自启动！$RESET"
			[ "$anonymous" = "YES" ] && chmod 775 $anonymousdir
			[ "$username" ] && {
				echo "$username:x:0:0:root:/:/bin/ash" >> /etc/passwd && log "添加用户名$username到/etc/passwd文件中"
				echo -e "$password\n$password" | passwd $username
				[ "$autorestore" ] && echo "$username $password" >> /data/$1/users
			}
			[ "$autorestore" ] && sed -i "/$1/d;/exit 0/i/data/$1/service_$1 restart &" /data/start_service_by_firewall
		else
			echo -e "\n$RED启动失败！$RESET请尝试修改 $BLUE/etc/opkg/distfeeds.conf$RESET 中的地址后重试安装！"
			rm -rf /etc/vsftpd.conf /data/vsftpd && opkg remove vsftpd &> /dev/null && echo -e "\n${RED}已自动使用 opkg 卸载 $YELLOW$1$RESET"
			[ -f /etc/services.backup ] && mv -f /etc/services.backup /etc/services && log "恢复/etc/services.backup文件并改名为services"
		fi
		main
	}
	[ "$1" = "etherwake" ] && {
		echo -e "\n$PINK请输入你的选项$RESET" && num="$2"
		echo "---------------------------------------------------------"
		echo "1. 实时网路唤醒网络设备"
		echo "2. 添加定时网络唤醒任务"
		echo "3. 删除已添加定时网路唤醒任务"
		echo "---------------------------------------------------------"
		echo "0. 返回主页面"
		while [ ! "$num" ];do
			echo -ne "\n"
			read -p "请输入对应选项的数字 > " num
			[ "$(echo $num | sed 's/[0-9]//g')" -o ! "$num" ] && num="" && continue
			[ "$num" -gt 3 ] && num="" && continue
			[ "$num" -eq 0 ] && main
		done
		if [ "$num" != 3 ];then
			echo -e "\n$PINK请选择需要操作的设备：$RESET" && devnum=""
			echo "---------------------------------------------------------"
			if [ -f /tmp/dhcp.leases ];then
				echo -e "${GREEN}ID\t$SKYBLUE设备 MAC 地址\t\t$PINK设备 IP 地址\t$GREEN设备名称$RESET"
				cat /tmp/dhcp.leases | awk '{print NR":'$SKYBLUE'\t"$2"'$PINK'\t"$3"'$GREEN'\t"$4"'$RESET'"}'
			else
				echo -e "$RED获取设备列表失败！请手动输入 MAC 地址进行继续$RESET"
			fi
			echo -e "255.\t$SKYBLUE手动输入 MAC 地址$RESET"
			echo "---------------------------------------------------------"
			echo -e "0.\t返回上一页"
			while [ ! "$devnum" ];do
				echo -ne "\n"
				read -p "请输入对应设备的数字 > " devnum
				[ "$(echo $devnum | sed 's/[0-9]//g')" -o ! "$devnum" ] && devnum="" && continue
				if [ -f /tmp/dhcp.leases ];then
					[ "$devnum" -gt $(cat /tmp/dhcp.leases | wc -l) -a "$devnum" != 255 ] && devnum="" && continue
				else
					[ "$devnum" != 255 ] && devnum="" && continue
				fi
				[ "$devnum" -eq 0 ] && opkg_test_install "etherwake"
			done
			devmac=$(sed -n ${devnum}p /tmp/dhcp.leases 2> /dev/null | awk '{print $2}')
			devname=" $(sed -n ${devnum}p /tmp/dhcp.leases 2> /dev/null | awk '{print $4}') "
			[ "$devnum" = 255 ] && {
				echo -e "\n$PINK请输入 xx:xx:xx:xx:xx:xx 格式的 MAC 地址：$RESET" && devmac=""
				echo "---------------------------------------------------------"
				while [ ! "$devmac" ];do
					echo -ne "\n"
					read -p "请输入 xx:xx:xx:xx:xx:xx 格式的 MAC 地址 > " devmac
					devmac=$(echo $devmac | awk '{print tolower($0)}')
					[ ! "$devmac" ] && continue
					[ "$devmac" = 0 ] && opkg_test_install "etherwake" "$num"
					[ ! "$(echo $devmac |grep -E '^([0-9a-f][02468ace])(([:]([0-9a-f]{2})){5})$')" ] && echo -e "\n$RED输入错误！请重新输入！$RESET" && devmac="" && continue
				done
			}
			if [ "$num" = 1 ];then
				etherwake -i br-lan $devmac &> /dev/null && echo -e "\n$SKYBLUE$devmac$GREEN$devname$YELLOW发送网络唤醒包成功！$RESET" && sleep 1
			else
				echo -e "\n$PINK请输入要设置的分钟时间（ 0-59 ）：$RESET" && minute=""
				echo "---------------------------------------------------------"
				while [ ! "$minute" ];do
					echo -ne "\n"
					read -p "请输入要设置的分钟时间（ 0-59 ) > " minute
					[ "$(echo $minute | sed 's/[0-9]//g')" -o ! "$minute" ] && minute="" && continue
					[ "$minute" -lt 0 -o "$minute" -gt 59 ] && minute=""
				done
				echo -e "\n$PINK请输入要设置的整点时间（ 0-23 ）：$RESET" && hour=""
				echo "---------------------------------------------------------"
				while [ ! "$hour" ];do
					echo -ne "\n"
					read -p "请输入要设置的整点时间（ 0-23 ) > " hour
					[ "$(echo $hour | sed 's/[0-9]//g')" -o ! "$hour" ] && hour="" && continue
					[ "$hour" -lt 0 -o "$hour" -gt 23 ] && hour=""
				done
				echo -e "\n$PINK请输入要设置的星期时间（ 1-7 或 *：每天 ）：$RESET" && week=""
				echo "---------------------------------------------------------"
				while [ ! "$week" ];do
					echo -ne "\n"
					read -p "请输入要设置的星期时间（ 1-7 或 *：每天 ) > " week
					[ "$week" = "*" ] && break
					[ "$(echo $week | sed 's/[0-9]//g')" -o ! "$week" ] && week="" && continue
					[ "$week" -lt 1 -o "$week" -gt 7 ] && week=""
				done
				case $week in
					1)wolinfo="每周一";;
					2)wolinfo="每周二";;
					3)wolinfo="每周三";;
					4)wolinfo="每周四";;
					5)wolinfo="每周五";;
					6)wolinfo="每周六";;
					7)wolinfo="每周日";;
					*)wolinfo="每天";;
				esac
				echo "$minute $hour * * $week etherwake -i br-lan $devmac #$wolinfo $(printf "%02d" $hour)点$(printf "%02d" $minute)分 网络唤醒设备 $devmac$devname" >> /etc/crontabs/root && /etc/init.d/cron restart &> /dev/null
				[ "$autorestore" ] && echo "$minute $hour * * $week etherwake -i br-lan $devmac #$wolinfo $(printf "%02d" $hour)点$(printf "%02d" $minute)分 网络唤醒设备 $devmac$devname" >> /data/$1/$1_list
				echo -e "\n$YELLOW定时任务 $PINK$wolinfo $(printf "%02d" $hour)点$(printf "%02d" $minute)分 网络唤醒设备 $SKYBLUE$devmac$GREEN$devname$YELLOW任务添加成功！$RESET" && sleep 1
			fi
		else
			num="" && while [ ! "$num" ];do
				if [ "$(cat "/etc/crontabs/root" | grep '网络唤醒')" ];then
					echo -e "\n$PINK请输入要删除的任务序号：$RESET"
					echo "---------------------------------------------------------"
					cat "/etc/crontabs/root" | grep '网络唤醒' | sed 's/.*#//' | awk '{print NR": "$0}'
					echo "---------------------------------------------------------"
					echo "0. 返回上一页"
					echo -ne "\n"
					read -p "请输入正确的任务序号 > " num
					[ "$(echo $num | sed 's/[0-9]//g')" -o ! "$num" ] && num="" && continue
					[ "$num" -gt $(cat "/etc/crontabs/root" | grep '网络唤醒' | sed 's/.*#//' | wc -l) ] && num="" && continue
					[ "$num" -eq 0 ] && opkg_test_install "etherwake"
					ruleweek=$(cat "/etc/crontabs/root" | grep '网络唤醒' | sed 's/.*#//' | sed -n ${num}p | awk '{print $1}')
					ruletime=$(cat "/etc/crontabs/root" | grep '网络唤醒' | sed 's/.*#//' | sed -n ${num}p | awk '{print $2}')
					rulemac=$(cat "/etc/crontabs/root" | grep '网络唤醒' | sed 's/.*#//' | sed -n ${num}p | awk '{print $4}')
					rulename=" $(cat "/etc/crontabs/root" | grep '网络唤醒' | sed 's/.*#//' | sed -n ${num}p | awk '{print $5}') "
					sed -i "/$ruleweek $ruletime/{/$rulemac/d}" /etc/crontabs/root && /etc/init.d/cron restart &> /dev/null
					[ "$autorestore" ] && sed -i "/$ruleweek $ruletime/{/$rulemac/d}" /data/$1/$1_list 2> /dev/null
					echo -e "\n$YELLOW定时任务 $PINK$ruleweek $ruletime 网络唤醒设备 $SKYBLUE$rulemac$GREEN$rulename$YELLOW任务删除成功！$RESET" && sleep 1 && num=""
				else
					echo -e "\n$RED当前没有定时网络唤醒设备任务！$RESET" && sleep 1 && opkg_test_install "etherwake"
				fi
			done
		fi
		opkg_test_install "etherwake"
	}
	return 0
}
sdadir_available_check(){
	sdadiravailable=$(df | grep " ${sdadir%/*}$" | awk '{print $4}') && upxneeded=""
	sizeneeded=$(echo $4 | grep -oE [0-9]{1,10})
	[ "$(echo $4 | grep MB)" ] && sizeneeded=$(($(echo $4 | grep -oE [0-9]{1,10})*1024))
	[ "$(echo $4 | grep GB)" ] && sizeneeded=$(($(echo $4 | grep -oE [0-9]{1,10})*1024*1024))
	if [ ! "$(echo $1 | grep -oE 'aria2|vsftpd|transmission|docker|homeassistant')" ];then
		[ "$sdadiravailable" -lt $sizeneeded ] && {
			echo -e "\n所选目录 $BLUE${sdadir%/*} $RED空间不足 $(($sizeneeded/1024)) MB$RESET！无法直接下载使用！不过可以尝试使用 ${YELLOW}upx$RESET 压缩后使用" && sleep 2
			tmpdiravailable=$(df | grep " /tmp$" | awk '{print $4}')
			[ "$tmpdiravailable" -ge 102400 ] && {
				echo -e "\n检测到临时目录 $BLUE/tmp$RESET 可用空间为 $RED$(awk BEGIN'{printf "%0.3f MB",'$tmpdiravailable'/1024}')$RESET" && tmpnum=""
				echo -e "\n$RED临时目录内的文件会在路由器重启后丢失$RESET，使用的话，每次开机后将会自动重新下载主程序文件，是否使用临时目录？" && sleep 1
				while [ ! "$tmpnum" ];do
					echo -ne "\n"
					read -p "确认使用请输入 y ，尝试压缩后使用请输入 1 ，返回上一页请输入 0 > " tmpnum
					[ "$tmpnum" = y ] && tmpdir="/tmp/XiaomiSimpleInstallBox" && echo -e "\n若使用临时目录一段时间后，重启路由器$YELLOW自动下载失败$RESET则可能是 ${YELLOW}github加速镜像 $RED已失效$RESET，届时可以运行本脚本重新下载以$GREEN更新开机时的下载地址$RESET" && sleep 3 && break
					[ "$(echo $tmpnum | sed 's/[0-9]//g')" -o ! "$tmpnum" ] && tmpnum="" && continue
					[ "$tmpnum" -gt 1 ] && tmpnum="" && continue
					[ "$tmpnum" -eq 0 ] && sda_install_remove "$1" "$2" "$3" "$4" "$5" "$6" "$7" "return"
				done
			}
			[ ! "$tmpdir" ] && {
				echo -e "\n下载完成后请使用电脑利用 ${YELLOW}upx$RESET 压缩器对其进行压缩"
				echo -e "\n${YELLOW}upx$RESET 主程序可以在 ${SKYBLUE}https://github.com/upx/upx/releases/latest$RESET 下载"
				echo -e "\n使用方法：下载完成后，先将 $YELLOW$2$RESET 文件放到 ${YELLOW}upx$RESET 主程序所在的同一个目录"
				echo -e "\n然后在 ${YELLOW}upx$RESET 主程序所在的目录内打开 ${YELLOW}cmd 控制台$RESET并输入：${PINK}upx --best $2$RESET" && sleep 5 && upxneeded=1
				[ -f /tmp/$2 ] && {
					echo -e "\n发现已下载好的 $YELLOW$2$RESET 主程序文件，是否直接尝试对其进行压缩？" && upxretry=""
					echo -e "\n$PINK请输入你的选项：$RESET"
					echo "---------------------------------------------------------"
					echo "1. 直接尝试"
					echo "---------------------------------------------------------"
					echo "0. 重新下载"
					while [ ! "$upxretry" ];do
						echo -ne "\n"
						read -p "请输入对应选项的数字 > " upxretry
						[ "$(echo $upxretry | sed 's/[0-9]//g')" -o ! "$upxretry" ] && upxretry="" && continue
						[ "$upxretry" -gt 1 ] && upxretry=""
					done
				}
			}
		}
	else
		[ "$sdadiravailable" -lt $sizeneeded ] && echo -e "\n所选目录 $BLUE${sdadir%/*} $RED空间不足 $(($sizeneeded/1024)) MB！无法安装！$RESET" && sleep 2 && num="" && return 1
		[ "$1" = "docker" ] && {
			[ ! "$miAARCH64" ] && echo -e "\n$RED本脚本 ${YELLOW}Docker $RED仅支持在$YELLOW aarch64 $RED架构的小米路由器中安装！本机处理器架构为 $YELLOW$(uname -m) $RED，无法安装！请自行查找其它安装方式！$RESET" && sleep 2 && main
			[ "$(df -T | grep ${sdadir%/*}$ | awk '{print $2}')" != "ext4" ] && echo -e "\n${YELLOW}Docker $RED仅支持安装在$YELLOW ext4 $RED格式的分区中！所选目录 $BLUE${sdadir%/*} $RED分区格式为 $YELLOW$(df -T | grep ${sdadir%/*}$ | awk '{print $2}') $RED，无法安装！请选择其它安装路径$RESET" && sleep 2 && num=""
		}
	fi
	return 0
}
github_download(){
	for MIRROR in $MIRRORS;do
		echo -e "\n尝试使用加速镜像 $SKYBLUE$MIRROR$RESET 下载"
		http_code=$(curl --connect-timeout 3 -m 20 -w "%{http_code}" -#Lko /tmp/$1 "$MIRROR$2")
		if [ $? = 0 -a $http_code = 200 ];then
			url="$MIRROR$2" && break
		else
			rm -f /tmp/$1
			echo -e "\n$RED下载失败！$RESET即将尝试使用下一个加速镜像进行尝试 ······" && sleep 2
		fi
	done
	[ -f /tmp/$1 ] && return 0 || return 1
}
firewalllog(){
	[ "$1" = "add" ] && {
		if [ "$5" = "1" ];then
			uci -q set firewall.$3=redirect
			uci -q set firewall.$3.name=$2-$3
			uci -q set firewall.$3.proto=$4
			uci -q set firewall.$3.ftype=$5
			uci -q set firewall.$3.dest_ip=$hostip
			uci -q set firewall.$3.src=$6
			uci -q set firewall.$3.dest=lan
			uci -q set firewall.$3.target=DNAT
			uci -q set firewall.$3.src_dport=$7
			uci -q set firewall.$3.dest_port=$8
			uci -q commit && log "更新$2-$3端口转发规则到/etc/config/firewall文件中"
		else
			uci -q set firewall.$3=redirect
			uci -q set firewall.$3.name=$2-$3
			uci -q set firewall.$3.proto=$4
			uci -q set firewall.$3.ftype=$5
			uci -q set firewall.$3.dest_ip=$hostip
			uci -q set firewall.$3.src=$6
			uci -q set firewall.$3.dest=lan
			uci -q set firewall.$3.target=DNAT
			uci -q set firewall.$3.src_dport=$7
			uci -q commit && log "更新$2-$3端口转发规则到/etc/config/firewall文件中"
		fi
		echo -e "\n$YELLOW$2$RESET 端口转发规则 $PINK$2-$3$RESET $GREEN已更新$RESET ······" && sleep 1
	}
	[ "$1" = "del" ] && {
		ruleexist=""
		while [ "$(uci show firewall | grep $2 | awk -F '.' '{print $2}' | head -1)" ];do
			firewallrule=$(uci show firewall | grep $2 | awk -F '.' '{print $2}' | head -1)
			uci -q del firewall.$firewallrule && uci -q commit && log "删除/etc/config/firewall文件中的端口转发规则$2-$firewallrule" && ruleexist=1
			echo -e "\n$YELLOW$2$RESET 端口转发规则 $PINK$2-$firewallrule$RESET $RED已删除$RESET ······" && sleep 1
		done
	}
	return 0
}
sda_install_remove(){
	sdalist=$(df | sed -n '1!p' | grep -vE "rom|tmp|ini|overlay|sys|lib|docker_disk" | awk '{print $6}' | grep -vE '^/$|/userdisk/|/data/|/etc/')
	autostartfileinit=/etc/init.d/$1 && autostartfilerc=/etc/rc.d/S95$1 && downloadfileinit=/etc/init.d/Download$1 && downloadfilerc=/etc/rc.d/S95Download$1 && tmpdir="" && old_tag="" && upxretry=0 && skipdownload="" && newuser="" && DNSINFO="" && adguardhomednsport=53
	[ "$3" = "del" ] && del="true" || del=""
	[ ! "$del" ] && {
		[ ! "$8" ] && {
			echo -e "\n$GREEN=========================================================$RESET"
			echo -e "\n$PINK\t[[  这里以下是 ${YELLOW}$1 $PINK的安装过程  ]]$RESET"
			echo -e "\n$YELLOW=========================================================$RESET"
		}
		[ "$1" = "vsftpd" ] && opkg_test_install "vsftpd"
	}
	for tmplist in $sdalist;do
		sdadir=$(find $tmplist -maxdepth 2 -name $2)
		for name in $sdadir;do
			[ -f "$name" -a "$(echo $name | grep -v '\.d')" -o -L "$name" -a "$(echo $name | grep -v '\.d')" ] && {
				sdadir=$name
				[ -L "$sdadir" -a "$(echo $name | grep -v '\.d')" ] && tmpdir="/tmp/XiaomiSimpleInstallBox"
				break
			}
		done
		[ -f "$sdadir" -a "$(echo $name | grep -v '\.d')" -o -L "$sdadir" -a "$(echo $name | grep -v '\.d')" ] && break || sdadir=""
	done
	if [ ! "$sdadir" ];then
		if [ ! "$del" ];then
			[ "$1" = "homeassistant" ] && echo -e "\n请先安装 ${YELLOW}Docker$RESET ！" && sleep 2 && main
			echo -e "\n$PINK请选择下载保存路径：$RESET" && listcount="" && num=""
			echo "---------------------------------------------------------"
			echo -e "${GREEN}ID\t$SKYBLUE剩余可用空间\t\t$BLUE可选路径$RESET"
			for tmp in $sdalist;do
				let listcount++
				available=$(df | grep " $tmp$" | awk '{print $4}')
				if [ "$available" -lt 1048576 ];then
					available="$RED$(awk BEGIN'{printf "%0.3f MB",'$available'/1024}')$RESET"
				elif [ "$available" -lt 10485760 ];then
					available="$YELLOW$(awk BEGIN'{printf "%0.3f GB",'$available'/1024/1024}')$RESET"
				else
					available="$GREEN$(awk BEGIN'{printf "%0.3f GB",'$available'/1024/1024}')$RESET"
				fi
				echo -e "$listcount.\t$available     \t\t$tmp"
			done
			echo "---------------------------------------------------------"
			echo -e "0.\t返回主页面"
			while [ ! "$num" ];do
				echo -ne "\n"
				read -p "请输入对应目录的数字 > " num
				[ "$(echo $num | sed 's/[0-9]//g')" -o ! "$num" ] && num="" && continue
				[ "$num" -gt $listcount ] && num="" && continue
				[ "$num" -eq 0 ] && main
				sdadir=$(echo $sdalist | awk '{print $'$num'}')/$1 && [ ! "$skipdownload" ] && sdadir_available_check "$1" "$2" "$3" "$4" "$5" "$6" "$7"
			done
		else
			[ "$1" != "vsftpd" -a "$1" != "etherwake" -o "$1" = "vsftpd" -a ! -d /data/vsftpd -o "$1" = "etherwake" -a ! -d /data/etherwake ] && echo -e "\n$RED没有找到 $YELLOW$1 $RED的安装路径！若是通过 opkg 安装的即将通过 opkg 进行卸载$RESET" && sleep 2
		fi
	else
		sdadir=${sdadir%/*}
		[ ! "$del" ] && {
			old_tag=$(eval $sdadir/$2 $3 2> /dev/null | sed 's/.*v/v/;s/^[^v]/v&/');[ "$7" ] && $7
			[ "$1" = "homeassistant" ] && {
				opkg_test_install "unzip"
				echo -e "\n找到 $YELLOW$2$RESET 的安装路径：$BLUE$sdadir$RESET" && sleep 2 && export PATH=$sdadir:$PATH
				[ ! "$(ps | grep docker | grep -vE 'grep|docker_disk')" ] && echo -e "\n请先启动 ${YELLOW}Docker$RESET ！" && sleep 2 && main
				if [ ! -d $sdadir/homeassistant/custom_components/hacs ];then
					sdadir_available_check "$1" "$2" "$3" "$4";[ "$?" = 1 ] && main
					echo -e "\n$RED安装文件较多、安装时间视网络与外接硬盘性能而定，请耐心等候！$RESET"
					echo -e "\n$YELLOW获取 Home-Assistants 镜像 ······$RESET" && docker pull homeassistant/aarch64-homeassistant
					echo -e "\n$YELLOW下载 HACS 文件 ······$RESET" && github_download "hacs.zip" "https://github.com/hacs-china/integration/releases/latest/download/hacs.zip"
					[ "$?" != 0 ] && echo -e "$RED下载 HACS 文件失败！$RESET" && sleep 2 && main
					echo -e "\n$YELLOW解压 HACS 文件 ······$RESET" && mkdir -p $sdadir/homeassistant/custom_components/hacs && unzip -oq /tmp/hacs.zip -d $sdadir/homeassistant/custom_components/hacs && rm -f /tmp/hacs.zip
					echo -e "\n$YELLOW启动 Home-Assistants ······$RESET" && docker run -d --name Home-Assistants --restart=unless-stopped --privileged --network=host -e TZ=Asia/Shanghai -v $sdadir/homeassistant:/config homeassistant/aarch64-homeassistant &> /dev/null
					while [ ! "$(netstat -lnWp | grep :8123)" ];do sleep 1;done
					echo -e "\n${YELLOW}Home-Assistants $GREEN安装成功$RESET！请登陆网页 $SKYBLUE$hostip:8123 $RESET进行管理" && main
				else
					docker run -d --name Home-Assistants --restart=unless-stopped --privileged --network=host -e TZ=Asia/Shanghai -v $sdadir/homeassistant:/config homeassistant/aarch64-homeassistant &> /dev/null
					docker start Home-Assistants &> /dev/null
					while [ ! "$(netstat -lnWp | grep :8123)" ];do sleep 1;done
					echo -e "\n${YELLOW}Home-Assistants $GREEN启动成功$RESET！请登陆网页 $SKYBLUE$hostip:8123 $RESET进行管理" && sleep 2 && main
				fi
			}
		}
		if [ "$1" != "homeassistant" ];then
			[ "$old_tag" ] && echo -e "\n找到 $YELLOW$1 $PINK$old_tag$RESET 的安装路径：$BLUE$sdadir$RESET" || echo -e "\n找到 $YELLOW$1$RESET 的安装路径：$BLUE$sdadir$RESET"
			sleep 2
		else
			echo -e "\n找到 $YELLOW$2$RESET 的安装路径：$BLUE$sdadir$RESET" && sleep 2
		fi
	fi
	[ "$del" ] && {
		$autostartfileinit stop 2> /dev/null
		[ -f $autostartfileinit ] && rm -f $autostartfileinit && log "删除自启动文件$autostartfileinit"
		[ -L $autostartfilerc ] && rm -f $autostartfilerc
		[ -f $downloadfileinit ] && rm -f $downloadfileinit && log "删除自启动文件$downloadfileinit"
		[ -L $downloadfilerc ] && rm -f $downloadfilerc
		firewalllog "del" "$1" && [ "$ruleexist" ] && echo -e "\n$YELLOW$1$RESET 端口转发规则 $RED已全部删除$RESET，即将重启防火墙 ······" && sleep 2 && /etc/init.d/firewall restart &> /dev/null
		[ "$1" = "AdGuardHome" ] && [ -f /etc/config/dhcp.backup ] && mv -f /etc/config/dhcp.backup /etc/config/dhcp && /etc/init.d/dnsmasq restart &> /dev/null && log "恢复/etc/config/dhcp.backup文件并改名为dhcp"
		[ "$1" = "aria2" ] && rm -rf /www/ariang /usr/bin/aria2c && opkg remove ariang aria2 &> /dev/null
		[ "$1" = "vsftpd" ] && rm -rf /etc/vsftpd.conf /data/vsftpd && opkg remove vsftpd &> /dev/null && [ -f /etc/services.backup ] && mv -f /etc/services.backup /etc/services && log "恢复/etc/services.backup文件并改名为services"
		[ "$1" = "transmission" ] && rm -rf /etc/config/transmission /usr/share/transmission/ && opkg remove transmission-web transmission-daemon-openssl transmission-daemon-mbedtls libnatpmp libminiupnpc &> /dev/null
		[ "$1" = "设备禁止访问网页黑名单" ] && {
			iptables -D FORWARD -i br-lan -j DOMAIN_REJECT_RULE &> /dev/null;ip6tables -D FORWARD -i br-lan -j DOMAIN_REJECT_RULE &> /dev/null
			iptables -F DOMAIN_REJECT_RULE &> /dev/null;ip6tables -F DOMAIN_REJECT_RULE &> /dev/null
			iptables -X DOMAIN_REJECT_RULE &> /dev/null;ip6tables -X DOMAIN_REJECT_RULE &> /dev/null
			sed -i "/domainblacklist/d" /data/start_service_by_firewall &> /dev/null
			[ -f /data/domainblacklist ] && rm -f /data/domainblacklist && log "删除文件/data/domainblacklist"
			[ "$(grep domainblacklist /etc/crontabs/root 2> /dev/null)" ] && sed -i '/domainblacklist/d' /etc/crontabs/root && /etc/init.d/cron restart &> /dev/null && log "删除/etc/crontabs/root文件中的定时任务domainblacklist"
		}
		[ "$1" = "etherwake" ] && rm -rf /data/etherwake && opkg remove etherwake &> /dev/null && sed -i '/网络唤醒/d' /etc/crontabs/root && /etc/init.d/cron restart &> /dev/null
		[ "$1" = "docker" ] && {
			rm -rf /lib/libblkid-tiny.so /lib/libubox.so.20230523 /lib/libubus.so.20230605 /lib/libblobmsg_json.so.20230523 /sbin/block /usr/lib/libjson-c.so.5 /usr/lib/libjson-c.so.5.2.0 /lib/upgrade/keep.d/block-mount  /usr/bin/containerd usr/bin/containerd-shim /usr/bin/containerd-shim-runc-v2 /usr/bin/ctr /usr/bin/docker /usr/bin/docker-init /usr/bin/docker-proxy /usr/bin/dockerd /usr/bin/runc /usr/bin/swapoff /usr/bin/swapon /opt/containerd/ /run/blkid/ /run/containerd/ /run/docker/ && sed -i '/\/docker:$PATH/d' /etc/profile 2> /dev/null && sed -i '/./,/^$/!d' /etc/profile 2> /dev/null
			[ -f /etc/config/mi_docker.backup ] && mv -f /etc/config/mi_docker.backup /etc/config/mi_docker && log "恢复/etc/config/mi_docker.backup文件并改名为mi_docker"
			[ -f /etc/init.d/mi_docker.backup ] && mv -f /etc/init.d/mi_docker.backup /etc/init.d/mi_docker && log "恢复/etc/init.d/mi_docker.backup文件并改名为mi_docker"
			[ -f /etc/init.d/cgroup_init.backup ] && mv -f /etc/init.d/cgroup_init.backup /etc/init.d/cgroup_init && log "恢复/etc/init.d/cgroup_init.backup文件并改名为cgroup_init" && /etc/init.d/cgroup_init restart
		}
		[ "$sdadir" ] && [ "$1" = "docker" -o "$1" = "homeassistant" ] && {
			echo -e "\n$YELLOW删除文件较多、卸载时间视外接硬盘性能而定，请耐心等候！$RESET"
			while [ "$(ps | grep -E 's6-|assistant' | grep -v grep)" ];do killpid $(ps | grep -E 's6-|assistant' | grep -v grep | head -1 | awk '{print $1}');done
		}
		[ "$1" = "homeassistant" ] && {
			[ ! "$(ps | grep docker | grep -vE 'grep|docker_disk')" ] && echo -e "\n请先启动 ${YELLOW}Docker$RESET ！" && sleep 2 && main
			echo -e "\n$YELLOW正在停止运行 Home-Assistants ······$RESET" && docker stop Home-Assistants &> /dev/null
			docker rm Home-Assistants &> /dev/null
			echo -e "\n$YELLOW正在删除 Home-Assistants ······$RESET" && docker rmi homeassistant/aarch64-homeassistant &> /dev/null
			sdadir=$sdadir/homeassistant
		}
		[ "$sdadir" ] && rm -rf $sdadir && log "删除文件夹$sdadir"
		sed -i "/$1/d" /data/start_service_by_firewall &> /dev/null
		echo -e "\n$YELLOW$1 $RED已一键删除！$RESET" && sleep 1 && main
	}
	[ "$1" = "aria2" ] && opkg_test_install "ariang" && opkg_test_install "aria2"
	[ "$1" = "transmission" ] && opkg_test_install "transmission-web" && opkg_test_install "transmission-daemon-openssl"
	if [ ! "$(echo $1 | grep -oE 'aria2|transmission')" ];then
		[ "$1" = "zerotier" ] && [ -L "$sdadir/$2" ] && [ "$(file $sdadir/$2 | awk '{print $5}' | grep -oE '^/tmp/|^/var/')" ] && [ "$(wc -c 2> /dev/null < $sdadir/networks.d/$(ls $sdadir/networks.d/ 2> /dev/null | grep -v local))" = "1" -o ! -d $sdadir/networks.d -o ! -f /etc/init.d/Download$1 ] && {
			echo -e "\n${YELLOW}ZeroTier-one $RED在使用临时目录时必须在首次下载安装时设置好网络！$RESET"
			sda_install_remove "$1" "$2" "del"
		}
		[ "$upxretry" -eq 0 ] && {
			urls="https://github.com/$5/$6/releases/latest"
			tag_url="https://api.github.com/repos/$5/$6/releases/latest"
			echo -e "\n即将获取 ${YELLOW}$1$RESET 最新版本号并下载" && sleep 2 && rm -f /tmp/$1.tmp && retry_count=5 && tag_name=""
			while [ ! "$tag_name" -a $retry_count != 0 ];do
				echo -e "\n正在获取最新 ${YELLOW}$1$RESET 版本号 ······ \c" && adtagcount=0
				if [ "$1" = "AdGuardHome" ];then
					while [ ! "$(echo $tag_name | grep '\-b')" -a $adtagcount -le 5 ];do
						tag_url="https://api.github.com/repos/$5/$6/releases?per_page=1&page=$adtagcount"
						tag_name=$(curl -m 3 -sk "$tag_url" | grep tag_name | cut -f4 -d '"')
						[ "$?" = 0 ] && let adtagcount++
					done
				elif [ "$1" = "docker" ];then
					[ "$(curl -m 2 -sko /dev/null -w "%{http_code}" google.tw)" != 404 ] && echo -e "$RED获取失败！为保证顺利安装 $YELLOW$1 $RED请先开启本机代理！$RESET" && sleep 1 && main
					tag_name=$(curl -m 3 -sk https://download.docker.com/linux/static/stable/aarch64/ | grep docker-[0-9] | tail -1 | awk -F \> '{print $1}' | grep -oE '[0-9].*[0-9]')
				else
					tag_name=$(curl -m 3 -sk "$tag_url" | grep tag_name | cut -f4 -d '"')
				fi
				[ ! "$tag_name" ] && {
					let retry_count--
					[ $retry_count != 0 ] && echo -e "$RED获取失败！$RESET\n\n即将尝试重连······（剩余重试次数：$PINK$retry_count$RESET）" && sleep 1
				}
			done
			[ ! "$tag_name" ] && {
				echo -e "$RED获取失败！\n\n获取版本号失败！$RESET如果没有代理的话建议多尝试几次！"
				[ "$1" != "docker" ] && echo -e "\n如果响应时间很短但获取失败，则是每小时内的请求次数已超过 ${PINK}github$RESET 限制，请更换 ${YELLOW}IP$RESET 或者等待一段时间后再试！"
				sleep 1 && main
			}
			echo -e "$GREEN获取成功！$RESET当前最新版本：$PINK$(echo $tag_name | sed 's/^[^v].*[^.0-9]/v/')$RESET" && sleep 2
			[ "$old_tag" ] && {
				new_tag=$(echo $tag_name | sed 's/^[^v].*[^.0-9]/v/')
				[ "$old_tag" \> "$new_tag" -o "$old_tag" \= "$new_tag" ] && {
				echo -e "\n当前已安装最新版 $YELLOW$1 $PINK$(echo $tag_name | sed 's/^[^v].*[^.0-9]/v/')$RESET ，无需更新！$RESET" && sleep 2
				echo -e "\n$PINK是否重新下载？$RESET" && downloadnum=""
				echo "---------------------------------------------------------"
				echo "1. 重新下载"
				[ "$1" = "docker" ] && echo "2. 修改虚拟内存大小"
				echo "---------------------------------------------------------"
				echo "0. 跳过下载"
				while [ ! "$downloadnum" ];do
						echo -ne "\n"
						read -p "请输入对应选项的数字 > " downloadnum
						[ "$(echo $downloadnum | sed 's/[0-9]//g')" -o ! "$downloadnum" ] && downloadnum="" && continue
						[ "$downloadnum" -gt 2 -o "$1" != "docker" -a "$downloadnum" = 2 ] && downloadnum="" && continue
						[ "$downloadnum" -eq 0 ] && skipdownload=1 && [ "$1" = "docker" ] && /etc/init.d/$1 start 2> /dev/null && main
					done
				}
				[ "$downloadnum" = 2 ] && {
					echo -e "\n$PINK请选择需要修改的虚拟内存的大小（当前大小：$(ls -lh $sdadir/swapfile 2> /dev/null | awk '{print $5}')）$RESET" && swapsize=""
					echo -e "$YELLOW提示：虚拟内存对路由器性能没有提升，但能避免爆内存导致路由器死机。若外接硬盘性能过低甚至可能会产生负面效果！$RESET"
					echo "---------------------------------------------------------"
					echo "1. 512 MB"
					echo "2. 1024 MB ( 1 GB )"
					echo "3. 2048 MB ( 2 GB )"
					echo "4. 3072 MB ( 3 GB )"
					echo "5. 4096 MB ( 4 GB )"
					echo "6. 禁用虚拟内存"
					echo "---------------------------------------------------------"
					echo "0. 取消修改并返回主页面"
					while [ ! "$swapsize" ];do
						echo -ne "\n"
						read -p "请输入对应选项的数字 > " swapsize
						[ "$(echo $swapsize | sed 's/[0-9]//g')" -o ! "$swapsize" ] && swapsize="" && continue
						[ "$swapsize" -gt 6 ] && swapsize="" && continue
						[ "$swapsize" -eq 0 ] && main
						[ $swapsize = 1 ] && swapsize=512;[ $swapsize = 2 ] && swapsize=1024;[ $swapsize = 3 ] && swapsize=2048;[ $swapsize = 4 ] && swapsize=3072;[ $swapsize = 5 ] && swapsize=4096
						[ "$swapsize" != 6 ] && {
							let sizeneed=$swapsize*1024
							[ -f $sdadir/swapfile ] && {
								let sizeneed=$sizeneed-$(($(ls -l $sdadir/swapfile | awk '{print $5}')/1024))
								[ "$(($(ls -l $sdadir/swapfile | awk '{print $5}')/1024/1024))" = "$swapsize" ] && echo -e "\n$RED当前大小与所选大小一样，请重新选择！$RESET" && sleep 1 && swapsize="" && continue
							}
							[ $(df | grep ${sdadir%/*}$ | awk '{print $4}') -lt $sizeneed ] && echo -e "\n$RED硬盘 $BLUE${sdadir%/*} $RED空间不足！请重新选择！$RESET" && sleep 1 && swapsize=""
						}
					done
					[ "$(ps | grep docker | grep -vE 'grep|docker_disk')" ] && {
						echo -e "\n检测到 ${YELLOW}$1 $RESET正在运行！若修改虚拟内存大小需要先停止运行 ${YELLOW}$1 $RESET！" && sleep 2
						echo -e "\n$PINK是否停止 $1 并修改虚拟内存大小？$RESET" && downloadnum=""
						echo "---------------------------------------------------------"
						echo "1. 确认停止并修改"
						echo "---------------------------------------------------------"
						echo "0. 取消修改并返回主页面"
						while [ ! "$downloadnum" ];do
							echo -ne "\n"
							read -p "请输入对应选项的数字 > " downloadnum
							[ "$(echo $downloadnum | sed 's/[0-9]//g')" -o ! "$downloadnum" ] && downloadnum="" && continue
							[ "$downloadnum" -gt 1 ] && downloadnum="" && continue
							[ "$downloadnum" -eq 0 ] && main
							echo && /etc/init.d/$1 stop
						done
					}
					[ "$swapsize" = 6 ] && rm -f $sdadir/swapfile || {
						echo -e "\n$YELLOW正在创建虚拟内存文件，创建时间视外接硬盘性能而定，请耐心等候！$RESET\n"
						dd if=/dev/zero of=$sdadir/swapfile bs=1M count=$swapsize &> /dev/null
						chmod 0600 $sdadir/swapfile && mkswap -L Docker $sdadir/swapfile
					}
					echo -e "\n$YELLOW虚拟内存文件大小$GREEN修改成功！$RESET" && sleep 2 && main
				}
			}
			[ ! "$skipdownload" ] && {
				[ -f $sdadir/upxneeded ] && upxneeded=1
				if [ "$1" != "docker" ]; then
					echo -e "\n$PINK请选择型号进行下载：$RESET" && num=""
					echo "---------------------------------------------------------"
					echo -e "1. $GREEN自动检测系统型号$RESET"
					echo "2. aarch64"
					[ "$1" = zerotier ] && echo "3. arm-eabi" || echo "3. arm"
					[ "$1" = zerotier ] && echo "4. arm-eabihf" || echo "4. x86_64"
					echo "5. mips"
					echo "6. mipsel"
					echo "7. mips64"
					echo "8. mips64el"
					echo "---------------------------------------------------------"
					echo "0. 返回主页面"
					echo -e "\n可以在 $SKYBLUE$urls$RESET 中查找并复制下载地址"
					while [ ! "$num" ];do
						echo -ne "\n"
						read -p "请输入对应型号的数字或直接输入以 http 或 ftp 开头的下载地址 > " num
							case "$num" in
								1)
									hardware_type=$(uname -m)
									[ "$hardware_type" = "aarch64" ] && hardware_type=arm64;;
								2)	hardware_type=arm64;;
								3)	hardware_type=arm;;
								4)	hardware_type=amd64;;
								5)	hardware_type=mips;;
								6)	hardware_type=mipsle;;
								7)	hardware_type=mips64;;
								8)	hardware_type=mips64le;;
								0)	main
							esac
						[ "$(echo $num | sed 's/[0-9]//g')" -a "${num:0:4}" != "http" -a "${num:0:3}" != "ftp" -o ! "$num" ] && num="" && continue
						[ "${num:0:4}" != "http" -a "${num:0:3}" != "ftp" ] && [ "$num" -lt 1 -o "$num" -gt 8 ] && num="" && continue
						[ "$1" = "qBittorrent" ] && {
							[ "$hardware_type" = "arm64" ] && hardware_type=aarch64
							[ "$hardware_type" = "mipsle" ] && hardware_type=mipsel
							[ "$hardware_type" = "mips64le" ] && hardware_type=mips64el
							[ "$hardware_type" = "amd64" ] && hardware_type=x86_64
						}
						[ "$1" = "AdGuardHome" ] && [ "$hardware_type" = "arm" ] && hardware_type=armv7
						[ "$1" = "zerotier" ] && {
							[ "$hardware_type" = "arm64" ] && hardware_type=aarch64
							[ "$hardware_type" = "mipsle" ] && hardware_type=mipsel
							[ "$hardware_type" = "mips64le" ] && hardware_type=mips64el
						}
					done
					[ "$1" = "qBittorrent" -o "$1" = "zerotier" ] && opkg_test_install "unzip"
					echo -e "\n下载 ${YELLOW}$1 $(echo $tag_name | sed 's/^[^v].*[^.0-9]/v/')$RESET ······" && retry_count=5 && eabi="" && softfloat="" && url=""
					while [ ! -f /tmp/$1.tmp -a $retry_count != 0 ];do
						[ "$hardware_type" = "arm" ] && eabi="eabi"
						[ "$1" = "zerotier" ] && [ "$hardware_type" = "amd64" ] && hardware_type=arm && eabi="eabihf"
						[ "${hardware_type:0:4}" = "mips" ] && softfloat="_softfloat"
						[ "$1" = "qBittorrent" ] && url="https://github.com/c0re100/qBittorrent-Enhanced-Edition/releases/download/$tag_name/qbittorrent-enhanced-nox_$hardware_type-linux-musl${eabi}_static.zip"
						[ "$1" = "Alist" ] && url="https://github.com/$5/$6/releases/download/$tag_name/alist-linux-musl$eabi-$hardware_type.tar.gz"
						[ "$1" = "AdGuardHome" ] && url="https://github.com/$5/$6/releases/download/$tag_name/AdGuardHome_linux_$hardware_type$softfloat.tar.gz"
						[ "$1" = "zerotier" ] && url="https://github.com/$5/$6/releases/download/$tag_name/zerotier-one-$hardware_type-linux-musl$eabi.zip"
						if [ "${num:0:4}" = "http" -o "${num:0:3}" = "ftp" ];then
							url="$num" && echo "" && curl --connect-timeout 3 -#Lko /tmp/$1.tmp "$url"
						else
							github_download "$1.tmp" "$url"
						fi
						if [ "$?" != 0 ];then
							rm -f /tmp/$1.tmp && let retry_count--
							[ $retry_count != 0 ] && echo -e "\n$RED下载失败！$RESET即将尝试重连······（剩余重试次数：$PINK$retry_count$RESET）" && sleep 1
						else
							[ "$(wc -c < /tmp/$1.tmp)" -lt 1024 ] && rm -f /tmp/$1.tmp && echo -e "\n$RED下载失败！$RESET没有找到适用于当前系统的文件包，请手动选择型号进行重试！" && sleep 1 && main
						fi
					done
					[ ! -f /tmp/$1.tmp ] && echo -e "\n$RED下载失败！$RESET如果没有代理的话建议多尝试几次！" && sleep 1 && main
					echo -e "\n$GREEN下载成功！$RESET即将解压安装并启动" && rm -f /tmp/$2 && sleep 2
					case "$1" in
						qBittorrent)	unzip -oq /tmp/$1.tmp -d /tmp;;
						Alist)	tar -zxf /tmp/$1.tmp -C /tmp;;
						AdGuardHome)	tar -zxf /tmp/$1.tmp -C /tmp && mv -f /tmp/$1 /tmp/$1.dir && mv -f /tmp/$1.dir/$1 /tmp/$1 && rm -rf /tmp/$1.dir;;
						zerotier)	unzip -P "ikwjqensa%^!" -oq /tmp/$1.tmp -d /tmp 2> /dev/null
							;;
					esac
					rm -f /tmp/$1.tmp
				else
					port=$(netstat -lnWp | grep -E ':8000 |:9000 |:9443 ' | awk '{print $4}' | grep -oE :[0-9.]{1,6} | grep -oE [0-9]{1,5} | head -1)
					process=$(netstat -lnWp | grep -E ':8000 |:9000 |:9443 ' | awk '{print $NF}' | sed 's/.*\///' | head -1)
					[ "$port" ] && {
						echo -e "\n$RED检测到 $PINK$port $RED端口已被 $YELLOW$process $RED占用！无法安装！$RESET" && sleep 2 && main
					}
					opkg_test_install "unzip"
					echo -e "\n下载 ${YELLOW}$1 $RESET安装脚本 ······" && retry_count=5 && rm -f /tmp/$1.tmp /tmp/$1.tgz /tmp/$1.sh
					while [ ! -f /tmp/$1.tmp -a $retry_count != 0 ];do
						curl -m 3 -#Lko /tmp/$1.tmp "https://raw.githubusercontent.com/xilaochengv/BuildKernelSU/main/docker.zip"
						if [ "$?" != 0 ];then
							rm -f /tmp/$1.tmp && let retry_count--
							[ $retry_count != 0 ] && echo -e "\n$RED下载失败！$RESET即将尝试重连······（剩余重试次数：$PINK$retry_count$RESET）" && sleep 1
						else
							[ "$(wc -c < /tmp/$1.tmp)" -lt 1024 ] && rm -f /tmp/$1.tmp && echo -e "\n$RED下载失败！$RESET" && sleep 1 && main
						fi
					done
					[ ! -f /tmp/$1.tmp ] && echo -e "\n$RED下载失败！$RESET" && sleep 1 && main
					echo -e "\n$GREEN下载成功！$RESET即将解压安装并启动" && rm -f /tmp/$2 && sleep 2
					echo -e "\n$PINK请选择即将创建的虚拟内存的大小$RESET" && swapsize=""
					echo -e "$YELLOW提示：虚拟内存对路由器性能没有提升，但能避免爆内存导致路由器死机。若外接硬盘性能过低甚至可能会产生负面效果！$RESET"
					echo "---------------------------------------------------------"
					echo "1. 512 MB"
					echo "2. 1024 MB ( 1 GB )"
					echo "3. 2048 MB ( 2 GB )"
					echo "4. 3072 MB ( 3 GB )"
					echo "5. 4096 MB ( 4 GB )"
					echo "6. 禁用虚拟内存"
					echo "---------------------------------------------------------"
					echo "0. 取消安装并返回主页面"
					while [ ! "$swapsize" ];do
						echo -ne "\n"
						read -p "请输入对应选项的数字 > " swapsize
						[ "$(echo $swapsize | sed 's/[0-9]//g')" -o ! "$swapsize" ] && swapsize="" && continue
						[ "$swapsize" -gt 6 ] && swapsize="" && continue
						[ "$swapsize" -eq 0 ] && rm -f /tmp/$1.tmp && main
						[ $swapsize = 1 ] && swapsize=512;[ $swapsize = 2 ] && swapsize=1024;[ $swapsize = 3 ] && swapsize=2048;[ $swapsize = 4 ] && swapsize=3072;[ $swapsize = 5 ] && swapsize=4096
						[ "$swapsize" = 6 ] && needswap="" || {
							let sizeneed=$swapsize*1024
							needswap=true && [ -f $sdadir/swapfile ] && let sizeneed=$sizeneed-$(($(ls -l $sdadir/swapfile | awk '{print $5}')/1024))
							[ $(df | grep ${sdadir%/*}$ | awk '{print $4}') -lt $sizeneed ] && echo -e "\n$RED硬盘 $BLUE${sdadir%/*} $RED空间不足！请重新选择！$RESET" && sleep 1 && swapsize=""
						}
					done
					[ -f /etc/init.d/mi_docker ] && {
						echo -e "\n检测到本路由器可安装官方固件版 $YELLOW$1 $RESET，安装最新完整版 $YELLOW$1 $RESET需要禁用官方固件版 $YELLOW$1$RESET ！" && sleep 2
						echo -e "\n$PINK是否禁用官方版 $1？$RESET" && num=""
						echo "---------------------------------------------------------"
						echo "1. 确认禁用"
						echo "---------------------------------------------------------"
						echo "0. 取消安装并返回主页面"
						while [ ! "$num" ];do
							echo -ne "\n"
							read -p "请输入对应选项的数字 > " num
							[ "$(echo $num | sed 's/[0-9]//g')" -o ! "$num" ] && num="" && continue
							[ "$num" -gt 1 ] && num="" && continue
							[ "$num" -eq 0 ] && rm -f /tmp/$1.tmp && main
						done
						uci -q set mi_docker.settings.docker_enable=0 && uci -q commit && /etc/init.d/mi_docker stop &> /dev/null &
						echo -e "\n$RED正在停止并禁用官方固件版 $YELLOW$1$RESET ······" && sleep 2
						while [ "$(ps | grep mi_docker | grep -v grep)" ];do sleep 1;done
						while [ "$(mount | grep cgroup | awk '{print $3}')" ];do umount $(mount | grep cgroup | awk '{print $3}' | tail -1);done
						[ -f /etc/config/mi_docker ] && mv -f /etc/config/mi_docker /etc/config/mi_docker.backup && log "备份/etc/config/mi_docker文件并改名为mi_docker.backup"
						[ -f /etc/init.d/mi_docker ] && mv -f /etc/init.d/mi_docker /etc/init.d/mi_docker.backup && log "备份/etc/init.d/mi_docker文件并改名为mi_docker.backup"
						[ -f /etc/init.d/cgroup_init ] && mv -f /etc/init.d/cgroup_init /etc/init.d/cgroup_init.backup && log "备份/etc/init.d/cgroup_init文件并改名为cgroup_init.backup"
					}
					unzip -P "kasjkdnwqe^*#@!!" -oq /tmp/$1.tmp -d /tmp 2> /dev/null && rm -f /tmp/$1.tmp
					[ -f /etc/init.d/$1 ] && /etc/init.d/$1 stop || [ -f $sdadir/service_$1 ] && $sdadir/service_$1 stop
					echo -e "\n$RED安装文件较多、安装时间视网络与外接硬盘性能而定，请耐心等候！$RESET"
					[ ! "$(grep docker /etc/group)" ] && echo "docker:x:0" >> /etc/group
					sed -i "s#install_dir#${sdadir%/*}#g;s/needswap/$needswap/;s/1024/$swapsize/" /tmp/docker.sh && chmod +x /tmp/docker.sh && /tmp/docker.sh
					if [ "$?" = 0 ];then
						while [ ! "$(netstat -lnWp | grep :9000)" ];do sleep 1;done
						firewalllog "add" "$1" "wan9000rdr1" "tcp" "1" "wan" "9000" "9000"
						[ "$autorestore" ] && sed -i "/$1/d;/exit 0/i$sdadir/service_$1 restart &" /data/start_service_by_firewall
						echo -e "\n$YELLOW$1$RESET 端口转发规则 $GREEN已全部更新$RESET，即将重启防火墙 ······" && sleep 2 && /etc/init.d/firewall restart &> /dev/null
						echo -e "\n${YELLOW}Docker $GREEN安装并启动成功！$RESET"
						echo -e "\n$YELLOW若需要使用 ${PINK}docker $YELLOW等命令，请关闭本窗口并重新进入 SSH ！$RESET"
						echo -e "\n管理页面地址：$SKYBLUE$hostip:9000$RESET"
						ipv4=$(curl -m 3 -sLk v4.ident.me)
						[ "$ipv4" ] && echo -e "\n外网管理页面地址：$SKYBLUE$ipv4:9000$RESET";main
					else
						echo -e "\n$RED下载文件出错！请重试！$RESET" && sleep 2 && main
					fi
				fi
			}
		}
		if [ "$upxneeded" = 1 ];then
			echo -e "\n请将 $BLUE/tmp/$2$RESET 文件移动到电脑上并使用 ${YELLOW}upx$RESET 进行压缩" && num=""
			echo -e "\n$YELLOW压缩完成后$RESET请将文件重新放回到 $BLUE/tmp$RESET 目录下，并输入 ${YELLOW}1$RESET 进行继续"
			while [ "$num" != 1 ];do echo -ne "\n";read -p "压缩完成后请输入 1 进行继续 > " num;done
			if [ -f /tmp/$2 ];then
				filesize=$(($(wc -c < /tmp/$2)+1048576)) && rm -f $sdadir/$2 && log "旧$1主程序文件已删除" && sleep 3
				sdadiravailable=$(df | grep " ${sdadir%/*}$" | awk '{print $4}')
				[ "$filesize" -gt "$(($sdadiravailable*1024))" ] && rm -f $sdadir/upxneeded && {
					if [ "$filesize" -gt 1073741824 ];then
						filesize="$(awk BEGIN'{printf "%0.3f",'$filesize'/1024/1024/1024}') GB"
						sdadiravailable="$(awk BEGIN'{printf "%0.3f",'$sdadiravailable'/1024/1024}') GB"
					elif [ "$filesize" -gt 1048576 ];then
						filesize="$(awk BEGIN'{printf "%0.3f",'$filesize'/1024/1024}') MB"
						sdadiravailable="$(awk BEGIN'{printf "%0.3f",'$sdadiravailable'/1024}') MB"
					else
						filesize="$(awk BEGIN'{printf "%0.3f",'$filesize'/1024}') KB"
						sdadiravailable="$sdadiravailable KB"
					fi
					echo -e "\n主程序文件大小 $PINK$filesize$RESET （预留 ${YELLOW}1 MB$RESET 空间），所选目录可用空间 $RED$sdadiravailable ，空间不足，无法安装！$RESET" && sleep 1 && sda_install_remove "$1" "$2" "$3" "$4" "$5" "$6" "$7" "return"
				}
				touch $sdadir/upxneeded
			else
				echo -e "\n$BLUE/tmp/$2$RESET 文件$RED不存在！$RESET" && sleep 1 && main
			fi
		fi
		[ ! "$skipdownload" ] && {
			while [ "$(pidof $2)" ];do killpid $(pidof $2 | awk '{print $1}');done
			[ ! -d $sdadir ] && mkdir -p $sdadir && log "新建文件夹$sdadir"
			[ "$tmpdir" -a ! -d $tmpdir ] && mkdir -p $tmpdir && log "新建文件夹$tmpdir"
			if [ ! "$tmpdir" ];then
				[ -f $sdadir/$2 ] && rm -f $sdadir/$2 && log "旧$1主程序文件已删除"
				mv -f /tmp/$2 $sdadir/$2 && log "$1主程序文件$2已安装到$sdadir文件夹中"
			else
				[ -f $tmpdir/$2 ] && rm -f $tmpdir/$2 && log "旧$1主程序文件已删除"
				mv -f /tmp/$2 $tmpdir/$2 && log "$1主程序文件$2已安装到$tmpdir文件夹中"
				ln -sf $tmpdir/$2 $sdadir/$2 && log "新建$1主程序链接文件$sdadir/$2并链接到$tmpdir/$2"
			fi
		}
		chmod 755 $sdadir/$2 $tmpdir/$2 &> /dev/null
		while [ "$(pidof $2)" ];do killpid $(pidof $2 | awk '{print $1}');done && firewalllog "del" "$1"
		[ "$1" = "qBittorrent" ] && {
			if [ -f $sdadir/qBittorrent_files/config/qBittorrent.conf ];then
				defineport=$(cat $sdadir/qBittorrent_files/config/qBittorrent.conf | grep -F 'WebUI\Port' | sed 's/.*=//')
				newdefineport=$defineport
				definetrackerport=$(cat $sdadir/qBittorrent_files/config/qBittorrent.conf | grep -F 'Advanced\trackerPort' | sed 's/.*=//')
				newtrackerport=$definetrackerport
				while [ "$(netstat -lnWp | grep tcp | grep ":$newdefineport " | awk '{print $NF}' | sed 's/.*\///' | head -1)" ];do let newdefineport++;sleep 1;done
				while [ "$(netstat -lnWp | grep ":$newtrackerport " | awk '{print $NF}' | sed 's/.*\///' | head -1)" ];do let newtrackerport++;sleep 1;done
				sed -i "s/=$defineport$/=$newdefineport/" $sdadir/qBittorrent_files/config/qBittorrent.conf
				sed -i "s/=$definetrackerport$/=$newtrackerport/" $sdadir/qBittorrent_files/config/qBittorrent.conf
			else
				newuser=1 && newdefineport=6880 && newtrackerport=54345 && mkdir -p $sdadir/qBittorrent_files/config
				while [ "$(netstat -lnWp | grep tcp | grep ":$newdefineport " | awk '{print $NF}' | sed 's/.*\///' | head -1)" ];do let newdefineport++;sleep 1;done
				while [ "$(netstat -lnWp | grep ":$newtrackerport " | awk '{print $NF}' | sed 's/.*\///' | head -1)" ];do let newtrackerport++;sleep 1;done
				echo -e "[Preferences]\nAdvanced\trackerPort=$newtrackerport\nBittorrent\CustomizeTrackersListUrl=https://trackerslist.com/all.txt\nGeneral\Locale=zh_CN\nWebUI\AuthSubnetWhitelist=0.0.0.0/0\nWebUI\AuthSubnetWhitelistEnabled=true\nWebUI\Username=admin\nWebUI\Password_PBKDF2=\"@ByteArray(yVAdTgYH36q3jEXe7W7i/A==:8Gmdf4KqS9nZ48ySkl+eX4z9dQWZxqECKJDl8B4c3rIgzf6TcxNACvSbVohaL+ltcHgICPGbg5jUhx1eZx25Ag==)\"" >> $sdadir/qBittorrent_files/config/qBittorrent.conf
			fi
			$sdadir/$2 --webui-port=$newdefineport --profile=$sdadir --configuration=files -d &> /dev/null
		}
		[ "$1" = "Alist" ] && {
			[ ! -f $sdadir/data/config.json ] && newuser=1 && touch $sdadir/.unadmin
			rm -f $sdadir/daemon/pid $tmpdir/daemon/pid && $sdadir/$2 start --data $sdadir/data &> /dev/null && sleep 2
			defineport=$(cat $sdadir/data/config.json 2> /dev/null | grep http_port | grep -oE [0-9]{1,5})
			newdefineport=$defineport
			[ ! "$(pidof $2)" ] && {
				while [ "$(netstat -lnWp | grep tcp | grep ":$newdefineport " | awk '{print $NF}' | sed 's/.*\///' | head -1)" ];do let newdefineport++;sleep 1;done
				sed -i "s/: $defineport,/: $newdefineport,/" $sdadir/data/config.json 2> /dev/null
				rm -f $sdadir/daemon/pid $tmpdir/daemon/pid && $sdadir/$2 start --data $sdadir/data &> /dev/null
			}
		}
		[ "$1" = "AdGuardHome" ] && {
			[ "$ruleexist" = 1 ] && echo -e "\n$YELLOW$1$RESET 端口转发规则 $RED已全部删除$RESET，即将重启防火墙 ······" && sleep 2 && /etc/init.d/firewall restart &> /dev/null
			if [ -f $sdadir/AdGuardHome.yaml ];then
				defineport=$(cat "$sdadir/AdGuardHome.yaml" | grep address | grep -oE [0-9]{1,5} | tail -1)
				definednsport=$(cat "$sdadir/AdGuardHome.yaml" | grep port: | grep -oE [0-9]{1,5} | tail -1)
				newdefineport=$defineport && newdnsport=$definednsport
				while [ "$(netstat -lnWp | grep tcp | grep ":$newdefineport " | awk '{print $NF}' | sed 's/.*\///' | head -1)" ];do let newdefineport++;sleep 1;done
				sed -i "s/:$defineport$/:$newdefineport/" $sdadir/AdGuardHome.yaml
				if [ "$newdnsport" = 53 ];then
					[ ! -f /etc/config/dhcp.backup ] && cp -f /etc/config/dhcp /etc/config/dhcp.backup && log "备份/etc/config/dhcp文件并改名为dhcp.backup"
					[ ! "$(uci -q get dhcp.@dnsmasq[0].port)" -o "$(uci -q get dhcp.@dnsmasq[0].port)" = 53 ] && uci -q set dhcp.@dnsmasq[0].port=0 && uci -q commit && /etc/init.d/dnsmasq restart &> /dev/null && log "修改/etc/config/dhcp文件中的选项：dnsmasq.port改为0（关闭dnsmasq的DNS服务）"
				else
					while [ "$(netstat -lnWp | grep ":$newdnsport " | awk '{print $NF}' | sed 's/.*\///' | head -1)" ];do let newdnsport++;sleep 1;done
					sed -i "s/: $definednsport$/: $newdnsport/" $sdadir/AdGuardHome.yaml
					adguardhomednsport=$newdnsport && DNSINFO="，${RED}DNS$RESET 监听端口为：$YELLOW$adguardhomednsport$RESET"
				fi
			else
				echo -e "\n$YELLOW检测到本次是首次安装$RESET！请先设置 ${PINK}DNS 监听端口$RESET！" && num=""
				while [ ! "$num" ];do
					echo -ne "\n"
					read -p "请输入要设置的 DNS 监听端口 > " num
					[ "$(echo $num | sed 's/[0-9]//g')" -o ! "$num" ] && num="" && continue
					[ "$num" -lt 1 -o "$num" -gt 65535 ] && num="" && continue
					echo -e "\n当前设置的 DNS 监听端口为：$PINK$num$RESET" && cnum=""
					while [ ! "$cnum" ];do
						echo -ne "\n"
						read -p "确认请输入 1 ，返回修改请输入 0 > " cnum
						[ "$(echo $cnum | sed 's/[0-9]//g')" -o ! "$cnum" ] && cnum="" && continue
						[ "$cnum" -gt 1 ] && cnum="" && continue
						[ "$cnum" -eq 0 ] && num=""
					done
					process=$(netstat -lnWp | grep ":$num " | awk '{print $NF}' | sed 's/.*\///' | head -1) && dnsnum=""
					[ "$process" ] && {
						if [ "$process" = "dnsmasq" ];then
							echo -e "\n$RED使用 ${PINK}53 $RED端口需要禁用本机自带的 ${YELLOW}dnsmasq $RED的 DNS 服务，确认禁用吗？$RESET"
							while [ ! "$dnsnum" ];do
								echo -ne "\n"
								read -p "确认请输入 1 ，返回修改请输入 0 > " dnsnum
								[ "$(echo $dnsnum | sed 's/[0-9]//g')" -o ! "$dnsnum" ] && dnsnum="" && continue
								[ "$dnsnum" -gt 1 ] && dnsnum="" && continue
								[ "$dnsnum" = 1 ] && {
									[ ! -f /etc/config/dhcp.backup ] && cp -f /etc/config/dhcp /etc/config/dhcp.backup && log "备份/etc/config/dhcp文件并改名为dhcp.backup"
									uci -q set dhcp.@dnsmasq[0].port=0 && uci -q commit && /etc/init.d/dnsmasq restart &> /dev/null && log "修改/etc/config/dhcp文件中的选项：dnsmasq.port改为0（关闭dnsmasq的DNS服务）"
								}
								[ "$dnsnum" -eq 0 ] && num=""
							done
						else
							echo -e "\n$RED检测到 $PINK$num $RED端口已被 $YELLOW$process $RED占用！请重新设置！$RESET" && num="" && sleep 1
						fi
					}
				done
				[ "$num" != 53 ] && adguardhomednsport=$num && DNSINFO="，${RED}DNS$RESET 监听端口为：$YELLOW$adguardhomednsport$RESET"
				newdefineport=3000 && while [ "$(netstat -lnWp | grep tcp | grep ":$newdefineport " | awk '{print $NF}' | sed 's/.*\///' | head -1)" ];do let newdefineport++;sleep 1;done
				echo -e "http:\n  pprof:\n    port: 6060\n    enabled: false\n  address: 0.0.0.0:$newdefineport\n  session_ttl: 720h" > $sdadir/AdGuardHome.yaml
				echo -e "dns:\n  port: $num\n  upstream_dns:\n    - 223.6.6.6" >> $sdadir/AdGuardHome.yaml
			fi
			$sdadir/$2 -w $sdadir &> /dev/null &
		}
		[ "$1" = "zerotier" ] && {
			if [ -f $sdadir/zerotier-one.port ];then
				defineport=$(cat $sdadir/zerotier-one.port)
				newdefineport=$defineport
				while [ "$(netstat -lnWp | grep ":$newdefineport " | awk '{print $NF}' | sed 's/.*\///' | head -1)" ];do let newdefineport++;sleep 1;done
				sed -i "s/$defineport$/$newdefineport/" $sdadir/zerotier-one.port
			else
				newdefineport=9993
				while [ "$(netstat -lnWp | grep ":$newdefineport " | awk '{print $NF}' | sed 's/.*\///' | head -1)" ];do let newdefineport++;sleep 1;done
			fi
			$sdadir/$2 -d $sdadir -p$newdefineport &> /dev/null
		}
		runtimecount=0 && [ ! "$tmpdir" ] && {
			[ -f $downloadfileinit ] && rm -f $downloadfileinit $sdadir/service_Download$1 && log "删除自启动文件$downloadfileinit"
			[ -L $downloadfilerc ] && rm -f $downloadfilerc
		}
		while [ ! "$(pidof $2)" -a "$runtimecount" -lt 5 ];do let runtimecount++;sleep 1;done
		if [ "$(pidof $2)" ];then
			{
				echo -e "#!/bin/sh /etc/rc.common\n\nSTART=95"
				[ "$autorestore" ] && echo -e "\nwhile [ \"\$(cat /proc/xiaoqiang/boot_status)\" != 3 ];do sleep 1;done\nln -sf $sdadir/service_$1 /etc/init.d/$1"
				echo -e "\nstart() {\n\texistedpid=\$(ps | grep -v grep | grep $2 | awk '{print \$1}');for pid in \$existedpid;do [ \$pid != \$\$ ] && killpid \$pid;done"
			} > $autostartfileinit
			[ "$tmpdir" -a ! "$skipdownload" ] && {
				echo -e "#!/bin/sh /etc/rc.common\n\nSTART=95"
				[ "$autorestore" ] && echo -e "\nwhile [ \"\$(cat /proc/xiaoqiang/boot_status)\" != 3 ];do sleep 1;done\n[ -f $sdadir/$2 ] && exit"
				echo -e "\nstart() {\n\tcat > /tmp/download$1file.sh <<EOF\n[ ! -d /tmp/XiaomiSimpleInstallBox ] && mkdir -p /tmp/XiaomiSimpleInstallBox\ntrycount=0;while [ \\\$trycount -lt 3 -a ! -f /tmp/$1.tmp ];do curl --connect-timeout 3 -sLko /tmp/$1.tmp \"$url\";[ \\\$? = 0 ] && [ \\\$(wc -c < /tmp/$1.tmp) -lt 1024 ] && rm -f /tmp/$1.tmp;[ ! -f /tmp/$1.tmp ] && let trycount++;done\n[ -f /tmp/$1.tmp ] && {"
			} > $downloadfileinit
			[ "$1" = "qBittorrent" ] && {
				while [ "$(pidof $2)" ];do killpid $(pidof $2 | awk '{print $1}');done
				sessionPort=$(cat $sdadir/qBittorrent_files/config/qBittorrent.conf | grep -F 'Session\Port' | sed 's/.*=//')
				firewalllog "add" "$1" "wan${sessionPort}rdr3" "tcpudp" "1" "wan" "$sessionPort" "$sessionPort"
				firewalllog "add" "$1" "wan${newtrackerport}rdr3" "tcpudp" "1" "wan" "$newtrackerport" "$newtrackerport"
				firewalllog "add" "$1" "wan${newdefineport}rdr1" "tcp" "1" "wan" "$newdefineport" "$newdefineport"
				echo -e "\t$sdadir/$2 --webui-port=$newdefineport --profile=$sdadir --configuration=files -d" >> $autostartfileinit
				[ "$tmpdir" -a ! "$skipdownload" ] && echo -e "\texport PATH=/data/unzip:\$PATH && unzip -oq /tmp/$1.tmp -d /tmp && mv -f /tmp/$2 /tmp/XiaomiSimpleInstallBox/$2" >> $downloadfileinit
			}
			[ "$1" = "Alist" ] && {
				[ -f $sdadir/.unadmin ] && sleep 5 && $sdadir/$2 admin set 12345678 --data $sdadir/data &> /dev/null && rm -f $sdadir/.unadmin
				firewalllog "add" "$1" "wan${newdefineport}rdr1" "tcp" "1" "wan" "$newdefineport" "$newdefineport"
				echo -e "\trm -f $sdadir/daemon/pid $tmpdir/daemon/pid\n\t$sdadir/$2 start --data $sdadir/data" >> $autostartfileinit
				[ "$tmpdir" -a ! "$skipdownload" ] && echo -e "\ttar -zxf /tmp/$1.tmp -C /tmp && mv -f /tmp/$2 /tmp/XiaomiSimpleInstallBox/$2" >> $downloadfileinit
			}
			[ "$1" = "AdGuardHome" ] && {
				while [ "$(pidof $2)" ];do killpid $(pidof $2 | awk '{print $1}');done
				echo -e "\t[ ! \"\$(uci -q get dhcp.@dnsmasq[0].port)\" -a \"\$(cat $sdadir/AdGuardHome.yaml | grep port: | grep -oE [0-9]{1,5} | tail -1)\" = \"53\" -o \"\$(uci -q get dhcp.@dnsmasq[0].port)\" = \"\$(cat $sdadir/AdGuardHome.yaml | grep port: | grep -oE [0-9]{1,5} | tail -1)\" ] && {\n\t\t[ ! -f /etc/config/dhcp.backup ] && cp -f /etc/config/dhcp /etc/config/dhcp.backup\n\t\tuci set dhcp.@dnsmasq[0].port=0\n\t\t[ ! \"\$(uci -q get dhcp.lan.dhcp_option | grep 6,)\" ] && uci add_list dhcp.lan.dhcp_option=6,\$(uci get network.lan.ipaddr)\n\t\tuci commit && /etc/init.d/dnsmasq restart &> /dev/null\n\t}\n\t$sdadir/$2 -w $sdadir &> /dev/null &" >> $autostartfileinit
				[ "$adguardhomednsport" != 53 ] && {
					firewalllog "add" "$1" "lan53rdr3" "tcpudp" "1" "lan" "53" "$adguardhomednsport"
					echo -e "\tip6tables -t nat -I PREROUTING -p tcp --dport 53 -j REDIRECT --to-ports ${adguardhomednsport}\n\tip6tables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-ports $adguardhomednsport" >> $autostartfileinit
				}
				[ "$tmpdir" -a ! "$skipdownload" ] && {
					echo -e "\ttar -zxf /tmp/$1.tmp -C /tmp && mv -f /tmp/$1 /tmp/$1.dir && mv -f /tmp/$1.dir/$2 /tmp/XiaomiSimpleInstallBox/$2 && rm -rf /tmp/$1.dir" >> $downloadfileinit
					if [ "$adguardhomednsport" = 53 ];then
						sed -i '/EOF/amv -f /etc/config/dhcp.backup /etc/config/dhcp && /etc/init.d/dnsmasq restart &> /dev/null' $downloadfileinit
						echo -e "\tcp -f /etc/config/dhcp /etc/config/dhcp.backup\nuci -q set dhcp.@dnsmasq[0].port=0 && uci -q commit && /etc/init.d/dnsmasq restart &> /dev/null" >> $downloadfileinit
					else
						sed -i '/EOF/auci -q del firewall.lan53rdr3 && uci -q commit && /etc/init.d/firewall restart' $downloadfileinit
						echo -e "\tuci -q set firewall.lan53rdr3=redirect && uci -q set firewall.lan53rdr3.name=$1-lan53rdr3 && uci -q set firewall.lan53rdr3.proto=tcpudp && uci -q set firewall.lan53rdr3.ftype=1 && uci -q set firewall.lan53rdr3.dest_ip=\$(uci -q get network.lan.ipaddr) && uci -q set firewall.lan53rdr3.src=lan && uci -q set firewall.lan53rdr3.dest=lan && uci -q set firewall.lan53rdr3.target=DNAT && uci -q set firewall.lan53rdr3.src_dport=53 && uci -q set firewall.lan53rdr3.dest_port=$adguardhomednsport && uci -q commit && /etc/init.d/firewall restart" >> $downloadfileinit
					fi
				}
			}
			[ "$1" = "zerotier" ] && {
				[ ! "$(ls $sdadir/networks.d 2> /dev/null)" ] && {
					[ ! "$tmpdir" ] && {
						echo -e "\n$PINK请选择是否马上添加并连接到 ZeroTier 网络中：$RESET"
						echo "---------------------------------------------------------" && num=""
						echo "1. 确认添加"
						echo "---------------------------------------------------------"
						echo "0. 返回主页面"
						while [ ! "$num" ];do
							echo -ne "\n"
							read -p "请输入对应选项的数字 > " num
							[ "$(echo $num | sed 's/[0-9]//g')" -o ! "$num" ] && num="" && continue
							[ "$num" -eq 0 ] && main
						done
					}
					echo -e "\n$RED后面的设置过程需要配合$YELLOW zerotier $RED网页端（${SKYBLUE}https://my.zerotier.com/$RED）进行（不会的请百度搜索关键字：${YELLOW}zerotier 授权$RED）$RESET" && NetworkID=""
					while [ ! "$NetworkID" ];do
						echo -ne "\n"
						read -p "请输入 $1 网页端中的 Network ID > " NetworkID
						[ "$NetworkID" = 0 ] && main
						echo -ne "\n"
						$sdadir/zerotier-one -q -D$sdadir join $NetworkID
						[ "$?" != 0 ] && echo -e "\n$RED加入失败！请重新输入！$RESET" && NetworkID=""
					done
					echo -e "\n$GREEN加入成功！$RESET请在$YELLOW zerotier 网页端$RESET进行设备授权以允许连接！正在等待授权中 ······" && sleep 3
					while [ ! "$(ifconfig | awk '{print $1}' | grep ^zt) " -o ! "$(ifconfig $(ifconfig | awk '{print $1}' | grep ^zt) | grep Mask | grep -oE [0-9.]{1,15})" ];do sleep 1;done
					echo -e "\n$GREEN连接成功！$RESET请在$YELLOW zerotier 网页端$PINK Add Routes$RESET 选项中的$YELLOW Destination$RESET 输入 $PINK$(ifconfig br-lan | sed -n 2p | grep -oE [0-9.]{1,15} | head -1 | sed 's/\.[0-9]*$/.0/')/24$RESET ，${YELLOW}Via$RESET 输入 $PINK$(ifconfig $(ifconfig | awk '{print $1}' | grep ^zt) | sed -n 2p | grep -oE [0-9.]{1,15} | head -1)$RESET 并保存$YELLOW（Submit）$RESET即可使用！"
					echo -e "\n$RED若要手动更改$YELLOW zerotier $RED分配给本机的$YELLOW IP$RED， 请在更改之前先删除上一步操作的路由表！！否则整个局域网网络会断开！谨记！！！$RESET"
					echo -e "\n$RED若真的局域网网络断开可以使用手机进行网页登录$YELLOW zerotier 网页端 $RED并删除路由表即可$RESET" && sleep 3
				}
				while [ ! "$(ifconfig | awk '{print $1}' | grep ^zt)" ];do sleep 1;done
				echo -e "\t$sdadir/$2 -d $sdadir -p$newdefineport\n\tiptables -I FORWARD -o $(ifconfig | awk '{print $1}' | grep ^zt) -m comment --comment \"ZeroTier 内网穿透网口出口\" -j ACCEPT 2> /dev/null\n\tiptables -I FORWARD -i $(ifconfig | awk '{print $1}' | grep ^zt) -m comment --comment \"ZeroTier 内网穿透网口入口\" -j ACCEPT 2> /dev/null\n\tiptables -t nat -I POSTROUTING -o $(ifconfig | awk '{print $1}' | grep ^zt) -m comment --comment \"ZeroTier 内网穿透网口出口钳制\" -j MASQUERADE 2> /dev/null\n\tip6tables -I FORWARD -o $(ifconfig | awk '{print $1}' | grep ^zt) -m comment --comment \"ZeroTier 内网穿透网口出口\" -j ACCEPT 2> /dev/null\n\tip6tables -I FORWARD -i $(ifconfig | awk '{print $1}' | grep ^zt) -m comment --comment \"ZeroTier 内网穿透网口入口\" -j ACCEPT 2> /dev/null\n\tip6tables -t nat -I POSTROUTING -o $(ifconfig | awk '{print $1}' | grep ^zt) -m comment --comment \"ZeroTier 内网穿透网口出口钳制\" -j MASQUERADE 2> /dev/null" >> $autostartfileinit
				[ "$tmpdir" -a ! "$skipdownload" ] && echo -e "\texport PATH=/data/unzip:\$PATH && unzip -P \"ikwjqensa%^!\" -oq /tmp/$1.tmp -d /tmp 2> /dev/null && mv -f /tmp/$2 /tmp/XiaomiSimpleInstallBox/$2" >> $downloadfileinit
			}
			echo -e "}\n\nstop() {\n\tservice_stop $sdadir/$2" >> $autostartfileinit
			[ "$1" = "AdGuardHome" ] && {
				echo -e "\t[ -f /etc/config/dhcp.backup ] && mv -f /etc/config/dhcp.backup /etc/config/dhcp && /etc/init.d/dnsmasq restart &> /dev/null" >> $autostartfileinit
				[ "$adguardhomednsport" != 53 ] && echo -e "\tip6tables -t nat -D PREROUTING -p tcp --dport 53 -j REDIRECT --to-ports ${adguardhomednsport}\n\tip6tables -t nat -D PREROUTING -p udp --dport 53 -j REDIRECT --to-ports $adguardhomednsport" >> $autostartfileinit
			}
			[ "$1" = "zerotier" ] && {
				echo -e "\tiptables -D FORWARD -o $(ifconfig | awk '{print $1}' | grep ^zt) -m comment --comment \"ZeroTier 内网穿透网口出口\" -j ACCEPT 2> /dev/null\n\tiptables -D FORWARD -i $(ifconfig | awk '{print $1}' | grep ^zt) -m comment --comment \"ZeroTier 内网穿透网口入口\" -j ACCEPT 2> /dev/null\n\tiptables -t nat -D POSTROUTING -o $(ifconfig | awk '{print $1}' | grep ^zt) -m comment --comment \"ZeroTier 内网穿透网口出口钳制\" -j MASQUERADE 2> /dev/null\n\tip6tables -D FORWARD -o $(ifconfig | awk '{print $1}' | grep ^zt) -m comment --comment \"ZeroTier 内网穿透网口出口\" -j ACCEPT 2> /dev/null\n\tip6tables -D FORWARD -i $(ifconfig | awk '{print $1}' | grep ^zt) -m comment --comment \"ZeroTier 内网穿透网口入口\" -j ACCEPT 2> /dev/null\n\tip6tables -t nat -D POSTROUTING -o $(ifconfig | awk '{print $1}' | grep ^zt) -m comment --comment \"ZeroTier 内网穿透网口出口钳制\" -j MASQUERADE 2> /dev/null" >> $autostartfileinit
				while [ "$(pidof $2)" ];do killpid $(pidof $2 | awk '{print $1}');done
				while [ "$(iptables -S | grep ZeroTier | head -1)" ];do eval iptables $(iptables -S | grep ZeroTier | sed 's/-A/-D/' | head -1);done
				while [ "$(iptables -t nat -S | grep ZeroTier | head -1)" ];do eval iptables -t nat $(iptables -t nat -S | grep ZeroTier | sed 's/-A/-D/' | head -1);done
			}
			echo "}" >> $autostartfileinit && chmod 755 $autostartfileinit && log "新建自启动文件$autostartfileinit"
			ln -sf $autostartfileinit $autostartfilerc && chmod 755 $autostartfilerc && cp -pf $autostartfileinit $sdadir/service_$1 && $autostartfileinit restart &> /dev/null
			[ "$autorestore" ] && sed -i "/$1/d;/exit 0/i$sdadir/service_$1 restart &" /data/start_service_by_firewall
			[ "$tmpdir" -a ! "$skipdownload" ] && {
				echo -e "\trm -f /tmp/$1.tmp\n\tchmod 755 /tmp/XiaomiSimpleInstallBox/$2\n\t$sdadir/service_$1 start &> /dev/null\n}\nrm -f /tmp/download$1file.sh\nEOF\n\tchmod 755 /tmp/download$1file.sh\n\t/tmp/download$1file.sh &\n}" >> $downloadfileinit && chmod 755 $downloadfileinit && log "新建自启动文件$downloadfileinit"
				ln -sf $downloadfileinit $downloadfilerc && chmod 755 $downloadfilerc && cp -pf $downloadfileinit $sdadir/service_Download$1 && /etc/init.d/$1 disable
			}
			[ "$autorestore" ] && [ "$tmpdir" ] && sed -i "/$1/d;/exit 0/i$sdadir/service_Download$1 start &" /data/start_service_by_firewall
			if [ "$1" != "zerotier" ];then
				echo -e "\n$YELLOW$1$RESET 端口转发规则 $GREEN已全部更新$RESET，即将重启防火墙 ······" && sleep 2 && /etc/init.d/firewall restart &> /dev/null
				echo -e "\n${YELLOW}$1 $PINK$(echo $tag_name | sed 's/^[^v].*[^.0-9]/v/') $GREEN已运行$RESET并设置为$YELLOW开机自启动！$RESET"
				echo -e "\n管理页面地址：$SKYBLUE$hostip:$newdefineport$RESET$DNSINFO"
				[ "$1" != "AdGuardHome" ] && {
					ipv4=$(curl -m 3 -sLk v4.ident.me)
					[ "$ipv4" ] && echo -e "\n外网管理页面地址：$SKYBLUE$ipv4:$newdefineport$RESET"
				}
				[ "$newuser" ] && echo -e "\n初始账号：${PINK}admin$RESET 初始密码：${PINK}12345678$RESET"
				[ "$1" = "Alist" ] && echo -e "\n官方使用指南：${SKYBLUE}https://alist.nn.ci/zh/$RESET"
			else
				echo -e "\n${YELLOW}$1$PINK v$($sdadir/$2 -v) $GREEN已运行$RESET并设置为$YELLOW开机自启动！$RESET"
			fi
		else
			echo -e "\n$RED启动失败！$RESET请下载适用于当前系统的文件包！"
			[ -f $autostartfileinit ] && rm -f $autostartfileinit $sdadir/service_$1 && log "删除自启动文件$autostartfileinit"
			[ -L $autostartfilerc ] && rm -f $autostartfilerc
			[ -f $downloadfileinit ] && rm -f $downloadfileinit $sdadir/service_Download$1 && log "删除自启动文件$downloadfileinit"
			[ -L $downloadfilerc ] && rm -f $downloadfilerc
			[ "$1" = "AdGuardHome" -a "$adguardhomednsport" = 53 ] && mv -f /etc/config/dhcp.backup /etc/config/dhcp && /etc/init.d/dnsmasq restart &> /dev/null && log "恢复/etc/config/dhcp.backup文件并改名为dhcp"
		fi
	else
		echo -e "\n$PINK请输入 $1 的下载默认保存路径：$RESET"
		echo "---------------------------------------------------------" && num="" && webui=""
		echo "0. 返回主页面"
		echo "---------------------------------------------------------"
		while [ ! -d "$num" -o "${num:0:1}" != / ];do
			echo -ne "\n"
			read -p "请输入以 '/' 开头的路径地址（完整路径） > " num
			[ "$num" = 0 ] && main
			[ "$num" = / ] && echo -e "\n$RED请不要使用根目录作为默认下载保存路径！$RESET" && sleep 1 && num="" && continue
			[ ! -d "$num" -o "${num:0:1}" != / ] && echo -e "\n路径 $BLUE$num $RED不存在！$RESET"
		done
		echo -e "\n$YELLOW$1$RESET 的下载默认保存路径已设置为：$BLUE$num$RESET" && sleep 1
		while [ "$(pidof $3)" ];do /etc/init.d/$1 stop &> /dev/null;done
		[ "$1" = "aria2" ] && {
			[ ! -d $sdadir ] && mkdir -p $sdadir && log "新建文件夹$sdadir"
			firewalllog "del" "$1" && touch $sdadir/aria2.session
			echo -e "#!/bin/sh\necho -e \"\\\ndownload-complete \$1 \$2 \$3\"\nDir=\"$num\"\nchmod -R 777 \"\$(echo \$Dir | sed 's#[^/]\$#&/#')\$(echo \$3 | sed -e \"s#\$Dir##\" -e 's#^/##' | awk -F '/' '{print \$1}')\"" > $sdadir/on-download-complete.sh && chmod 755 $sdadir/on-download-complete.sh
			echo -e "#!/bin/sh\necho -e \"\\\ndownload-stop \$1 \$2 \$3\"\nDir=\"$num\"\nrm -rf \"\$(echo \$Dir | sed 's#[^/]\$#&/#')\$(echo \$3 | sed -e \"s#\$Dir##\" -e 's#^/##' | awk -F '/' '{print \$1}')\"\nrm -f \"\$(echo \$Dir | sed 's#[^/]\$#&/#')\$(echo \$3 | sed -e \"s#\$Dir##\" -e 's#^/##' | awk -F '/' '{print \$1}').aria2\"" > $sdadir/on-download-stop.sh && chmod 755 $sdadir/on-download-stop.sh
			echo -e "ConfPath=\"$sdadir/aria2.conf\"\nrm -f /tmp/tracker_all.tmp && [ \$(cat /proc/uptime | awk '{print \$1}' | sed 's/\..*//') -le 60 ] && sleep 30\necho -e \"\\\n即将尝试获取最新 \\\033[1;33mTracker\\\033[0m 服务器列表（\\\033[1;33m成功与否不影响正常启动\\\033[0m） ······ \\\c\" && sleep 2\ncurl --connect-timeout 3 -skLo /tmp/tracker_all.tmp \"https://trackerslist.com/all.txt\"\n[ \"\$?\" != 0 ] && {\n\trm -f /tmp/tracker_all.tmp\n\techo -e \"\\\033[0;31m获取失败！\\\033[0m\" && sleep 2\n}\n[ -f /tmp/tracker_all.tmp ] && {\n\techo -e \"\\\033[1;32m获取成功！\\\033[0m\"\n\t#过滤IPv6的Tracker服务器地址：\n\t#sed -i '/\/\/\[/d' /tmp/tracker_all.tmp\n\tsed -i \"/^$/d\" /tmp/tracker_all.tmp\n\tTrackers=\$(sed \":i;N;s|\\\n|,|;ti\" /tmp/tracker_all.tmp)\n\tsed -i \"s|bt-tracker=.*|bt-tracker=\$Trackers|\" \$ConfPath\n}\n[ -d $sdadir/ariang ] && ln -sf $sdadir/ariang /www/ariang && ln -sf $sdadir/aria2c /usr/bin/aria2c\naria2c --conf-path=\$ConfPath -D &> /dev/null" > $sdadir/tracker_update.sh && chmod 755 $sdadir/tracker_update.sh
			echo -e "enable-rpc=true\nrpc-allow-origin-all=true\nrpc-listen-all=true\npeer-id-prefix=BC1980-\npeer-agent=BitComet 1.98\nuser-agent=BitComet/1.98\ninput-file=$sdadir/aria2.session\non-download-complete=$sdadir/on-download-complete.sh\non-download-stop=$sdadir/on-download-stop.sh\ndir=$num\nmax-concurrent-downloads=2\ncontinue=true\nmax-connection-per-server=16\nmin-split-size=20M\nremote-time=true\nsplit=16\nbt-remove-unselected-file=true\nbt-detach-seed-only=true\nbt-enable-lpd=true\nbt-max-peers=0\nbt-tracker=\ndht-file-path=$sdadir/dht.dat\ndht-file-path6=$sdadir/dht6.dat\ndht-listen-port=6881-6999\nlisten-port=6881-6999\nmax-overall-upload-limit=3M\nmax-upload-limit=0\nseed-ratio=3\nseed-time=2880\npause-metadata=false\nalways-resume=false\nauto-save-interval=1\nfile-allocation=none\nforce-save=false\nmax-overall-download-limit=0\nmax-download-limit=0\nsave-session=$sdadir/aria2.session\nsave-session-interval=1" > $sdadir/aria2.conf && $sdadir/tracker_update.sh
		}
		[ "$1" = "transmission" ] && {
			[ "$autorestore" -a ! -d $sdadir/web/tr-web-control -o ! "$autorestore" -a ! -d /usr/share/transmission/web/tr-web-control ] && {
				echo -e "\n检测到还没有安装第三方加强版 Web-UI ，即将下载第三方加强版 ${YELLOW}Transmission Web-UI$RESET ······" && sleep 2
				github_download "$1-webUI.tmp" "https://github.com/ronggang/transmission-web-control/archive/master.tar.gz"
				if [ "$?" = 0 ];then
					echo -e "\n$GREEN下载成功！$RESET即将解压安装"
					tar -zxf /tmp/transmission-webUI.tmp -C /tmp
					[ "$autorestore" ] && mv -f $sdadir/web/index.html $sdadir/web/index.original.html || mv -f /usr/share/transmission/web/index.html /usr/share/transmission/web/index.original.html
					[ "$autorestore" ] && mv -f /tmp/transmission-web-control-master/src/* $sdadir/web/ || mv -f /tmp/transmission-web-control-master/src/* /usr/share/transmission/web/
					rm -rf /tmp/$1-webUI.tmp /tmp/transmission-web-control-master
				else
					echo -e "\n$RED下载失败！目前仅能使用原版 Web-UI"
				fi
			}
			firewalllog "del" "$1" && [ ! -d $sdadir ] && mkdir -p $sdadir && log "新建文件夹$sdadir"
			[ "$autorestore" ] && variable="-c $sdadir/config" || variable=""
			newpeerport=$(uci $variable -q get transmission.@transmission[0].peer_port)
			newdefineport=$(uci $variable -q get transmission.@transmission[0].rpc_port)
			while [ "$(netstat -lnWp | grep ":$newpeerport " | awk '{print $NF}' | sed 's/.*\///' | head -1)" ];do let newpeerport++;sleep 1;done
			while [ "$(netstat -lnWp | grep tcp | grep ":$newdefineport " | awk '{print $NF}' | sed 's/.*\///' | head -1)" ];do let newdefineport++;sleep 1;done
			uci $variable -q set transmission.@transmission[0].enabled=1
			uci $variable -q set transmission.@transmission[0].config_dir=$sdadir
			uci $variable -q set transmission.@transmission[0].user=root
			uci $variable -q set transmission.@transmission[0].group=root
			[ "$autorestore" ] && uci $variable -q set transmission.@transmission[0].web_home=$sdadir/web
			uci $variable -q set transmission.@transmission[0].download_dir="$num"
			uci $variable -q set transmission.@transmission[0].download_queue_size=2
			uci $variable -q set transmission.@transmission[0].incomplete_dir="$(echo $num | sed 's#/$##')/transmission下载中文件"
			uci $variable -q set transmission.@transmission[0].incomplete_dir_enabled=true
			uci $variable -q set transmission.@transmission[0].lpd_enabled=true
			uci $variable -q set transmission.@transmission[0].peer_limit_per_torrent=120
			uci $variable -q set transmission.@transmission[0].peer_port=$newpeerport
			uci $variable -q set transmission.@transmission[0].peer_socket_tos=lowcost
			uci $variable -q set transmission.@transmission[0].queue_stalled_minutes=240
			uci $variable -q set transmission.@transmission[0].rpc_host_whitelist="*.*.*.*"
			uci $variable -q set transmission.@transmission[0].rpc_host_whitelist_enabled=true
			uci $variable -q set transmission.@transmission[0].rpc_port=$newdefineport
			uci $variable -q set transmission.@transmission[0].rpc_whitelist="*.*.*.*"
			uci $variable -q set transmission.@transmission[0].rpc_whitelist_enabled=true
			uci $variable -q set transmission.@transmission[0].speed_limit_up=3072
			uci $variable -q set transmission.@transmission[0].speed_limit_up_enabled=true
			uci $variable -q set transmission.@transmission[0].umask=22
			uci $variable -q set transmission.@transmission[0].rpc_authentication_required=true
			uci $variable -q set transmission.@transmission[0].rpc_username=admin
			uci $variable -q set transmission.@transmission[0].rpc_password=12345678 && uci $variable -q commit
			/etc/init.d/transmission start &> /dev/null
		}
		runtimecount=0
		while [ ! "$(pidof $3)" -a "$runtimecount" -lt 5 ];do let runtimecount++;sleep 1;done
		if [ "$(pidof $3)" ];then
			[ "$1" = "aria2" ] && {
				webui="/ariang"
				{
					echo -e "#!/bin/sh /etc/rc.common\n\nSTART=95"
					[ "$autorestore" ] && echo -e "\nwhile [ \"\$(cat /proc/xiaoqiang/boot_status)\" != 3 ];do sleep 1;done\nln -sf $sdadir/service_$1 /etc/init.d/$1"
					echo -e "\nstart() {"
				} > $autostartfileinit
				newdefineport=8888 && while [ "$(netstat -lnWp | grep tcp | grep ":$newdefineport " | awk '{print $NF}' | sed 's/.*\///' | head -1)" ];do let newdefineport++;sleep 1;done
				firewalllog "add" "$1" "wan${newdefineport}rdr1" "tcp" "1" "wan" "$newdefineport" "8080"
				firewalllog "add" "$1" "wan6800rdr1" "tcp" "1" "wan" "6800" "6800"
				firewalllog "add" "$1" "wan6881rdr3" "tcpudp" "2" "wan" "6881-6999"
				echo -e "\t$sdadir/tracker_update.sh" >> $autostartfileinit
				echo -e "}\n\nstop() {\n\tservice_stop /usr/bin/aria2c\n\tservice_stop $sdadir/aria2c\n}" >> $autostartfileinit && chmod 755 $autostartfileinit && log "新建自启动文件$autostartfileinit"
				ln -sf $autostartfileinit $autostartfilerc && chmod 755 $autostartfilerc && cp -pf $autostartfileinit $sdadir/service_$1 && $autostartfileinit restart &> /dev/null
			}
			[ "$1" = "transmission" ] && {
				firewalllog "add" "$1" "wan${newpeerport}rdr3" "tcpudp" "1" "wan" "$newpeerport" "$newpeerport"
				firewalllog "add" "$1" "wan${newdefineport}rdr1" "tcp" "1" "wan" "$newdefineport" "$newdefineport"
			}
			[ "$autorestore" ] && sed -i "/$1/d;/exit 0/i$sdadir/service_$1 restart &" /data/start_service_by_firewall
			echo -e "\n$YELLOW$1$RESET 端口转发规则 $GREEN已全部更新$RESET，即将重启防火墙 ······" && sleep 2 && /etc/init.d/firewall restart &> /dev/null
			echo -e "\n${YELLOW}$1 $GREEN已运行$RESET并设置为$YELLOW开机自启动！$RESET"
			[ "$1" = "aria2" ] && echo -e "\n管理页面地址：$SKYBLUE$hostip$webui$RESET"
			[ "$1" = "transmission" ] && echo -e "\n管理页面地址：$SKYBLUE$hostip:$newdefineport$RESET"
			ipv4=$(curl -m 3 -sLk v4.ident.me)
			[ "$ipv4" ] && echo -e "\n外网管理页面地址：$SKYBLUE$ipv4:$newdefineport$webui$RESET"
			[ "$1" = "transmission" ] && echo -e "\n初始账号：${PINK}admin$RESET 初始密码：${PINK}12345678$RESET"
		else
			echo -e "\n$RED启动失败！$RESET请尝试修改 $BLUE/etc/opkg/distfeeds.conf$RESET 中的地址后重试安装！"
			rm -rf $sdadir && log "删除文件夹$sdadir"
			[ "$1" = "aria2" ] && rm -rf /www/ariang /usr/bin/aria2c && opkg remove ariang aria2 &> /dev/null
			[ "$1" = "transmission" ] && rm -rf /etc/config/transmission /usr/share/transmission /usr/bin/transmission-daemon && opkg remove transmission-web transmission-daemon-openssl transmission-daemon-mbedtls libnatpmp libminiupnpc &> /dev/null
		fi
	fi
	main
}
domainblacklist_update(){
	[ -f /data/domainblacklist ] && [ "$(grep $devmac /data/domainblacklist)" ] && {
		echo -e "\n$SKYBLUE$devmac$GREEN$devname$YELLOW当前已添加网页黑名单：$RESET"
		echo "---------------------------------------------------------"
		sed -n /$devmac/p /data/domainblacklist | awk '{print NR":'$SKYBLUE'\t"$2"'$RESET'"}'
		echo "---------------------------------------------------------"
		[ "$(grep $devmac /data/domainblacklist)" ] && echo -e "$PINK删除请输入 ${YELLOW}-ID $PINK，如：${YELLOW}-2$PINK 删除第二条已添加网页黑名单$RESET"
	}
	[ "$1" = "reload" ] && /data/domainblacklist "reload"
	return 0
}
main(){
	num="$1" && [ ! "$num" ] && {
		echo -e "\n$YELLOW=========================================================$RESET"
		echo -e "\n$PINK\t\t[[  这里以下是主页面  ]]$RESET"
		echo -e "\n$GREEN=========================================================$RESET"
		echo -e "\n欢迎使用$YELLOW小米路由器$GREEN简易安装插件脚本 $PINK$version$RESET ，觉得好用希望能够$RED$BLINK打赏支持~！$RESET"
		echo -e "\n$PINK请输入你的选项：$RESET"
		echo "---------------------------------------------------------"
		echo -e "1. $RED更新或下载$RESET并$GREEN启动$RESET最新版${YELLOW}qbittorrent增强版$RESET（BT & 磁链下载神器）"
		echo -e "2. $RED更新或下载$RESET并$GREEN启动$RESET最新版${YELLOW}Alist$RESET（挂载网盘神器）"
		echo -e "3. $RED更新或下载$RESET并$GREEN启动$RESET最新版${YELLOW}AdGuardHome$RESET（DNS 去广告神器）"
		echo -e "4. $RED下载$RESET并$GREEN启动$RESET${YELLOW}Aria2$RESET（经典下载神器）"
		echo -e "5. $RED下载$RESET并$GREEN启动$RESET${YELLOW}VSFTP$RESET（FTP 服务器搭建神器）"
		echo -e "6. $RED下载$RESET并$GREEN启动$RESET${YELLOW}Transmission$RESET（PT 下载神器）"
		echo -e "7. $GREEN添加$RESET或$RED删除$RESET设备禁止访问网页$RED黑名单$RESET（针对某个设备禁止访问黑名单中的网页）"
		echo -e "8. $GREEN实时$RESET或$RED定时$YELLOW网络唤醒局域网内设备$RESET"
		echo -e "9. $RED更新或下载$RESET并$GREEN启动$RESET最新版${YELLOW}ZeroTier-One$RESET（老牌免费内网穿透神器）"
		echo -e "10.$RED更新或下载$RESET并$GREEN启动$RESET最新版${YELLOW}Docker$RESET（老牌应用容器引擎）"
		echo -e "11.$RED下载$RESET并$GREEN启动$RESET最新版${YELLOW}Home-Assistant$RESET（智能家居设备控制神器）"
		echo -e "\n99. $RED$BLINK给作者打赏支持$RESET"
		echo "---------------------------------------------------------"
		echo -e "del+ID. 一键删除对应选项插件 如：${YELLOW}del1$RESET"
		echo -e "0. 退出$YELLOW小米路由器$GREEN简易安装插件脚本$RESET"
		[ "$changlogshowed" != "true" -a -f ${0%/*}/XiaomiSimpleInstallBox-change.log ] && {
			sed -i '2s/changlogshowed=.*/changlogshowed=true/' $0 && changlogshowed=true
			echo -e "\n$PINK=========================================================$RESET"
			echo -e "\n$YELLOW\t小米路由器$GREEN简易安装插件脚本$YELLOW更新日志$RESET"
			cat ${0%/*}/XiaomiSimpleInstallBox-change.log
			echo -e "\n$PINK=========================================================$RESET"
		}
	}
	while [ ! "$num" ];do
		echo -ne "\n"
		read -p "请输入对应选项的数字 > " num
		[ "$num" = 99 ] && break
		[ "${num:0:3}" = "del" ] && [ "${num:3}" ] && [ ! "$(echo ${num:3} | sed 's/[0-9]//g')" ] && [ "${num:3}" -gt 0 -a "${num:3}" -le 11 ] && break
		[ "$(echo $num | sed 's/[0-9]//g')" -o ! "$num" ] && num="" && continue
		[ "$num" -lt 0 -o "$num" -gt 11 ] && num="" && continue
		[ "$num" -eq 0 ] && echo && exit
	done
	[ "${num:0:3}" = "del" ] && {
		case "${num:3}" in
			1)	plugin="qBittorrent";pluginfile="qbittorrent-nox";;
			2)	plugin="Alist";pluginfile="alist";;
			3)	plugin="AdGuardHome";pluginfile="AdGuardHome";;
			4)	plugin="aria2";pluginfile="aria2.conf";;
			5)	plugin="vsftpd";pluginfile=".notexist";;
			6)	plugin="transmission";pluginfile="settings.json";;
			7)	plugin="设备禁止访问网页黑名单";pluginfile=".notexist";;
			8)	plugin="etherwake";pluginfile=".notexist";;
			9)	plugin="zerotier";pluginfile="zerotier-one";;
			10)	plugin="docker";pluginfile="docker";;
			11)	plugin="homeassistant";pluginfile="docker";;
		esac
		echo -e "\n$PINK确认一键卸载 $plugin 吗？（若确认所有配置文件将会全部删除）$RESET" && num=""
		echo "---------------------------------------------------------"
		echo "1. 确认卸载"
		echo "---------------------------------------------------------"
		echo "0. 返回主页面"
		while [ ! "$num" ];do
			echo -ne "\n"
			read -p "请输入对应选项的数字 > " num
			[ "$(echo $num | sed 's/[0-9]//g')" -o ! "$num" ] && num="" && continue
			[ "$num" -gt 1 ] && num="" && continue
			[ "$num" -eq 0 ] && main
			sda_install_remove "$plugin" "$pluginfile" "del"
		done
	}
	case "$num" in
		1)	sda_install_remove "qBittorrent" "qbittorrent-nox" "-v" "30MB" "c0re100" "qBittorrent-Enhanced-Edition" "rm -rf /.cache /.config /.local";;
		2)	sda_install_remove "Alist" "alist" "version | grep v" "64MB" "alist-org" "alist";;
		3)	sda_install_remove "AdGuardHome" "AdGuardHome" "--version" "30MB" "AdGuardTeam" "AdGuardHome";;
		4)	sda_install_remove "aria2" "aria2.conf" "aria2c" "30KB";;
		5)	sda_install_remove "vsftpd";;
		6)	sda_install_remove "transmission" "settings.json" "transmission-daemon" "5KB";;
		7)
			devnum="$2" && domain="" && [ ! "$devnum" ] && {
				echo -e "\n$PINK请选择需要操作的设备：$RESET"
				echo "---------------------------------------------------------"
				if [ -f /tmp/dhcp.leases ];then
					echo -e "${GREEN}ID\t$SKYBLUE设备 MAC 地址\t\t$PINK设备 IP 地址\t$GREEN设备名称$RESET"
					cat /tmp/dhcp.leases | awk '{print NR":'$SKYBLUE'\t"$2"'$PINK'\t"$3"'$GREEN'\t"$4"'$RESET'"}'
				else
					echo -e "$RED获取设备列表失败！请手动输入 MAC 地址进行继续$RESET"
				fi
				echo -e "255.\t$SKYBLUE手动输入 MAC 地址$RESET"
				echo "---------------------------------------------------------"
				echo -e "0.\t返回上一页"
			}
			while [ ! "$devnum" ];do
				echo -ne "\n"
				read -p "请输入对应设备的数字 > " devnum
				[ "$(echo $devnum | sed 's/[0-9]//g')" -o ! "$devnum" ] && devnum="" && continue
				if [ -f /tmp/dhcp.leases ];then
					[ "$devnum" -gt $(cat /tmp/dhcp.leases | wc -l) -a "$devnum" != 255 ] && devnum="" && continue
				else
					[ "$devnum" != 255 ] && devnum="" && continue
				fi
				[ "$devnum" -eq 0 ] && main
			done
			devmac=$(sed -n ${devnum}p /tmp/dhcp.leases 2> /dev/null | awk '{print $2}')
			devname=" $(sed -n ${devnum}p /tmp/dhcp.leases 2> /dev/null | awk '{print $4}') "
			[ "$devnum" = 255 ] && {
				echo -e "\n$PINK请输入 xx:xx:xx:xx:xx:xx 格式的 MAC 地址：$RESET" && devmac=""
				echo "---------------------------------------------------------"
				while [ ! "$devmac" ];do
					echo -ne "\n"
					read -p "请输入 xx:xx:xx:xx:xx:xx 格式的 MAC 地址 > " devmac
					devmac=$(echo $devmac | awk '{print tolower($0)}')
					[ ! "$devmac" ] && continue
					[ "$devmac" = 0 ] && main "$num"
					[ ! "$(echo $devmac |grep -E '^([0-9a-f][02468ace])(([:]([0-9a-f]{2})){5})$')" ] && echo -e "\n$RED输入错误！请重新输入！$RESET" && devmac="" && continue
				done
			}
			echo -e "\n$PINK请输入要添加的网页地址或网页地址包含的关键字（如 ${SKYBLUE}www.baidu.com $PINK或 ${SKYBLUE}baidu.com $PINK或 ${SKYBLUE}baidu$PINK）：$RESET"
			echo -e "$PINK当前已选择设备：$SKYBLUE$devmac$GREEN$devname$RESET"
			echo "---------------------------------------------------------"
			echo -e "0.\t返回上一页" && domainblacklist_update
			[ ! -f /data/domainblacklist ] && {
				[ "$autorestore" ] && echo -e "while [ \"\$(cat /proc/xiaoqiang/boot_status)\" != 3 ];do sleep 1;done\n[ ! \"\$(grep domainblacklist /etc/crontabs/root)\" ] && echo \"* * * * * /data/domainblacklist\" >> /etc/crontabs/root && /etc/init.d/cron restart &> /dev/null" && sed -i "/domainblacklist/d;/exit 0/i/data/domainblacklist &" /data/start_service_by_firewall
				echo -e "reload(){\n\tiptables -D FORWARD -i br-lan -j DOMAIN_REJECT_RULE &> /dev/null;ip6tables -D FORWARD -i br-lan -j DOMAIN_REJECT_RULE &> /dev/null\n\tiptables -F DOMAIN_REJECT_RULE &> /dev/null;ip6tables -F DOMAIN_REJECT_RULE &> /dev/null\n\tiptables -X DOMAIN_REJECT_RULE &> /dev/null;ip6tables -X DOMAIN_REJECT_RULE &> /dev/null\n\tiptables -N DOMAIN_REJECT_RULE;ip6tables -N DOMAIN_REJECT_RULE\n\tiptables -I FORWARD -i br-lan -j DOMAIN_REJECT_RULE;ip6tables -I FORWARD -i br-lan -j DOMAIN_REJECT_RULE\n\tsed -n /\\\|\\\|/,/*/p /data/domainblacklist | tail +2 | while read LINE;do\n\t\tiptables -A DOMAIN_REJECT_RULE -m mac --mac-source \${LINE:1:18} -m string --string \"\${LINE:19:\$\$}\" --algo bm -j REJECT\n\t\tip6tables -A DOMAIN_REJECT_RULE -m mac --mac-source \${LINE:1:18} -m string --string \"\${LINE:19:\$\$}\" --algo bm -j REJECT\n\tdone\n}\ndomain_rule_check(){\n\t[ ! \"\$(iptables -S FORWARD | grep -e -i | head -1 | grep DOMAIN)\" -o ! \"\$(ip6tables -S FORWARD | grep -e -i | head -1 | grep DOMAIN)\" ] && reload\n}\n[ \"\$1\" = \"reload\" ] && reload || domain_rule_check"
			} > /data/domainblacklist && log "新建文件/data/domainblacklist" && chmod 755 /data/domainblacklist && sed -n /\|\|/,/*/p /etc/domainblacklist 2> /dev/null | tail +2 >> /data/domainblacklist && rm -f /etc/domainblacklist
			[ ! "$(grep domainblacklist /etc/crontabs/root)" ] && echo "* * * * * /data/domainblacklist" >> /etc/crontabs/root && /etc/init.d/cron restart &> /dev/null && log "添加定时任务domainblacklist到/etc/crontabs/root文件中"
			while [ ! "$domain" ];do
				echo -ne "\n"
				read -p "请输入要过滤的网页地址或网页地址包含的关键字，返回上一页输入 0 > " domain
				[ ! "$domain" ] && continue
				[ "$domain" = 0 ] && {
					[ "$devnum" = 255 ] && main "$num" "$devnum" || main "$num"
				}
				[ "${domain:0:1}" = "-" ] && {
					[ "$(echo ${domain:1:$$} | sed 's/[0-9]//g')" -o ! "$(grep $devmac /data/domainblacklist 2> /dev/null)" ] && echo -e "\n$RED输入错误！请重新输入！$RESET" && domain="" && continue
					domainrule=$(grep $devmac /data/domainblacklist | awk '{print $2}' | sed -n ${domain:1:$$}p | sed 's/#//')
					if [ "$domainrule" ];then
						sed -i "/$devmac $domainrule$/d" /data/domainblacklist
						echo -e "\n$SKYBLUE$devmac$GREEN$devname$YELLOW网页黑名单规则 $SKYBLUE$domainrule $RED已删除！$RESET" && sleep 1 && domainblacklist_update "reload" && domain="" && continue
					else
						echo -e "\n$RED输入错误！请重新输入！$RESET" && domain="" && continue
					fi
				}
				[ "$(grep -E "$devmac.*$domain$" /data/domainblacklist)" ] && echo -e "\n$SKYBLUE$devmac$GREEN$devname$YELLOW网页黑名单规则 $SKYBLUE$domain $RED已存在！$RESET" && sleep 1 && domainblacklist_update && domain="" && continue
				echo "#$devmac $domain" >> /data/domainblacklist
				echo -e "\n$SKYBLUE$devmac$GREEN$devname$YELLOW网页黑名单规则 $SKYBLUE$domain $GREEN添加成功！$RESET" && sleep 1 && domainblacklist_update "reload" && domain=""
			done;;
		8)	opkg_test_install "etherwake";;
		9)	sda_install_remove "zerotier" "zerotier-one" "-v" "4MB" "xilaochengv" "ZeroTierOne";;
		10)	sda_install_remove "docker" "docker" "-v | grep -oE [.0-9]{1,7} | head -1" "2GB";;
		11)	sda_install_remove "homeassistant" "docker" "" "2GB";;
		99)
			echo -e "\n$RED$BLINK十分感谢您的支持！！！！！！！！$RESET\n\n$YELLOW微信扫码：$RESET\n"
			echo H4sIAAAAAAAAA71UwQ3DMAj8d4oblQcPJuiAmaRSHMMZYzcvS6hyXAPHcXB97Tpon5PJcj5cX2XDfS3wL2mW3i38FhkMwHNqoaSb9YP291p7rSInTCneDRugbLr0q7uhlbX7lkUwxxVsfctaMMW/2a87YPD01e+yGiF6onHq/MAvlFwGUO2AMW7VFwODFGolOMBToaU6d1UEAYwp+jtCN9dxdsppCr4Q4N0F5EbiEiKS/P5MRupGKMGIFp4Jv8jv1lzNyiLMg3QcEc03CMI6U70PImYSU9d2nhxLttkkYKF01fZ/Q9n6Cvu0D1i7gd1rYQZjG2ynYrtL5md8r5P7C7YO2PF8PwRFQamaBwAA | base64 -d | gzip -d
			echo -e "\n$YELLOW支付宝扫码：$RESET\n"
			echo H4sIAAAAAAAAA71USQ7EMAi7zyv8VA4c8oI+sC8ZqQ3gLNC5TCVUKSlgsAnn0c4X7fMm2IyH81A2XNf3wb0Et2d4J3EJQgMog/Rw0Pn66uKdZyRsO3tJYp5qaEij9hrozpolV662nz17EV1igVgQUBPEDQy7Owh+6sYLE+4DlF24I2VYLJVKgRQRzpG1EyJdhYPhB7Wq/K2zINwLaM44w9wKT0mlhmSMjeKLN+Uj5koGuSlKIyBnKtA34yBLaJthCu1nFVkmUy6YtKEEHjRJ94D6NIxyBFFtXABJ9mEbCFV8/xD/qKPV72G3B+Ak82PtzCB21jQCT296tz/WFcESrZeTQ/4u/mqv430B27+RdoQHAAA= | base64 -d | gzip -d && echo "" && exit
	esac
}
[ "$autorestore" ] && {
	[ "$(uci -q get firewall.start_service_by_firewall.reload)" != 1 ] && {
		uci set firewall.start_service_by_firewall=include
		uci set firewall.start_service_by_firewall.path="/data/start_service_by_firewall"
		uci set firewall.start_service_by_firewall.reload='1'
		uci commit firewall
		log "防火墙配置文件/etc/firewall添加规则：start_service_by_firewall"
	}
	[ ! -f /data/start_service_by_firewall ] && {
		echo "exit 0" > /data/start_service_by_firewall
		log "添加跟随防火墙启动文件/data/start_service_by_firewall"
	}
}
sed -i '/XiaomiSimpleInstallBox.sh/d' /etc/profile 2> /dev/null
echo -e "MIRRORS=\"$(echo $MIRRORS)\"\n[ -f $0 ] && {\n\tgithub_download(){\n\t\tfor MIRROR in \$MIRRORS;do\n\t\t\tcurl --connect-timeout 3 -sLko /tmp/\$1 \"\$MIRROR\$2\"\n\t\t\tif [ \"\$?\" = 0 ];then\n\t\t\t\t[ \$(wc -c < /tmp/\$1) -lt 1024 ] && rm -f /tmp/\$1 || break\n\t\t\telse\n\t\t\t\trm -f /tmp/\$1\n\t\t\tfi\n\t\tdone\n\t\t[ -f /tmp/\$1 ] && return 0 || return 1\n\t}\n\trm -f /tmp/XiaomiSimpleInstallBox.sh.tmp && for tmp in \$(ps | grep _update_check | awk '{print \$1}');do [ \"\$tmp\" != \"\$\$\" ] && killpid \$tmp;done\n\twhile [ ! -f /tmp/XiaomiSimpleInstallBox.sh.tmp ];do\n\t\tgithub_download \"XiaomiSimpleInstallBox.sh.tmp\" \"https://raw.githubusercontent.com/xilaochengv/BuildKernelSU/main/XiaomiSimpleInstallBox.sh\"\n\t\t[ \"\$?\" != 0 ] && {\n\t\t\tcurl --connect-timeout 3 -sLko /tmp/XiaomiSimpleInstallBox.sh.tmp \"https://raw.githubusercontent.com/xilaochengv/BuildKernelSU/main/XiaomiSimpleInstallBox.sh\"\n\t\t\t[ \"\$?\" != 0 ] && rm -f /tmp/XiaomiSimpleInstallBox.sh.tmp\n\t\t}\n\tdone\n\tif [ \"\$(sed -n '1p' $0 | sed 's/version=//')\" \< \"\$(sed -n '1p' /tmp/XiaomiSimpleInstallBox.sh.tmp | sed 's/version=//')\" ];then\n\t\t[ \$(sed -n '2p' /tmp/XiaomiSimpleInstallBox.sh.tmp | grep -o false) ] && {\n\t\t\trm -f /tmp/XiaomiSimpleInstallBox-change.log\n\t\t\twhile [ ! -f /tmp/XiaomiSimpleInstallBox-change.log ];do\n\t\t\t\tgithub_download \"XiaomiSimpleInstallBox-change.log\" \"https://raw.githubusercontent.com/xilaochengv/BuildKernelSU/main/XiaomiSimpleInstallBox-change.log\"\n\t\t\t\t[ \"\$?\" != 0 ] && {\n\t\t\t\t\tcurl --connect-timeout 3 -sLko /tmp/XiaomiSimpleInstallBox-change.log \"https://raw.githubusercontent.com/xilaochengv/BuildKernelSU/main/XiaomiSimpleInstallBox-change.log\"\n\t\t\t\t\t[ \"\$?\" != 0 ] && rm -f /tmp/XiaomiSimpleInstallBox-change.log\n\t\t\t\t}\n\t\t\tdone\n\t\t\tmv -f /tmp/XiaomiSimpleInstallBox-change.log ${0%/*}/XiaomiSimpleInstallBox-change.log\n\t\t}\n\t\techo -e \"\\\n$PINK===============================================================$RESET\"\n\t\techo -e \"\\\n$YELLOW小米路由器$GREEN简易安装插件脚本 $PINK\$(sed -n '1p' $0 | sed 's/version=//') $BLUE已自动更新到最新版：$PINK\$(sed -n '1p' /tmp/XiaomiSimpleInstallBox.sh.tmp | sed 's/version=//') ，$BLUE请重新运行脚本$RESET\"\n\t\techo -e \"\\\n$PINK===============================================================$RESET\"\n\t\tmv -f /tmp/XiaomiSimpleInstallBox.sh.tmp $0\n\t\tchmod 755 $0\n\telse\n\t\trm -f /tmp/XiaomiSimpleInstallBox.sh.tmp\n\tfi\n}\n[ ! -f $0 ] && sed -i '/XiaomiSimpleInstallBox.sh/d' /etc/profile 2> /dev/null\n[ ! \"\$(grep $0 /etc/profile 2> /dev/null)\" ] && {\n\tsed -n '1,43p' /tmp/XiaomiSimpleInstallBox_update_check > /tmp/XiaomiSimpleInstallBox_update_check.tmp\n\tsed -i 's/\\\t/\\\\\\\t/g' /tmp/XiaomiSimpleInstallBox_update_check.tmp\n\tsed -i 's/\\\"/\\\\\\\\\\\"/g' /tmp/XiaomiSimpleInstallBox_update_check.tmp\n\tsed -i 's/\\\$/\\\\\\\\\\$/g' /tmp/XiaomiSimpleInstallBox_update_check.tmp\n\tsed -i 's/\\\\\\\n/\\\\\\\\\\\\\\\\\\\\\\\n/' /tmp/XiaomiSimpleInstallBox_update_check.tmp\n\tsed -i ':i;N;s|\\\n|\\\\\\\n|;ti' /tmp/XiaomiSimpleInstallBox_update_check.tmp\n\tsed -i 's/ ，\e\[1;34m请重新运行脚本//' /tmp/XiaomiSimpleInstallBox_update_check.tmp\n\techo >> /etc/profile && echo \"echo -e \\\"\$(cat /tmp/XiaomiSimpleInstallBox_update_check.tmp)\\\nrm -f /tmp/XiaomiSimpleInstallBox_update_check\\\" > /tmp/XiaomiSimpleInstallBox_update_check && chmod 755 /tmp/XiaomiSimpleInstallBox_update_check && (exec /tmp/XiaomiSimpleInstallBox_update_check &)\" >> /etc/profile 2> /dev/null\n\tsed -i '/./,/^$/!d' /etc/profile\n}\nrm -f /tmp/XiaomiSimpleInstallBox_update_check /tmp/XiaomiSimpleInstallBox_update_check.tmp" > /tmp/XiaomiSimpleInstallBox_update_check && chmod 755 /tmp/XiaomiSimpleInstallBox_update_check && /tmp/XiaomiSimpleInstallBox_update_check &
main
