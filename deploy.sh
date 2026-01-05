#!/bin/bash

# Headscale 快速部署脚本
# 适用于 CentOS VPS 服务器

set -e

echo "=========================================="
echo "Headscale 中继服务部署脚本"
echo "=========================================="

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
    echo "请使用root权限运行此脚本"
    echo "使用: sudo bash deploy.sh"
    exit 1
fi

# 检查Docker是否安装
if ! command -v docker &> /dev/null; then
    echo "检测到Docker未安装，开始安装Docker..."
    
    # 安装Docker
    yum install -y yum-utils device-mapper-persistent-data lvm2
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    yum install -y docker-ce docker-ce-cli containerd.io
    
    # 启动Docker
    systemctl start docker
    systemctl enable docker
    
    echo "Docker安装完成"
else
    echo "Docker已安装: $(docker --version)"
fi

# 检查Docker Compose是否安装
if ! command -v docker-compose &> /dev/null; then
    echo "检测到Docker Compose未安装，开始安装..."
    
    # 安装Docker Compose
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    echo "Docker Compose安装完成: $(docker-compose --version)"
else
    echo "Docker Compose已安装: $(docker-compose --version)"
fi

# 配置防火墙
echo "配置防火墙规则..."
if command -v firewall-cmd &> /dev/null; then
    # 检查FirewallD服务是否运行
    if systemctl is-active --quiet firewalld 2>/dev/null; then
        echo "FirewallD服务正在运行，配置防火墙规则..."
        firewall-cmd --permanent --add-port=9080/tcp
        firewall-cmd --permanent --add-port=9443/tcp
        firewall-cmd --permanent --add-port=41641/udp
        firewall-cmd --permanent --add-port=3478/udp
        firewall-cmd --reload
        echo "防火墙规则已配置（firewalld）"
    elif systemctl is-enabled firewalld &>/dev/null; then
        # 服务已安装但未运行，尝试启动
        echo "FirewallD服务未运行，尝试启动..."
        if systemctl start firewalld 2>/dev/null; then
            sleep 2
            firewall-cmd --permanent --add-port=9080/tcp
            firewall-cmd --permanent --add-port=9443/tcp
            firewall-cmd --permanent --add-port=41641/udp
            firewall-cmd --permanent --add-port=3478/udp
            firewall-cmd --reload
            echo "防火墙规则已配置（firewalld）"
        else
            echo "警告: 无法启动FirewallD服务，跳过防火墙配置"
            echo "请手动配置防火墙规则，需要开放的端口: 9080/tcp, 9443/tcp, 41641/udp, 3478/udp"
        fi
    else
        echo "警告: FirewallD服务未安装或未启用，跳过防火墙配置"
        echo "请手动配置防火墙规则，需要开放的端口: 9080/tcp, 9443/tcp, 41641/udp, 3478/udp"
    fi
else
    echo "警告: 未检测到firewalld，请手动配置防火墙规则"
    echo "需要开放的端口: 9080/tcp, 9443/tcp, 41641/udp, 3478/udp"
fi

# 创建数据目录
echo "创建数据目录..."
mkdir -p data
chown -R 1000:1000 data 2>/dev/null || true

# 检查环境变量文件
if [ ! -f .env ]; then
    echo "创建.env文件..."
    if [ -f env.example ]; then
        cp env.example .env
        echo "已从env.example创建.env文件，请编辑.env文件设置您的配置"
    else
        echo "警告: env.example文件不存在"
    fi
else
    echo ".env文件已存在"
fi

# 获取VPS公网IP（如果未设置）
if ! grep -q "HEADSCALE_SERVER_URL=http" .env 2>/dev/null || grep -q "your-vps-ip" .env 2>/dev/null; then
    echo "检测VPS公网IP..."
    PUBLIC_IP=$(curl -s ifconfig.me || curl -s ip.sb || echo "unknown")
    if [ "$PUBLIC_IP" != "unknown" ]; then
        echo "检测到公网IP: $PUBLIC_IP"
        read -p "是否使用此IP作为HEADSCALE_SERVER_URL? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sed -i "s|HEADSCALE_SERVER_URL=.*|HEADSCALE_SERVER_URL=http://$PUBLIC_IP:9080|g" .env
            sed -i "s|server_url:.*|server_url: http://$PUBLIC_IP:9080|g" config/config.yaml
            echo "已更新配置为使用IP: $PUBLIC_IP"
        fi
    fi
fi

# 启动服务
echo "启动Headscale服务..."
docker-compose down 2>/dev/null || true
docker-compose pull
docker-compose up -d

# 等待服务启动
echo "等待服务启动..."
sleep 10

# 检查服务状态
echo "检查服务状态..."
docker-compose ps

# 生成API密钥提示
echo ""
echo "=========================================="
echo "部署完成！"
echo "=========================================="
echo ""
echo "下一步操作："
echo "1. 生成API密钥（用于Headscale UI）："
echo "   docker exec -it headscale headscale apikeys create -e 365d"
echo ""
echo "2. 将生成的API密钥添加到.env文件中的HEADSCALE_API_KEY"
echo ""
echo "3. 创建命名空间："
echo "   docker exec -it headscale headscale namespaces create robots"
echo ""
echo "4. 生成预认证密钥（用于客户端连接）："
echo "   docker exec -it headscale headscale preauthkeys create -e 365d -n robots"
echo ""
echo "5. 访问Web界面："
echo "   http://$(grep HEADSCALE_SERVER_URL .env | cut -d'/' -f3 | cut -d':' -f1):9443"
echo ""
echo "查看日志："
echo "   docker-compose logs -f"
echo ""
echo "详细文档请查看 README.md"
echo "=========================================="

