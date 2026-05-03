#!/bin/bash
set -e

CONFIG_FILE="/app/cloud_pc.json"

# 如果有环境变量 CONFIG_JSON，直接恢复配置
if [ -n "$CONFIG_JSON" ]; then
    echo "$CONFIG_JSON" > "$CONFIG_FILE"
    echo "[entrypoint] Config restored from CONFIG_JSON env var"
fi

# 如果配置文件不存在，且提供了 PHONE + PASSWORD，自动密码登录
if [ ! -f "$CONFIG_FILE" ] && [ -n "$PHONE" ] && [ -n "$PASSWORD" ]; then
    echo "[entrypoint] Auto login with password mode..."
    # y=确认免责声明, 2=密码登录, 然后输入手机号、用户名、密码
    # 如果有多台云电脑，默认选第 CONNECT_INDEX 台（默认0）
    printf "y\n2\n${PHONE}\n${USERNAME}\n${PASSWORD}\n${CONNECT_INDEX:-0}\n" | /app/cloudpc login || true
    sleep 2
fi

# 如果提供了 LOGIN 模式，进入交互式登录
if [ "$MODE" = "login" ]; then
    echo "[entrypoint] Interactive login mode"
    exec /app/cloudpc login
fi

# 检查配置文件是否存在
if [ ! -f "$CONFIG_FILE" ]; then
    echo "[entrypoint] Login failed or no config found."
    echo "[entrypoint] Set MODE=login for interactive login via shell."
    sleep 3600
    exit 1
fi

echo "[entrypoint] Config found, starting keepalive (forever mode)..."
echo "[entrypoint] $(cat $CONFIG_FILE)"
exec /app/cloudpc keepalive --forever
