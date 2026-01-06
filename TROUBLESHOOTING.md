# Headscale 连接问题排查指南

本文档提供 macOS 客户端连接 Headscale 服务器时的日志查看和问题排查方法。

## 📋 目录

- [服务器端日志查看](#服务器端日志查看)
- [客户端日志查看](#客户端日志查看)
- [常见问题排查](#常见问题排查)
- [网络诊断](#网络诊断)

## 🔍 服务器端日志查看

### 方法1：使用诊断脚本（推荐）

在服务器上执行：

```bash
cd /path/to/headscale-deploy
./diagnose.sh
```

这个脚本会自动检查：
- 容器状态
- 端口监听
- 防火墙规则
- 网络连接
- 显示最近日志

### 方法2：使用日志查看脚本

```bash
cd /path/to/headscale-deploy

# 实时查看日志
./view-logs.sh

# 查看最近100行
./view-logs.sh tail 100

# 只查看错误
./view-logs.sh error

# 查看最近5分钟的日志
./view-logs.sh since 5m

# 同时查看所有服务日志
./view-logs.sh both
```

### 方法3：直接使用 Docker 命令

```bash
# 实时查看日志（推荐）
docker logs -f headscale

# 查看最近100行
docker logs --tail=100 headscale

# 查看最近10分钟的日志
docker logs --since=10m headscale

# 查看所有日志
docker logs headscale

# 同时查看所有服务
docker compose logs -f
```

### 方法4：查看特定类型的日志

```bash
# 只查看错误
docker logs headscale 2>&1 | grep -i error

# 只查看警告
docker logs headscale 2>&1 | grep -i warn

# 查看连接请求
docker logs headscale 2>&1 | grep -i "register\|connect\|client"

# 查看认证相关
docker logs headscale 2>&1 | grep -i "auth\|bearer\|key"
```

## 💻 客户端日志查看（macOS）

### 方法1：查看 Tailscale 状态

```bash
# 查看连接状态
tailscale status

# 查看详细状态（JSON格式）
tailscale status --json

# 查看健康状态
tailscale status --json | jq '.Health'

# 查看IP地址
tailscale ip
```

### 方法2：查看 Tailscale 日志

macOS 上 Tailscale 的日志位置：

```bash
# 查看系统日志（Tailscale相关）
log show --predicate 'process == "tailscaled"' --last 10m

# 或者使用 Console.app 查看
# 打开"控制台"应用，搜索 "tailscaled"

# 查看 Tailscale 客户端日志
log show --predicate 'subsystem == "com.tailscale.ipn"' --last 10m
```

### 方法3：启用详细日志模式

```bash
# 设置环境变量启用详细日志
export TS_DEBUG_METALOGS=1
export TS_DEBUG_LOG_HTTP=1

# 然后重新连接
sudo tailscale up --reset --login-server=http://your-server-ip:9080
```

### 方法4：查看连接错误详情

```bash
# 查看详细错误信息
tailscale status --json | jq '.Health'

# 测试服务器连接
curl -v http://your-server-ip:9080

# 测试端口连通性
nc -zv your-server-ip 9080
```

## 🐛 常见问题排查

### 问题1：客户端显示 "logged out" 或连接失败

**症状：**
```
You are logged out. The last login error was: register request: Post "https://..."
```

**排查步骤：**

1. **检查服务器日志是否有连接请求**
   ```bash
   docker logs -f headscale
   # 在客户端重新连接时观察是否有新日志
   ```

2. **检查端口映射**
   ```bash
   docker ps | grep headscale
   # 确认端口映射是否正确
   ```

3. **检查防火墙**
   ```bash
   firewall-cmd --list-ports
   # 确认 9080, 41641, 3478 端口已开放
   ```

4. **测试网络连接**
   ```bash
   # 在客户端执行
   curl -v http://your-server-ip:9080
   nc -zv your-server-ip 9080
   ```

### 问题2：服务器日志没有显示连接请求

**可能原因：**
- 端口映射只监听本地（`127.0.0.1:8080`）
- 防火墙阻止了连接
- 网络路由问题

**解决方案：**

1. **检查端口映射配置**
   ```bash
   cat docker-compose.yml | grep ports
   ```
   
   如果显示 `127.0.0.1:8080:8080`，需要：
   - 使用 Nginx 代理，或
   - 修改为 `0.0.0.0:9080:8080`

2. **检查 Nginx 配置**（如果使用）
   ```bash
   systemctl status nginx
   curl -I http://your-server-ip:9080
   ```

3. **直接暴露端口**（如果不使用 Nginx）
   ```yaml
   # 修改 docker-compose.yml
   ports:
     - "0.0.0.0:9080:8080"  # 改为监听所有接口
   ```

### 问题3：客户端尝试使用 HTTPS 连接

**症状：**
```
Post "https://106.54.43.41:9080/...": dial tcp 106.54.43.41:443: connect: connection refused
```

**解决方案：**

1. **完全清理客户端状态**
   ```bash
   sudo tailscale down
   sudo rm -rf /var/lib/tailscale/*
   sudo launchctl stop com.tailscale.tailscaled
   sudo launchctl start com.tailscale.tailscaled
   ```

2. **使用 HTTP 重新连接**
   ```bash
   sudo tailscale up --reset --login-server=http://your-server-ip:9080
   ```

### 问题4：设备在服务器上不显示

**排查步骤：**

1. **检查设备列表**
   ```bash
   docker exec headscale headscale nodes list
   ```

2. **检查用户列表**
   ```bash
   docker exec headscale headscale users list
   ```

3. **检查预认证密钥**
   ```bash
   docker exec headscale headscale preauthkeys list
   ```

4. **查看注册日志**
   ```bash
   docker logs headscale | grep -i register
   ```

## 🌐 网络诊断

### 服务器端网络检查

```bash
# 检查端口监听
ss -tulpn | grep -E "8080|9080|41641|3478"

# 检查防火墙
firewall-cmd --list-all
iptables -L -n | grep -E "9080|8080"

# 测试本地连接
curl -I http://localhost:8080

# 测试外部连接（从服务器本身）
curl -I http://your-server-ip:9080
```

### 客户端网络检查

```bash
# 测试服务器连接
curl -v http://your-server-ip:9080

# 测试端口连通性
nc -zv your-server-ip 9080
nc -zuv your-server-ip 41641  # UDP端口

# 检查DNS解析
nslookup your-server-ip
ping your-server-ip
```

## 📊 实时监控

### 同时监控服务器和客户端

**服务器端：**
```bash
# 在一个终端窗口
docker logs -f headscale

# 在另一个终端窗口
watch -n 2 'docker exec headscale headscale nodes list'
```

**客户端：**
```bash
# 实时查看状态
watch -n 2 'tailscale status'

# 查看JSON状态
watch -n 2 'tailscale status --json | jq ".Health"'
```

## 🔧 快速修复命令

### 完全重置客户端连接

```bash
# macOS 客户端
sudo tailscale down
sudo rm -rf /var/lib/tailscale/*
sudo launchctl stop com.tailscale.tailscaled
sudo launchctl start com.tailscale.tailscaled
sleep 3
sudo tailscale up --reset --login-server=http://your-server-ip:9080
```

### 重启服务器服务

```bash
# 服务器端
cd /path/to/headscale-deploy
docker compose restart headscale
docker logs -f headscale
```

## 📝 日志分析技巧

### 查找关键信息

```bash
# 查找所有连接尝试
docker logs headscale | grep -E "register|connect|client"

# 查找错误
docker logs headscale | grep -i error

# 查找特定IP的连接
docker logs headscale | grep "your-client-ip"

# 查找认证相关
docker logs headscale | grep -E "auth|bearer|key|unauthorized"
```

### 保存日志到文件

```bash
# 保存最近1000行日志
docker logs --tail=1000 headscale > headscale_logs_$(date +%Y%m%d_%H%M%S).log

# 保存错误日志
docker logs headscale 2>&1 | grep -i error > errors_$(date +%Y%m%d_%H%M%S).log
```

## 🆘 获取帮助

如果以上方法都无法解决问题，请收集以下信息：

1. **服务器日志**
   ```bash
   docker logs headscale > server_logs.txt
   ```

2. **客户端状态**
   ```bash
   tailscale status --json > client_status.json
   ```

3. **网络测试结果**
   ```bash
   curl -v http://your-server-ip:9080 > network_test.txt
   ```

4. **配置信息**
   ```bash
   docker exec headscale cat /etc/headscale/config.yaml > config.yaml
   ```

