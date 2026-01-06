# Headscale 客户端连接完整指南

根据你的情况，交互式登录没有显示 URL 或命令，说明服务器可能没有收到连接请求。按照以下步骤操作：

## 🔍 当前状态分析

从你的输出可以看到：
- ✅ 服务器连接正常（HTTP 404 是正常的）
- ⚠️ 交互式登录没有显示 URL/命令
- ❌ 设备仍然 offline
- ⚠️ 警告：`--accept-routes` 参数缺失（已修复）

## 📋 完整连接步骤

### 步骤1：在服务器上检查日志

**在服务器上执行：**

```bash
# 实时查看 Headscale 日志
docker logs -f headscale
```

**保持这个终端窗口打开**，然后继续下一步。

### 步骤2：在客户端重新连接

**在 macOS 客户端执行：**

```bash
# 使用修复后的脚本（已添加 --accept-routes）
sudo bash reset-macos-client.sh http://106.54.43.41:9080
```

**或者手动执行：**

```bash
sudo tailscale down
sudo tailscale up --reset \
  --login-server=http://106.54.43.41:9080 \
  --accept-routes
```

### 步骤3：观察服务器日志

在步骤1的服务器终端窗口中，你应该能看到类似这样的日志：

```
INFO: New registration request from ...
INFO: Machine registration request received
```

**如果没有看到任何日志**，说明请求没有到达服务器，可能是：
- 防火墙问题
- 网络路由问题
- Nginx 配置问题

### 步骤4：如果服务器收到请求但没有显示 URL

如果服务器日志显示收到了请求，但没有显示 URL，可能需要：

**方法A：使用预认证密钥（推荐）**

```bash
# 在服务器上生成预认证密钥
docker exec headscale headscale preauthkeys create -e 365d --user robots

# 复制生成的密钥，然后在客户端使用
sudo tailscale up --reset \
  --login-server=http://106.54.43.41:9080 \
  --accept-routes \
  --authkey=your-generated-key-here
```

**方法B：在服务器上批准设备**

```bash
# 在服务器上查看待注册的设备
docker exec headscale headscale nodes list

# 如果看到设备（状态可能是 pending），批准它
docker exec headscale headscale nodes approve -i <设备ID>

# 或者批准所有待批准的设备
docker exec headscale headscale nodes list | grep -i pending
```

## 🛠️ 如果服务器没有收到请求

### 检查1：Nginx 配置

```bash
# 在服务器上检查 Nginx 是否正常运行
systemctl status nginx

# 检查 Nginx 日志
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log

# 测试 Nginx 代理
curl -v http://localhost:9080
curl -v http://106.54.43.41:9080
```

### 检查2：防火墙

```bash
# 检查防火墙规则
firewall-cmd --list-ports
# 应该包含: 9080/tcp 41641/udp 3478/udp

# 如果没有，添加规则
firewall-cmd --permanent --add-port=9080/tcp
firewall-cmd --permanent --add-port=41641/udp
firewall-cmd --permanent --add-port=3478/udp
firewall-cmd --reload
```

### 检查3：端口监听

```bash
# 检查端口是否在监听
ss -tulpn | grep -E "9080|8080"

# 应该看到：
# tcp  0  0  0.0.0.0:9080  ... nginx
# tcp  0  0  127.0.0.1:8080 ... docker-proxy
```

### 检查4：Headscale 配置

```bash
# 检查 server_url 配置
docker exec headscale cat /etc/headscale/config.yaml | grep server_url

# 应该显示：
# server_url: http://106.54.43.41:9080
```

## 🎯 推荐操作流程

### 方案1：使用预认证密钥（最简单）

```bash
# === 在服务器上 ===
# 1. 生成预认证密钥
docker exec headscale headscale preauthkeys create -e 365d --user robots

# 复制生成的密钥（类似：hskey-xxxxxxxxxxxxx）

# === 在客户端 ===
# 2. 使用密钥连接
sudo tailscale up --reset \
  --login-server=http://106.54.43.41:9080 \
  --accept-routes \
  --authkey=your-key-here

# 3. 检查状态
tailscale status
tailscale ip
```

### 方案2：交互式登录 + 服务器批准

```bash
# === 在服务器上（终端1）===
# 实时查看日志
docker logs -f headscale

# === 在服务器上（终端2）===
# 监控设备列表
watch -n 2 'docker exec headscale headscale nodes list'

# === 在客户端 ===
# 连接
sudo tailscale up --reset \
  --login-server=http://106.54.43.41:9080 \
  --accept-routes

# === 回到服务器 ===
# 当看到新设备时，批准它
docker exec headscale headscale nodes approve -i <设备ID>
```

## 🔧 调试命令

### 客户端调试

```bash
# 查看详细状态
tailscale status --json | jq '.'

# 查看健康状态
tailscale status --json | jq '.Health'

# 测试服务器连接
curl -v http://106.54.43.41:9080
curl -v http://106.54.43.41:9080/machine/register

# 测试 UDP 端口
nc -zuv 106.54.43.41 41641
nc -zuv 106.54.43.41 3478
```

### 服务器调试

```bash
# 查看所有日志
docker logs headscale

# 查看错误日志
docker logs headscale 2>&1 | grep -i error

# 查看注册请求
docker logs headscale 2>&1 | grep -i register

# 查看设备列表
docker exec headscale headscale nodes list

# 查看用户列表
docker exec headscale headscale users list
```

## 📝 常见问题

### Q: 为什么交互式登录没有显示 URL？

A: 可能原因：
1. 服务器没有收到连接请求（检查服务器日志）
2. Headscale 配置问题（检查 server_url）
3. Nginx 代理问题（检查 Nginx 日志）

### Q: 如何知道服务器是否收到了请求？

A: 在服务器上运行 `docker logs -f headscale`，当客户端连接时应该能看到新的日志条目。

### Q: 预认证密钥创建失败怎么办？

A: 检查用户是否存在：
```bash
docker exec headscale headscale users list
docker exec headscale headscale preauthkeys create --help
```

## ✅ 成功连接的标志

连接成功后，你应该看到：

**客户端：**
```bash
$ tailscale status
100.116.239.71  liuyichunmacbook-air  ...  macOS    active  # 显示 active

$ tailscale ip
100.116.239.71  # 显示分配的IP
```

**服务器：**
```bash
$ docker exec headscale headscale nodes list
ID | Hostname            | ... | Connected
1  | liuyichunmacbook-air | ... | true     # 显示 Connected: true
```

## 🆘 如果仍然失败

请收集以下信息：

1. **服务器日志**
   ```bash
   docker logs headscale > server_logs.txt
   ```

2. **客户端状态**
   ```bash
   tailscale status --json > client_status.json
   ```

3. **网络测试**
   ```bash
   curl -v http://106.54.43.41:9080 > network_test.txt
   ```

4. **Nginx 日志**（如果使用）
   ```bash
   tail -100 /var/log/nginx/error.log > nginx_error.log
   ```

