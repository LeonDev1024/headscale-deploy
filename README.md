# Headscale 中继服务部署文档

本文档介绍如何在CentOS VPS云服务器上部署Headscale中继服务，用于异地组网，支持约200台设备。

## 目录

- [系统要求](#系统要求)
- [前置准备](#前置准备)
- [安装步骤](#安装步骤)
- [配置说明](#配置说明)
- [服务管理](#服务管理)
- [客户端连接](#客户端连接)
- [故障排查](#故障排查)
- [性能优化](#性能优化)

## 系统要求

### 硬件要求
- **CPU**: 2核心或以上（推荐4核心）
- **内存**: 2GB或以上（推荐4GB）
- **磁盘**: 10GB或以上可用空间
- **网络**: 具有公网IP的VPS服务器

### 软件要求
- **操作系统**: CentOS 7/8 或 Rocky Linux 8/9
- **Docker**: 20.10或更高版本
- **Docker Compose**: 1.29或更高版本

## 前置准备

### 1. 更新系统

```bash
# CentOS 7
sudo yum update -y

# CentOS 8 / Rocky Linux
sudo dnf update -y
```

### 2. 安装Docker

```bash
# 安装必要的工具
sudo yum install -y yum-utils device-mapper-persistent-data lvm2

# 添加Docker仓库
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# 安装Docker
sudo yum install -y docker-ce docker-ce-cli containerd.io

# 启动Docker服务
sudo systemctl start docker
sudo systemctl enable docker

# 验证Docker安装
sudo docker --version
```

### 3. 安装Docker Compose

```bash
# 下载Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# 添加执行权限
sudo chmod +x /usr/local/bin/docker-compose

# 验证安装
docker-compose --version
```

### 4. 配置防火墙

```bash
# 开放必要端口
sudo firewall-cmd --permanent --add-port=9080/tcp    # Headscale API
sudo firewall-cmd --permanent --add-port=9443/tcp   # Headscale UI
sudo firewall-cmd --permanent --add-port=41641/udp   # DERP端口
sudo firewall-cmd --permanent --add-port=3478/udp    # STUN端口

# 如果使用iptables
# sudo iptables -A INPUT -p tcp --dport 9080 -j ACCEPT
# sudo iptables -A INPUT -p tcp --dport 9443 -j ACCEPT
# sudo iptables -A INPUT -p udp --dport 41641 -j ACCEPT
# sudo iptables -A INPUT -p udp --dport 3478 -j ACCEPT

# 重新加载防火墙规则
sudo firewall-cmd --reload
```

## 安装步骤

### 1. 克隆或下载项目文件

```bash
# 创建项目目录
mkdir -p ~/headscale
cd ~/headscale

# 如果使用git
# git clone <your-repo-url> .

# 或者手动创建以下目录结构：
# headscale/
# ├── config/
# │   ├── config.yaml
# │   └── acl.hujson
# ├── docker-compose.yml
# └── env.example
```

### 2. 配置环境变量

```bash
# 复制环境变量模板
cp env.example .env

# 编辑环境变量文件
vi .env
```

修改以下关键配置：

```bash
# 将your-vps-ip替换为您的VPS公网IP地址
HEADSCALE_SERVER_URL=http://your-vps-ip:9080

# 如果使用域名，可以设置为：
# HEADSCALE_SERVER_URL=https://headscale.yourdomain.com
```

### 3. 修改Headscale配置文件

编辑 `config/config.yaml`：

```bash
vi config/config.yaml
```

**重要配置项：

1. **server_url**: 修改为您的VPS公网IP或域名
   ```yaml
   server_url: http://your-vps-ip:9080
   ```

2. **base_domain**: 如果使用MagicDNS，修改为您的域名
   ```yaml
   base_domain: yourdomain.com
   ```

### 4. 创建数据目录

```bash
# 创建数据目录
mkdir -p data

# 设置权限（确保Docker可以访问）
sudo chown -R 1000:1000 data
```

### 5. 启动服务

```bash
# 使用docker-compose启动服务
docker-compose up -d

# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs -f
```

### 6. 生成API密钥（用于Headscale UI）

```bash
# 进入headscale容器
docker exec -it headscale sh

# 生成API密钥
headscale apikeys create -e 365d

# 复制生成的API密钥，退出容器
exit

# 将API密钥添加到.env文件
vi .env
# 设置 HEADSCALE_API_KEY=your-generated-api-key

# 重启headscale-ui服务
docker-compose restart headscale-ui
```

## 配置说明

### 目录结构

```
headscale/
├── config/
│   ├── config.yaml      # Headscale主配置文件
│   └── acl.hujson       # 访问控制列表配置
├── data/                # 数据目录（SQLite数据库、密钥等）
│   ├── db.sqlite        # SQLite数据库（自动创建）
│   ├── private.key      # 私钥（自动生成）
│   └── noise_private.key # Noise私钥（自动生成）
├── docker-compose.yml   # Docker Compose配置
├── env.example          # 环境变量模板
└── .env                 # 环境变量配置（需创建）
```

### 端口说明

- **9080**: Headscale API端口，用于客户端连接和管理
- **9443**: Headscale UI Web界面端口
- **41641/udp**: DERP中继端口，用于NAT穿透
- **3478/udp**: STUN端口，用于NAT检测

### 配置文件说明

#### config.yaml

- `server_url`: 服务器访问地址（必须修改为公网IP或域名）
- `db_type: sqlite3`: 使用SQLite数据库（适合200台设备）
- `ip_prefixes`: IP地址池配置
- `derp`: DERP中继服务器配置
- `acl_policy_path`: ACL策略文件路径

#### acl.hujson

访问控制列表，控制设备间的访问权限。当前配置允许所有节点互相访问。

## 服务管理

### 启动服务

```bash
docker-compose up -d
```

### 停止服务

```bash
docker-compose down
```

### 重启服务

```bash
docker-compose restart
```

### 查看日志

```bash
# 查看所有服务日志
docker-compose logs -f

# 查看特定服务日志
docker-compose logs -f headscale
docker-compose logs -f headscale-ui
```

### 更新服务

```bash
# 拉取最新镜像
docker-compose pull

# 重启服务
docker-compose up -d
```

## 客户端连接

### 1. 创建命名空间（Namespace）

```bash
# 进入headscale容器
docker exec -it headscale sh

# 创建命名空间（例如：robots）
headscale namespaces create robots

# 列出所有命名空间
headscale namespaces list

# 退出容器
exit
```

### 2. 生成预认证密钥（推荐用于机器人）

```bash
# 进入headscale容器
docker exec -it headscale sh

# 生成预认证密钥（有效期365天）
headscale preauthkeys create -e 365d -n robots

# 复制生成的密钥，用于客户端连接
exit
```

### 3. 客户端连接示例

#### Linux客户端

```bash
# 安装Tailscale客户端
curl -fsSL https://tailscale.com/install.sh | sh

# 使用预认证密钥连接
sudo tailscale up --login-server=http://your-vps-ip:9080 --accept-routes --authkey=your-preauth-key
```

#### Windows客户端

1. 下载Tailscale客户端：https://tailscale.com/download/windows
2. 安装并运行
3. 在登录界面输入：
   - Login server: `http://your-vps-ip:9080`
   - Auth key: `your-preauth-key`

#### macOS客户端

```bash
# 使用Homebrew安装
brew install tailscale

# 连接
sudo tailscale up --login-server=http://your-vps-ip:9080 --accept-routes --authkey=your-preauth-key
```

### 4. 管理设备

```bash
# 进入headscale容器
docker exec -it headscale sh

# 列出所有设备
headscale nodes list

# 查看设备详情
headscale nodes list -n robots

# 删除设备
headscale nodes delete -i <node-id>

# 退出容器
exit
```

## 故障排查

### 1. 服务无法启动

```bash
# 检查Docker服务状态
sudo systemctl status docker

# 检查容器日志
docker-compose logs headscale

# 检查端口占用
sudo netstat -tulpn | grep -E '9080|9443|41641|3478'
```

### 2. 客户端无法连接

- **检查防火墙**: 确保端口9080、41641、3478已开放
- **检查server_url**: 确保config.yaml中的server_url配置正确
- **检查网络**: 确保VPS有公网IP且可访问

### 3. 数据库问题

```bash
# 检查数据库文件
ls -lh data/db.sqlite

# 如果数据库损坏，可以备份后重新初始化
# 注意：这会删除所有数据！
docker-compose down
rm data/db.sqlite
docker-compose up -d
```

### 4. 查看服务健康状态

```bash
# 检查容器状态
docker-compose ps

# 检查headscale服务状态
docker exec headscale headscale status
```

## 性能优化

### 针对200台设备的优化建议

1. **数据库优化**
   - 当前使用SQLite，适合200台设备
   - 如果超过500台，建议迁移到PostgreSQL

2. **系统资源**
   - 确保VPS有足够的CPU和内存
   - 监控系统资源使用情况

3. **网络优化**
   - 确保VPS带宽充足
   - 考虑使用CDN加速（如果使用域名）

4. **定期维护**

```bash
# 定期清理过期节点
docker exec headscale headscale nodes expire

# 备份数据库
cp data/db.sqlite data/db.sqlite.backup.$(date +%Y%m%d)
```

## 访问Web界面

部署完成后，可以通过以下地址访问Headscale UI：

```
http://your-vps-ip:9443
```

在UI界面中，您需要：
1. 输入Headscale服务器地址：`http://your-vps-ip:9080`
2. 输入之前生成的API密钥

## 安全建议

1. **使用HTTPS**: 如果使用域名，建议配置Nginx反向代理并启用HTTPS
2. **防火墙规则**: 仅开放必要端口
3. **API密钥安全**: 妥善保管API密钥，不要泄露
4. **定期更新**: 定期更新Docker镜像和系统

## 常见问题

### Q: 如何修改IP地址池？

A: 编辑 `config/config.yaml` 中的 `ip_prefixes` 配置项。

### Q: 如何添加更多DERP服务器？

A: 编辑 `config/config.yaml` 中的 `derp.urls` 配置项。

### Q: 如何限制设备访问权限？

A: 编辑 `config/acl.hujson` 文件，配置ACL规则。

### Q: 数据库文件在哪里？

A: 数据库文件位于 `data/db.sqlite`，建议定期备份。

## 技术支持

如遇到问题，可以：
1. 查看Headscale官方文档：https://headscale.net/
2. 查看GitHub Issues：https://github.com/juanfont/headscale
3. 检查日志文件：`docker-compose logs`

## 许可证

本项目遵循Headscale的许可证。

