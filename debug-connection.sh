#!/bin/bash

# Headscale 连接问题调试脚本
# 在服务器上运行

echo "=========================================="
echo "Headscale 连接问题调试"
echo "=========================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== 1. 检查 Headscale 服务状态 ==="
if docker ps | grep -q headscale; then
    echo -e "${GREEN}✓ Headscale 容器正在运行${NC}"
    docker ps | grep headscale
else
    echo -e "${RED}✗ Headscale 容器未运行${NC}"
    exit 1
fi
echo ""

echo "=== 2. 检查端口监听 ==="
echo "检查 8080 端口（Headscale 内部）:"
ss -tulpn | grep ":8080" || echo -e "${YELLOW}⚠ 8080 端口未监听${NC}"

echo ""
echo "检查 9080 端口（外部访问）:"
ss -tulpn | grep ":9080" || echo -e "${YELLOW}⚠ 9080 端口未监听${NC}"
echo ""

echo "=== 3. 检查防火墙 ==="
if command -v firewall-cmd &> /dev/null; then
    PORTS=$(firewall-cmd --list-ports 2>/dev/null)
    if echo "$PORTS" | grep -qE "9080|41641|3478"; then
        echo -e "${GREEN}✓ 相关端口已开放${NC}"
        echo "$PORTS" | grep -E "9080|41641|3478"
    else
        echo -e "${YELLOW}⚠ 相关端口可能未开放${NC}"
        echo "当前开放的端口: $PORTS"
    fi
else
    echo "检查 iptables..."
    iptables -L -n | grep -E "9080|41641|3478" || echo -e "${YELLOW}⚠ 未找到相关规则${NC}"
fi
echo ""

echo "=== 4. 测试本地连接 ==="
echo "测试 localhost:8080:"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 2>/dev/null || echo "000")
if [ "$HTTP_CODE" != "000" ]; then
    echo -e "${GREEN}✓ 本地连接正常 (HTTP $HTTP_CODE)${NC}"
else
    echo -e "${RED}✗ 本地连接失败${NC}"
fi

echo ""
echo "测试 localhost:9080:"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9080 2>/dev/null || echo "000")
if [ "$HTTP_CODE" != "000" ]; then
    echo -e "${GREEN}✓ Nginx 代理正常 (HTTP $HTTP_CODE)${NC}"
else
    echo -e "${RED}✗ Nginx 代理失败${NC}"
fi
echo ""

echo "=== 5. 检查 Headscale 配置 ==="
echo "server_url 配置:"
docker exec headscale cat /etc/headscale/config.yaml 2>/dev/null | grep server_url || echo "无法读取配置"
echo ""

echo "=== 6. 检查用户和密钥 ==="
echo "用户列表:"
docker exec headscale headscale users list
echo ""

echo "预认证密钥列表:"
docker exec headscale headscale preauthkeys list 2>/dev/null || echo "无法列出密钥"
echo ""

echo "=== 7. 检查设备列表 ==="
echo "已注册的设备:"
docker exec headscale headscale nodes list
echo ""

echo "=== 8. 最近的日志（最后50行）==="
echo "查找注册请求..."
docker logs headscale --tail=100 2>&1 | grep -iE "register|connect|client|machine" | tail -20 || echo "未找到相关日志"
echo ""

echo "=== 9. 错误日志 ==="
ERRORS=$(docker logs headscale 2>&1 | grep -i error | tail -10)
if [ -n "$ERRORS" ]; then
    echo -e "${RED}发现错误:${NC}"
    echo "$ERRORS"
else
    echo -e "${GREEN}未发现错误${NC}"
fi
echo ""

echo "=========================================="
echo "调试完成"
echo "=========================================="
echo ""
echo "如果设备列表为空，说明客户端请求没有到达服务器"
echo "请检查："
echo "  1. 防火墙是否开放 9080, 41641, 3478 端口"
echo "  2. Nginx 是否正常运行"
echo "  3. 客户端是否使用正确的服务器地址（http:// 不是 https://）"
echo ""

