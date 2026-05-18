#!/bin/bash
# sing-box Debian/Ubuntu Linux 安装脚本
# 使用方法:
# SB_VERSION=1.13.12 AL_PORTS="65031-65037" RE_PORT=443 AL_DOMAIN=example.com RE_SNI=www.example.com bash install.sh

set -e

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
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

# 检查 root 权限
if [ "$(id -u)" -ne 0 ]; then
    print_error "此脚本需要 root 权限运行"
    exit 1
fi

# 配置变量（支持环境变量和位置参数，优先使用环境变量）
SB_VERSION=${SB_VERSION:-${1:-1.13.12}}
AL_PORTS=${AL_PORTS:-"65031-65037"}
RE_PORT=${RE_PORT:-443}
AL_DOMAIN=${AL_DOMAIN:-us.yyds.nyc.mn}
RE_SNI=${RE_SNI:-www.cityofrc.us}

# 显示配置信息
print_info "=========================================="
print_info "sing-box 安装脚本"
print_info "=========================================="
print_info "sing-box 版本: $SB_VERSION"
print_info "AL 端口配置: $AL_PORTS"
print_info "Reality 端口: $RE_PORT"
print_info "AL 域名: $AL_DOMAIN"
print_info "Reality SNI: $RE_SNI"
print_info "=========================================="

# 解析端口（支持范围表示法）
if [[ "$AL_PORTS" =~ ^([0-9]+)-([0-9]+)$ ]]; then
    # 范围表示法: 65031-65037
    START_PORT=${BASH_REMATCH[1]}
    END_PORT=${BASH_REMATCH[2]}
    PORT_COUNT=$((END_PORT - START_PORT + 1))

    if [ $PORT_COUNT -ne 7 ]; then
        print_error "端口范围必须包含7个端口，当前为 $PORT_COUNT 个"
        exit 1
    fi

    SK_PORT=$START_PORT
    SS_PORT=$((START_PORT + 1))
    TR_PORT=$((START_PORT + 2))
    VL_PORT=$((START_PORT + 3))
    TU_PORT=$((START_PORT + 4))
    HY_PORT=$((START_PORT + 5))
    NA_PORT=$((START_PORT + 6))

    print_info "端口分配:"
    print_info "  SOCKS5=${SK_PORT}"
    print_info "  Shadowsocks=${SS_PORT}"
    print_info "  Trojan=${TR_PORT}"
    print_info "  VLESS=${VL_PORT}"
    print_info "  TUIC=${TU_PORT}"
    print_info "  Hysteria2=${HY_PORT}"
    print_info "  Naive=${NA_PORT}"
else
    # 逗号分隔表示法
    # 65031,65032,65033,65034,65035,65036,65037
    IFS=',' read -ra PORT_ARRAY <<< "$AL_PORTS"

    if [ ${#PORT_ARRAY[@]} -ne 7 ]; then
        print_error "必须提供7个端口"
        exit 1
    fi

    SK_PORT=${PORT_ARRAY[0]}
    SS_PORT=${PORT_ARRAY[1]}
    TR_PORT=${PORT_ARRAY[2]}
    VL_PORT=${PORT_ARRAY[3]}
    TU_PORT=${PORT_ARRAY[4]}
    HY_PORT=${PORT_ARRAY[5]}
    NA_PORT=${PORT_ARRAY[6]}

    print_info "端口分配:"
    print_info "  SOCKS5=${SK_PORT}"
    print_info "  Shadowsocks=${SS_PORT}"
    print_info "  Trojan=${TR_PORT}"
    print_info "  VLESS=${VL_PORT}"
    print_info "  TUIC=${TU_PORT}"
    print_info "  Hysteria2=${HY_PORT}"
    print_info "  Naive=${NA_PORT}"
fi

# 安装 sing-box
print_info "正在安装 sing-box $SB_VERSION ..."

systemctl stop sing-box.service 2>/dev/null || true

curl -fsSL -o /tmp/sing-box-official-install.sh https://sing-box.app/install.sh
chmod +x /tmp/sing-box-official-install.sh

if yes Y | DEBIAN_FRONTEND=noninteractive bash /tmp/sing-box-official-install.sh --version "$SB_VERSION" 2>&1 | tee /tmp/sing-box-install.log; then
    print_info "sing-box $SB_VERSION 安装成功"
else
    print_warning "官方安装脚本返回失败，尝试修复 dpkg 未完成配置..."
    if yes Y | DEBIAN_FRONTEND=noninteractive dpkg --force-confnew --configure -a 2>&1 | tee -a /tmp/sing-box-install.log; then
        print_info "dpkg 修复完成"
    else
        print_error "sing-box 安装失败，日志见: /tmp/sing-box-install.log"
        exit 1
    fi
fi

# 创建目录
CONFIG_DIR="/etc/sing-box"
WORK_DIR="/var/lib/sing-box"

mkdir -p "$CONFIG_DIR" "$WORK_DIR"

# 生成配置文件
print_info "正在生成配置文件..."

cat > "$CONFIG_DIR/config.json" << EOF
{
  "log": {
    "disabled": false,
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "socks",
      "tag": "socks-in",
      "listen": "::",
      "listen_port": ${SK_PORT},
      "users": [
        {
          "username": "hide3110",
          "password": "L3vCBgE7nSUlHQcV0D9qYA"
        }
      ]
    },
    {
      "type": "shadowsocks",
      "tag": "ss-in",
      "listen": "::",
      "listen_port": ${SS_PORT},
      "method": "aes-128-gcm",
      "password": "L3vCBgE7nSUlHQcV0D9qYA=="
    },
    {
      "type": "trojan",
      "tag": "trojan-in",
      "listen": "::",
      "listen_port": ${TR_PORT},
      "users": [
        {
          "password": "hBh1uKxMhYr6yTc40MDIcg=="
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "${AL_DOMAIN}",
        "alpn": [
          "h2",
          "http/1.1"
        ],
        "acme": {
          "domain": "${AL_DOMAIN}",
          "data_directory": "acme",
          "email": "yyds88@gmail.com"
        }
      }
    },
    {
      "type": "vless",
      "tag": "vless-in",
      "listen": "::",
      "listen_port": ${VL_PORT},
      "users": [
        {
          "uuid": "43a1f08a-d9ff-4aea-ac8a-cc622caf62a5"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "${AL_DOMAIN}",
        "alpn": [
          "h2",
          "http/1.1"
        ],
        "acme": {
          "domain": "${AL_DOMAIN}",
          "data_directory": "acme",
          "email": "yyds88@gmail.com"
        }
      }
    },
    {
      "type": "tuic",
      "tag": "tuic-in",
      "listen": "::",
      "listen_port": ${TU_PORT},
      "users": [
        {
          "uuid": "47013aa0-b699-4468-b6e4-56250573f3ab",
          "password": "Ro060jU4fghfvTpHxiDQyA=="
        }
      ],
      "congestion_control": "bbr",
      "tls": {
        "enabled": true,
        "server_name": "${AL_DOMAIN}",
        "alpn": [
          "h3"
        ],
        "acme": {
          "domain": "${AL_DOMAIN}",
          "data_directory": "acme",
          "email": "yyds88@gmail.com"
        }
      }
    },
    {
      "type": "hysteria2",
      "tag": "hysteria2-in",
      "listen": "::",
      "listen_port": ${HY_PORT},
      "users": [
        {
          "password": "yK9VdaPrUZ5iZRLpv0ZNow=="
        }
      ],
      "ignore_client_bandwidth": false,
      "tls": {
        "enabled": true,
        "server_name": "${AL_DOMAIN}",
        "alpn": [
          "h3"
        ],
        "acme": {
          "domain": "${AL_DOMAIN}",
          "data_directory": "acme",
          "email": "yyds88@gmail.com"
        }
      }
    },
    {
      "type": "naive",
      "tag": "naive-in",
      "listen": "::",
      "listen_port": ${NA_PORT},
      "users": [
        {
          "username": "hide3110",
          "password": "L3vCBgE7nSUlHQcV0D9qYA=="
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "${AL_DOMAIN}",
        "alpn": [
          "h2",
          "http/1.1"
        ],
        "acme": {
          "domain": "${AL_DOMAIN}",
          "data_directory": "acme",
          "email": "yyds88@gmail.com"
        }
      }
    },
    {
      "type": "vless",
      "tag": "real-in",
      "listen": "::",
      "listen_port": ${RE_PORT},
      "users": [
        {
          "uuid": "43a1f08a-d9ff-4aea-ac8a-cc622caf62a5",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "${RE_SNI}",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "${RE_SNI}",
            "server_port": 443
          },
          "private_key": "IJ7MvrtAgMGCJdLk4JHtaRci5uAIa2SD5aNO0hsNJ2U",
          "short_id": [
            "4eae9cfd38fb5a8d"
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ]
}
EOF

print_info "配置文件已创建: $CONFIG_DIR/config.json"

# 验证配置
print_info "正在验证配置文件..."

if sing-box check -c "$CONFIG_DIR/config.json" > /dev/null 2>&1; then
    print_info "配置文件验证通过"
else
    print_error "配置文件验证失败，请检查配置"
    exit 1
fi

# 启动服务
print_info "正在启动 sing-box 服务..."

systemctl daemon-reload
systemctl enable sing-box.service --now > /dev/null 2>&1

# 等待服务启动
sleep 2

# 检查服务状态
if systemctl is-active --quiet sing-box.service; then
    SERVICE_STATUS="运行中"
else
    SERVICE_STATUS="启动失败"
    print_error "服务启动失败，请检查日志:"
    print_error "journalctl -u sing-box -n 50"
    exit 1
fi

# 输出结果
echo ""

print_info "=========================================="
print_info "sing-box 安装并启动完成！"
print_info "=========================================="

echo ""

print_info "版本信息:"
print_info "  sing-box 版本: $SB_VERSION"

echo ""

print_info "端口配置:"
print_info "  SOCKS5: $SK_PORT"
print_info "  Shadowsocks: $SS_PORT"
print_info "  Trojan (TLS): $TR_PORT"
print_info "  VLESS (TLS): $VL_PORT"
print_info "  TUIC: $TU_PORT"
print_info "  Hysteria2: $HY_PORT"
print_info "  Naive: $NA_PORT"
print_info "  Reality: $RE_PORT"

echo ""

print_info "域名配置:"
print_info "  ACME 域名: $AL_DOMAIN"
print_info "  Reality SNI: $RE_SNI"

echo ""

print_info "文件位置:"
print_info "  配置文件: $CONFIG_DIR/config.json"
print_info "  工作目录: $WORK_DIR"
print_info "  证书目录: $WORK_DIR/acme"

echo ""

print_info "服务状态:"
print_info "  当前状态: $SERVICE_STATUS"
print_info "  开机自启: 已启用"

echo ""

print_info "常用命令:"
print_info "  查看状态: systemctl status sing-box"
print_info "  查看日志: journalctl -u sing-box -f"
print_info "  重启服务: systemctl restart sing-box"

print_info "=========================================="
