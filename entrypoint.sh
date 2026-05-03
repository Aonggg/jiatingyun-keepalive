#!/bin/bash
set -e

CONFIG_FILE="/app/cloud_pc.json"

# 如果提供了 LOGIN 模式，进入交互式登录
if [ "$MODE" = "login" ]; then
    echo "[entrypoint] Interactive login mode"
    exec /app/cloudpc login
fi

# 如果有环境变量，生成配置文件（用于已登录过、恢复 token 的场景）
if [ -n "$CONFIG_JSON" ]; then
    echo "$CONFIG_JSON" > "$CONFIG_FILE"
    echo "[entrypoint] Config restored from CONFIG_JSON env var"
fi

# 检查配置文件是否存在
if [ ! -f "$CONFIG_FILE" ]; then
    echo "[entrypoint] No config found. Please run with MODE=login first."
    echo "[entrypoint] Or set CONFIG_JSON env var with saved config."
    exit 1
fi

echo "[entrypoint] Starting keepalive (forever mode)..."
exec /app/cloudpc keepalive --forever
