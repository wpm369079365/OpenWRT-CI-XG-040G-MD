#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

PKG_PATH="$GITHUB_WORKSPACE/wrt/package/"

#预置HomeProxy数据
if [ -d *"homeproxy"* ]; then
	echo " "

	HP_RULE="surge"
	HP_PATH="homeproxy/root/etc/homeproxy"

	rm -rf ./$HP_PATH/resources/*

	git clone -q --depth=1 --single-branch --branch "release" "https://github.com/Loyalsoldier/surge-rules.git" ./$HP_RULE/
	cd ./$HP_RULE/ && RES_VER=$(git log -1 --pretty=format:'%s' | grep -o "[0-9]*")

	echo $RES_VER | tee china_ip4.ver china_ip6.ver china_list.ver gfw_list.ver
	awk -F, '/^IP-CIDR,/{print $2 > "china_ip4.txt"} /^IP-CIDR6,/{print $2 > "china_ip6.txt"}' cncidr.txt
	sed 's/^\.//g' direct.txt > china_list.txt ; sed 's/^\.//g' gfw.txt > gfw_list.txt
	mv -f ./{china_*,gfw_list}.{ver,txt} ../$HP_PATH/resources/

	cd .. && rm -rf ./$HP_RULE/

	cd $PKG_PATH && echo "homeproxy date has been updated!"
fi

#修改argon主题字体和颜色
if [ -d *"luci-theme-argon"* ]; then
	echo " " && cd ./luci-theme-argon/

	sed -i "s/primary '.*'/primary '#31a1a1'/; s/'0.2'/'0.5'/; s/'none'/'bing'/; s/'600'/'normal'/" ./luci-app-argon-config/root/etc/config/argon

	cd $PKG_PATH && echo "theme-argon has been fixed!"
fi

#修改aurora菜单式样
if [ -d *"luci-app-aurora-config"* ]; then
	echo " " && cd ./luci-app-aurora-config/

	sed -i "s/nav_submenu_type '.*'/nav_submenu_type 'boxed-dropdown'/g" $(find ./root/usr/share/aurora/ -type f -name "*.template")

	cd $PKG_PATH && echo "theme-aurora has been fixed!"
fi

#修改mini-diskmanager菜单位置
if [ -d *"luci-app-mini-diskmanager"* ]; then
	echo " " && cd ./luci-app-mini-diskmanager/

	sed -i "s/services/system/g" ./luci-app-mini-diskmanager/root/usr/share/luci/menu.d/luci-app-mini-diskmanager.json

	cd $PKG_PATH && echo "mini-diskmanager has been fixed!"
fi

#修复TailScale配置文件冲突
TS_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/tailscale/Makefile")
if [ -f "$TS_FILE" ]; then
	echo " "

	sed -i '/\/files/d' $TS_FILE

	cd $PKG_PATH && echo "tailscale has been fixed!"
fi

#修复Rust编译失败
RUST_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/rust/Makefile")
if [ -f "$RUST_FILE" ]; then
	echo " "

	sed -i 's/ci-llvm=true/ci-llvm=false/g' $RUST_FILE

	cd $PKG_PATH && echo "rust has been fixed!"
fi

#修复 HomeProxy 与 sing-box 1.13+ 不兼容导致「未运行」：
#源码自带(openwrt-25.12)的 generate_client.uc 仍在 inbound 里写 legacy 字段
#(sniff / sniff_override_destination)，而 sing-box 自 1.13.0 起移除该格式，
#配置校验失败 -> 服务起不来。immortalwrt/luci master 版已改为 route 的 action:sniff。
#两版仅差 sniff 相关 30 余行、import 相同，故只替换这一个脚本，避免混入 master 其他文件。
HP_GEN=$(find ../feeds/luci/ $PKG_PATH -type f -path '*luci-app-homeproxy*generate_client.uc' 2>/dev/null | head -n1)
if [ -n "$HP_GEN" ]; then
	echo " "
	TMP_GEN="$HP_GEN.hpnew"
	wget -q --timeout=30 -O "$TMP_GEN" "https://raw.githubusercontent.com/immortalwrt/luci/master/applications/luci-app-homeproxy/root/etc/homeproxy/scripts/generate_client.uc"
	#校验：新版含 route 的 action:'sniff'，且不再有 legacy 的 sniff_override_destination
	if [ -s "$TMP_GEN" ] && grep -qE "^[[:space:]]*action: 'sniff'" "$TMP_GEN" && ! grep -q "sniff_override_destination" "$TMP_GEN"; then
		mv -f "$TMP_GEN" "$HP_GEN"
		cd $PKG_PATH && echo "homeproxy generate_client.uc patched for sing-box 1.13+!"
	else
		echo "homeproxy patch SKIPPED (download failed or unexpected content)"
		rm -f "$TMP_GEN"
	fi
fi
