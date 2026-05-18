#!/bin/bash
# sing-box Debian/Ubuntu Linux 安装脚本
# 使用方法: SB_VERSION=1.11.4 AL_PORTS="8443-8447" RE_PORT=443 AL_DOMAIN=example.com RE_SNI=www.example.com bash install_hardened.sh

set -Eeuo pipefail

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

require_command() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        print_error "缺少依赖命令: $cmd"
        exit 1
    fi
}

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        print_error "此脚本需要 root 权限运行"
        exit 1
    fi
}

check_os() {
    if [ ! -r /etc/os-release ]; then
        print_error "无法读取 /etc/os-release，不能确认系统类型"
        exit 1
    fi

    # shellcheck disable=SC1091
    . /etc/os-release
    local os_id="${ID:-}"
    local os_like="${ID_LIKE:-}"
    local os_text=" $os_id $os_like "

    case "$os_text" in
        *debian*|*ubuntu*)
            ;;
        *)
            print_error "此脚本仅面向 Debian/Ubuntu 或 Debian 系发行版，当前 ID=${os_id:-unknown}, ID_LIKE=${os_like:-unknown}"
            exit 1
            ;;
    esac
}

check_systemd() {
    if [ ! -d /run/systemd/system ]; then
        print_error "当前环境似乎不是正在运行的 systemd 系统，无法使用 systemctl 管理 sing-box 服务"
        exit 1
    fi
}

validate_version() {
    local version="$1"
    if [[ ! "$version" =~ ^v?[0-9]+(\.[0-9]+){1,3}([._-][A-Za-z0-9]+)*$ ]]; then
        print_error "非法 sing-box 版本号: $version"
        print_error "示例: 1.13.12 或 v1.13.12"
        exit 1
    fi
}

validate_port() {
    local port="$1"
    if [[ ! "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        print_error "非法端口: $port，端口必须是 1-65535 的整数"
        exit 1
    fi
}

validate_domain() {
    local value="$1"
    local name="$2"

    if [ -z "$value" ] || [ "${#value}" -gt 253 ]; then
        print_error "$name 非法: $value"
        exit 1
    fi

    if [[ "$value" == .* || "$value" == *. || "$value" == *..* ]]; then
        print_error "$name 非法: $value"
        exit 1
    fi

    if [[ ! "$value" =~ ^[A-Za-z0-9.-]+$ ]]; then
        print_error "$name 只能包含字母、数字、点和连字符: $value"
        exit 1
    fi

    local label
    IFS='.' read -r -a labels <<< "$value"
    for label in "${labels[@]}"; do
        if [ -z "$label" ] || [ "${#label}" -gt 63 ]; then
            print_error "$name 包含非法标签: $value"
            exit 1
        fi
        if [[ ! "$label" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$ ]]; then
            print_error "$name 的标签不能以连字符开头或结尾: $value"
            exit 1
        fi
    done
}

ensure_unique_ports() {
    local seen=""
    local port
    for port in "$@"; do
        case " $seen " in
            *" $port "*)
                print_error "端口重复: $port"
                exit 1
                ;;
        esac
        seen="$seen $port"
    done
}

parse_al_ports() {
    local ports_raw="$1"
    local ports_clean="${ports_raw//[[:space:]]/}"

    if [[ "$ports_clean" =~ ^([0-9]+)-([0-9]+)$ ]]; then
        # 范围表示法: 8443-8447
        START_PORT="${BASH_REMATCH[1]}"
        END_PORT="${BASH_REMATCH[2]}"
        validate_port "$START_PORT"
        validate_port "$END_PORT"

        if [ "$END_PORT" -lt "$START_PORT" ]; then
            print_error "端口范围非法: $ports_clean"
            exit 1
        fi

        PORT_COUNT=$((END_PORT - START_PORT + 1))
        if [ "$PORT_COUNT" -ne 5 ]; then
            print_error "端口范围必须包含 5 个端口，当前为 $PORT_COUNT 个"
            exit 1
        fi

        SS_PORT="$START_PORT"
        TR_PORT=$((START_PORT + 1))
        VL_PORT=$((START_PORT + 2))
        TU_PORT=$((START_PORT + 3))
        HY_PORT=$((START_PORT + 4))
    else
        # 逗号分隔表示法: 8443,9443,10443,11443,12443
        IFS=',' read -r -a PORT_ARRAY <<< "$ports_clean"
        if [ "${#PORT_ARRAY[@]}" -ne 5 ]; then
            print_error "AL_PORTS 必须提供 5 个端口，示例: 65031,65032,65033,65034,65035 或 8443-8447"
            exit 1
        fi

        SS_PORT="${PORT_ARRAY[0]}"
        TR_PORT="${PORT_ARRAY[1]}"
        VL_PORT="${PORT_ARRAY[2]}"
        TU_PORT="${PORT_ARRAY[3]}"
        HY_PORT="${PORT_ARRAY[4]}"
    fi

    validate_port "$SS_PORT"
    validate_port "$TR_PORT"
    validate_port "$VL_PORT"
    validate_port "$TU_PORT"
    validate_port "$HY_PORT"
    validate_port "$RE_PORT"
    ensure_unique_ports "$SS_PORT" "$TR_PORT" "$VL_PORT" "$TU_PORT" "$HY_PORT" "$RE_PORT"
}

run_installer() {
    DEBIAN_FRONTEND=noninteractive bash /tmp/sing-box-official-install.sh --version "$SB_VERSION" 2>&1 | tee -a "$INSTALL_LOG"
}

rollback_config() {
    if [ -n "${BACKUP_FILE:-}" ] && [ -f "$BACKUP_FILE" ]; then
        print_warning "服务启动失败，正在回滚到旧配置: $BACKUP_FILE"
        cp -a "$BACKUP_FILE" "$CONFIG_DIR/config.json"
        if systemctl restart sing-box.service >/dev/null 2>&1; then
            print_warning "已恢复旧配置并重启 sing-box 服务"
        else
            print_warning "已恢复旧配置，但旧服务重启失败，请手动检查: journalctl -u sing-box -n 50"
        fi
    else
        print_warning "没有旧配置可回滚，正在移除本次生成的新配置"
        rm -f "$CONFIG_DIR/config.json"
        systemctl stop sing-box.service >/dev/null 2>&1 || true
    fi
}

cleanup_tmp() {
    if [ -n "${CONFIG_TMP:-}" ] && [ -f "$CONFIG_TMP" ]; then
        rm -f "$CONFIG_TMP"
    fi
}
trap cleanup_tmp EXIT

# 检查运行环境
check_root
require_command curl
require_command systemctl
require_command dpkg
require_command tee
require_command mktemp
require_command date
check_os
check_systemd

# 配置变量（支持环境变量和位置参数，优先使用环境变量）
SB_VERSION=${SB_VERSION:-${1:-1.13.12}}
AL_PORTS=${AL_PORTS:-"65031,65032,65033,65034,65035"}
RE_PORT=${RE_PORT:-443}
AL_DOMAIN=${AL_DOMAIN:-us.yyds.nyc.mn}
RE_SNI=${RE_SNI:-www.cityofrc.us}

CONFIG_DIR="/etc/sing-box"
WORK_DIR="/var/lib/sing-box"
INSTALL_LOG="/tmp/sing-box-install.log"
CHECK_LOG="/tmp/sing-box-check.log"
BACKUP_FILE=""
CONFIG_TMP=""

# 参数校验
validate_version "$SB_VERSION"
validate_domain "$AL_DOMAIN" "AL_DOMAIN"
validate_domain "$RE_SNI" "RE_SNI"
parse_al_ports "$AL_PORTS"

# 显示配置信息
print_info "=========================================="
print_info "sing-box 安装脚本"
print_info "=========================================="
print_info "sing-box 版本: $SB_VERSION"
print_info "AL 端口配置: $AL_PORTS"
print_info "端口分配: SS=$SS_PORT, Trojan=$TR_PORT, VLESS=$VL_PORT, TUIC=$TU_PORT, Hysteria2=$HY_PORT"
print_info "Reality 端口: $RE_PORT"
print_info "AL 域名: $AL_DOMAIN"
print_info "Reality SNI: $RE_SNI"
print_info "=========================================="

# 安装 sing-box
print_info "正在安装 sing-box $SB_VERSION ..."
: > "$INSTALL_LOG"

if ! curl -fsSL -o /tmp/sing-box-official-install.sh https://sing-box.app/install.sh; then
    print_error "下载安装脚本失败"
    exit 1
fi
chmod +x /tmp/sing-box-official-install.sh

if run_installer; then
    print_info "sing-box $SB_VERSION 安装成功"
else
    print_warning "官方安装脚本返回失败，尝试修复 dpkg 未完成配置..."
    if DEBIAN_FRONTEND=noninteractive dpkg --force-confnew --configure -a 2>&1 | tee -a "$INSTALL_LOG"; then
        print_info "dpkg 修复完成，正在重新尝试安装 sing-box..."
        if run_installer; then
            print_info "sing-box $SB_VERSION 重新安装成功"
        else
            print_error "sing-box 重新安装失败，日志见: $INSTALL_LOG"
            exit 1
        fi
    else
        print_error "dpkg 修复失败，日志见: $INSTALL_LOG"
        exit 1
    fi
fi

if ! command -v sing-box >/dev/null 2>&1; then
    print_error "安装后未找到 sing-box 命令，安装可能失败，日志见: $INSTALL_LOG"
    exit 1
fi

if ! systemctl cat sing-box.service >/dev/null 2>&1; then
    print_error "未找到 sing-box.service，安装可能不完整，日志见: $INSTALL_LOG"
    exit 1
fi

# 创建目录
mkdir -p "$CONFIG_DIR" "$WORK_DIR"

# 生成临时配置文件：先验证，后覆盖正式配置
print_info "正在生成临时配置文件..."
CONFIG_TMP=$(mktemp "$CONFIG_DIR/config.json.tmp.XXXXXX")
cat > "$CONFIG_TMP" << EOF
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

chmod 600 "$CONFIG_TMP"
chown root:root "$CONFIG_TMP"
print_info "临时配置文件已创建: $CONFIG_TMP"

# 验证配置
print_info "正在验证配置文件..."
if sing-box check -c "$CONFIG_TMP" > "$CHECK_LOG" 2>&1; then
    print_info "配置文件验证通过"
else
    print_error "配置文件验证失败，正式配置未被覆盖"
    print_error "校验日志见: $CHECK_LOG"
    exit 1
fi

# 备份并替换正式配置
if [ -f "$CONFIG_DIR/config.json" ]; then
    BACKUP_FILE="$CONFIG_DIR/config.json.$(date +%Y%m%d%H%M%S).bak"
    cp -a "$CONFIG_DIR/config.json" "$BACKUP_FILE"
    print_info "已备份旧配置: $BACKUP_FILE"
fi

mv "$CONFIG_TMP" "$CONFIG_DIR/config.json"
CONFIG_TMP=""
chmod 600 "$CONFIG_DIR/config.json"
chown root:root "$CONFIG_DIR/config.json"
print_info "配置文件已更新: $CONFIG_DIR/config.json"

# 启动服务：不提前停止旧服务；新配置校验通过后再重启。若失败则回滚。
print_info "正在重启 sing-box 服务..."
systemctl daemon-reload
systemctl enable sing-box.service >/dev/null 2>&1

if ! systemctl restart sing-box.service >/dev/null 2>&1; then
    print_error "服务重启失败，请检查日志: journalctl -u sing-box -n 50"
    rollback_config
    exit 1
fi

# 等待服务启动
sleep 2

# 检查服务状态
if systemctl is-active --quiet sing-box.service; then
    SERVICE_STATUS="运行中"
else
    SERVICE_STATUS="启动失败"
    print_error "服务启动失败，请检查日志: journalctl -u sing-box -n 50"
    rollback_config
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
print_info "  Shadowsocks: $SS_PORT"
print_info "  Trojan (TLS): $TR_PORT"
print_info "  VLESS (TLS): $VL_PORT"
print_info "  TUIC: $TU_PORT"
print_info "  Hysteria2: $HY_PORT"
print_info "  Reality: $RE_PORT"
echo ""
print_info "域名配置:"
print_info "  ACME 域名: $AL_DOMAIN"
print_info "  Reality SNI: $RE_SNI"
echo ""
print_info "文件位置:"
print_info "  配置文件: $CONFIG_DIR/config.json"
if [ -n "${BACKUP_FILE:-}" ]; then
    print_info "  旧配置备份: $BACKUP_FILE"
fi
print_info "  工作目录: $WORK_DIR"
print_info "  证书目录: $WORK_DIR/acme (相对路径)"
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
