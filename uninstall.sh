#!/bin/bash
# sing-box Debian/Ubuntu 完全卸载脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[信息]${NC} $1"
}

print_error() {
    echo -e "${RED}[错误]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

# 检查是否为 root 用户
if [ "$(id -u)" -ne 0 ]; then
    print_error "此脚本需要 root 权限运行"
    exit 1
fi

print_warning "=========================================="
print_warning "sing-box 完全卸载脚本"
print_warning "=========================================="
print_warning "此操作将删除以下内容："
print_warning "  - sing-box 服务"
print_warning "  - 配置文件"
print_warning "  - 证书文件"
print_warning "  - 工作目录"
print_warning "  - 可执行文件"
print_warning "=========================================="

# 确认操作
read -p "是否继续？(yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    print_info "已取消卸载"
    exit 0
fi

echo ""

# 步骤1：停止并禁用服务
print_info "步骤 1/6: 停止并禁用 sing-box 服务"
if systemctl is-active --quiet sing-box.service 2>/dev/null; then
    systemctl stop sing-box.service
    print_info "服务已停止"
else
    print_warning "服务未运行"
fi

if systemctl is-enabled --quiet sing-box.service 2>/dev/null; then
    systemctl disable sing-box.service
    print_info "已禁用开机自启"
else
    print_warning "服务未设置自启"
fi

# 步骤2：删除服务文件
print_info "步骤 2/6: 删除 systemd 服务文件"
if [ -f /etc/systemd/system/sing-box.service ]; then
    rm -f /etc/systemd/system/sing-box.service
    systemctl daemon-reload
    print_info "服务文件已删除"
else
    print_warning "服务文件不存在"
fi

# 步骤3：删除配置文件
print_info "步骤 3/6: 删除配置文件"
if [ -d /etc/sing-box ]; then
    rm -rf /etc/sing-box
    print_info "配置目录已删除: /etc/sing-box"
else
    print_warning "配置目录不存在"
fi

# 步骤4：删除工作目录和证书目录
print_info "步骤 4/6: 删除工作目录和证书"
if [ -d /var/lib/sing-box ]; then
    rm -rf /var/lib/sing-box
    print_info "工作目录已删除: /var/lib/sing-box"
else
    print_warning "工作目录不存在"
fi

if [ -f /etc/ssl/private/bing.com.key ] || [ -f /etc/ssl/private/bing.com.crt ]; then
    rm -f /etc/ssl/private/bing.com.key
    rm -f /etc/ssl/private/bing.com.crt
    print_info "自签证书已删除"
else
    print_warning "证书文件不存在"
fi

# 步骤5：卸载 sing-box 二进制文件
print_info "步骤 5/6: 卸载 sing-box 二进制文件"
if [ -f /usr/local/bin/sing-box ]; then
    rm -f /usr/local/bin/sing-box
    print_info "已删除: /usr/local/bin/sing-box"
fi

if [ -f /usr/bin/sing-box ]; then
    rm -f /usr/bin/sing-box
    print_info "已删除: /usr/bin/sing-box"
fi

# 步骤6：清理 APT 缓存（如果通过 dpkg 安装）
print_info "步骤 6/6: 检查并清理包管理器缓存"
if dpkg -l | grep -q sing-box 2>/dev/null; then
    apt-get remove --purge -y sing-box 2>/dev/null || true
    apt-get autoremove -y 2>/dev/null || true
    print_info "已通过 apt 清理"
else
    print_warning "未通过包管理器安装，跳过"
fi

# 完成
echo ""
print_info "=========================================="
print_info "sing-box 已完全卸载！"
print_info "=========================================="
print_info "已删除的内容："
print_info "  ✓ systemd 服务文件"
print_info "  ✓ 配置文件 (/etc/sing-box)"
print_info "  ✓ 工作目录 (/var/lib/sing-box)"
print_info "  ✓ 证书文件 (/etc/ssl/private/bing.com.*)"
print_info "  ✓ 可执行文件"
print_info "=========================================="
