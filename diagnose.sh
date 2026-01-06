#!/bin/bash

# Headscale 连接诊断脚本
# 用于诊断 macOS 客户端连接问题

echo "=========================================="
echo "Headscale 连接诊断工具"
echo "=========================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== 1. 检查 Headscale 容器状态 ==="
if docker ps | grep -q headscale; then
    echo -e "${GREEN}✓ Headscale 容器正在运行${NC}"
    docker ps | grep headscale
else
    echo -e "${RED}✗ Headscale 容器未运行${NC}"
fi
echo ""

echo "=== 2. 检查端口监听情况 ==="
echo "检查 8080 端口（Headscale 内部端口）:"
if ss -tulpn 2>/dev/null | grep -q ":8080"; then
    echo -e "${GREEN}✓ 8080 端口正在监听${NC}"
    ss -tulpn | grep ":8080"
else
    echo -e "${YELLOW}⚠ 8080 端口未监听（可能只监听本地）${NC}"
fi

echo ""
echo "检查 9080 端口（外部访问端口）:"
if ss -tulpn 2>/dev/null | grep -q ":9080"; then
    echo -e "${GREEN}✓ 9080 端口正在监听${NC}"
    ss -tulpn | grep ":9080"
else
    echo -e "${YELLOW}⚠ 9080 端口未监听${NC}"
    echo "提示: 如果使用 Nginx 代理，请检查 Nginx 状态"
fi
echo ""

echo "=== 3. 检查防火墙规则 ==="
if command -v firewall-cmd &> /dev/null; then
    if systemctl is-active --quiet firewalld 2>/dev/null; then
        echo "FirewallD 状态:"
        firewall-cmd --list-ports | grep -E "9080|8080|41641|3478" && echo -e "${GREEN}✓ 相关端口已开放${NC}" || echo -e "${YELLOW}⚠ 相关端口可能未开放${NC}"
    else
        echo -e "${YELLOW}⚠ FirewallD 未运行${NC}"
    fi
else
    echo "检查 iptables:"
    iptables -L -n | grep -E "9080|8080|41641|3478" || echo -e "${YELLOW}⚠ 未找到相关规则${NC}"
fi
echo ""

echo "=== 4. 测试本地连接 ==="
echo "测试 localhost:8080:"
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 2>/dev/null | grep -q "[0-9]"; then
    echo -e "${GREEN}✓ 本地连接正常${NC}"
    curl -I http://localhost:8080 2>&1 | head -3
else
    echo -e "${RED}✗ 本地连接失败${NC}"
fi
echo ""

echo "测试容器内部连接:"
if docker exec headscale curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 2>/dev/null | grep -q "[0-9]"; then
    echo -e "${GREEN}✓ 容器内部连接正常${NC}"
else
    echo -e "${RED}✗ 容器内部连接失败${NC}"
fi
echo ""

echo "=== 5. 检查 Docker 端口映射 ==="
docker ps --format "table {{.Names}}\t{{.Ports}}" | grep headscale
echo ""

echo "=== 6. Headscale 配置检查 ==="
echo "server_url 配置:"
docker exec headscale cat /etc/headscale/config.yaml 2>/dev/null | grep server_url || echo "无法读取配置"
echo ""

echo "=== 7. Headscale 日志（最近50行）==="
echo "按 Ctrl+C 停止查看日志"
echo "----------------------------------------"
docker logs headscale --tail=50 2>&1
echo ""

echo "=== 8. 实时监控日志（30秒）==="
echo "将在30秒后自动停止，或按 Ctrl+C 提前停止"
echo "----------------------------------------"
timeout 30 docker logs -f headscale 2>&1 || docker logs --tail=10 headscale 2>&1
echo ""

echo "=========================================="
echo "诊断完成"
echo "=========================================="
echo ""
echo "常用日志查看命令:"
echo "  实时查看: docker logs -f headscale"
echo "  最近100行: docker logs --tail=100 headscale"
echo "  查看错误: docker logs headscale 2>&1 | grep -i error"
echo "  查看警告: docker logs headscale 2>&1 | grep -i warn"
echo ""

