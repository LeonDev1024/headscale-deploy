#!/bin/bash

# macOS Tailscale 客户端重置脚本
# 用于完全清理客户端状态并重新连接到 Headscale 服务器
#
# 使用方法:
#   sudo bash reset-macos-client.sh [服务器地址] [预认证密钥]
#
# 示例:
#   sudo bash reset-macos-client.sh                                    # 使用默认配置
#   sudo bash reset-macos-client.sh http://106.54.43.41:9080          # 指定服务器地址
#   sudo bash reset-macos-client.sh http://106.54.43.41:9080 your-key  # 指定服务器和密钥
#
# 默认配置:
#   服务器地址: http://106.54.43.41:9080
#   预认证密钥: 56a87d31f5bd739a64eb59882a2c09626a5123e806ce7a78

set -e

echo "=========================================="
echo "macOS Tailscale 客户端重置脚本"
echo "=========================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查是否为 root 用户
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}错误: 需要 root 权限${NC}"
    echo "请使用: sudo bash $0"
    exit 1
fi

# 获取服务器地址和预认证密钥
SERVER_URL="${1:-http://106.54.43.41:9080}"
AUTH_KEY="${2:-56a87d31f5bd739a64eb59882a2c09626a5123e806ce7a78}"

echo "服务器地址: $SERVER_URL"
if [ -n "$AUTH_KEY" ]; then
    echo "使用预认证密钥: ${AUTH_KEY:0:20}..."
else
    echo "将使用交互式登录"
fi
echo ""

# 步骤1: 停止 Tailscale
echo "步骤 1: 停止 Tailscale..."
tailscale down 2>/dev/null || true
echo -e "${GREEN}✓ Tailscale 已停止${NC}"
sleep 2

# 步骤2: 停止 Tailscale 守护进程
echo ""
echo "步骤 2: 停止 Tailscale 守护进程..."
launchctl stop com.tailscale.tailscaled 2>/dev/null || true
sleep 2
echo -e "${GREEN}✓ 守护进程已停止${NC}"

# 步骤3: 清理状态文件
echo ""
echo "步骤 3: 清理状态文件..."
if [ -d "/var/lib/tailscale" ]; then
    rm -rf /var/lib/tailscale/*
    echo -e "${GREEN}✓ /var/lib/tailscale 已清理${NC}"
fi

if [ -d "/var/db/tailscale" ]; then
    rm -rf /var/db/tailscale/*
    echo -e "${GREEN}✓ /var/db/tailscale 已清理${NC}"
fi

# 步骤4: 重启守护进程
echo ""
echo "步骤 4: 重启 Tailscale 守护进程..."
launchctl start com.tailscale.tailscaled 2>/dev/null || true
sleep 5
echo -e "${GREEN}✓ 守护进程已重启${NC}"

# 步骤5: 测试服务器连接
echo ""
echo "步骤 5: 测试服务器连接..."
if curl -s -o /dev/null -w "%{http_code}" "$SERVER_URL" | grep -q "[0-9]"; then
    echo -e "${GREEN}✓ 服务器连接正常${NC}"
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$SERVER_URL")
    echo "   HTTP 状态码: $HTTP_CODE"
else
    echo -e "${RED}✗ 无法连接到服务器${NC}"
    echo "   请检查网络连接和服务器地址"
    exit 1
fi

# 步骤6: 重新连接
echo ""
echo "步骤 6: 连接到 Headscale 服务器..."
echo "----------------------------------------"

if [ -n "$AUTH_KEY" ]; then
    echo "使用预认证密钥连接..."
    tailscale up --reset \
        --login-server="$SERVER_URL" \
        --accept-routes \
        --authkey="$AUTH_KEY"
else
    echo "使用交互式登录..."
    echo ""
    echo "请按照以下提示操作："
    echo "1. 如果显示 URL，请在浏览器中打开完成认证"
    echo "2. 如果显示命令，请在服务器上执行该命令"
    echo ""
    tailscale up --reset \
        --login-server="$SERVER_URL" \
        --accept-routes
fi

sleep 3

# 步骤7: 检查连接状态
echo ""
echo "步骤 7: 检查连接状态..."
echo "----------------------------------------"
tailscale status

echo ""
echo "检查健康状态..."
HEALTH=$(tailscale status --json 2>/dev/null | grep -o '"Health":\[.*\]' || echo "")
if [ -n "$HEALTH" ]; then
    echo "$HEALTH" | python3 -m json.tool 2>/dev/null || echo "$HEALTH"
fi

echo ""
echo "=========================================="
echo "重置完成！"
echo "=========================================="
echo ""
echo "如果连接成功，你应该能看到："
echo "  - tailscale status 显示设备在线"
echo "  - tailscale ip 显示分配的IP地址"
echo ""
echo "如果仍有问题，请检查："
echo "  1. 服务器日志: docker logs -f headscale"
echo "  2. 防火墙是否开放 9080, 41641, 3478 端口"
echo "  3. Headscale 配置中的 server_url 是否正确"
echo ""

