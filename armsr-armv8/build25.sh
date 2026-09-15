#!/bin/bash
# ImmortalWrt 25.12.x armsr-armv8 (QEMU) 构建脚本
# 25.12 起使用 apk，不要再 source 24.10 的 custom-packages.sh / switch_repository.sh

source shell/apk-custom-packages.sh
echo "第三方apk软件包: $CUSTOM_PACKAGES"
LOGFILE="/tmp/uci-defaults-log.txt"
echo "Starting build25 at $(date)" >> $LOGFILE

echo "Building for profile: $PROFILE"
echo "Building for ROOTFS_PARTSIZE: $ROOTFS_PARTSIZE MB"

echo "Create pppoe-settings"
mkdir -p /home/build/immortalwrt/files/etc/config

cat << EOF > /home/build/immortalwrt/files/etc/config/pppoe-settings
enable_pppoe=${ENABLE_PPPOE}
pppoe_account=${PPPOE_ACCOUNT}
pppoe_password=${PPPOE_PASSWORD}
EOF

echo "cat pppoe-settings"
cat /home/build/immortalwrt/files/etc/config/pppoe-settings

if [ -z "$CUSTOM_PACKAGES" ]; then
  echo "⚪️ 未选择任何第三方软件包"
else
  echo "🔄 正在同步第三方 apk 仓库..."
  git clone --depth=1 https://github.com/wukongdaily/apk.git /tmp/store-apk-repo
  mkdir -p /home/build/immortalwrt/extra-packages
  # arm64 用 aarch64 / arm64 目录（若仓库结构不同可再调整）
  if [ -d /tmp/store-apk-repo/run/arm64 ]; then
    cp -r /tmp/store-apk-repo/run/arm64/* /home/build/immortalwrt/extra-packages/ || true
  elif [ -d /tmp/store-apk-repo/run/aarch64 ]; then
    cp -r /tmp/store-apk-repo/run/aarch64/* /home/build/immortalwrt/extra-packages/ || true
  fi
  if [ -f shell/apk-prepare-packages.sh ]; then
    sh shell/apk-prepare-packages.sh
  fi
  ls -lah /home/build/immortalwrt/packages/ 2>/dev/null || true
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - 开始构建 QEMU-arm64 25.12 固件..."

# ========== ImmortalWrt 仓库内插件（可按需删减）==========
PACKAGES=""
PACKAGES="$PACKAGES curl"
PACKAGES="$PACKAGES luci-i18n-diskman-zh-cn"
PACKAGES="$PACKAGES luci-i18n-firewall-zh-cn"
PACKAGES="$PACKAGES luci-theme-argon"
PACKAGES="$PACKAGES luci-app-argon-config"
PACKAGES="$PACKAGES luci-i18n-argon-config-zh-cn"
PACKAGES="$PACKAGES luci-i18n-package-manager-zh-cn"
PACKAGES="$PACKAGES luci-i18n-ttyd-zh-cn"
PACKAGES="$PACKAGES openssh-sftp-server"
PACKAGES="$PACKAGES luci-i18n-filemanager-zh-cn"

# 合并第三方 apk（目前支持较少，见项目 Discussion #699）
PACKAGES="$PACKAGES $CUSTOM_PACKAGES"

# Docker（由工作流 INCLUDE_DOCKER 控制）
if [ "$INCLUDE_DOCKER" = "yes" ]; then
  PACKAGES="$PACKAGES luci-i18n-dockerman-zh-cn"
  echo "Adding package: luci-i18n-dockerman-zh-cn"
fi

# OpenClash 内核（若集成了 luci-app-openclash）
if echo "$PACKAGES" | grep -q "luci-app-openclash"; then
  echo "✅ 已选择 luci-app-openclash，添加 openclash core"
  mkdir -p files/etc/openclash/core
  META_URL="https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-arm64.tar.gz"
  wget -qO- "$META_URL" | tar xOvz > files/etc/openclash/core/clash_meta
  chmod +x files/etc/openclash/core/clash_meta
  wget -q https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat -O files/etc/openclash/GeoIP.dat
  wget -q https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat -O files/etc/openclash/GeoSite.dat
else
  echo "⚪️ 未选择 luci-app-openclash"
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - Building image with packages:"
echo "$PACKAGES"

# 关键：不要再碰 repositories.conf / opkg-key
make image PROFILE="${PROFILE:-generic}" PACKAGES="$PACKAGES" \
  FILES="/home/build/immortalwrt/files" \
  ROOTFS_PARTSIZE="${ROOTFS_PARTSIZE}"

if [ $? -ne 0 ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Error: Build failed!"
  exit 1
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - Build completed successfully."
