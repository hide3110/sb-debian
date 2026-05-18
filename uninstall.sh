#!/bin/bash
# sing-box Debian/Ubuntu 完全卸载脚本（增强版）
# 适用于官方 install.sh 安装方式

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info() {
    echo -e "${GREEN}[信息]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

error() {
    echo -e "${RED}[错误]${NC} $1"
}

if [ "$(id -u)" -ne 0 ]; then
    error "请使用 root 权限运行"
    exit 1
fi

echo ""
info "======================================"
info "开始彻底卸载 sing-box ..."
info "======================================"
echo ""

# 停止服务
info "[1/8] 停止 sing-box 服务..."

systemctl stop sing-box.service 2>/dev/null || true
systemctl disable sing-box.service 2>/dev/null || true
systemctl mask sing-box.service 2>/dev/null || true

# 杀掉残留进程
info "[2/8] 清理残留进程..."

pkill -9 sing-box 2>/dev/null || true
killall -9 sing-box 2>/dev/null || true

sleep 1

# 删除 systemd 服务
info "[3/8] 删除 systemd 服务..."

rm -f /etc/systemd/system/sing-box.service
rm -f /lib/systemd/system/sing-box.service
rm -f /usr/lib/systemd/system/sing-box.service

# 删除程序文件
info "[4/8] 删除程序文件..."

rm -f /usr/local/bin/sing-box
rm -f /usr/bin/sing-box
rm -f /bin/sing-box

# 删除配置和数据
info "[5/8] 删除配置与数据..."

rm -rf /etc/sing-box
rm -rf /var/lib/sing-box
rm -rf /usr/local/etc/sing-box

# 删除 ACME/证书缓存
info "[6/8] 删除证书缓存..."

rm -rf /root/.acme.sh
rm -rf /etc/ssl/private/sing-box*
rm -rf /etc/ssl/certs/sing-box*
rm -rf /var/lib/sing-box/acme

# 重载 systemd
info "[7/8] 重载 systemd..."

systemctl daemon-reload
systemctl reset-failed

# 删除可能残留的 tmp 文件
info "[8/8] 清理临时文件..."

rm -f /tmp/sing-box-official-install.sh
rm -f /tmp/sing-box-install.log

echo ""

# 检查是否卸载成功
if command -v sing-box >/dev/null 2>&1; then
    warn "检测到 sing-box 命令仍存在:"
    command -v sing-box
else
    info "sing-box 可执行文件已删除"
fi

if systemctl list-unit-files | grep -q "sing-box.service"; then
    warn "检测到 sing-box.service 仍存在"
else
    info "systemd 服务已清理"
fi

echo ""
info "======================================"
info "✓ sing-box 已彻底卸载完成！"
info "======================================"
echo ""

echo "建议执行："
echo "reboot"
