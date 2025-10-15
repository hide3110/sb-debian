#!/bin/bash

# sing-box Debian/Ubuntu Linux 安装脚本

set -e

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[信息]${NC} $1"
}

print_error() {
    echo -e "${RED}[错误]${NC} $1"
}

# 检查 root 权限
if [ "$(id -u)" -ne 0 ]; then
    print_error "此脚本需要 root 权限运行"
    exit 1
fi

# 配置变量
SING_BOX_VERSION=${1:-1.11.15}
AL_PORTS=${AL_PORTS:-"65031,65032,65033"}
RE_PORT=${RE_PORT:-443}
AL_DOMAIN=${AL_DOMAIN:-us.yyds.nyc.mn}
RE_SNI=${RE_SNI:-music.apple.com}
API_TOKEN=${API_TOKEN:-K3Xo_z-SayrFiyQ7icsio0t5lDSRoCFogdYr7HFY}

# 解析端口（支持范围表示法）
if [[ "$AL_PORTS" =~ ^([0-9]+)-([0-9]+)$ ]]; then
    # 范围表示法: 8443-8445
    START_PORT=${BASH_REMATCH[1]}
    END_PORT=${BASH_REMATCH[2]}
    
    PORT_COUNT=$((END_PORT - START_PORT + 1))
    if [ $PORT_COUNT -ne 3 ]; then
        print_error "端口范围必须包含3个端口，当前为 $PORT_COUNT 个"
        exit 1
    fi
    
    SS_PORT=$START_PORT
    TR_PORT=$((START_PORT + 1))
    WS_PORT=$((START_PORT + 2))
else
    # 逗号分隔表示法: 8443,9443,10443
    IFS=',' read -ra PORT_ARRAY <<< "$AL_PORTS"
    SS_PORT=${PORT_ARRAY[0]:-65031}
    TR_PORT=${PORT_ARRAY[1]:-65032}
    WS_PORT=${PORT_ARRAY[2]:-65033}
fi

# 安装 sing-box
print_info "正在安装 sing-box $SING_BOX_VERSION ..."
curl -fsSL https://sing-box.app/install.sh | bash -s -- --version "$SING_BOX_VERSION" > /dev/null 2>&1

# 创建目录
CONFIG_DIR="/etc/sing-box"
WORK_DIR="/var/lib/sing-box"
mkdir -p "$CONFIG_DIR" "$WORK_DIR"

# 生成配置文件
cat > "$CONFIG_DIR/config.json" << EOF
{
  "log": {
    "disabled": false,
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
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
          "email": "yyds88@gmail.com",
          "dns01_challenge": {
            "provider": "cloudflare",
            "api_token": "${API_TOKEN}"
          }
        }
      }
    },
    {
      "type": "vless",
      "tag": "vless-wss-in",
      "listen": "::",
      "listen_port": ${WS_PORT},
      "users": [
        {
          "uuid": "43a1f08a-d9ff-4aea-ac8a-cc622caf62a5"
        }
      ],
      "transport": {
        "type": "ws",
        "path": "/42af2c6b"
      },
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
          "email": "yyds88@gmail.com",
          "dns01_challenge": {
            "provider": "cloudflare",
            "api_token": "${API_TOKEN}"
          }
        }
      },
      "multiplex": {
        "enabled": true
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

# 验证配置
sing-box check -c "$CONFIG_DIR/config.json" > /dev/null 2>&1

# 启动服务
systemctl daemon-reload
systemctl enable sing-box.service --now > /dev/null 2>&1

# 等待服务启动
sleep 2

# 输出结果
print_info ""
print_info "=========================================="
print_info "sing-box 安装并启动完成！"
print_info "=========================================="
print_info ""
print_info "文件位置:"
print_info "  配置文件: $CONFIG_DIR/config.json"
print_info "  工作目录: $WORK_DIR"
print_info ""
print_info "服务状态:"
print_info "  当前状态: 运行中"
print_info "  开机自启: 已启用"
print_info "=========================================="
