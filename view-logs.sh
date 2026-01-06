#!/bin/bash

# Headscale 日志查看脚本
# 提供多种日志查看方式

case "$1" in
    "real-time"|"rt"|"")
        echo "实时查看 Headscale 日志（按 Ctrl+C 停止）..."
        docker logs -f headscale
        ;;
    "tail"|"t")
        LINES=${2:-100}
        echo "查看最近 $LINES 行日志..."
        docker logs --tail=$LINES headscale
        ;;
    "error"|"e")
        echo "查看错误日志..."
        docker logs headscale 2>&1 | grep -i error
        ;;
    "warn"|"w")
        echo "查看警告日志..."
        docker logs headscale 2>&1 | grep -i warn
        ;;
    "all"|"a")
        echo "查看所有日志..."
        docker logs headscale
        ;;
    "ui")
        echo "查看 Headscale UI 日志..."
        docker logs -f headscale-ui
        ;;
    "both"|"b")
        echo "同时查看 Headscale 和 UI 日志..."
        docker compose logs -f
        ;;
    "since"|"s")
        TIME=${2:-"10m"}
        echo "查看最近 $TIME 的日志..."
        docker logs --since=$TIME headscale
        ;;
    *)
        echo "用法: $0 [选项]"
        echo ""
        echo "选项:"
        echo "  (无参数) 或 real-time/rt  - 实时查看日志"
        echo "  tail/t [行数]             - 查看最近N行日志（默认100行）"
        echo "  error/e                   - 只查看错误日志"
        echo "  warn/w                    - 只查看警告日志"
        echo "  all/a                     - 查看所有日志"
        echo "  ui                        - 查看 UI 日志"
        echo "  both/b                    - 同时查看所有服务日志"
        echo "  since/s [时间]            - 查看最近指定时间的日志（如: 10m, 1h）"
        echo ""
        echo "示例:"
        echo "  $0                        # 实时查看"
        echo "  $0 tail 50                # 查看最近50行"
        echo "  $0 error                 # 查看错误"
        echo "  $0 since 5m              # 查看最近5分钟"
        ;;
esac

