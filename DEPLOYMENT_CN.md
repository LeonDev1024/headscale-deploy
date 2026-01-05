# Headscale 中继服务部署文档（中文版）

本文档提供在CentOS VPS云服务器上部署Headscale中继服务的完整指南，支持约200台设备的异地组网。

## 📋 目录

- [系统要求](#系统要求)
- [快速部署](#快速部署)
- [手动部署](#手动部署)
- [配置说明](#配置说明)
- [客户端连接](#客户端连接)
- [常见问题](#常见问题)

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

## 快速部署

### 一键部署脚本

```bash
# 下载项目文件到服务器
cd ~
# 将项目文件上传到服务器，或使用git克隆

# 进入项目目录
cd headscale

# 运行部署脚本（需要root权限）
sudo bash deploy.sh
```

部署脚本会自动完成：
- ✅ 安装Docker和Docker Compose
- ✅ 配置防火墙规则
- ✅ 创建必要的目录
- ✅ 检测并配置公网IP
- ✅ 启动服务

### 部署后配置

1. **生成API密钥**（用于Headscale UI）
```bash
docker exec -it headscale headscale apikeys create -e 365d
```

2. **配置API密钥**
```bash
# 编辑.env文件，添加生成的API密钥
vi .env
# 设置 HEADSCALE_API_KEY=your-generated-api-key

# 重启UI服务
docker-compose restart headscale-ui
```

3. **创建命名空间**
```bash
docker exec -it headscale headscale namespaces create robots
```

4. **生成预认证密钥**（用于机器人连接）
```bash
docker exec -it headscale headscale preauthkeys create -e 365d -n robots
```

## 手动部署

### 步骤1: 安装Docker

```bash
# 更新系统
sudo yum update -y

# 安装必要工具
sudo yum install -y yum-utils device-mapper-persistent-data lvm2

# 添加Docker仓库
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# 安装Docker
sudo yum install -y docker-ce docker-ce-cli containerd.io

# 启动Docker
sudo systemctl start docker
sudo systemctl enable docker

# 验证安装
sudo docker --version
```

### 步骤2: 安装Docker Compose

```bash
# 下载Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# 添加执行权限
sudo chmod +x /usr/local/bin/docker-compose

# 验证安装
docker-compose --version
```

### 步骤3: 配置防火墙

```bash
# 开放必要端口
sudo firewall-cmd --permanent --add-port=9080/tcp    # Headscale API
sudo firewall-cmd --permanent --add-port=9443/tcp    # Headscale UI
sudo firewall-cmd --permanent --add-port=41641/udp   # DERP端口
sudo firewall-cmd --permanent --add-port=3478/udp    # STUN端口

# 重新加载防火墙
sudo firewall-cmd --reload
```

### 步骤4: 准备项目文件

```bash
# 创建项目目录
mkdir -p ~/headscale
cd ~/headscale

# 创建必要的目录结构
mkdir -p config data

# 上传或创建以下文件：
# - docker-compose.yml
# - config/config.yaml
# - config/acl.hujson
# - env.example
```

### 步骤5: 配置环境变量

```bash
# 复制环境变量模板
cp env.example .env

# 编辑环境变量
vi .env
```

修改关键配置：
```bash
# 将your-vps-ip替换为您的VPS公网IP
HEADSCALE_SERVER_URL=http://your-vps-ip:9080
```

### 步骤6: 修改Headscale配置

```bash
# 编辑配置文件
vi config/config.yaml
```

修改 `server_url` 为您的VPS公网IP：
```yaml
server_url: http://your-vps-ip:9080
```

### 步骤7: 启动服务

```bash
# 创建数据目录并设置权限
mkdir -p data
sudo chown -R 1000:1000 data

# 启动服务
docker-compose up -d

# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs -f
```

## 配置说明

### 目录结构

```
headscale/
├── config/
│   ├── config.yaml      # Headscale主配置文件
│   └── acl.hujson       # 访问控制列表
├── data/                # 数据目录（SQLite数据库、密钥等）
│   ├── db.sqlite        # SQLite数据库（自动创建）
│   ├── private.key      # 私钥（自动生成）
│   └── noise_private.key # Noise私钥（自动生成）
├── docker-compose.yml   # Docker Compose配置
├── env.example          # 环境变量模板
├── .env                 # 环境变量配置（需创建）
└── deploy.sh            # 快速部署脚本
```

### 端口说明

| 端口 | 协议 | 说明 |
|------|------|------|
| 9080 | TCP | Headscale API端口，客户端连接使用 |
| 9443 | TCP | Headscale UI Web管理界面 |
| 41641 | UDP | DERP中继端口，用于NAT穿透 |
| 3478 | UDP | STUN端口，用于NAT检测 |

### 配置文件详解

#### config.yaml 关键配置

- **server_url**: 服务器访问地址（必须修改为公网IP）
- **db_type: sqlite3**: 使用SQLite数据库（适合200台设备）
- **ip_prefixes**: IP地址池，默认使用100.64.0.0/10
- **derp**: DERP中继服务器配置
- **acl_policy_path**: ACL策略文件路径

#### acl.hujson

访问控制列表，控制设备间的访问权限。当前配置允许所有节点互相访问。

## 客户端连接

### 创建命名空间和预认证密钥

```bash
# 进入headscale容器
docker exec -it headscale sh

# 创建命名空间
headscale namespaces create robots

# 生成预认证密钥（有效期365天）
headscale preauthkeys create -e 365d -n robots

# 复制生成的密钥，用于客户端连接
exit
```

### Linux客户端连接

```bash
# 安装Tailscale客户端
curl -fsSL https://tailscale.com/install.sh | sh

# 使用预认证密钥连接
sudo tailscale up \
  --login-server=http://your-vps-ip:9080 \
  --accept-routes \
  --authkey=your-preauth-key
```

### Windows客户端

1. 下载Tailscale客户端：https://tailscale.com/download/windows
2. 安装并运行
3. 在登录界面输入：
   - Login server: `http://your-vps-ip:9080`
   - Auth key: `your-preauth-key`

### macOS客户端

```bash
# 使用Homebrew安装
brew install tailscale

# 连接
sudo tailscale up \
  --login-server=http://your-vps-ip:9080 \
  --accept-routes \
  --authkey=your-preauth-key
```

### 管理设备

```bash
# 列出所有设备
docker exec headscale headscale nodes list

# 查看特定命名空间的设备
docker exec headscale headscale nodes list -n robots

# 删除设备
docker exec headscale headscale nodes delete -i <node-id>
```

## 服务管理

### 常用命令

```bash
# 启动服务
docker-compose up -d

# 停止服务
docker-compose down

# 重启服务
docker-compose restart

# 查看日志
docker-compose logs -f

# 查看特定服务日志
docker-compose logs -f headscale
docker-compose logs -f headscale-ui

# 更新服务
docker-compose pull
docker-compose up -d
```

### 备份和恢复

```bash
# 备份数据库
cp data/db.sqlite data/db.sqlite.backup.$(date +%Y%m%d)

# 备份整个数据目录
tar -czf headscale-backup-$(date +%Y%m%d).tar.gz data/ config/

# 恢复数据库（注意：会覆盖现有数据）
cp data/db.sqlite.backup.YYYYMMDD data/db.sqlite
docker-compose restart headscale
```

## 访问Web界面

部署完成后，访问Headscale UI：

```
http://your-vps-ip:9443
```

在UI界面中：
1. 输入Headscale服务器地址：`http://your-vps-ip:9080`
2. 输入之前生成的API密钥

## 常见问题

### Q1: 服务无法启动怎么办？

**检查步骤：**
```bash
# 1. 检查Docker服务
sudo systemctl status docker

# 2. 查看容器日志
docker-compose logs headscale

# 3. 检查端口占用
sudo netstat -tulpn | grep -E '9080|9443|41641|3478'

# 4. 检查配置文件语法
docker-compose config
```

### Q2: 客户端无法连接？

**可能原因和解决方案：**

1. **防火墙未开放端口**
   ```bash
   sudo firewall-cmd --list-ports
   # 确保9080、41641、3478端口已开放
   ```

2. **server_url配置错误**
   - 检查 `config/config.yaml` 中的 `server_url`
   - 确保使用公网IP，不是localhost

3. **网络问题**
   - 确保VPS有公网IP
   - 测试端口连通性：`telnet your-vps-ip 9080`

### Q3: 如何修改IP地址池？

编辑 `config/config.yaml`：
```yaml
ip_prefixes:
  - fd7a:115c:a1e0::/48  # IPv6地址池
  - 100.64.0.0/10        # IPv4地址池
```

### Q4: 如何限制设备访问权限？

编辑 `config/acl.hujson` 文件，配置ACL规则。例如，只允许特定组访问：
```json
{
  "acls": [
    {
      "action": "accept",
      "src": ["group:robots"],
      "dst": ["group:robots:*"]
    }
  ]
}
```

### Q5: 数据库文件在哪里？如何备份？

- 数据库文件：`data/db.sqlite`
- 备份命令：
  ```bash
  cp data/db.sqlite data/db.sqlite.backup.$(date +%Y%m%d)
  ```

### Q6: 支持多少台设备？

- 当前配置使用SQLite，适合**200台设备**左右
- 如果超过500台，建议迁移到PostgreSQL

### Q7: 如何查看设备连接状态？

```bash
# 进入容器
docker exec -it headscale sh

# 查看所有节点
headscale nodes list

# 查看节点详情
headscale nodes list -n robots

# 查看节点状态
headscale status
```

## 性能优化建议

### 针对200台设备的优化

1. **系统资源**
   - 确保VPS有2核心CPU和2GB内存
   - 监控资源使用：`htop` 或 `docker stats`

2. **数据库优化**
   - SQLite适合200台设备
   - 定期清理过期节点：`docker exec headscale headscale nodes expire`

3. **网络优化**
   - 确保VPS带宽充足（建议10Mbps以上）
   - 如果使用域名，考虑配置CDN

4. **定期维护**
   ```bash
   # 定期备份
   cp data/db.sqlite data/db.sqlite.backup.$(date +%Y%m%d)
   
   # 清理过期节点
   docker exec headscale headscale nodes expire
   
   # 更新镜像
   docker-compose pull && docker-compose up -d
   ```

## 安全建议

1. **使用HTTPS**: 如果使用域名，建议配置Nginx反向代理并启用HTTPS
2. **防火墙**: 仅开放必要端口，限制访问来源
3. **API密钥**: 妥善保管API密钥，定期轮换
4. **定期更新**: 定期更新Docker镜像和系统补丁
5. **访问控制**: 配置ACL规则，限制设备访问权限

## 技术支持

- Headscale官方文档：https://headscale.net/
- GitHub仓库：https://github.com/juanfont/headscale
- 查看日志：`docker-compose logs -f`

---

**祝部署顺利！** 🚀

