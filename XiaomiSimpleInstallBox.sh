version=v1.0.0
RED='\e[0;31m';GREEN='\e[1;32m';YELLOW='\e[1;33m';BLUE='\e[1;34m';PINK='\e[1;35m';SKYBLUE='\e[1;36m';UNDERLINE='\e[4m';BLINK='\e[5m';RESET='\e[0m'
hardware_release=$(cat /etc/openwrt_release | grep RELEASE | grep -oE [.0-9]{1,10})
hardware_arch=$(cat /etc/openwrt_release | grep ARCH | awk -F "'" '{print $2}')
sdalist=$(df | sed -n '1!p' | grep -vE "rom|tmp|ini|overlay" | awk '{print $6}')
hostip=$(ip route | grep br-lan | awk {'print $9'})
MIRRORS="
https://ghps.cc/
https://gh.ddlc.top/
https://mirror.ghproxy.com/
https://hub.gitmirror.com/
"
log(){
	echo "[ $(date '+%F %T') ] $1" >> ${0%/*}/XiaomiSimpleInstallBox.log
}
opkg_test_install(){
	echo -e "\n本次操作需要使用到 $YELLOW$1$RESET" && sleep 1
	if [ -z "$(opkg list-installed | grep $1 2> /dev/null)" ];then
		echo -e "\n本机还$RED没有安装 $YELLOW$1$RESET ！即将通过 opkg 下载安装\n" && sleep 1
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
					echo -e "\n更新源$RED连接失败$RESET！请检查 $BLUE/etc/opkg/distfeeds.conf$RESET 中的地址是否正确后重试！" && main exit
				}
			else
				touch /tmp/opkg_updated
			fi
		}
		opkg install $1
		[ "$?" != 0 ] && echo -e "\n安装 ${YELLOW}$1$RED 失败！$RESET请检查 $BLUE/etc/opkg/distfeeds.conf$RESET 中的地址是否正确并有效！" && main exit
		echo -e "\n$GREEN安装 $YELLOW$1 $GREEN成功$RESET" && sleep 2 && log "通过opkg命令安装了$1" && [ "$1" = "vsftpd" ] && newuser=1
	else
		echo -e "\n检测到已安装 $YELLOW$1$RESET ，跳过安装" && sleep 1
	fi
	[ "$1" = "vsftpd" ] && {
		[ -z "$newuser" ] && {
			echo -e "\n$PINK是否需要重新配置设置参数？$RESET" && num=""
			echo "---------------------------------------------------------"
			echo "1. 重新配置"
			echo "---------------------------------------------------------"
			echo "0. 返回主页面"
			while [ -z "$num" ];do
				echo -ne "\n"
				read -p "请输入对应选项的数字 > " num
				[ -n "$(echo $num | sed 's/[0-9]//g')" -o -z "$num" ] && num="" && continue
				[ "$num" -gt 1 ] && num="" && continue
				[ "$num" -eq 0 ] && main exit
			done
		}
		echo -e "\n$PINK是否允许匿名登陆？$RESET" && anonymous="" && anonymousdir=""
		echo "---------------------------------------------------------"
		echo "1. 允许匿名登陆"
		echo "2. 禁止匿名登陆"
		echo "---------------------------------------------------------"
		echo "0. 返回主页面"
		while [ -z "$anonymous" ];do
			echo -ne "\n"
			read -p "请输入对应选项的数字 > " anonymous
			[ -n "$(echo $anonymous | sed 's/[0-9]//g')" -o -z "$anonymous" ] && anonymous="" && continue
			[ "$anonymous" -gt 2 ] && anonymous="" && continue
			[ "$anonymous" -eq 0 ] && main exit
			[ "$anonymous" = 1 ] && anonymous="YES" || anonymous="NO"
		done
		[ "$anonymous" = "YES" ] && {
			echo -e "\n$PINK请输入匿名登陆默认路径：$RESET"
			echo "---------------------------------------------------------"
			echo "0. 返回主页面"
			echo "---------------------------------------------------------"
			while [ ! -d "$anonymousdir" -o "${anonymousdir:0:1}" != / ];do
				echo -ne "\n"
				read -p "请输入以 '/' 开头的路径地址（完整路径） > " anonymousdir
				[ "$anonymousdir" = 0 ] && main exit
				[ ! -d "$anonymousdir" -o "${anonymousdir:0:1}" != / ] && echo -e "\n路径 $BLUE$anonymousdir $RED不存在！$RESET"
			done
			echo -e "\n${YELLOW}vsftpd$RESET 的匿名登陆默认路径已设置为：$BLUE$anonymousdir$RESET" && sleep 1
		}
		echo -e "\n$PINK是否允许用户名登陆？$RESET" && locals="" && localsdir="" && localswriteable=""
		echo "---------------------------------------------------------"
		echo "1. 允许用户名登陆"
		echo "2. 禁止用户名登陆"
		echo "---------------------------------------------------------"
		echo "0. 返回主页面"
		while [ -z "$locals" ];do
			echo -ne "\n"
			read -p "请输入对应选项的数字 > " locals
			[ -n "$(echo $locals | sed 's/[0-9]//g')" -o -z "$locals" ] && locals="" && continue
			[ "$locals" -gt 2 ] && locals="" && continue
			[ "$locals" -eq 0 ] && main exit
			[ "$locals" = 1 ] && locals="YES" || locals="NO"
		done
		[ "$locals" = "YES" ] && {
			echo -e "\n$PINK请输入用户名登陆默认路径：$RESET"
			echo "---------------------------------------------------------"
			echo "0. 返回主页面"
			echo "---------------------------------------------------------"
			while [ ! -d "$localsdir" -o "${localsdir:0:1}" != / ];do
				echo -ne "\n"
				read -p "请输入以 '/' 开头的路径地址（完整路径） > " localsdir
				[ "$localsdir" = 0 ] && main exit
				[ ! -d "$localsdir" -o "${localsdir:0:1}" != / ] && echo -e "\n路径 $BLUE$localsdir $RED不存在！$RESET"
			done
			echo -e "\n${YELLOW}vsftpd$RESET 的用户名登陆默认路径已设置为：$BLUE$localsdir$RESET" && sleep 1
		}
		echo -e "listen=NO\nlisten_ipv6=YES\nbackground=YES\ncheck_shell=NO\nwrite_enable=YES\nsession_support=YES\ntext_userdb_names=YES\nanonymous_enable=$anonymous\nanon_root=$anonymousdir\nlocal_enable=$locals\nlocal_root=$localsdir\nchroot_local_user=YES\nallow_writeable_chroot=YES\nlocal_umask=080\nfile_open_mode=0777\nuser_config_dir=/cfg/vsftpd/" > /etc/vsftpd.conf
		while [ -n "$(pidof vsftpd)" ];do killpid $(pidof vsftpd | awk '{print $1}');done
		/etc/init.d/vsftpd start && runtimecount=0
		while [ -z "$(pidof vsftpd)" -a "$runtimecount" -lt 5 ];do let runtimecount++;sleep 1;done
		if [ -n "$(pidof vsftpd)" ];then
			echo -e "\n配置完成！ ${YELLOW}vsftpd $GREEN已运行$RESET并设置为$YELLOW开机自启动！$RESET"
			[ "$anonymous" = "YES" ] && chmod 775 $anonymousdir
			[ "$locals" = "YES" ] && {
				echo -e "\n$RED请自行设置登陆用户名！$YELLOW若之前已设置过可忽略！$RESET"
				echo -e "\n设置方法：退出本脚本并在控制台输入：${YELLOW}passwd ${PINK}user$RESET（紫色为用户名，可自行更改）"
				echo -e "\n然后输入两次密码确认成功即可（$YELLOW输入密码时控制台不会显示出来$RESET)"
			}
		else
			echo -e "\n$RED启动失败！$RESET请尝试修改 $BLUE/etc/opkg/distfeeds.conf$RESET 中的地址后重试安装！"
			rm -f /etc/vsftpd.conf && opkg remove vsftpd &> /dev/null
		fi
		main exit
	}
}
sdadir_available_check(){
	sdadiravailable=$(df | grep " ${sdadir%/*}$" | awk '{print $4}') && upxneeded=""
	if [ -z "$(echo $1 | grep -oE 'aria2|vsftpd')" ];then
		[ "$sdadiravailable" -lt $3 ] && {
			echo -e "\n所选目录 $BLUE${sdadir%/*} $RED空间不足 $(($3/1024)) MB$RESET！无法直接下载使用！不过可以尝试使用 ${YELLOW}upx$RESET 压缩后使用" && sleep 2
			tmpdiravailable=$(df | grep " /tmp$" | awk '{print $4}')
			[ "$tmpdiravailable" -ge 102400 ] && {
				echo -e "\n检测到临时目录 $BLUE/tmp$RESET 可用空间为 $RED$(awk BEGIN'{printf "%0.3f MB",'$tmpdiravailable'/1024}')$RESET" && tmpnum=""
				echo -e "\n$RED临时目录内文件会在路由器重启后丢失！$RESET使用的话每次开机将会自动重新下载主程序文件，是否使用临时目录？" && sleep 1
				while [ -z "$tmpnum" ];do
					echo -ne "\n"
					read -p "确认使用请输入 1 ，尝试压缩后使用请输入 0 > " tmpnum
					[ -n "$(echo $tmpnum | sed 's/[0-9]//g')" -o -z "$tmpnum" ] && tmpnum="" && continue
					[ "$tmpnum" -gt 1 ] && tmpnum="" && continue
					[ "$tmpnum" = 1 ] && tmpdir="/tmp/XiaomiSimpleInstallBox"
				done
			}
			[ -z "$tmpdir" ] && {
				echo -e "\n下载完成后请使用电脑利用 ${YELLOW}upx$RESET 压缩器对其进行压缩"
				echo -e "\n${YELLOW}upx$RESET 主程序可以在 ${SKYBLUE}https://github.com/upx/upx/releases/latest$RESET 下载"
				echo -e "\n使用方法：下载完成后，先将 $YELLOW$2$RESET 文件放到 ${YELLOW}upx$RESET 主程序所在的同一个目录"
				echo -e "\n然后在 ${YELLOW}upx$RESET 主程序所在的目录内打开 ${YELLOW}cmd 控制台$RESET并输入：${PINK}upx --best $2$RESET" && sleep 2 && upxneeded=1
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
						[ "$upxretry" -gt 1 ] && upxretry="" && continue
					done
				}
			}
		}
	else
		[ "$sdadiravailable" -lt $3 ] && echo -e "\n所选目录 $BLUE${sdadir%/*} $RED空间不足！无法安装！$RESET请选择其它安装路径" && sleep 2 && num="" && continue
	fi
}
github_download(){
	for MIRROR in $MIRRORS;do
		curl --connect-timeout 3 -#Lko /tmp/$1 "$MIRROR$2"
		[ "$?" = 0 ] && break || rm -f /tmp/$1
	done
	[ -f /tmp/$1 ] && return 0 || return 1
}
sda_install(){
	sizeneeded=$(echo $4 | grep -oE [0-9]{1,10})
	[ -n "$(echo $4 | grep MB)" ] && sizeneeded=$(($(echo $4 | grep -oE [0-9]{1,10})*1024))
	[ -n "$(echo $4 | grep GB)" ] && sizeneeded=$(($(echo $4 | grep -oE [0-9]{1,10})*1024*1024))
	echo -e "\n$GREEN=========================================================$RESET" && tmpdir="" && old_tag="" && dnsnum="" && upxretry=0 && newuser="" && DNSINFO=""
	echo -e "\n$PINK\t[[  这里以下是 ${YELLOW}$1 $PINK的安装过程  ]]$RESET"
	echo -e "\n$YELLOW=========================================================$RESET"
	[ "$1" = "qBittorrent" ] && opkg_test_install unzip
	[ "$1" = "aria2" ] && opkg_test_install ariang
	[ "$1" = "vsftpd" ] && opkg_test_install vsftpd
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
		echo -e "\n$PINK请选择下载保存路径：$RESET" && listcount="" && num="" && skipdownload=""
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
			[ "$num" -eq 0 ] && main exit
			sdadir=$(echo $sdalist | awk '{print $'$num'}')/$1 && sdadir_available_check "$1" "$2" "$sizeneeded"
		done
	else
		sdadir=${sdadir%/*}
		old_tag=$(eval $sdadir/$2 $3 2> /dev/null | grep -oE [.0-9]{1,10});[ -n "$7" ] && $7
		[ -n "$old_tag" ] && \
		echo -e "\n找到 $YELLOW$1 $PINK$old_tag$RESET 的安装路径：$BLUE$sdadir$RESET" || \
		echo -e "\n找到 $YELLOW$1$RESET 的安装路径：$BLUE$sdadir$RESET"
		sleep 2
	fi
	if [ -z "$(echo $1 | grep -oE 'aria2|vsftpd')" ];then
		[ -z "$upxretry" -o "$upxretry" -eq 0 ] && {
			urls="https://github.com/$5/$6/releases/latest"
			tag_url="https://api.github.com/repos/$5/$6/releases/latest"
			echo -e "\n即将获取 ${YELLOW}$1$RESET 最新版本号并下载" && sleep 2 && rm -f /tmp/$1.tmp && retry_count=5 && tag_name=""
			while [ -z "$tag_name" -a $retry_count != 0 ];do
				echo -e "\n正在获取最新 ${YELLOW}$1$RESET 版本号 ······ \c"
				tag_name=$(curl --connect-timeout 3 -sk "$tag_url" | grep tag_name | cut -f4 -d '"')
				[ -z "$tag_name" ] && {
					let retry_count--
					[ $retry_count != 0 ] && echo -e "$RED获取失败！$RESET\n\n即将尝试重连······（剩余重试次数：$PINK$retry_count$RESET）" && sleep 1
				}
			done
			[ -z "$tag_name" ] && {
				echo -e "$RED获取失败！\n\n获取版本号失败！$RESET如果没有代理的话建议多尝试几次！"
				echo -e "\n如果响应时间很短但获取失败，则是每小时内的请求次数已超过 ${PINK}github$RESET 限制，请更换 ${YELLOW}IP$RESET 或者等待一段时间后再试！" && main exit
			}
			echo -e "$GREEN获取成功！$RESET当前最新版本：$PINK$(echo $tag_name | grep -oE [.0-9]{1,10})$RESET" && sleep 2
			[ -n "$old_tag" ] && {
				old_tag=$(echo $old_tag | grep -oE [.0-9]{1,10} | sed 's/\.//g')
				new_tag=$(echo $tag_name | grep -oE [.0-9]{1,10} | sed 's/\.//g')
				[ "$old_tag" -ge "$new_tag" ] && echo -e "\n当前已安装最新版 $YELLOW$1 $PINK$(echo $tag_name | grep -oE [.0-9]{1,10})$RESET ，无需更新！$RESET" && skipdownload=1
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
				echo "0. 返回主页面"
				echo -e "\n可以在 $SKYBLUE$urls$RESET 中查找并复制下载地址"
				while [ -z "$num" ];do
					echo -ne "\n"
					read -p "请输入对应型号的数字或直接输入以 http 或 ftp 开头的下载地址 > " num
						case "$num" in
						1)
							hardware_type=$(uname -m)
							[ "$hardware_type" = "aarch64" ] && hardware_type=arm64
							;;
						2)
							hardware_type=arm64
							;;
						3)
							hardware_type=arm
							;;
						4)
							hardware_type=mips
							;;
						5)
							hardware_type=mips64
							;;
						6)
							hardware_type=mips64le
							;;
						7)
							hardware_type=mipsle
							;;
						8)
							hardware_type=amd64
							;;
						0)
							main exit
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
				echo -e "\n下载 ${YELLOW}$1 $(echo $tag_name | grep -oE [.0-9]{1,10})$RESET ······\n" && retry_count=5 && eabi="" && softfloat="" && url=""
				while [ ! -f /tmp/$1.tmp -a $retry_count != 0 ];do
						[ "$hardware_type" = "arm" ] && eabi="eabi"
						[ "${hardware_type:0:4}" = "mips" ] && softfloat="_softfloat"
						[ "$1" = "qBittorrent" ] && url="https://github.com/c0re100/qBittorrent-Enhanced-Edition/releases/download/$tag_name/qbittorrent-enhanced-nox_$hardware_type-linux-musl${eabi}_static.zip"
						[ "$1" = "Alist" ] && url="https://github.com/alist-org/alist/releases/download/$tag_name/alist-linux-musl$eabi-$hardware_type.tar.gz"
						[ "$1" = "AdGuardHome" ] && url="https://github.com/AdguardTeam/AdGuardHome/releases/download/$tag_name/AdGuardHome_linux_$hardware_type$softfloat.tar.gz"
						[ "${num:0:4}" = "http" -o "${num:0:3}" = "ftp" ] && url="$num"
						github_download "$1.tmp" "$url"
					if [ "$?" != 0 ];then
						rm -f /tmp/$1.tmp && let retry_count--
						[ $retry_count != 0 ] && echo -e "\n$RED下载失败！$RESET尝试重连中······（剩余重试次数：$PINK$retry_count$RESET）\n"
					else
						[ "$(wc -c < /tmp/$1.tmp)" = 9 ] && rm -f /tmp/$1.tmp && echo -e "\n$RED下载失败！$RESET没有找到适用于当前系统的文件包，请手动选择型号进行尝试" && main exit
					fi
				done;
				[ ! -f /tmp/$1.tmp ] && echo -e "\n$RED下载失败！$RESET如果没有代理的话建议多尝试几次！" && main exit
				echo -e "\n$GREEN下载成功！$RESET即将解压安装并启动" && rm -f /tmp/$2
				while [ -n "$(pidof $2)" ];do killpid $(pidof $2 | awk '{print $1}');done
				case "$1" in
					qBittorrent)
						unzip -oq /tmp/$1.tmp -d /tmp
						;;
					Alist)
						tar -zxf /tmp/$1.tmp -C /tmp
						;;
					AdGuardHome)
						tar -zxf /tmp/AdGuardHome.tmp -C /tmp && mv -f /tmp/$1 /tmp/$1.dir && mv -f /tmp/$1.dir/$1 /tmp/$1 && rm -rf /tmp/$1.dir
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
					echo -e "\n主程序文件大小 $PINK$filesize$RESET （预留 ${YELLOW}1 MB$RESET空间用于配置文件），所选目录可用空间 $RED$sdadiravailable ，空间不足，无法安装！$RESET" && main exit
				}
			else
				echo -e "\n$BLUE/tmp/$2$RESET 文件$RED不存在！$RESET" && main exit
			fi
		fi
		[ -z "$skipdownload" ] && {
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
		while [ -n "$(pidof $2)" ];do killpid $(pidof $2 | awk '{print $1}');done
		[ "$1" = "qBittorrent" ] && {
			if [ -f $sdadir/qBittorrent_files/config/qBittorrent.conf ];then
				defineport=$(cat $sdadir/qBittorrent_files/config/qBittorrent.conf | grep -F 'WebUI\Port' | sed 's/^.*=//')
				newdefineport=$defineport
				while [ -n "$(netstat -lnWp | grep ":$newdefineport " | awk '{print $NF}' | sed 's/.*\///' | head -1)" ];do let newdefineport++;sleep 1;done
				sed -i "s/=$defineport$/=$newdefineport/" $sdadir/qBittorrent_files/config/qBittorrent.conf
			else
				newuser=1 && newdefineport=6880 && mkdir -p $sdadir/qBittorrent_files/config
				while [ -n "$(netstat -lnWp | grep ":$newdefineport " | awk '{print $NF}' | sed 's/.*\///' | head -1)" ];do let newdefineport++;sleep 1;done
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
				while [ -n "$(netstat -lnWp | grep ":$newdefineport " | awk '{print $NF}' | sed 's/.*\///' | head -1)" ];do let newdefineport++;sleep 1;done
				sed -i "s/: $defineport,/: $newdefineport,/" $sdadir/data/config.json 2> /dev/null
				rm -f $sdadir/daemon/pid $tmpdir/daemon/pid && $sdadir/$2 start --data $sdadir/data &> /dev/null
			}
		}
		[ "$1" = "AdGuardHome" ] && {
			if [ -f $sdadir/AdGuardHome.yaml ];then
				defineport=$(cat "$sdadir/AdGuardHome.yaml" | grep address | grep -oE [0-9]{1,5} | tail -1)
				definednsport=$(cat "$sdadir/AdGuardHome.yaml" | grep port: | grep -oE [0-9]{1,5} | tail -1)
				[ -z "$(uci get dhcp.@dnsmasq[0].port 2> /dev/null)" -a "$definednsport" = 53 -o "$(uci get dhcp.@dnsmasq[0].port 2> /dev/null)" = "$definednsport" ] && {
					dnsnum=1
					cp -f /etc/config/dhcp /etc/config/dhcp.backup && log "备份/etc/config/dhcp文件并改名为dhcp.backup"
					uci set dhcp.@dnsmasq[0].port=0 && uci commit && /etc/init.d/dnsmasq restart &> /dev/null && log "修改/etc/config/dhcp文件中的选项：dnsmasq.port改为0（关闭dnsmasq的DNS服务）"
				}
				newdefineport=$defineport && newdnsport=$definednsport
				while [ -n "$(netstat -lnWp | grep ":$newdefineport " | awk '{print $NF}' | sed 's/.*\///' | head -1)" ];do let newdefineport++;sleep 1;done
				while [ -n "$(netstat -lnWp | grep ":$newdnsport " | awk '{print $NF}' | sed 's/.*\///' | head -1)" ];do let newdnsport++;sleep 1;done
				sed -i "s/:$defineport$/:$newdefineport/" $sdadir/AdGuardHome.yaml
				sed -i "s/: $definednsport$/: $newdnsport/" $sdadir/AdGuardHome.yaml
				[ "$newdnsport" != 53 ] && DNSINFO="${RED}DNS$RESET 监听端口设置为：$YELLOW$newdnsport$RESET"
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
									cp -f /etc/config/dhcp /etc/config/dhcp.backup && log "备份/etc/config/dhcp文件并改名为dhcp.backup"
									uci set dhcp.@dnsmasq[0].port=0 && uci commit && /etc/init.d/dnsmasq restart &> /dev/null && log "修改/etc/config/dhcp文件中的选项：dnsmasq.port改为0（关闭dnsmasq的DNS服务）"
								}
								[ "$dnsnum" -eq 0 ] && num=""
							done
						else
							echo -e "\n$RED检测到 $PINK$num $RED端口已被 $YELLOW$process $RED占用！请重新设置！$RESET" && num=""
						fi
					}
				done
				echo -e "dns:\n  port: $num\n  upstream_dns:\n    - 223.6.6.6" > $sdadir/AdGuardHome.yaml && newdefineport=3000
				while [ -n "$(netstat -lnWp | grep ":$newdefineport " | awk '{print $NF}' | sed 's/.*\///' | head -1)" ];do let newdefineport++;sleep 1;done
				echo -e "http:\n  pprof:\n    port: 6060\n    enabled: false\n  address: 0.0.0.0:$newdefineport\n  session_ttl: 720h" >> $sdadir/AdGuardHome.yaml
				[ "$num" != 53 ] && DNSINFO="${RED}DNS$RESET 监听端口设置为：$YELLOW$num$RESET"
			fi
			$sdadir/$2 -w $sdadir &> /dev/null &
		}
		runtimecount=0 && autostartfileinit=/etc/init.d/$1 && autostartfilerc=/etc/rc.d/S95$1 && downloadfileinit=/etc/init.d/Download$1 && downloadfilerc=/etc/rc.d/S95Download$1
		[ -z "$tmpdir" ] && {
			[ -f "$downloadfileinit" ] && rm -f $downloadfileinit && log "删除自启动文件$downloadfileinit"
			[ -L "$downloadfilerc" ] && rm -f $downloadfilerc && "删除自启动链接文件$downloadfilerc"
		}
		while [ -z "$(pidof $2)" -a "$runtimecount" -lt 5 ];do let runtimecount++;sleep 1;done
		if [ -n "$(pidof $2)" ];then
			echo -e "#!/bin/sh /etc/rc.common\n\nSTART=95\n\nstart() {" > $autostartfileinit
			[ -n "$tmpdir" -a -z "$skipdownload" ] && echo -e "#!/bin/sh /etc/rc.common\n\nSTART=95\n\nstart() {\n\tcat > /tmp/download$1file.sh <<EOF\n[ ! -d /tmp/XiaomiSimpleInstallBox ] && mkdir -p /tmp/XiaomiSimpleInstallBox\nwhile [ ! -f /tmp/$1.tmp ];do curl --connect-timeout 3 -sLko /tmp/$1.tmp \"$url\";[ \"\$?\" != 0 ] && rm -f /tmp/$1.tmp;done" > $downloadfileinit
			[ "$1" = "qBittorrent" ] && {
				while [ -n "$(pidof $2)" ];do killpid $(pidof $2 | awk '{print $1}');done
				echo -e "\t$sdadir/$2 --webui-port=$newdefineport --profile=$sdadir --configuration=files -d" >> $autostartfileinit
				[ -n "$tmpdir" -a -z "$skipdownload" ] && echo -e "unzip -oq /tmp/$1.tmp -d /tmp && mv -f /tmp/$2 /tmp/XiaomiSimpleInstallBox/$2" >> $downloadfileinit
			}
			[ "$1" = "Alist" ] && {
				[ -f $sdadir/.unadmin ] && sleep 5 && $sdadir/$2 admin set 12345678 --data $sdadir/data &> /dev/null && rm -f $sdadir/.unadmin
				echo -e "\trm -f $sdadir/daemon/pid $tmpdir/daemon/pid\n\t$sdadir/$2 start --data $sdadir/data" >> $autostartfileinit
				[ -n "$tmpdir" -a -z "$skipdownload" ] && echo -e "tar -zxf /tmp/$1.tmp -C /tmp && mv -f /tmp/$2 /tmp/XiaomiSimpleInstallBox/$2" >> $downloadfileinit
			}
			[ "$1" = "AdGuardHome" ] && {
				while [ -n "$(pidof $2)" ];do killpid $(pidof $2 | awk '{print $1}');done
				echo -e "\t$sdadir/$2 -w $sdadir &> /dev/null &" >> $autostartfileinit
				[ -n "$tmpdir" -a -z "$skipdownload" ] && {
					echo -e "tar -zxf /tmp/$1.tmp -C /tmp && mv -f /tmp/$1 /tmp/$1.dir && mv -f /tmp/$1.dir/$2 /tmp/XiaomiSimpleInstallBox/$2 && rm -rf /tmp/$1.dir" >> $downloadfileinit
					[ "$dnsnum" = 1 ] && {
						sed -i '7a mv -f /etc/config/dhcp.backup /etc/config/dhcp && /etc/init.d/dnsmasq restart &> /dev/null' $downloadfileinit
						echo -e "cp -f /etc/config/dhcp /etc/config/dhcp.backup\nuci set dhcp.@dnsmasq[0].port=0 && uci commit && /etc/init.d/dnsmasq restart &> /dev/null" >> $downloadfileinit
					}
				}
			}
			echo -e "}\n\nstop() {\n\tservice_stop $sdadir/$2\n}" >> $autostartfileinit && chmod 755 $autostartfileinit && log "新建自启动文件$autostartfileinit"
			ln -sf $autostartfileinit $autostartfilerc && log "新建自启动链接文件$autostartfilerc并链接到$autostartfileinit" && chmod 777 $autostartfilerc && $autostartfileinit start &> /dev/null
			[ -n "$tmpdir" -a -z "$skipdownload" ] && {
				echo -e "rm -f /tmp/$1.tmp\nchmod 755 /tmp/XiaomiSimpleInstallBox/$2\netc/init.d/$1 restart &> /dev/null\nrm -f /tmp/download$1file.sh\nEOF\n\tchmod 755 /tmp/download$1file.sh\n\t/tmp/download$1file.sh &\n}" >> $downloadfileinit && chmod 755 $downloadfileinit && log "新建自启动文件$downloadfileinit"
				ln -sf $downloadfileinit $downloadfilerc && log "新建自启动链接文件$downloadfilerc并链接到$downloadfileinit" && chmod 777 $downloadfilerc
			}
			echo -e "\n${YELLOW}$1 $(echo $tag_name | grep -oE [.0-9]{1,10}) $GREEN已运行$RESET并设置为$YELLOW开机自启动！$RESET"
			echo -e "\n请登录网页 $PINK$hostip:$newdefineport$RESET 使用 $DNSINFO"
			[ -n "$newuser" ] && echo -e "\n初始账号：${PINK}admin$RESET 初始密码：${PINK}12345678$RESET"
			[ "$1" = "Alist" ] && echo -e "\n官方使用指南：${SKYBLUE}https://alist.nn.ci/zh/$RESET"
		else
			echo -e "\n$RED启动失败！$RESET请下载适用于当前系统的文件包！"
			[ "$dnsnum" = 1 ] && mv -f /etc/config/dhcp.backup /etc/config/dhcp && /etc/init.d/dnsmasq restart &> /dev/null && log "恢复/etc/config/dhcp.backup文件并改名为dhcp"
		fi
	else
		while [ -n "$(pidof $3)" ];do killpid $(pidof $3 | awk '{print $1}');done
		[ "$1" = "aria2" ] && {
			[ ! -d $sdadir ] && mkdir -p $sdadir && log "新建文件夹$sdadir"
			touch $sdadir/aria2.session && num=""
			echo -e "\n$PINK请输入 aria2 的下载默认保存路径：$RESET"
			echo "---------------------------------------------------------"
			echo "0. 返回主页面"
			echo "---------------------------------------------------------"
			while [ ! -d "$num" -o "${num:0:1}" != / ];do
				echo -ne "\n"
				read -p "请输入以 '/' 开头的路径地址（完整路径） > " num
				[ "$num" = 0 ] && main exit
				[ "$num" = / ] && echo -e "\n$RED请不要使用根目录作为默认下载保存路径！$RESET" && sleep 1 && num="" && continue
				[ ! -d "$num" -o "${num:0:1}" != / ] && echo -e "\n路径 $BLUE$num $RED不存在！$RESET"
			done
			echo -e "\n${YELLOW}aria2$RESET 的下载默认保存路径已设置为：$BLUE$num$RESET" && sleep 1
			echo -e "#!/bin/sh\necho -e \"\\\ndownload-complete \$1 \$2 \$3\"\nDir=\"$num\"\nchmod -R 777 \"\$(echo \$Dir | sed 's#[^/]\$#&/#')\$(echo \$3 | sed -e \"s#\$Dir##\" -e 's#^/##' | awk -F '/' '{print \$1}')\"" > $sdadir/on-download-complete.sh && chmod 755 $sdadir/on-download-complete.sh
			echo -e "#!/bin/sh\necho -e \"\\\ndownload-stop \$1 \$2 \$3\"\nDir=\"$num\"\nrm -rf \"\$(echo \$Dir | sed 's#[^/]\$#&/#')\$(echo \$3 | sed -e \"s#\$Dir##\" -e 's#^/##' | awk -F '/' '{print \$1}')\"\nrm -f \"\$(echo \$Dir | sed 's#[^/]\$#&/#')\$(echo \$3 | sed -e \"s#\$Dir##\" -e 's#^/##' | awk -F '/' '{print \$1}').aria2\"" > $sdadir/on-download-stop.sh && chmod 755 $sdadir/on-download-stop.sh
			echo -e "ConfPath=\"$sdadir/aria2.conf\"\nrm -f /tmp/tracker_all.tmp && [ \$(cat /proc/uptime | awk '{print \$1}' | sed 's/\..*//') -le 60 ] && sleep 30\necho -e \"\\\n即将尝试获取最新 \\\033[1;33mTracker\\\033[0m 服务器列表（\\\033[1;33m成功与否不影响正常启动\\\033[0m） ······ \\\c\" && sleep 2\ncurl --connect-timeout 3 -skLo /tmp/tracker_all.tmp \"https://trackerslist.com/all.txt\"\n[ \"\$?\" != 0 ] && {\n\trm -f /tmp/tracker_all.tmp\n\techo -e \"\\\033[0;31m获取失败！\\\033[0m\" && sleep 2\n}\n[ -f /tmp/tracker_all.tmp ] && {\n\techo -e \"\\\033[1;32m获取成功！\\\033[0m\"\n\t#过滤IPv6的Tracker服务器地址：\n\tsed -i '/\/\/\[/d' /tmp/tracker_all.tmp\n\tsed -i \"/^$/d\" /tmp/tracker_all.tmp\n\tTrackers=\$(sed \":i;N;s|\\\n|,|;ti\" /tmp/tracker_all.tmp)\n\tsed -i \"s|bt-tracker=.*|bt-tracker=\$Trackers|\" \$ConfPath\n}\naria2c --conf-path=\$ConfPath -D &> /dev/null" > $sdadir/tracker_update.sh && chmod 755 $sdadir/tracker_update.sh
			echo -e "enable-rpc=true\nrpc-allow-origin-all=true\nrpc-listen-all=true\npeer-id-prefix=BC1980-\npeer-agent=BitComet 1.98\nuser-agent=BitComet/1.98\ninput-file=$sdadir/aria2.session\non-download-complete=$sdadir/on-download-complete.sh\non-download-stop=$sdadir/on-download-stop.sh\ndir=$num\nmax-concurrent-downloads=2\ncontinue=true\nmax-connection-per-server=16\nmin-split-size=20M\nremote-time=true\nsplit=16\nbt-remove-unselected-file=true\nbt-detach-seed-only=true\nbt-enable-lpd=true\nbt-max-peers=0\nbt-tracker=\ndht-file-path=$sdadir/dht.dat\ndht-file-path6=$sdadir/dht6.dat\ndht-listen-port=6881-6999\nlisten-port=6881-6999\nmax-overall-upload-limit=3M\nmax-upload-limit=0\nseed-ratio=3\nseed-time=2880\npause-metadata=false\nalways-resume=false\nauto-save-interval=1\nfile-allocation=falloc\nforce-save=false\nmax-overall-download-limit=0\nmax-download-limit=0\nsave-session=$sdadir/aria2.session\nsave-session-interval=1" > $sdadir/aria2.conf && $sdadir/tracker_update.sh
		}
		runtimecount=0 && autostartfileinit=/etc/init.d/$1 && autostartfilerc=/etc/rc.d/S95$1
		while [ -z "$(pidof $3)" -a "$runtimecount" -lt 5 ];do let runtimecount++;sleep 1;done
		if [ -n "$(pidof $3)" ];then
			echo -e "#!/bin/sh /etc/rc.common\n\nSTART=95\n\nstart() {" > $autostartfileinit
			[ "$1" = "aria2" ] && echo -e "\t$sdadir/tracker_update.sh" >> $autostartfileinit
			echo -e "}\n\nstop() {\n\tservice_stop /usr/bin/aria2c\n}" >> $autostartfileinit && chmod 755 $autostartfileinit && log "新建自启动文件$autostartfileinit"
			ln -sf $autostartfileinit $autostartfilerc && log "新建自启动链接文件$autostartfilerc并链接到$autostartfileinit" && chmod 777 $autostartfilerc && $autostartfileinit start &> /dev/null
			echo -e "\n${YELLOW}$1 $GREEN已运行$RESET并设置为$YELLOW开机自启动！$RESET"
			[ "$1" = "aria2" ] && echo -e "\n请登录网页 $PINK$hostip/ariang$RESET 使用"
		else
			echo -e "\n$RED启动失败！$RESET请尝试修改 $BLUE/etc/opkg/distfeeds.conf$RESET 中的地址后重试安装！"
			[ "$1" = "aria2" ] && rm -rf $sdadir && log "删除文件夹$sdadir" && opkg remove ariang aria2 &> /dev/null
		fi
	fi
	main exit
}
update_check(){
	echo -e "\n$GREEN=========================================================$RESET"
	echo -e "\n$PINK[[  这里以下是小米路由器简易安装插件脚本检查更新过程  ]]$RESET"
	echo -e "\n$YELLOW=========================================================$RESET"
	rm -f /tmp/XiaomiSimpleInstallBox.sh.tmp
	echo -e "\n即将获取$YELLOW最新版本脚本$RESET ······" && sleep 1
	while [ ! -f /tmp/XiaomiSimpleInstallBox.sh.tmp ];do
		echo -ne "\n" && github_download "XiaomiSimpleInstallBox.sh.tmp" "https://raw.githubusercontent.com/xilaochengv/BuildKernelSU/main/XiaomiSimpleInstallBox.sh"
		[ "$?" != 0 ] && {
			echo -ne "\n"
			curl --connect-timeout 3 -#Lko /tmp/XiaomiSimpleInstallBox.sh.tmp "https://raw.githubusercontent.com/xilaochengv/BuildKernelSU/main/XiaomiSimpleInstallBox.sh"
			[ "$?" != 0 ] && rm -f /tmp/XiaomiSimpleInstallBox.sh.tmp
		}
	done
	if [ "$version" != "$(sed -n '1p' /tmp/XiaomiSimpleInstallBox.sh.tmp | grep -oE v[.0-9]{1,5})" ];then
		echo -e "\n即将获取$YELLOW更新日志$RESET ······" && sleep 1
		rm -f /tmp/XiaomiSimpleInstallBox-change.log
		while [ ! -f /tmp/XiaomiSimpleInstallBox-change.log ];do
			echo -ne "\n" && github_download "XiaomiSimpleInstallBox-change.log" "https://raw.githubusercontent.com/xilaochengv/BuildKernelSU/main/XiaomiSimpleInstallBox-change.log"
			[ "$?" != 0 ] && {
				echo -ne "\n"
				curl --connect-timeout 3 -#Lko /tmp/XiaomiSimpleInstallBox-change.log "https://raw.githubusercontent.com/xilaochengv/BuildKernelSU/main/XiaomiSimpleInstallBox-change.log"
				[ "$?" != 0 ] && rm -f /tmp/XiaomiSimpleInstallBox-change.log
			}
		done
		mv -f /tmp/XiaomiSimpleInstallBox-change.log ${0%/*}/XiaomiSimpleInstallBox-change.log
		echo -e "\n$YELLOW当前脚本版本：$PINK$version$RESET ，$GREEN现已更新到最新版：$PINK$(sed -n '1p' /tmp/XiaomiSimpleInstallBox.sh.tmp | grep -oE [.0-9]{1,5})$RESET ，$RED请重新运行脚本$RESET"
		mv -f $0 ${0%/*}/XiaomiSimpleInstallBox.sh.$version.backup
		mv -f /tmp/XiaomiSimpleInstallBox.sh.tmp ${0%/*}/XiaomiSimpleInstallBox.sh
		chmod 755 ${0%/*}/XiaomiSimpleInstallBox.sh && exit
	else
		echo -e "\n当前已是$GREEN最新版本：$PINK$version$RESET，无需更新！"
		rm -f /tmp/XiaomiSimpleInstallBox.sh.tmp && main exit
	fi
}
main(){
	[ "$1" = "exit" ] && echo -e "\n\n$PINK\t\t [[  即将返回主页面  ]]$RESET" && sleep 2
	echo -e "\n$YELLOW=========================================================$RESET" && num=""
	echo -e "\n$PINK\t\t[[  这里以下是主页面  ]]$RESET"
	echo -e "\n$GREEN=========================================================$RESET"
	echo -e "\n$PINK请输入你的选项：$RESET"
	echo "---------------------------------------------------------"
	echo -e "1. $RED更新或下载$RESET并$GREEN启动$RESET最新版${YELLOW}qbittorrent增强版$RESET（BT & 磁链下载神器）"
	echo -e "\n2. $RED更新或下载$RESET并$GREEN启动$RESET最新版${YELLOW}Alist$RESET（挂载网盘神器）"
	echo -e "\n3. $RED更新或下载$RESET并$GREEN启动$RESET最新版${YELLOW}AdGuardHome$RESET（DNS 去广告神器）"
	echo -e "\n4. $RED更新或下载$RESET并$GREEN启动$RESET${YELLOW}Aria2$RESET（经典下载神器）"
	echo -e "\n5. $RED更新或下载$RESET并$GREEN启动$RESET${YELLOW}vsftp$RESET（搭建 FTP 服务器神器）"
	echo -e "\n9. $YELLOW检查脚本更新$RESET"
	echo "---------------------------------------------------------"
	echo -e "0. 退出$YELLOW小米路由器$GREEN简易安装插件脚本$RESET"
	while [ -z "$num" ];do
		echo -ne "\n"
		read -p "请输入对应选项的数字 > " num
		case "$num" in
		1)
			sda_install "qBittorrent" "qbittorrent-nox" "-v" "30MB" "c0re100" "qBittorrent-Enhanced-Edition" "rm -rf /.cache /.config /.local" 
			;;
		2)
			sda_install "Alist" "alist" "version | grep v" "64MB" "alist-org" "alist"
			;;
		3)
			sda_install "AdGuardHome" "AdGuardHome" "--version" "30MB" "AdGuardTeam" "AdGuardHome"
			;;
		4)
			sda_install "aria2" "aria2.conf" "aria2c" "30KB"
			;;
		5)
			sda_install "vsftpd"
			;;
		9)
			update_check
			;;
		0)
			echo -e "\n$GREEN=========================================================$RESET"
			echo -e "\n$PINK\t[[  已退出小米路由器简易安装插件脚本  ]]$RESET"
			echo -e "\n$RED=========================================================$RESET"
			echo -e "\n感谢使用$YELLOW小米路由器$GREEN简易安装插件脚本 $PINK$version$RESET ，觉得好用希望能够$RED$BLINK打赏支持~！$RESET"
			echo -e "\n您的小小支持是我持续更新的动力~~~$RED$BLINK十分感谢~ ~ ~ ! ! !$RESET"
			echo -e "\n$YELLOW打赏地址：${SKYBLUE}https://github.com/xilaochengv/BuildKernelSU$RESET"
			echo -e "\n$GREEN问题反馈：${SKYBLUE}https://www.right.com.cn/forum/thread-8266532-1-1.html$RESET"
			echo -e "\n$RED=========================================================$RESET" && exit
		esac
		[ -n "$(echo $num | sed 's/[0-9]//g')" -o -z "$num" ] && num="" && continue
		[ "$num" -lt 1	-o "$num" -gt 5 ] && num=""
	done
}
echo -e "\n$YELLOW=========================================================$RESET" && rm -f /tmp/opkg_updated
echo -e "\n欢迎使用$YELLOW小米路由器$GREEN简易安装插件脚本 $PINK$version$RESET ，觉得好用希望能够$RED$BLINK打赏支持~！$RESET"
echo -e "\n您的小小支持是我持续更新的动力~~~$RED$BLINK十分感谢~ ~ ~ ! ! !$RESET"
echo -e "\n$YELLOW打赏地址：${SKYBLUE}https://github.com/xilaochengv/BuildKernelSU$RESET"
echo -e "\n$GREEN问题反馈：${SKYBLUE}https://www.right.com.cn/forum/thread-8266532-1-1.html$RESET" && main