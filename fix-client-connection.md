# 修复 macOS 客户端连接问题

根据你的检测结果，客户端可以访问服务器（`curl` 成功），但 Tailscale 客户端仍然尝试使用 HTTPS 连接。

## 🔍 问题分析

从你的检测结果：
- ✅ `curl http://106.54.43.41:9080` 成功（返回 404，这是正常的）
- ✅ Nginx 正在工作并代理请求
- ❌ Tailscale 客户端尝试使用 `https://106.54.43.41:9080`（错误）
- ❌ 尝试连接 443 端口失败

## 🛠️ 解决方案

### 方法1：使用重置脚本（推荐）

我已经创建了一个重置脚本，可以完全清理客户端状态：

```bash
# 下载脚本到你的 Mac
# 然后在 Mac 上执行：

# 使用交互式登录（推荐，如果预认证密钥有问题）
sudo bash reset-macos-client.sh http://106.54.43.41:9080

# 或使用预认证密钥
sudo bash reset-macos-client.sh http://106.54.43.41:9080 your-auth-key-here
```

### 方法2：手动重置（如果脚本不可用）

```bash
# 1. 完全停止 Tailscale
sudo tailscale down
sudo launchctl stop com.tailscale.tailscaled

# 2. 清理所有状态文件
sudo rm -rf /var/lib/tailscale/*
sudo rm -rf /var/db/tailscale/*

# 3. 重启守护进程
sudo launchctl start com.tailscale.tailscaled
sleep 5

# 4. 测试服务器连接（确认使用 HTTP）
curl -v http://106.54.43.41:9080

# 5. 使用交互式登录（不使用预认证密钥）
sudo tailscale up --reset --login-server=http://106.54.43.41:9080

# 6. 查看状态
tailscale status
tailscale ip
```

### 方法3：在服务器上批准设备

如果使用交互式登录，需要在服务器上批准设备：

```bash
# 在服务器上执行

# 1. 实时查看日志，等待设备注册请求
docker logs -f headscale

# 2. 在另一个终端查看设备列表
watch -n 2 'docker exec headscale headscale nodes list'

# 3. 当看到新设备时，批准它（假设设备ID是1）
docker exec headscale headscale nodes approve -i 1
```

## 🔧 关键步骤

### 确保使用 HTTP（不是 HTTPS）

在连接时，**必须明确指定 `http://`**：

```bash
# ✅ 正确
sudo tailscale up --reset --login-server=http://106.54.43.41:9080

# ❌ 错误（不要使用 https://）
sudo tailscale up --reset --login-server=https://106.54.43.41:9080
```

### 完全清理缓存

Tailscale 客户端可能缓存了 HTTPS 配置，需要完全清理：

```bash
# 删除所有状态文件
sudo rm -rf /var/lib/tailscale/*
sudo rm -rf /var/db/tailscale/*
```

## 📊 验证步骤

### 1. 在客户端验证

```bash
# 检查连接状态
tailscale status

# 检查健康状态（应该没有错误）
tailscale status --json | jq '.Health'

# 检查IP地址
tailscale ip
```

### 2. 在服务器验证

```bash
# 查看设备列表
docker exec headscale headscale nodes list

# 应该能看到你的 Mac 设备
```

## 🐛 如果仍然失败

### 检查服务器日志

```bash
# 在服务器上实时查看日志
docker logs -f headscale

# 在客户端重新连接时，观察是否有新的日志
```

### 检查网络连接

```bash
# 在客户端测试
curl -v http://106.54.43.41:9080
nc -zv 106.54.43.41 9080
nc -zuv 106.54.43.41 41641  # UDP端口
```

### 检查防火墙

```bash
# 在服务器上检查
firewall-cmd --list-ports
# 应该包含: 9080/tcp 41641/udp 3478/udp
```

## 📝 常见问题

### Q: 为什么客户端尝试使用 HTTPS？

A: Tailscale 客户端可能：
1. 缓存了之前的配置
2. 检测到某些配置后自动使用 HTTPS
3. 需要完全清理状态文件

### Q: 如何强制使用 HTTP？

A: 
1. 完全清理客户端状态（删除 `/var/lib/tailscale/*`）
2. 明确指定 `http://` 协议
3. 使用 `--reset` 参数

### Q: 服务器日志没有显示连接请求？

A: 可能原因：
1. 客户端请求没有到达服务器（网络/防火墙问题）
2. 客户端使用了错误的协议（HTTPS vs HTTP）
3. 端口映射问题

## 🎯 快速修复命令

```bash
# 一键重置和连接（在 Mac 上执行）
sudo tailscale down && \
sudo launchctl stop com.tailscale.tailscaled && \
sudo rm -rf /var/lib/tailscale/* /var/db/tailscale/* && \
sudo launchctl start com.tailscale.tailscaled && \
sleep 5 && \
sudo tailscale up --reset --login-server=http://106.54.43.41:9080 && \
tailscale status
```

## 📞 获取帮助

如果以上方法都不行，请提供：

1. **客户端状态**
   ```bash
   tailscale status --json > client_status.json
   ```

2. **服务器日志**
   ```bash
   docker logs headscale > server_logs.txt
   ```

3. **网络测试结果**
   ```bash
   curl -v http://106.54.43.41:9080 > network_test.txt
   ```

