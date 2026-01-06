#!/bin/bash

# 检查预认证密钥是否有效的脚本
# 在服务器上运行

echo "=========================================="
echo "预认证密钥检查工具"
echo "=========================================="
echo ""

# 检查密钥
KEY="56a87d31f5bd739a64eb59882a2c09626a5123e806ce7a78"

echo "检查预认证密钥: ${KEY:0:20}..."
echo ""

# 列出所有预认证密钥
echo "=== 所有预认证密钥列表 ==="
docker exec headscale headscale preauthkeys list
echo ""

# 检查特定用户的密钥
echo "=== robots 用户的预认证密钥 ==="
docker exec headscale headscale preauthkeys list -u robots 2>/dev/null || \
docker exec headscale headscale preauthkeys list --user robots 2>/dev/null || \
echo "无法列出用户密钥，尝试其他方法..."
echo ""

# 检查用户是否存在
echo "=== 用户列表 ==="
docker exec headscale headscale users list
echo ""

# 如果密钥不存在，创建新的
echo "=== 创建新的预认证密钥 ==="
echo "如果上面的列表中没有你的密钥，将创建新的密钥..."
echo ""
read -p "是否创建新的预认证密钥? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "创建预认证密钥..."
    docker exec headscale headscale preauthkeys create -e 365d --user robots || \
    docker exec headscale headscale preauthkeys create -e 365d -u robots || \
    docker exec headscale headscale preauthkeys create -e 365d -u 1
    
    echo ""
    echo "新的预认证密钥已创建，请更新客户端脚本中的密钥"
fi

echo ""
echo "=========================================="

