version=v1.0.5e
RED='\e[0;31m';GREEN='\e[1;32m';YELLOW='\e[1;33m';BLUE='\e[1;34m';PINK='\e[1;35m';SKYBLUE='\e[1;36m';UNDERLINE='\e[4m';BLINK='\e[5m';RESET='\e[0m'
hardware_release=$(cat /etc/openwrt_release | grep RELEASE | grep -oE [.0-9]{1,10})
hardware_arch=$(cat /etc/openwrt_release | grep ARCH | awk -F "'" '{print $2}')
sdalist=$(df | sed -n '1!p' | grep -vE "rom|tmp|ini|overlay" | awk '{print $6}')
hostip=$(uci get network.lan.ipaddr)
wanifname=$(uci get network.wan.ifname)
MIRRORS="
https://gh.ddlc.top/
https://hub.gitmirror.com/
https://mirror.ghproxy.com/
https://ghps.cc/
"
log(){
	echo "[ $(date '+%F %T') ] $1" >> ${0%/*}/XiaomiSimpleInstallBox.log
}
opkg_test_install(){
	[ -z "$(opkg list-installed | grep $1 2> /dev/null)" ] && {
		echo -e "\n本次操作需要使用到 $YELLOW$1$RESET" && sleep 1
		echo -e "\n本机还$RED没有安装 $YELLOW$1$RESET ！即将通过 opkg 下载安装\n" && sleep 1
		[ "$1" = "aria2" ] && rm -rf /www/ariang && opkg remove ariang aria2 &> /dev/null
		[ "$1" = "vsftpd" ] && rm -f /etc/vsftpd.conf && opkg remove vsftpd &> /dev/null
		[ "$1" = "transmission" ] && rm -rf /etc/config/transmission /usr/share/transmission/ && opkg remove transmission-web transmission-daemon-openssl transmission-daemon-mbedtls libnatpmp libminiupnpc &> /dev/null
		[ "$1" = "wakeonlan" ] && rm -rf /usr/share/perl /usr/lib/perl5/ && opkg remove wakeonlan perlbase-net perlbase-time perlbase-dynaloader perlbase-filehandle perlbase-class perlbase-getopt perlbase-io perlbase-socket perlbase-selectsaver perlbase-symbol perlbase-scalar perlbase-posix perlbase-tie perlbase-list perlbase-fcntl perlbase-xsloader perlbase-errno perlbase-bytes perlbase-base perlbase-essential perlbase-config perl &> /dev/null
		[ ! -f /tmp/opkg_updated ] && {
			opkg update
			if [ "$?" != 0 ];then
			[ ! -f /etc/opkg/distfeeds.conf.backup ] && mv /etc/opkg/distfeeds.conf /etc/opkg/distfeeds.conf.backup && log "文件/etc/opkg/distfeeds.conf改名为distfeeds.conf.backup"
				echo -e "\n更新源$RED连接失败$RESET，将尝试根据获取的机型信息 $PINK$hardware_release-$hardware_arch$RESET 进行重试\n" && sleep 2
				echo "src/gz openwrt_base http://downloads.openwrt.org/releases/packages-$hardware_release/$hardware_arch/base" > /etc/opkg/distfeeds.conf
				echo "src/gz openwrt_packages http://downloads.openwrt.org/releases/packages-$hardware_release/$hardware_arch/packages" >> /etc/opkg/distfeeds.conf
				echo "src/gz openwrt_routing http://downloads.openwrt.org/releases/packages-$hardware_release/$hardware_arch/routing" >> /etc/opkg/distfeeds.conf && log "新建文件/etc/opkg/distfeeds.conf"
				opkg update
				[ "$?" = 0 ] && touch /tmp/opkg_updated || {
					echo -e "\n更新源$RED连接失败$RESET！请检查 $BLUE/etc/opkg/distfeeds.conf$RESET 中的地址是否正确或 ${SKYBLUE}/overlay$RESET 空间是否足够后重试！" && main
				}
			else
				touch /tmp/opkg_updated
			fi
		}
		opkg install $1
		[ "$?" != 0 ] && echo -e "\n安装 ${YELLOW}$1$RED 失败！$RESET请检查 $BLUE/etc/opkg/distfeeds.conf$RESET 中的地址是否正确并有效！" && main
		echo -e "\n$GREEN安装 $YELLOW$1 $GREEN成功$RESET" && sleep 2 && [ "$1" = "vsftpd" ] && newuser=1
	}
	[ "$1" = "vsftpd" ] && {
		[ -z "$newuser" ] && {
			echo -e "\n$PINK是否需要重新配置参数？$RESET" && num="$2"
			echo "---------------------------------------------------------"
			echo "1. 重新配置"
			echo "---------------------------------------------------------"
			echo "0. 返回主页面"
			while [ -z "$num" ];do
				echo -ne "\n"
				read -p "请输入对应选项的数字 > " num
				[ -n "$(echo $num | sed 's/[0-9]//g')" -o -z "$num" ] && num="" && continue
				[ "$num" -gt 1 ] && num="" && continue
				[ "$num" -eq 0 ] && main
			done
		}
		echo -e "\n$PINK请输入要设置的 FTP 监听端口$RESET" && ftpnum="$3"
		echo "---------------------------------------------------------"
		echo -e "1. 使用默认端口（${YELLOW}21$RESET）"
		echo "---------------------------------------------------------"
		echo "0. 返回上一页"
		while [ -z "$ftpnum" ];do
			echo -ne "\n"
			read -p "请输入要设置的 FTP 监听端口 > " ftpnum
			[ -n "$(echo $ftpnum | sed 's/[0-9]//g')" -o -z "$ftpnum" ] && ftpnum="" && continue
			[ "$ftpnum" -gt 65535 ] && ftpnum="" && continue
			[ "$ftpnum" -eq 0 ] && opkg_test_install "vsftpd"
			if [ "$ftpnum" != 1 ];then
				echo -e "\n当前设置的 FTP 监听端口为：$PINK$ftpnum$RESET" && cnum=""
				while [ -z "$cnum" ];do
					echo -ne "\n"
					read -p "确认请输入 1 ，返回修改请输入 0 > " cnum
					[ -n "$(echo $cnum | sed 's/[0-9]//g')" -o -z "$cnum" ] && cnum="" && continue
					[ "$cnum" -gt 1 ] && cnum="" && continue
					[ "$cnum" -eq 0 ] && ftpnum=""
				done
				process=$(netstat -lnWp | grep tcp | grep ":$ftpnum " | awk '{print $NF}' | sed 's/.*\///' | head -1)
				[ -n "$process" -a "$process" != "$1" ] && echo -e "\n$RED检测到 $PINK$ftpnum $RED端口已被 $YELLOW$process $RED占用！请重新设置！$RESET" && ftpnum="" && sleep 1
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
		while [ -z "$anonymous" ];do
			echo -ne "\n"
			read -p "请输入对应选项的数字 > " anonymous
			[ -n "$(echo $anonymous | sed 's/[0-9]//g')" -o -z "$anonymous" ] && anonymous="" && continue
			[ "$anonymous" -gt 2 ] && anonymous="" && continue
			[ "$anonymous" -eq 0 ] && opkg_test_install "vsftpd" "$num"
			[ "$anonymous" = 1 ] && anonymous="YES" || anonymous="NO"
		done
		[ "$anonymous" = "YES" -a -z "$anonymousdir" ] && {
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
		echo -e "\n$PINK是否允许用户名登陆？$RESET" && locals="" && localsdir="" && localswriteable=""
		echo "---------------------------------------------------------"
		echo "1. 允许用户名登陆"
		echo "2. 禁止用户名登陆"
		echo "---------------------------------------------------------"
		echo "0. 返回上一页"
		while [ -z "$locals" ];do
			echo -ne "\n"
			read -p "请输入对应选项的数字 > " locals
			[ -n "$(echo $locals | sed 's/[0-9]//g')" -o -z "$locals" ] && locals="" && continue
			[ "$locals" -gt 2 ] && locals="" && continue
			[ "$locals" -eq 0 ] && opkg_test_install "vsftpd" "$num" "$ftpnum"
			[ "$locals" = 1 ] && locals="YES" || locals="NO"
		done
		[ "$locals" = "YES" ] && {
			echo -e "\n$PINK请设置登陆用户名（以前有设置过的可跳过）：$RESET" && username=""
			sed -i 's#^ftp:.*#ftp:*:55:55:ftp:/:/bin/false#' /etc/passwd
			echo "---------------------------------------------------------"
			echo "0. 跳过设置"
			echo "---------------------------------------------------------"
			while [ -z "$username" ];do
				echo -ne "\n"
				read -p "请设置登陆用户名（不可带标点符号） > " username
				[ -n "$(echo $username | sed 's/[0-9a-zA-Z]//g')" -o -z "$username" ] && username="" && continue
				for tmp in $(cat /etc/passwd | awk -F ':' '{print $1}');do
					[ "$username" = "$tmp" ] && echo -e "\n用户名 $PINK$username$RESET 已存在！$RED请重新设置！$RESET" && username="" && break
				done
			done
			[ -z "$(echo $username | sed 's/[0-9]//g')" ] && [ "$username" -eq 0 ] && username=""
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
		if [ "$ftpnum" != 21 ];then
			[ ! -f /etc/services.backup ] && cp /etc/services /etc/services.backup && log "备份/etc/services文件并改名为services.backup"
			sed -i "s/^ftp\t.*tcp$/ftp\t\t$ftpnum\/tcp/" /etc/services && log "/etc/services文件ftp端口修改为$ftpnum"
		else
			[ -f /etc/services.backup ] && mv -f /etc/services.backup /etc/services && log "恢复/etc/services.backup文件并改名为services"
		fi
		echo -e "listen=NO\nlisten_ipv6=YES\nlisten_port=$ftpnum\nbackground=YES\ncheck_shell=NO\nwrite_enable=YES\nsession_support=YES\ntext_userdb_names=YES\nanonymous_enable=$anonymous\nanon_root=$anonymousdir\nlocal_enable=$locals\nlocal_root=$localsdir\nchroot_local_user=YES\nallow_writeable_chroot=YES\nlocal_umask=080\nfile_open_mode=0777\nuser_config_dir=/cfg/vsftpd/" > /etc/vsftpd.conf
		while [ -n "$(pidof $1)" ];do killpid $(pidof $1 | awk '{print $1}');done && firewalllog "del" "$1" && runtimecount=0 && /etc/init.d/$1 start &> /dev/null
		while [ -z "$(pidof $1)" -a "$runtimecount" -lt 5 ];do let runtimecount++;sleep 1;done
		if [ -n "$(pidof $1)" ];then
			firewalllog "add" "$1" "wan${ftpnum}rdr1" "tcp" "1" "wan" "$ftpnum" "$ftpnum"
			echo -e "\n$YELLOW$1$RESET 端口转发规则 $GREEN已全部更新$RESET，即将重启防火墙 ······" && sleep 2 && /etc/init.d/firewall restart &> /dev/null
			echo -e "\n配置完成！ $YELLOW$1 $GREEN已运行$RESET并设置为$YELLOW开机自启动！$RESET"
			[ "$anonymous" = "YES" ] && chmod 775 $anonymousdir
			[ -n "$username" ] && {
				echo -e "\n$RED请设置登陆密码！$RESET设置方法：退出本脚本后在控制台直接输入：${YELLOW}passwd $PINK$username$RESET"
				echo -e "\n然后输入两次密码确认成功即可（$YELLOW输入密码时控制台不会显示出来$RESET)"
				sed -i 's#/root#/#' /etc/passwd && echo "$username:x:0:0:root:/:/bin/ash" >> /etc/passwd && log "添加用户名$username到/etc/passwd文件中"
			}
		else
			echo -e "\n$RED启动失败！$RESET请尝试修改 $BLUE/etc/opkg/distfeeds.conf$RESET 中的地址后重试安装！"
			rm -f /etc/vsftpd.conf && opkg remove vsftpd &> /dev/null && echo -e "\n${RED}已自动使用 opkg 卸载 $YELLOW$1$RESET"
			[ -f /etc/services.backup ] && mv -f /etc/services.backup /etc/services && log "恢复/etc/services.backup文件并改名为services"
		fi
		main
	}
	[ "$1" = "wakeonlan" ] && {
		echo -e "\n$PINK请输入你的选项$RESET" && num="$2"
		echo "---------------------------------------------------------"
		echo "1. 实时网路唤醒网络设备"
		echo "2. 添加定时网络唤醒任务"
		echo "3. 删除已添加定时网路唤醒任务"
		echo "---------------------------------------------------------"
		echo "0. 返回主页面"
		while [ -z "$num" ];do
			echo -ne "\n"
			read -p "请输入对应选项的数字 > " num
			[ -n "$(echo $num | sed 's/[0-9]//g')" -o -z "$num" ] && num="" && continue
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
			while [ -z "$devnum" ];do
				echo -ne "\n"
				read -p "请输入对应设备的数字 > " devnum
				[ -n "$(echo $devnum | sed 's/[0-9]//g')" -o -z "$devnum" ] && devnum="" && continue
				if [ -f /tmp/dhcp.leases ];then
					[ "$devnum" -gt $(cat /tmp/dhcp.leases | wc -l) -a "$devnum" != 255 ] && devnum="" && continue
				else
					[ "$devnum" != 255 ] && devnum="" && continue
				fi
				[ "$devnum" -eq 0 ] && opkg_test_install "wakeonlan"
			done
			devmac=$(sed -n ${devnum}p /tmp/dhcp.leases 2> /dev/null | awk '{print $2}')
			devname=" $(sed -n ${devnum}p /tmp/dhcp.leases 2> /dev/null | awk '{print $4}') "
			[ "$devnum" = 255 ] && {
				echo -e "\n$PINK请输入 xx:xx:xx:xx:xx:xx 格式的 MAC 地址：$RESET" && devmac=""
				echo "---------------------------------------------------------"
				while [ -z "$devmac" ];do
					echo -ne "\n"
					read -p "请输入 xx:xx:xx:xx:xx:xx 格式的 MAC 地址 > " devmac
					devmac=$(echo $devmac | awk '{print tolower($0)}')
					[ -z "$devmac" ] && continue
					[ "$devmac" = 0 ] && opkg_test_install "wakeonlan" "$num"
					[ -z "$(echo $devmac |grep -E '^([0-9a-f][02468ace])(([:]([0-9a-f]{2})){5})$')" ] && echo -e "\n$RED输入错误！请重新输入！$RESET" && devmac="" && continue
				done
			}
			devip=$(ip neigh | grep $devmac | awk '{print $1}' | grep -v :)
			[ -z "$devip" ] && {
				devip=$(ip neigh | grep FAILED | head -1 | awk '{print $1}' | grep -v :)
				[ -z "$devip" ] && devip=159 && while [ -n "$(ip neigh | grep $devip)" ];do let devip++;done && devip="$(uci get network.lan.ipaddr | sed 's/[0-9]*$//')$devip"
			}
			if [ "$num" = 1 ];then
				ip neigh add "$devip" lladdr "$devmac" nud stale dev br-lan &> /dev/null || ip neigh chg "$devip" lladdr "$devmac" nud stale dev br-lan
				wakeonlan -i $devip $devmac &> /dev/null && echo -e "\n$SKYBLUE$devmac$GREEN$devname$YELLOW发送网络唤醒包成功！$RESET" && ip neigh del "$devip" dev br-lan && sleep 1
			else
				echo -e "\n$PINK请输入要设置的分钟时间（ 0-59 ）：$RESET" && minute=""
				echo "---------------------------------------------------------"
				while [ -z "$minute" ];do
					echo -ne "\n"
					read -p "请输入要设置的分钟时间（ 0-59 ) > " minute
					[ -n "$(echo $minute | sed 's/[0-9]//g')" -o -z "$minute" ] && minute="" && continue
					[ "$minute" -lt 0 -o "$minute" -gt 59 ] && minute=""
				done
				echo -e "\n$PINK请输入要设置的整点时间（ 0-23 ）：$RESET" && hour=""
				echo "---------------------------------------------------------"
				while [ -z "$hour" ];do
					echo -ne "\n"
					read -p "请输入要设置的整点时间（ 0-23 ) > " hour
					[ -n "$(echo $hour | sed 's/[0-9]//g')" -o -z "$hour" ] && hour="" && continue
					[ "$hour" -lt 0 -o "$hour" -gt 23 ] && hour=""
				done
				echo -e "\n$PINK请输入要设置的星期时间（ 1-7 或 *：每天 ）：$RESET" && week=""
				echo "---------------------------------------------------------"
				while [ -z "$week" ];do
					echo -ne "\n"
					read -p "请输入要设置的星期时间（ 1-7 或 *：每天 ) > " week
					[ "$week" = "*" ] && break
					[ -n "$(echo $week | sed 's/[0-9]//g')" -o -z "$week" ] && week="" && continue
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
				echo "$minute $hour * * $week ip neigh add \"$devip\" lladdr \"$devmac\" nud stale dev br-lan || ip neigh chg \"$devip\" lladdr \"$devmac\" nud stale dev br-lan && wakeonlan -i $devip $devmac && ip neigh del \"$devip\" dev br-lan #$wolinfo $(printf "%02d" $hour)点$(printf "%02d" $minute)分 网络唤醒设备 $devmac$devname" >> /etc/crontabs/root && /etc/init.d/cron restart &> /dev/null
				echo -e "\n$YELLOW定时任务 $PINK$wolinfo $(printf "%02d" $hour)点$(printf "%02d" $minute)分 网络唤醒设备 $SKYBLUE$devmac$GREEN$devname$YELLOW任务添加成功！$RESET" && sleep 1
			fi
		else
			num="" && while [ -z "$num" ];do
				if [ -n "$(cat "/etc/crontabs/root" | grep '网络唤醒')" ];then
					echo -e "\n$PINK请输入要删除的任务序号：$RESET"
					echo "---------------------------------------------------------"
					cat "/etc/crontabs/root" | grep '网络唤醒' | sed 's/.*#//' | awk '{print NR": "$0}'
					echo "---------------------------------------------------------"
					echo "0. 返回上一页"
					echo -ne "\n"
					read -p "请输入正确的任务序号 > " num
					[ -n "$(echo $num | sed 's/[0-9]//g')" -o -z "$num" ] && num="" && continue
					[ "$num" -gt $(cat "/etc/crontabs/root" | grep '网络唤醒' | sed 's/.*#//' | wc -l) ] && num="" && continue
					[ "$num" -eq 0 ] && opkg_test_install "wakeonlan"
					ruleweek=$(cat "/etc/crontabs/root" | grep '网络唤醒' | sed 's/.*#//' | sed -n ${num}p | awk '{print $1}')
					ruletime=$(cat "/etc/crontabs/root" | grep '网络唤醒' | sed 's/.*#//' | sed -n ${num}p | awk '{print $2}')
					rulemac=$(cat "/etc/crontabs/root" | grep '网络唤醒' | sed 's/.*#//' | sed -n ${num}p | awk '{print $4}')
					rulename=" $(cat "/etc/crontabs/root" | grep '网络唤醒' | sed 's/.*#//' | sed -n ${num}p | awk '{print $5}') "
					sed -i "/$ruleweek $ruletime/{/$rulemac/d}" /etc/crontabs/root && /etc/init.d/cron restart &> /dev/null
					echo -e "\n$YELLOW定时任务 $PINK$ruleweek $ruletime 网络唤醒设备 $SKYBLUE$rulemac$GREEN$rulename$YELLOW任务删除成功！$RESET" && sleep 1 && num=""
				else
					echo -e "\n$RED当前没有定时网络唤醒设备任务！$RESET" && sleep 1 && opkg_test_install "wakeonlan"
				fi
			done
		fi
		opkg_test_install "wakeonlan"
	}
	return 0
}
sdadir_available_check(){
	sdadiravailable=$(df | grep " ${sdadir%/*}$" | awk '{print $4}') && upxneeded=""
	sizeneeded=$(echo $4 | grep -oE [0-9]{1,10})
	[ -n "$(echo $4 | grep MB)" ] && sizeneeded=$(($(echo $4 | grep -oE [0-9]{1,10})*1024))
	[ -n "$(echo $4 | grep GB)" ] && sizeneeded=$(($(echo $4 | grep -oE [0-9]{1,10})*1024*1024))
	if [ -z "$(echo $1 | grep -oE 'aria2|vsftpd|transmission')" ];then
		[ "$sdadiravailable" -lt $sizeneeded ] && {
			echo -e "\n所选目录 $BLUE${sdadir%/*} $RED空间不足 $(($sizeneeded/1024)) MB$RESET！无法直接下载使用！不过可以尝试使用 ${YELLOW}upx$RESET 压缩后使用" && sleep 2
			tmpdiravailable=$(df | grep " /tmp$" | awk '{print $4}')
			[ "$tmpdiravailable" -ge 102400 ] && {
				echo -e "\n检测到临时目录 $BLUE/tmp$RESET 可用空间为 $RED$(awk BEGIN'{printf "%0.3f MB",'$tmpdiravailable'/1024}')$RESET" && tmpnum=""
				echo -e "\n$RED临时目录内的文件会在路由器重启后丢失$RESET，使用的话，每次开机后将会自动重新下载主程序文件，是否使用临时目录？" && sleep 1
				while [ -z "$tmpnum" ];do
					echo -ne "\n"
					read -p "确认使用请输入 y ，尝试压缩后使用请输入 1 ，返回上一页请输入 0 > " tmpnum
					[ "$tmpnum" = y ] && tmpdir="/tmp/XiaomiSimpleInstallBox" && echo -e "\n若使用临时目录一段时间后，重启路由器$YELLOW自动下载失败$RESET则可能是 ${YELLOW}github加速镜像 $RED已失效$RESET，届时可以运行本脚本重新下载以$GREEN更新开机时的下载地址$RESET" && sleep 3 && break
					[ -n "$(echo $tmpnum | sed 's/[0-9]//g')" -o -z "$tmpnum" ] && tmpnum="" && continue
					[ "$tmpnum" -gt 1 ] && tmpnum="" && continue
					[ "$tmpnum" -eq 0 ] && sda_install_remove "$1" "$2" "$3" "$4" "$5" "$6" "$7" "return"
				done
			}
			[ -z "$tmpdir" ] && {
				echo -e "\n下载完成后请使用电脑利用 ${YELLOW}upx$RESET 压缩器对其进行压缩"
				echo -e "\n${YELLOW}upx$RESET 主程序可以在 ${SKYBLUE}https://github.com/upx/upx/releases/latest$RESET 下载"
				echo -e "\n使用方法：下载完成后，先将 $YELLOW$2$RESET 文件放到 ${YELLOW}upx$RESET 主程序所在的同一个目录"
				echo -e "\n然后在 ${YELLOW}upx$RESET 主程序所在的目录内打开 ${YELLOW}cmd 控制台$RESET并输入：${PINK}upx --best $2$RESET" && sleep 5 && upxneeded=1
				[ -f "/tmp/$2" ] && {
					echo -e "\n发现已下载好的 $YELLOW$2$RESET 主程序文件，是否直接尝试对其进行压缩？" && upxretry=""
					echo -e "\n$PINK请输入你的选项：$RESET"
					echo "---------------------------------------------------------"
					echo "1. 直接尝试"
					echo "---------------------------------------------------------"
					echo "0. 重新下载"
					while [ -z "$upxretry" ];do
						echo -ne "\n"
						read -p "请输入对应选项的数字 > " upxretry
						[ -n "$(echo $upxretry | sed 's/[0-9]//g')" -o -z "$upxretry" ] && upxretry="" && continue
						[ "$upxretry" -gt 1 ] && upxretry=""
					done
				}
			}
		}
	else
		[ "$sdadiravailable" -lt $sizeneeded ] && echo -e "\n所选目录 $BLUE${sdadir%/*} $RED空间不足！无法安装！$RESET请选择其它安装路径" && sleep 2 && num=""
	fi
}
github_download(){
	for MIRROR in $MIRRORS;do
		echo -e "\n尝试使用加速镜像 $SKYBLUE$MIRROR$RESET 下载"
		curl --connect-timeout 3 -#${3}Lko /tmp/$1 "$MIRROR$2"
		if [ "$?" = 0 ];then
			if [ $(wc -c < /tmp/$1) -lt 1024 ];then
				rm -f /tmp/$1
				echo -e "\n$RED下载文件错误！$RESET即将尝试使用下一个加速镜像进行尝试 ······" && sleep 2
			else
				url="$MIRROR$2" && break
			fi
		else
			rm -f /tmp/$1
		fi
	done
	[ -f /tmp/$1 ] && return 0 || return 1
}
firewalllog(){
	[ "$1" = "add" ] && {
		if [ "$5" = "1" ];then
			uci set firewall.$3=redirect
			uci set firewall.$3.name=$2-$3
			uci set firewall.$3.proto=$4
			uci set firewall.$3.ftype=$5
			uci set firewall.$3.dest_ip=$hostip
			uci set firewall.$3.src=$6
			uci set firewall.$3.dest=lan
			uci set firewall.$3.target=DNAT
			uci set firewall.$3.src_dport=$7
			uci set firewall.$3.dest_port=$8
			uci commit && log "更新$2-$3端口转发规则到/etc/config/firewall文件中"
		else
			uci set firewall.$3=redirect
			uci set firewall.$3.name=$2-$3
			uci set firewall.$3.proto=$4
			uci set firewall.$3.ftype=$5
			uci set firewall.$3.dest_ip=$hostip
			uci set firewall.$3.src=$6
			uci set firewall.$3.dest=lan
			uci set firewall.$3.target=DNAT
			uci set firewall.$3.src_dport=$7
			uci commit && log "更新$2-$3端口转发规则到/etc/config/firewall文件中"
		fi
		echo -e "\n$YELLOW$2$RESET 端口转发规则 $PINK$2-$3$RESET $GREEN已更新$RESET ······" && sleep 1
	}
	[ "$1" = "del" ] && {
		ruleexist=""
		while [ -n "$(uci show firewall | grep $2 | awk -F '.' '{print $2}' | head -1)" ];do
			firewallrule=$(uci show firewall | grep $2 | awk -F '.' '{print $2}' | head -1)
			uci del firewall.$firewallrule && uci commit && log "删除/etc/config/firewall文件中的端口转发规则$2-$firewallrule" && ruleexist=1
			echo -e "\n$YELLOW$2$RESET 端口转发规则 $PINK$2-$firewallrule$RESET $RED已删除$RESET ······" && sleep 1
		done
	}
	return 0
}
sda_install_remove(){
	autostartfileinit=/etc/init.d/$1 && autostartfilerc=/etc/rc.d/S95$1 && downloadfileinit=/etc/init.d/Download$1 && downloadfilerc=/etc/rc.d/S95Download$1 && tmpdir="" && old_tag="" && upxretry=0 && skipdownload="" && newuser="" && DNSINFO="" && adguardhomednsport=53
	[ "$3" = "del" ] && del="true" || del=""
	[ -z "$del" ] && {
		[ -z "$8" ] && {
			echo -e "\n$GREEN=========================================================$RESET"
			echo -e "\n$PINK\t[[  这里以下是 ${YELLOW}$1 $PINK的安装过程  ]]$RESET"
			echo -e "\n$YELLOW=========================================================$RESET"
		}
		[ "$1" = "qBittorrent" ] && opkg_test_install unzip
		[ "$1" = "aria2" ] && opkg_test_install ariang && opkg_test_install aria2
		[ "$1" = "vsftpd" ] && opkg_test_install vsftpd
		[ "$1" = "transmission" ] && {
			opkg_test_install transmission-web
			[ -n "$(find /usr -name openssl)" ] && opkg_test_install transmission-daemon-openssl || opkg_test_install transmission-daemon-mbedtls
		}
	}
	for tmplist in $sdalist;do
		sdadir=$(find $tmplist -name $2)
		for name in $sdadir;do
			[ -f "$name" -a -n "$(echo $name | grep -v '\.d')" -o -L "$name" -a -n "$(echo $name | grep -v '\.d')" ] && {
				sdadir=$name
				[ -L "$sdadir" -a -n "$(echo $name | grep -v '\.d')" ] && tmpdir="/tmp/XiaomiSimpleInstallBox"
				break
			}
		done
		[ -f "$sdadir" -a -n "$(echo $name | grep -v '\.d')" -o -L "$sdadir" -a -n "$(echo $name | grep -v '\.d')" ] && break || sdadir=""
	done
	if [ -z "$sdadir" ];then
		if [ -z "$del" ];then
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
			while [ -z "$num" ];do
				echo -ne "\n"
				read -p "请输入对应目录的数字 > " num
				[ -n "$(echo $num | sed 's/[0-9]//g')" -o -z "$num" ] && num="" && continue
				[ "$num" -gt $listcount ] && num="" && continue
				[ "$num" -eq 0 ] && main
				sdadir=$(echo $sdalist | awk '{print $'$num'}')/$1 && sdadir_available_check "$1" "$2" "$3" "$4" "$5" "$6" "$7"
			done
		else
			echo -e "\n$RED没有找到 $YELLOW$1 $RED的安装路径！若是通过 opkg 安装的即将通过 opkg 进行卸载$RESET" && sleep 2
		fi
	else
		sdadir=${sdadir%/*}
		[ -z "$del" ] && old_tag=$(eval $sdadir/$2 $3 2> /dev/null | sed 's/.*v/v/');[ -n "$7" ] && $7
		[ -n "$old_tag" ] && echo -e "\n找到 $YELLOW$1 $PINK$old_tag$RESET 的安装路径：$BLUE$sdadir$RESET" || echo -e "\n找到 $YELLOW$1$RESET 的安装路径：$BLUE$sdadir$RESET"
		sleep 2
	fi
	[ -n "$del" ] && {
		firewalllog "del" "$1" && $autostartfileinit stop &> /dev/null
		[ -n "$ruleexist" ] && echo -e "\n$YELLOW$1$RESET 端口转发规则 $RED已全部删除$RESET，即将重启防火墙 ······" && sleep 2 && /etc/init.d/firewall restart &> /dev/null
		[ "$1" = "qBittorrent" ] && opkg remove unzip &> /dev/null
		[ "$1" = "AdGuardHome" ] && [ -f /etc/config/dhcp.backup ] && mv -f /etc/config/dhcp.backup /etc/config/dhcp && /etc/init.d/dnsmasq restart &> /dev/null && log "恢复/etc/config/dhcp.backup文件并改名为dhcp"
		[ "$1" = "aria2" ] && rm -rf /www/ariang && opkg remove ariang aria2 &> /dev/null
		[ "$1" = "vsftpd" ] && rm -f /etc/vsftpd.conf && opkg remove vsftpd &> /dev/null && [ -f /etc/services.backup ] && mv -f /etc/services.backup /etc/services && log "恢复/etc/services.backup文件并改名为services"
		[ "$1" = "transmission" ] && rm -rf /etc/config/transmission /usr/share/transmission/ && opkg remove transmission-web transmission-daemon-openssl transmission-daemon-mbedtls libnatpmp libminiupnpc &> /dev/null
		[ "$1" = "设备禁止访问网页黑名单" ] && {
			iptables -D FORWARD -i br-lan -j DOMAIN_REJECT_RULE &> /dev/null
			iptables -F DOMAIN_REJECT_RULE &> /dev/null
			iptables -X DOMAIN_REJECT_RULE &> /dev/null
			[ -f /etc/domainblacklist ] && rm -f /etc/domainblacklist && log "删除文件/etc/domainblacklist"
			sed -i '/domainblacklist/d' /etc/crontabs/root && /etc/init.d/cron restart &> /dev/null
		}
		[ "$1" = "wakeonlan" ] && rm -rf /usr/share/perl /usr/lib/perl5/ && opkg remove wakeonlan perlbase-net perlbase-time perlbase-dynaloader perlbase-filehandle perlbase-class perlbase-getopt perlbase-io perlbase-socket perlbase-selectsaver perlbase-symbol perlbase-scalar perlbase-posix perlbase-tie perlbase-list perlbase-fcntl perlbase-xsloader perlbase-errno perlbase-bytes perlbase-base perlbase-essential perlbase-config perl &> /dev/null && sed -i '/网络唤醒/d' /etc/crontabs/root && /etc/init.d/cron restart &> /dev/null
		[ -f "$autostartfileinit" ] && rm -f $autostartfileinit && log "删除自启动文件$autostartfileinit"
		[ -L "$autostartfilerc" ] && rm -f $autostartfilerc && log "删除自启动链接文件$autostartfilerc"
		[ -f "$downloadfileinit" ] && rm -f $downloadfileinit && log "删除自启动文件$downloadfileinit"
		[ -L "$downloadfilerc" ] && rm -f $downloadfilerc && log "删除自启动链接文件$downloadfilerc"
		[ -n "$sdadir" ] && rm -rf $sdadir && log "删除文件夹$sdadir"
		echo -e "\n$YELLOW$1 $RED已一键删除！$RESET" && sleep 1 && main
	}
	if [ -z "$(echo $1 | grep -oE 'aria2|vsftpd|transmission')" ];then
		[ -z "$upxretry" -o "$upxretry" -eq 0 ] && {
			urls="https://github.com/$5/$6/releases/latest"
			tag_url="https://api.github.com/repos/$5/$6/releases/latest"
			echo -e "\n即将获取 ${YELLOW}$1$RESET 最新版本号并下载" && sleep 2 && rm -f /tmp/$1.tmp && retry_count=5 && tag_name=""
			while [ -z "$tag_name" -a $retry_count != 0 ];do
				echo -e "\n正在获取最新 ${YELLOW}$1$RESET 版本号 ······ \c" && adtagcount=0
				if [ "$1" = "AdGuardHome" ];then
					while [ -z "$(echo $tag_name | grep '\-b')" -a $adtagcount -le 5 ];do
						tag_url="https://api.github.com/repos/$5/$6/releases?per_page=1&page=$adtagcount"
						tag_name=$(curl --connect-timeout 3 -sk "$tag_url" | grep tag_name | cut -f4 -d '"')
						[ "$?" = 0 ] && let adtagcount++
					done
				else
					tag_name=$(curl --connect-timeout 3 -sk "$tag_url" | grep tag_name | cut -f4 -d '"')
				fi
				[ -z "$tag_name" ] && {
					let retry_count--
					[ $retry_count != 0 ] && echo -e "$RED获取失败！$RESET\n\n即将尝试重连······（剩余重试次数：$PINK$retry_count$RESET）" && sleep 1
				}
			done
			[ -z "$tag_name" ] && {
				echo -e "$RED获取失败！\n\n获取版本号失败！$RESET如果没有代理的话建议多尝试几次！"
				echo -e "\n如果响应时间很短但获取失败，则是每小时内的请求次数已超过 ${PINK}github$RESET 限制，请更换 ${YELLOW}IP$RESET 或者等待一段时间后再试！" && sleep 1 && main
			}
			echo -e "$GREEN获取成功！$RESET当前最新版本：$PINK$(echo $tag_name | sed 's/^[^v].*[^.0-9]/v/')$RESET" && sleep 2
			[ -n "$old_tag" ] && {
				old_tag=$(echo $old_tag | sed 's/[^0-9]//g')
				new_tag=$(echo $tag_name | sed 's/[^0-9]//g')
				[ "$old_tag" -ge "$new_tag" ] && {
					echo -e "\n当前已安装最新版 $YELLOW$1 $PINK$(echo $tag_name | sed 's/^[^v].*[^.0-9]/v/')$RESET ，无需更新！$RESET" && sleep 2
					echo -e "\n$PINK是否重新下载？$RESET" && downloadnum=""
					echo "---------------------------------------------------------"
					echo "1. 重新下载"
					echo "---------------------------------------------------------"
					echo "0. 跳过下载"
					while [ -z "$downloadnum" ];do
						echo -ne "\n"
						read -p "请输入对应选项的数字 > " downloadnum
						[ -n "$(echo $downloadnum | sed 's/[0-9]//g')" -o -z "$downloadnum" ] && downloadnum="" && continue
						[ "$downloadnum" -gt 1 ] && downloadnum="" && continue
						[ "$downloadnum" -eq 0 ] && skipdownload=1
					done
				}
			}
			[ -z "$skipdownload" ] && {
				echo -e "\n$PINK请选择型号进行下载：$RESET" && num=""
				echo "---------------------------------------------------------"
				echo -e "1. $GREEN自动检测系统型号$RESET"
				echo "2. aarch64"
				echo "3. arm"
				echo "4. mips"
				echo "5. mips64"
				echo "6. mips64el"
				echo "7. mipsel"
				echo "8. x86_64"
				echo "---------------------------------------------------------"
				echo "0. 返回上一页"
				echo -e "\n可以在 $SKYBLUE$urls$RESET 中查找并复制下载地址"
				while [ -z "$num" ];do
					echo -ne "\n"
					read -p "请输入对应型号的数字或直接输入以 http 或 ftp 开头的下载地址 > " num
						case "$num" in
							1)
								hardware_type=$(uname -m)
								[ "$hardware_type" = "aarch64" ] && hardware_type=arm64;;
							2)	hardware_type=arm64;;
							3)	hardware_type=arm;;
							4)	hardware_type=mips;;
							5)	hardware_type=mips64;;
							6)	hardware_type=mips64le;;
							7)	hardware_type=mipsle;;
							8)	hardware_type=amd64;;
							0)	sda_install_remove "$1" "$2" "$3" "$4" "$5" "$6" "$7" "return"
						esac
					[ -n "$(echo $num | sed 's/[0-9]//g')" -a "${num:0:4}" != "http" -a "${num:0:3}" != "ftp" -o -z "$num" ] && num="" && continue
					[ "${num:0:4}" != "http" -a "${num:0:3}" != "ftp" ] && [ "$num" -lt 1 -o "$num" -gt 8 ] && num="" && continue
					[ "$1" = "qBittorrent" ] && {
						[ "$hardware_type" = "arm64" ] && hardware_type=aarch64
						[ "$hardware_type" = "mips64le" ] && hardware_type=mips64el
						[ "$hardware_type" = "mipsle" ] && hardware_type=mipsel
						[ "$hardware_type" = "amd64" ] && hardware_type=x86_64
					}
					[ "$1" = "AdGuardHome" ] && [ "$hardware_type" = "arm" ] && hardware_type=armv7
				done
				echo -e "\n下载 ${YELLOW}$1 $(echo $tag_name | sed 's/^[^v].*[^.0-9]/v/')$RESET ······" && retry_count=5 && eabi="" && softfloat="" && url=""
				while [ ! -f /tmp/$1.tmp -a $retry_count != 0 ];do
					[ "$hardware_type" = "arm" ] && eabi="eabi"
					[ "${hardware_type:0:4}" = "mips" ] && softfloat="_softfloat"
					[ "$1" = "qBittorrent" ] && url="https://github.com/c0re100/qBittorrent-Enhanced-Edition/releases/download/$tag_name/qbittorrent-enhanced-nox_$hardware_type-linux-musl${eabi}_static.zip"
					[ "$1" = "Alist" ] && url="https://github.com/alist-org/alist/releases/download/$tag_name/alist-linux-musl$eabi-$hardware_type.tar.gz"
					[ "$1" = "AdGuardHome" ] && url="https://github.com/AdguardTeam/AdGuardHome/releases/download/$tag_name/AdGuardHome_linux_$hardware_type$softfloat.tar.gz"
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
				done;
				[ ! -f /tmp/$1.tmp ] && echo -e "\n$RED下载失败！$RESET如果没有代理的话建议多尝试几次！" && sleep 1 && main
				echo -e "\n$GREEN下载成功！$RESET即将解压安装并启动" && rm -f /tmp/$2
				case "$1" in
					qBittorrent)	unzip -oq /tmp/$1.tmp -d /tmp;;
					Alist)	tar -zxf /tmp/$1.tmp -C /tmp;;
					AdGuardHome)	tar -zxf /tmp/AdGuardHome.tmp -C /tmp && mv -f /tmp/$1 /tmp/$1.dir && mv -f /tmp/$1.dir/$1 /tmp/$1 && rm -rf /tmp/$1.dir
				esac
				rm -f /tmp/$1.tmp
			}
		}
		if [ "$upxneeded" = 1 ];then
			echo -e "\n请将 $BLUE/tmp/$2$RESET 文件移动到电脑上并使用 ${YELLOW}upx$RESET 进行压缩" && num=""
			echo -e "\n$YELLOW压缩完成后$RESET请将文件重新放回到 $BLUE/tmp$RESET 目录下，并输入 ${YELLOW}1$RESET 进行继续"
			while [ "$num" != 1 ];do echo -ne "\n";read -p "压缩完成后请输入 1 进行继续 > " num;done
			if [ -f "/tmp/$2" ];then
				filesize=$(($(wc -c < /tmp/$2)+1048576))
				[ "$filesize" -gt "$(($sdadiravailable*1024))" ] && {
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
					echo -e "\n主程序文件大小 $PINK$filesize$RESET （预留 ${YELLOW}1 MB$RESET 空间用于配置文件），所选目录可用空间 $RED$sdadiravailable ，空间不足，无法安装！$RESET" && sleep 1 && sda_install_remove "$1" "$2" "$3" "$4" "$5" "$6" "$7" "return"
				}
			else
				echo -e "\n$BLUE/tmp/$2$RESET 文件$RED不存在！$RESET" && sleep 1 && main
			fi
		fi
		[ -z "$skipdownload" ] && {
			while [ -n "$(pidof $2)" ];do killpid $(pidof $2 | awk '{print $1}');done
			[ ! -d $sdadir ] && mkdir -p $sdadir && log "新建文件夹$sdadir"
			[ -n "$tmpdir" -a ! -d $tmpdir ] && mkdir -p $tmpdir && log "新建文件夹$tmpdir"
			if [ -z "$tmpdir" ];then
				[ -f $sdadir/$2 ] && rm -f $sdadir/$2 && log "旧$1主程序文件已删除"
				mv -f /tmp/$2 $sdadir/$2 && log "$1主程序文件$2已安装到$sdadir文件夹中"
			else
				[ -f $tmpdir/$2 ] && rm -f $tmpdir/$2 && log "旧$1主程序文件已删除"
				mv -f /tmp/$2 $tmpdir/$2 && log "$1主程序文件$2已安装到$tmpdir文件夹中"
				ln -sf $tmpdir/$2 $sdadir/$2 && log "新建$1主程序链接文件$sdadir/$2并链接到$tmpdir/$2"
			fi
		}
		chmod 755 $sdadir/$2 $tmpdir/$2 &> /dev/null
		while [ -n "$(pidof $2)" ];do killpid $(pidof $2 | awk '{print $1}');done && firewalllog "del" "$1"
		[ "$1" = "qBittorrent" ] && {
			if [ -f $sdadir/qBittorrent_files/config/qBittorrent.conf ];then
				defineport=$(cat $sdadir/qBittorrent_files/config/qBittorrent.conf | grep -F 'WebUI\Port' | sed 's/.*=//')
				newdefineport=$defineport
				while [ -n "$(netstat -lnWp | grep tcp | grep ":$newdefineport " | awk '{print $NF}' | sed 's/.*\///' | head -1)" ];do let newdefineport++;sleep 1;done
				sed -i "s/=$defineport$/=$newdefineport/" $sdadir/qBittorrent_files/config/qBittorrent.conf
			else
				newuser=1 && newdefineport=6880 && mkdir -p $sdadir/qBittorrent_files/config
				while [ -n "$(netstat -lnWp | grep tcp | grep ":$newdefineport " | awk '{print $NF}' | sed 's/.*\///' | head -1)" ];do let newdefineport++;sleep 1;done
				echo -e "[Preferences]\nWebUI\Username=admin\nWebUI\Password_PBKDF2=\"@ByteArray(yVAdTgYH36q3jEXe7W7i/A==:8Gmdf4KqS9nZ48ySkl+eX4z9dQWZxqECKJDl8B4c3rIgzf6TcxNACvSbVohaL+ltcHgICPGbg5jUhx1eZx25Ag==)\"" >> $sdadir/qBittorrent_files/config/qBittorrent.conf
			fi
			$sdadir/$2 --webui-port=$newdefineport --profile=$sdadir --configuration=files -d &> /dev/null
		}
		[ "$1" = "Alist" ] && {
			[ ! -f $sdadir/data/config.json ] && newuser=1 && touch $sdadir/.unadmin
			rm -f $sdadir/daemon/pid $tmpdir/daemon/pid && $sdadir/$2 start --data $sdadir/data &> /dev/null && sleep 2
			defineport=$(cat $sdadir/data/config.json 2> /dev/null | grep http_port | grep -oE [0-9]{1,5})
			newdefineport=$defineport
			[ -z "$(pidof $2)" ] && {
				while [ -n "$(netstat -lnWp | grep tcp | grep ":$newdefineport " | awk '{print $NF}' | sed 's/.*\///' | head -1)" ];do let newdefineport++;sleep 1;done
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
				while [ -n "$(netstat -lnWp | grep tcp | grep ":$newdefineport " | awk '{print $NF}' | sed 's/.*\///' | head -1)" ];do let newdefineport++;sleep 1;done
				sed -i "s/:$defineport$/:$newdefineport/" $sdadir/AdGuardHome.yaml
				if [ "$newdnsport" = 53 ];then
					[ ! -f /etc/config/dhcp.backup ] && cp -f /etc/config/dhcp /etc/config/dhcp.backup && log "备份/etc/config/dhcp文件并改名为dhcp.backup"
					uci set dhcp.@dnsmasq[0].port=0 && uci commit && /etc/init.d/dnsmasq restart &> /dev/null && log "修改/etc/config/dhcp文件中的选项：dnsmasq.port改为0（关闭dnsmasq的DNS服务）"
				else
					while [ -n "$(netstat -lnWp | grep ":$newdnsport " | awk '{print $NF}' | sed 's/.*\///' | head -1)" ];do let newdnsport++;sleep 1;done
					sed -i "s/: $definednsport$/: $newdnsport/" $sdadir/AdGuardHome.yaml
					adguardhomednsport=$newdnsport && DNSINFO="，${RED}DNS$RESET 监听端口为：$YELLOW$adguardhomednsport$RESET"
				fi
			else
				echo -e "\n$YELLOW检测到本次是首次安装$RESET！请先设置 ${PINK}DNS 监听端口$RESET！" && num=""
				while [ -z "$num" ];do
					echo -ne "\n"
					read -p "请输入要设置的 DNS 监听端口 > " num
					[ -n "$(echo $num | sed 's/[0-9]//g')" -o -z "$num" ] && num="" && continue
					[ "$num" -lt 1 -o "$num" -gt 65535 ] && num="" && continue
					echo -e "\n当前设置的 DNS 监听端口为：$PINK$num$RESET" && cnum=""
					while [ -z "$cnum" ];do
						echo -ne "\n"
						read -p "确认请输入 1 ，返回修改请输入 0 > " cnum
						[ -n "$(echo $cnum | sed 's/[0-9]//g')" -o -z "$cnum" ] && cnum="" && continue
						[ "$cnum" -gt 1 ] && cnum="" && continue
						[ "$cnum" -eq 0 ] && num=""
					done
					process=$(netstat -lnWp | grep ":$num " | awk '{print $NF}' | sed 's/.*\///' | head -1) && dnsnum=""
					[ -n "$process" ] && {
						if [ "$process" = "dnsmasq" ];then
							echo -e "\n$RED使用 ${PINK}53 $RED端口需要禁用本机自带的 ${YELLOW}dnsmasq $RED的 DNS 服务，确认禁用吗？$RESET"
							while [ -z "$dnsnum" ];do
								echo -ne "\n"
								read -p "确认请输入 1 ，返回修改请输入 0 > " dnsnum
								[ -n "$(echo $dnsnum | sed 's/[0-9]//g')" -o -z "$dnsnum" ] && dnsnum="" && continue
								[ "$dnsnum" -gt 1 ] && dnsnum="" && continue
								[ "$dnsnum" = 1 ] && {
									[ ! -f /etc/config/dhcp.backup ] && cp -f /etc/config/dhcp /etc/config/dhcp.backup && log "备份/etc/config/dhcp文件并改名为dhcp.backup"
									uci set dhcp.@dnsmasq[0].port=0 && uci commit && /etc/init.d/dnsmasq restart &> /dev/null && log "修改/etc/config/dhcp文件中的选项：dnsmasq.port改为0（关闭dnsmasq的DNS服务）"
								}
								[ "$dnsnum" -eq 0 ] && num=""
							done
						else
							echo -e "\n$RED检测到 $PINK$num $RED端口已被 $YELLOW$process $RED占用！请重新设置！$RESET" && num="" && sleep 1
						fi
					}
				done
				[ "$num" != 53 ] && adguardhomednsport=$num && DNSINFO="，${RED}DNS$RESET 监听端口为：$YELLOW$adguardhomednsport$RESET"
				newdefineport=3000 && while [ -n "$(netstat -lnWp | grep tcp | grep ":$newdefineport " | awk '{print $NF}' | sed 's/.*\///' | head -1)" ];do let newdefineport++;sleep 1;done
				echo -e "http:\n  pprof:\n    port: 6060\n    enabled: false\n  address: 0.0.0.0:$newdefineport\n  session_ttl: 720h" > $sdadir/AdGuardHome.yaml
				echo -e "dns:\n  port: $num\n  upstream_dns:\n    - 223.6.6.6" >> $sdadir/AdGuardHome.yaml
			fi
			$sdadir/$2 -w $sdadir &> /dev/null &
		}
		runtimecount=0 && [ -z "$tmpdir" ] && {
			[ -f "$downloadfileinit" ] && rm -f $downloadfileinit && log "删除自启动文件$downloadfileinit"
			[ -L "$downloadfilerc" ] && rm -f $downloadfilerc && log "删除自启动链接文件$downloadfilerc"
		}
		while [ -z "$(pidof $2)" -a "$runtimecount" -lt 5 ];do let runtimecount++;sleep 1;done
		if [ -n "$(pidof $2)" ];then
			echo -e "#!/bin/sh /etc/rc.common\n\nSTART=95\n\nstart() {" > $autostartfileinit
			[ -n "$tmpdir" -a -z "$skipdownload" ] && echo -e "#!/bin/sh /etc/rc.common\n\nSTART=95\n\nstart() {\n\tcat > /tmp/download$1file.sh <<EOF\n[ ! -d /tmp/XiaomiSimpleInstallBox ] && mkdir -p /tmp/XiaomiSimpleInstallBox\nwhile [ ! -f /tmp/$1.tmp ];do curl --connect-timeout 3 -sLko /tmp/$1.tmp \"$url\";[ \"\$?\" != 0 ] && rm -f /tmp/$1.tmp;done" > $downloadfileinit
			[ "$1" = "qBittorrent" ] && {
				while [ -n "$(pidof $2)" ];do killpid $(pidof $2 | awk '{print $1}');done
				sessionPort=$(cat $sdadir/qBittorrent_files/config/qBittorrent.conf | grep -F 'Session\Port' | sed 's/.*=//')
				firewalllog "add" "$1" "wan${sessionPort}rdr3" "tcpudp" "1" "wan" "$sessionPort" "$sessionPort"
				firewalllog "add" "$1" "wan${newdefineport}rdr1" "tcp" "1" "wan" "$newdefineport" "$newdefineport"
				echo -e "\t$sdadir/$2 --webui-port=$newdefineport --profile=$sdadir --configuration=files -d" >> $autostartfileinit
				[ -n "$tmpdir" -a -z "$skipdownload" ] && echo -e "unzip -oq /tmp/$1.tmp -d /tmp && mv -f /tmp/$2 /tmp/XiaomiSimpleInstallBox/$2" >> $downloadfileinit
			}
			[ "$1" = "Alist" ] && {
				[ -f $sdadir/.unadmin ] && sleep 5 && $sdadir/$2 admin set 12345678 --data $sdadir/data &> /dev/null && rm -f $sdadir/.unadmin
				firewalllog "add" "$1" "wan${newdefineport}rdr1" "tcp" "1" "wan" "$newdefineport" "$newdefineport"
				echo -e "\trm -f $sdadir/daemon/pid $tmpdir/daemon/pid\n\t$sdadir/$2 start --data $sdadir/data" >> $autostartfileinit
				[ -n "$tmpdir" -a -z "$skipdownload" ] && echo -e "tar -zxf /tmp/$1.tmp -C /tmp && mv -f /tmp/$2 /tmp/XiaomiSimpleInstallBox/$2" >> $downloadfileinit
			}
			[ "$1" = "AdGuardHome" ] && {
				while [ -n "$(pidof $2)" ];do killpid $(pidof $2 | awk '{print $1}');done
				[ "$adguardhomednsport" != 53 ] && firewalllog "add" "$1" "lan53rdr3" "tcpudp" "1" "lan" "53" "$adguardhomednsport"
				firewalllog "add" "$1" "wan${newdefineport}rdr1" "tcp" "1" "wan" "$newdefineport" "$newdefineport"
				echo -e "\t$sdadir/$2 -w $sdadir &> /dev/null &" >> $autostartfileinit
				[ -n "$tmpdir" -a -z "$skipdownload" ] && {
					echo -e "tar -zxf /tmp/$1.tmp -C /tmp && mv -f /tmp/$1 /tmp/$1.dir && mv -f /tmp/$1.dir/$2 /tmp/XiaomiSimpleInstallBox/$2 && rm -rf /tmp/$1.dir" >> $downloadfileinit
					if [ "$adguardhomednsport" = 53 ];then
						sed -i '7a mv -f /etc/config/dhcp.backup /etc/config/dhcp && /etc/init.d/dnsmasq restart &> /dev/null' $downloadfileinit
						echo -e "cp -f /etc/config/dhcp /etc/config/dhcp.backup\nuci set dhcp.@dnsmasq[0].port=0 && uci commit && /etc/init.d/dnsmasq restart &> /dev/null" >> $downloadfileinit
					else
						sed -i "7a uci del firewall.lan53rdr3 && uci commit && /etc/init.d/firewall restart" $downloadfileinit
						echo "uci set firewall.lan53rdr3=redirect && uci set firewall.lan53rdr3.name=$1-lan53rdr3 && uci set firewall.lan53rdr3.proto=tcpudp && uci set firewall.lan53rdr3.ftype=1 && uci set firewall.lan53rdr3.dest_ip=\$(uci get network.lan.ipaddr) && uci set firewall.lan53rdr3.src=lan && uci set firewall.lan53rdr3.dest=lan && uci set firewall.lan53rdr3.target=DNAT && uci set firewall.lan53rdr3.src_dport=53 && uci set firewall.lan53rdr3.dest_port=$adguardhomednsport && uci commit && /etc/init.d/firewall restart" >> $downloadfileinit
					fi
				}
			}
			echo -e "}\n\nstop() {\n\tservice_stop $sdadir/$2\n}" >> $autostartfileinit && chmod 755 $autostartfileinit && log "新建自启动文件$autostartfileinit"
			ln -sf $autostartfileinit $autostartfilerc && log "新建自启动链接文件$autostartfilerc并链接到$autostartfileinit" && chmod 777 $autostartfilerc && $autostartfileinit start &> /dev/null
			[ -n "$tmpdir" -a -z "$skipdownload" ] && {
				echo -e "rm -f /tmp/$1.tmp\nchmod 755 /tmp/XiaomiSimpleInstallBox/$2\netc/init.d/$1 restart &> /dev/null\nrm -f /tmp/download$1file.sh\nEOF\n\tchmod 755 /tmp/download$1file.sh\n\t/tmp/download$1file.sh &\n}" >> $downloadfileinit && chmod 755 $downloadfileinit && log "新建自启动文件$downloadfileinit"
				ln -sf $downloadfileinit $downloadfilerc && log "新建自启动链接文件$downloadfilerc并链接到$downloadfileinit" && chmod 777 $downloadfilerc
			}
			echo -e "\n$YELLOW$1$RESET 端口转发规则 $GREEN已全部更新$RESET，即将重启防火墙 ······" && sleep 2 && /etc/init.d/firewall restart &> /dev/null
			echo -e "\n${YELLOW}$1 $PINK$(echo $tag_name | sed 's/^[^v].*[^.0-9]/v/') $GREEN已运行$RESET并设置为$YELLOW开机自启动！$RESET"
			echo -e "\n管理页面地址：$SKYBLUE$hostip:$newdefineport$RESET$DNSINFO"
			echo -e "\n外网管理页面地址：$SKYBLUE$(curl -sLk v4.ident.me):$newdefineport$RESET"
			[ -n "$newuser" ] && echo -e "\n初始账号：${PINK}admin$RESET 初始密码：${PINK}12345678$RESET"
			[ "$1" = "Alist" ] && echo -e "\n官方使用指南：${SKYBLUE}https://alist.nn.ci/zh/$RESET"
		else
			echo -e "\n$RED启动失败！$RESET请下载适用于当前系统的文件包！"
			[ -f "$autostartfileinit" ] && rm -f $autostartfileinit && log "删除自启动文件$autostartfileinit"
			[ -L "$autostartfilerc" ] && rm -f $autostartfilerc && log "删除自启动链接文件$autostartfilerc"
			[ -f "$downloadfileinit" ] && rm -f $downloadfileinit && log "删除自启动文件$downloadfileinit"
			[ -L "$downloadfilerc" ] && rm -f $downloadfilerc && log "删除自启动链接文件$downloadfilerc"
			[ "$adguardhomednsport" = 53 ] && mv -f /etc/config/dhcp.backup /etc/config/dhcp && /etc/init.d/dnsmasq restart &> /dev/null && log "恢复/etc/config/dhcp.backup文件并改名为dhcp"
		fi
	else
		while [ -n "$(pidof $3)" ];do /etc/init.d/$1 stop &> /dev/null;done
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
		[ "$1" = "aria2" ] && {
			[ ! -d $sdadir ] && mkdir -p $sdadir && log "新建文件夹$sdadir"
			firewalllog "del" "$1" && touch $sdadir/aria2.session
			echo -e "#!/bin/sh\necho -e \"\\\ndownload-complete \$1 \$2 \$3\"\nDir=\"$num\"\nchmod -R 777 \"\$(echo \$Dir | sed 's#[^/]\$#&/#')\$(echo \$3 | sed -e \"s#\$Dir##\" -e 's#^/##' | awk -F '/' '{print \$1}')\"" > $sdadir/on-download-complete.sh && chmod 755 $sdadir/on-download-complete.sh
			echo -e "#!/bin/sh\necho -e \"\\\ndownload-stop \$1 \$2 \$3\"\nDir=\"$num\"\nrm -rf \"\$(echo \$Dir | sed 's#[^/]\$#&/#')\$(echo \$3 | sed -e \"s#\$Dir##\" -e 's#^/##' | awk -F '/' '{print \$1}')\"\nrm -f \"\$(echo \$Dir | sed 's#[^/]\$#&/#')\$(echo \$3 | sed -e \"s#\$Dir##\" -e 's#^/##' | awk -F '/' '{print \$1}').aria2\"" > $sdadir/on-download-stop.sh && chmod 755 $sdadir/on-download-stop.sh
			echo -e "ConfPath=\"$sdadir/aria2.conf\"\nrm -f /tmp/tracker_all.tmp && [ \$(cat /proc/uptime | awk '{print \$1}' | sed 's/\..*//') -le 60 ] && sleep 30\necho -e \"\\\n即将尝试获取最新 \\\033[1;33mTracker\\\033[0m 服务器列表（\\\033[1;33m成功与否不影响正常启动\\\033[0m） ······ \\\c\" && sleep 2\ncurl --connect-timeout 3 -skLo /tmp/tracker_all.tmp \"https://trackerslist.com/all.txt\"\n[ \"\$?\" != 0 ] && {\n\trm -f /tmp/tracker_all.tmp\n\techo -e \"\\\033[0;31m获取失败！\\\033[0m\" && sleep 2\n}\n[ -f /tmp/tracker_all.tmp ] && {\n\techo -e \"\\\033[1;32m获取成功！\\\033[0m\"\n\t#过滤IPv6的Tracker服务器地址：\n\t#sed -i '/\/\/\[/d' /tmp/tracker_all.tmp\n\tsed -i \"/^$/d\" /tmp/tracker_all.tmp\n\tTrackers=\$(sed \":i;N;s|\\\n|,|;ti\" /tmp/tracker_all.tmp)\n\tsed -i \"s|bt-tracker=.*|bt-tracker=\$Trackers|\" \$ConfPath\n}\naria2c --conf-path=\$ConfPath -D &> /dev/null" > $sdadir/tracker_update.sh && chmod 755 $sdadir/tracker_update.sh
			echo -e "enable-rpc=true\nrpc-allow-origin-all=true\nrpc-listen-all=true\npeer-id-prefix=BC1980-\npeer-agent=BitComet 1.98\nuser-agent=BitComet/1.98\ninput-file=$sdadir/aria2.session\non-download-complete=$sdadir/on-download-complete.sh\non-download-stop=$sdadir/on-download-stop.sh\ndir=$num\nmax-concurrent-downloads=2\ncontinue=true\nmax-connection-per-server=16\nmin-split-size=20M\nremote-time=true\nsplit=16\nbt-remove-unselected-file=true\nbt-detach-seed-only=true\nbt-enable-lpd=true\nbt-max-peers=0\nbt-tracker=\ndht-file-path=$sdadir/dht.dat\ndht-file-path6=$sdadir/dht6.dat\ndht-listen-port=6881-6999\nlisten-port=6881-6999\nmax-overall-upload-limit=3M\nmax-upload-limit=0\nseed-ratio=3\nseed-time=2880\npause-metadata=false\nalways-resume=false\nauto-save-interval=1\nfile-allocation=none\nforce-save=false\nmax-overall-download-limit=0\nmax-download-limit=0\nsave-session=$sdadir/aria2.session\nsave-session-interval=1" > $sdadir/aria2.conf && $sdadir/tracker_update.sh
		}
		[ "$1" = "transmission" ] && {
			[ ! -d /usr/share/transmission/web/tr-web-control ] && {
				echo -e "\n检测到还没有安装第三方加强版 Web-UI ，即将下载第三方加强版 ${YELLOW}Transmission Web-UI$RESET ······" && sleep 2
				github_download "$1-webUI.tmp" "https://github.com/ronggang/transmission-web-control/archive/master.tar.gz" "s"
				if [ "$?" = 0 ];then
					echo -e "\n$GREEN下载成功！$RESET即将解压安装"
					tar -zxf /tmp/transmission-webUI.tmp -C /tmp
					mv -f /usr/share/transmission/web/index.html /usr/share/transmission/web/index.original.html
					mv -f /tmp/transmission-web-control-master/src/* /usr/share/transmission/web/
					rm -rf /tmp/$1-webUI.tmp /tmp/transmission-web-control-master
				else
					echo -e "\n$RED下载失败！目前仅能使用原版 Web-UI"
				fi
			}
			firewalllog "del" "$1" && [ ! -d $sdadir ] && mkdir -p $sdadir && log "新建文件夹$sdadir"
			newpeerport=$(uci get transmission.@transmission[0].peer_port)
			newdefineport=$(uci get transmission.@transmission[0].rpc_port)
			while [ -n "$(netstat -lnWp | grep ":$newpeerport " | awk '{print $NF}' | sed 's/.*\///' | head -1)" ];do let newpeerport++;sleep 1;done
			while [ -n "$(netstat -lnWp | grep tcp | grep ":$newdefineport " | awk '{print $NF}' | sed 's/.*\///' | head -1)" ];do let newdefineport++;sleep 1;done
			uci set transmission.@transmission[0].enabled=1
			uci set transmission.@transmission[0].config_dir=$sdadir
			uci set transmission.@transmission[0].user=root
			uci set transmission.@transmission[0].group=root
			uci set transmission.@transmission[0].download_dir="$num"
			uci set transmission.@transmission[0].download_queue_size=2
			uci set transmission.@transmission[0].incomplete_dir="$(echo $num | sed 's#/$##')/transmission下载中文件"
			uci set transmission.@transmission[0].incomplete_dir_enabled=true
			uci set transmission.@transmission[0].lpd_enabled=true
			uci set transmission.@transmission[0].peer_limit_per_torrent=120
			uci set transmission.@transmission[0].peer_port=$newpeerport
			uci set transmission.@transmission[0].peer_socket_tos=lowcost
			uci set transmission.@transmission[0].queue_stalled_minutes=240
			uci set transmission.@transmission[0].rpc_host_whitelist="*.*.*.*"
			uci set transmission.@transmission[0].rpc_host_whitelist_enabled=true
			uci set transmission.@transmission[0].rpc_port=$newdefineport
			uci set transmission.@transmission[0].rpc_whitelist="*.*.*.*"
			uci set transmission.@transmission[0].rpc_whitelist_enabled=true
			uci set transmission.@transmission[0].speed_limit_up=3072
			uci set transmission.@transmission[0].speed_limit_up_enabled=true
			uci set transmission.@transmission[0].umask=22
			uci set transmission.@transmission[0].rpc_authentication_required=true
			uci set transmission.@transmission[0].rpc_username=admin
			uci set transmission.@transmission[0].rpc_password=12345678 && uci commit
			/etc/init.d/transmission start &> /dev/null
		}
		runtimecount=0 && autostartfileinit=/etc/init.d/$1 && autostartfilerc=/etc/rc.d/S95$1
		while [ -z "$(pidof $3)" -a "$runtimecount" -lt 5 ];do let runtimecount++;sleep 1;done
		if [ -n "$(pidof $3)" ];then
			[ "$1" = "aria2" ] && {
				webui="/ariang"
				echo -e "#!/bin/sh /etc/rc.common\n\nSTART=95\n\nstart() {" > $autostartfileinit
				newdefineport=8888 && while [ -n "$(netstat -lnWp | grep tcp | grep ":$newdefineport " | awk '{print $NF}' | sed 's/.*\///' | head -1)" ];do let newdefineport++;sleep 1;done
				firewalllog "add" "$1" "wan${newdefineport}rdr1" "tcp" "1" "wan" "$newdefineport" "8080"
				firewalllog "add" "$1" "wan6800rdr1" "tcp" "1" "wan" "6800" "6800"
				firewalllog "add" "$1" "wan6881rdr3" "tcpudp" "2" "wan" "6881-6999"
				echo -e "\t$sdadir/tracker_update.sh" >> $autostartfileinit
				echo -e "}\n\nstop() {\n\tservice_stop /usr/bin/aria2c\n}" >> $autostartfileinit && chmod 755 $autostartfileinit && log "新建自启动文件$autostartfileinit"
				ln -sf $autostartfileinit $autostartfilerc && log "新建自启动链接文件$autostartfilerc并链接到$autostartfileinit" && chmod 777 $autostartfilerc && $autostartfileinit start &> /dev/null
			}
			[ "$1" = "transmission" ] && {
				firewalllog "add" "$1" "wan${newpeerport}rdr3" "tcpudp" "1" "wan" "$newpeerport" "$newpeerport"
				firewalllog "add" "$1" "wan${newdefineport}rdr1" "tcp" "1" "wan" "$newdefineport" "$newdefineport"
			}
			echo -e "\n$YELLOW$1$RESET 端口转发规则 $GREEN已全部更新$RESET，即将重启防火墙 ······" && sleep 2 && /etc/init.d/firewall restart &> /dev/null
			echo -e "\n${YELLOW}$1 $GREEN已运行$RESET并设置为$YELLOW开机自启动！$RESET"
			[ "$1" = "aria2" ] && echo -e "\n管理页面地址：$SKYBLUE$hostip/$webui$RESET"
			[ "$1" = "transmission" ] && echo -e "\n管理页面地址：$SKYBLUE$hostip:$newdefineport$RESET"
			echo -e "\n外网管理页面地址：$SKYBLUE$(curl -sLk v4.ident.me):$newdefineport$webui$RESET"
			[ "$1" = "transmission" ] && echo -e "\n初始账号：${PINK}admin$RESET 初始密码：${PINK}12345678$RESET"
		else
			echo -e "\n$RED启动失败！$RESET请尝试修改 $BLUE/etc/opkg/distfeeds.conf$RESET 中的地址后重试安装！"
			rm -rf $sdadir && log "删除文件夹$sdadir"
			[ "$1" = "aria2" ] && rm -rf /www/ariang && opkg remove ariang aria2 &> /dev/null && echo -e "\n${RED}已自动使用 opkg 卸载 $YELLOW$1$RESET"
			[ "$1" = "transmission" ] && rm -rf /etc/config/transmission /usr/share/transmission/ && opkg remove transmission-web transmission-daemon-openssl transmission-daemon-mbedtls libnatpmp libminiupnpc &> /dev/null && echo -e "\n${RED}已自动使用 opkg 卸载 $YELLOW$1$RESET"
		fi
	fi
	main
}
domainblacklist_update(){
	[ -f /etc/domainblacklist ] && [ -n "$(grep $devmac /etc/domainblacklist)" ] && {
		echo -e "\n$SKYBLUE$devmac$GREEN$devname$YELLOW当前已添加网页黑名单：$RESET"
		echo "---------------------------------------------------------"
		sed -n /$devmac/p /etc/domainblacklist | awk '{print NR":'$SKYBLUE'\t"$2"'$RESET'"}'
		echo "---------------------------------------------------------"
		[ -n "$(grep $devmac /etc/domainblacklist)" ] && echo -e "$PINK删除请输入 ${YELLOW}-ID $PINK，如：${YELLOW}-2$PINK 删除第二条已添加网页黑名单$RESET"
	}
	[ "$1" = "reload" ] && /etc/domainblacklist "reload"
	return 0
}
main(){
	num="$1" && [ -z "$num" ] && {
		echo -e "\n$YELLOW=========================================================$RESET" && 
		echo -e "\n$PINK\t\t[[  这里以下是主页面  ]]$RESET"
		echo -e "\n$GREEN=========================================================$RESET"
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
		echo -e "\n99. $RED$BLINK给作者打赏支持$RESET"
		echo "---------------------------------------------------------"
		echo -e "del+ID. 一键删除对应选项插件 如：${YELLOW}del1$RESET"
		echo -e "0. 退出$YELLOW小米路由器$GREEN简易安装插件脚本$RESET"
	}
	while [ -z "$num" ];do
		echo -ne "\n"
		read -p "请输入对应选项的数字 > " num
		[ "$num" = 99 ] && break
		[ "${num:0:3}" = "del" ] && [ -n "${num:3:1}" ] && [ -z "$(echo ${num:3:1} | sed 's/[0-9]//g')" ] && [ "${num:3:1}" -ge 1 -a "${num:3:1}" -le 8 ] && break
		[ -n "$(echo $num | sed 's/[0-9]//g')" -o -z "$num" ] && num="" && continue
		[ "$num" -lt 0 -o "$num" -gt 8 ] && num="" && continue
		[ "$num" -eq 0 ] && {
			echo -e "\n$GREEN=========================================================$RESET"
			echo -e "\n$PINK\t[[  已退出小米路由器简易安装插件脚本  ]]$RESET"
			echo -e "\n$RED=========================================================$RESET"
			echo -e "\n感谢使用$YELLOW小米路由器$GREEN简易安装插件脚本 $PINK$version$RESET ，觉得好用希望能够$RED$BLINK打赏支持~！$RESET"
			echo -e "\n您的小小支持是我持续更新的动力~~~$RED$BLINK十分感谢~ ~ ~ ! ! !$RESET"
			echo -e "\n$YELLOW打赏地址：${SKYBLUE}https://github.com/xilaochengv/BuildKernelSU$RESET 或$RED$BLINK主页面输入：99$RESET"
			echo -e "\n$GREEN问题反馈：${SKYBLUE}https://www.right.com.cn/forum/thread-8322811-1-1.html$RESET"
			echo -e "\n$RED=========================================================$RESET" && exit
		}
	done
	case "$num" in
		1)	sda_install_remove "qBittorrent" "qbittorrent-nox" "-v" "30MB" "c0re100" "qBittorrent-Enhanced-Edition" "rm -rf /.cache /.config /.local";;
		2)	sda_install_remove "Alist" "alist" "version | grep v" "64MB" "alist-org" "alist";;
		3)	sda_install_remove "AdGuardHome" "AdGuardHome" "--version" "30MB" "AdGuardTeam" "AdGuardHome";;
		4)	sda_install_remove "aria2" "aria2.conf" "aria2c" "30KB";;
		5)	sda_install_remove "vsftpd";;
		6)	sda_install_remove "transmission" "settings.json" "transmission-daemon" "5KB";;
		7)
			devnum="$2" && domain="" && [ -z "$devnum" ] && {
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
			while [ -z "$devnum" ];do
				echo -ne "\n"
				read -p "请输入对应设备的数字 > " devnum
				[ -n "$(echo $devnum | sed 's/[0-9]//g')" -o -z "$devnum" ] && devnum="" && continue
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
				while [ -z "$devmac" ];do
					echo -ne "\n"
					read -p "请输入 xx:xx:xx:xx:xx:xx 格式的 MAC 地址 > " devmac
					devmac=$(echo $devmac | awk '{print tolower($0)}')
					[ -z "$devmac" ] && continue
					[ "$devmac" = 0 ] && main "$num"
					[ -z "$(echo $devmac |grep -E '^([0-9a-f][02468ace])(([:]([0-9a-f]{2})){5})$')" ] && echo -e "\n$RED输入错误！请重新输入！$RESET" && devmac="" && continue
				done
			}
			echo -e "\n$PINK请输入要添加的网页地址或网页地址包含的关键字（如 ${SKYBLUE}www.baidu.com $PINK或 ${SKYBLUE}baidu.com $PINK或 ${SKYBLUE}baidu$PINK）：$RESET"
			echo -e "$PINK当前已选择设备：$SKYBLUE$devmac$GREEN$devname$RESET"
			echo "---------------------------------------------------------"
			echo -e "0.\t返回上一页" && domainblacklist_update
			[ ! -f /etc/domainblacklist -o -z "$(sed -n 1p /etc/domainblacklist 2> /dev/null | grep reload)" ] && echo -e "reload(){\n\tiptables -D FORWARD -i br-lan -j DOMAIN_REJECT_RULE &> /dev/null\n\tiptables -F DOMAIN_REJECT_RULE &> /dev/null\n\tiptables -X DOMAIN_REJECT_RULE &> /dev/null\n\tiptables -N DOMAIN_REJECT_RULE\n\tiptables -I FORWARD -i br-lan -j DOMAIN_REJECT_RULE\n\tsed -n 15,\$\$p /etc/domainblacklist | while read LINE;do\n\t\tiptables -A DOMAIN_REJECT_RULE -m mac --mac-source \${LINE:1:18} -m string --string \"\${LINE:19:\$\$}\" --algo bm -j REJECT\n\tdone\n}\ndomain_rule_check(){\n\t[ -z \"\$(iptables -S FORWARD | grep -e -i | head -1 | grep DOMAIN)\" ] && reload\n}\n[ \"\$1\" = \"reload\" ] && reload || domain_rule_check" > /etc/domainblacklist && log "新建文件/etc/domainblacklist" && chmod 755 /etc/domainblacklist
			[ -z "$(grep domainblacklist /etc/crontabs/root)" ] && echo "*/1 * * * * /etc/domainblacklist" >> /etc/crontabs/root && /etc/init.d/cron restart &> /dev/null && log "添加定时任务domainblacklist到/etc/crontabs/root文件中"
			while [ -z "$domain" ];do
				echo -ne "\n"
				read -p "请输入要过滤的网页地址或网页地址包含的关键字，返回上一页输入 0 > " domain
				[ -z "$domain" ] && continue
				[ "$domain" = 0 ] && {
					[ "$devnum" = 255 ] && main "$num" "$devnum" || main "$num"
				}
				[ "${domain:0:1}" = "-" ] && {
					[ -n "$(echo ${domain:1:$$} | sed 's/[0-9]//g')" -o -z "$(grep $devmac /etc/domainblacklist 2> /dev/null)" ] && echo -e "\n$RED输入错误！请重新输入！$RESET" && domain="" && continue
					domainrule=$(grep $devmac /etc/domainblacklist | awk '{print $2}' | sed -n ${domain:1:$$}p | sed 's/#//')
					if [ -n "$domainrule" ];then
						sed -i "/$devmac $domainrule$/d" /etc/domainblacklist
						echo -e "\n$SKYBLUE$devmac$GREEN$devname$YELLOW网页黑名单规则 $SKYBLUE$domainrule $RED已删除！$RESET" && sleep 1 && domainblacklist_update "reload" && domain="" && continue
					else
						echo -e "\n$RED输入错误！请重新输入！$RESET" && domain="" && continue
					fi
				}
				[ -n "$(grep -E "$devmac.*$domain$" /etc/domainblacklist)" ] && echo -e "\n$SKYBLUE$devmac$GREEN$devname$YELLOW网页黑名单规则 $SKYBLUE$domain $RED已存在！$RESET" && sleep 1 && domainblacklist_update && domain="" && continue
				echo "#$devmac $domain" >> /etc/domainblacklist
				echo -e "\n$SKYBLUE$devmac$GREEN$devname$YELLOW网页黑名单规则 $SKYBLUE$domain $GREEN添加成功！$RESET" && sleep 1 && domainblacklist_update "reload" && domain=""
			done;;
		8)	opkg_test_install "wakeonlan";;
		99)
			echo -e "\n$RED$BLINK十分感谢您的支持！！！！！！！！$RESET\n\n$YELLOW微信扫码：$RESET\n"
			echo H4sIAAAAAAAAA71UwQ3DMAj8d4oblQcPJuiAmaRSHMMZYzcvS6hyXAPHcXB97Tpon5PJcj5cX2XDfS3wL2mW3i38FhkMwHNqoaSb9YP291p7rSInTCneDRugbLr0q7uhlbX7lkUwxxVsfctaMMW/2a87YPD01e+yGiF6onHq/MAvlFwGUO2AMW7VFwODFGolOMBToaU6d1UEAYwp+jtCN9dxdsppCr4Q4N0F5EbiEiKS/P5MRupGKMGIFp4Jv8jv1lzNyiLMg3QcEc03CMI6U70PImYSU9d2nhxLttkkYKF01fZ/Q9n6Cvu0D1i7gd1rYQZjG2ynYrtL5md8r5P7C7YO2PF8PwRFQamaBwAA | base64 -d | gzip -d
			echo -e "\n$YELLOW支付宝扫码：$RESET\n"
			echo H4sIAAAAAAAAA71USQ7EMAi7zyv8VA4c8oI+sC8ZqQ3gLNC5TCVUKSlgsAnn0c4X7fMm2IyH81A2XNf3wb0Et2d4J3EJQgMog/Rw0Pn66uKdZyRsO3tJYp5qaEij9hrozpolV662nz17EV1igVgQUBPEDQy7Owh+6sYLE+4DlF24I2VYLJVKgRQRzpG1EyJdhYPhB7Wq/K2zINwLaM44w9wKT0mlhmSMjeKLN+Uj5koGuSlKIyBnKtA34yBLaJthCu1nFVkmUy6YtKEEHjRJ94D6NIxyBFFtXABJ9mEbCFV8/xD/qKPV72G3B+Ak82PtzCB21jQCT296tz/WFcESrZeTQ/4u/mqv430B27+RdoQHAAA= | base64 -d | gzip -d && exit;;
		del[1-8])
			case "${num:3:1}" in
				1)	plugin="qBittorrent";pluginfile="qbittorrent-nox";;
				2)	plugin="Alist";pluginfile="alist";;
				3)	plugin="AdGuardHome";pluginfile="AdGuardHome";;
				4)	plugin="aria2";pluginfile="aria2.conf";;
				5)	plugin="vsftpd";pluginfile=".notexist";;
				6)	plugin="transmission";pluginfile="settings.json";;
				7)	plugin="设备禁止访问网页黑名单";pluginfile=".notexist";;
				8)	plugin="wakeonlan";pluginfile=".notexist"
			esac
			echo -e "\n$PINK确认一键卸载 $plugin 吗？（若确认所有配置文件将会全部删除）$RESET" && num=""
			echo "---------------------------------------------------------"
			echo "1. 确认卸载"
			echo "---------------------------------------------------------"
			echo "0. 返回主页面"
			while [ -z "$num" ];do
				echo -ne "\n"
				read -p "请输入对应选项的数字 > " num
				[ -n "$(echo $num | sed 's/[0-9]//g')" -o -z "$num" ] && num="" && continue
				[ "$num" -gt 1 ] && num="" && continue
				[ "$num" -eq 0 ] && main
				sda_install_remove "$plugin" "$pluginfile" "del"
			done
	esac
}
echo -e "MIRRORS=\"$MIRRORS\"\ngithub_download(){\n\tfor MIRROR in \$MIRRORS;do\n\t\tcurl --connect-timeout 3 -sLko /tmp/\$1 \"\$MIRROR\$2\"\n\t\tif [ \"\$?\" = 0 ];then\n\t\t\t[ \$(wc -c < /tmp/\$1) -lt 1024 ] && rm -f /tmp/\$1 || break\n\t\telse\n\t\t\trm -f /tmp/\$1\n\t\tfi\n\tdone\n\t[ -f /tmp/\$1 ] && return 0 || return 1\n}\nrm -f /tmp/XiaomiSimpleInstallBox.sh.tmp && for tmp in \$(ps | grep _update_check | awk '{print \$1}');do [ \"\$tmp\" != \"\$\$\" ] && killpid \$tmp;done\nwhile [ ! -f /tmp/XiaomiSimpleInstallBox.sh.tmp ];do\n\tgithub_download \"XiaomiSimpleInstallBox.sh.tmp\" \"https://raw.githubusercontent.com/xilaochengv/BuildKernelSU/main/XiaomiSimpleInstallBox.sh\"\n\t[ \"\$?\" != 0 ] && {\n\t\tcurl --connect-timeout 3 -sLko /tmp/XiaomiSimpleInstallBox.sh.tmp \"https://raw.githubusercontent.com/xilaochengv/BuildKernelSU/main/XiaomiSimpleInstallBox.sh\"\n\t\t[ \"\$?\" != 0 ] && rm -f /tmp/XiaomiSimpleInstallBox.sh.tmp\n\t}\ndone\nif [ \"$version\" != \"\$(sed -n '1p' /tmp/XiaomiSimpleInstallBox.sh.tmp | sed 's/version=//')\" ];then\n\trm -f /tmp/XiaomiSimpleInstallBox-change.log\n\twhile [ ! -f /tmp/XiaomiSimpleInstallBox-change.log ];do\n\t\tgithub_download \"XiaomiSimpleInstallBox-change.log\" \"https://raw.githubusercontent.com/xilaochengv/BuildKernelSU/main/XiaomiSimpleInstallBox-change.log\"\n\t\t[ \"\$?\" != 0 ] && {\n\t\t\tcurl --connect-timeout 3 -sLko /tmp/XiaomiSimpleInstallBox-change.log \"https://raw.githubusercontent.com/xilaochengv/BuildKernelSU/main/XiaomiSimpleInstallBox-change.log\"\n\t\t\t[ \"\$?\" != 0 ] && rm -f /tmp/XiaomiSimpleInstallBox-change.log\n\t\t}\n\tdone\n\techo -e \"\\\n$PINK=========================================================$RESET\"\n\techo -e \"\\\n$YELLOW小米路由器$GREEN简易安装插件脚本 $PINK$version $BLUE已自动更新到最新版：$PINK\$(sed -n '1p' /tmp/XiaomiSimpleInstallBox.sh.tmp | sed 's/version=//') $BLUE，请重新运行脚本$RESET\"\n\techo -e \"\\\n$PINK=========================================================$RESET\"\n\tmv -f /tmp/XiaomiSimpleInstallBox-change.log ${0%/*}/XiaomiSimpleInstallBox-change.log\n\tmv -f $0 ${0%/*}/XiaomiSimpleInstallBox.sh.$version.backup\n\tmv -f /tmp/XiaomiSimpleInstallBox.sh.tmp ${0%/*}/XiaomiSimpleInstallBox.sh\n\tchmod 755 ${0%/*}/XiaomiSimpleInstallBox.sh\nelse\n\trm -f /tmp/XiaomiSimpleInstallBox.sh.tmp\nfi\nrm -f /tmp/XiaomiSimpleInstallBox_update_check" > /tmp/XiaomiSimpleInstallBox_update_check && chmod 755 /tmp/XiaomiSimpleInstallBox_update_check && /tmp/XiaomiSimpleInstallBox_update_check &

#修复设备网页黑名单重启后不会生效问题
[ -f /etc/domainblacklist ] && [ -z "$(sed -n 12p /etc/domainblacklist 2> /dev/null | grep '(')" ] && sed -i "12c\\\t[ -z \"\$(iptables -S FORWARD | grep -e -i | head -1 | grep DOMAIN)\" ] && reload" /etc/domainblacklist && /etc/domainblacklist

echo -e "\n$YELLOW=========================================================$RESET" && rm -f /tmp/opkg_updated
echo -e "\n欢迎使用$YELLOW小米路由器$GREEN简易安装插件脚本 $PINK$version$RESET ，觉得好用希望能够$RED$BLINK打赏支持~！$RESET"
echo -e "\n您的小小支持是我持续更新的动力~~~$RED$BLINK十分感谢~ ~ ~ ! ! !$RESET"
echo -e "\n$YELLOW打赏地址：${SKYBLUE}https://github.com/xilaochengv/BuildKernelSU$RESET 或$RED$BLINK主页面输入：99$RESET"
echo -e "\n$GREEN问题反馈：${SKYBLUE}https://www.right.com.cn/forum/thread-8322811-1-1.html$RESET" && main