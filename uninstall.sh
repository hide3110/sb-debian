#!/bin/bash
# sing-box Debian/Ubuntu 自动卸载脚本（无需确认）

set -e

GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}[1/4] 正在停止服务...${NC}"
systemctl stop sing-box.service 2>/dev/null || true
systemctl disable sing-box.service 2>/dev/null || true

echo -e "${GREEN}[2/4] 正在删除文件...${NC}"
rm -rf /etc/sing-box /var/lib/sing-box
rm -f /etc/systemd/system/sing-box.service
rm -f /usr/local/bin/sing-box /usr/bin/sing-box

echo -e "${GREEN}[3/4] 正在删除证书...${NC}"
rm -f /etc/ssl/private/bing.com.key /etc/ssl/private/bing.com.crt

echo -e "${GREEN}[4/4] 重载 systemd...${NC}"
systemctl daemon-reload

echo -e "${GREEN}✓ sing-box 已完全卸载！${NC}"
