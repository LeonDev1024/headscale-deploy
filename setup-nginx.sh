#!/bin/bash

# Nginx 配置脚本
# 用于解决 Headscale UI 的 CORS 问题

set -e

echo "=========================================="
echo "Nginx 配置脚本"
echo "=========================================="

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
    echo "请使用root权限运行此脚本"
    echo "使用: sudo bash setup-nginx.sh"
    exit 1
fi

# 检查 Nginx 是否已安装
if ! command -v nginx &> /dev/null; then
    echo "错误: Nginx 未安装，请先安装 Nginx"
    exit 1
fi

echo "检测到 Nginx: $(nginx -v 2>&1)"

# 备份原有配置
if [ -f /etc/nginx/conf.d/headscale.conf ]; then
    cp /etc/nginx/conf.d/headscale.conf /etc/nginx/conf.d/headscale.conf.backup.$(date +%Y%m%d_%H%M%S)
    echo "已备份原有配置文件"
fi

# 复制配置文件
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/nginx-headscale.conf" ]; then
    cp "$SCRIPT_DIR/nginx-headscale.conf" /etc/nginx/conf.d/headscale.conf
    echo "已复制 Nginx 配置文件"
else
    echo "错误: 找不到 nginx-headscale.conf 文件"
    exit 1
fi

# 测试 Nginx 配置
echo "测试 Nginx 配置..."
if nginx -t; then
    echo "Nginx 配置测试通过"
else
    echo "错误: Nginx 配置测试失败"
    exit 1
fi

# 检查并启动/重新加载 Nginx
echo "检查 Nginx 服务状态..."
if systemctl is-active --quiet nginx; then
    echo "Nginx 正在运行，重新加载配置..."
    systemctl reload nginx
else
    echo "Nginx 未运行，启动服务..."
    systemctl start nginx
    systemctl enable nginx
fi

# 验证 Nginx 是否在监听 9080 端口
sleep 2
if ss -tuln | grep -q ":9080 "; then
    echo "✓ Nginx 已成功监听 9080 端口"
else
    echo "⚠ 警告: Nginx 可能未正确监听 9080 端口，请检查配置"
    echo "运行以下命令检查: ss -tuln | grep 9080"
fi

echo ""
echo "=========================================="
echo "Nginx 配置完成！"
echo "=========================================="
echo ""
echo "Nginx 已配置为反向代理 Headscale API，并添加了 CORS 支持"
echo ""
echo "配置详情："
echo "  - 监听端口: 9080"
echo "  - 后端服务: http://127.0.0.1:8080"
echo "  - 允许的源: http://106.54.43.41:9443"
echo ""
echo "请确保："
echo "  1. Headscale 容器正在运行（端口 8080）"
echo "  2. 防火墙已开放 9080 端口"
echo "  3. 在 Headscale UI 中使用 http://106.54.43.41:9080 作为服务器地址"
echo ""
echo "查看 Nginx 状态: systemctl status nginx"
echo "查看 Nginx 日志: tail -f /var/log/nginx/error.log"
echo "=========================================="

