#!/bin/bash
set -e

CONFIG_FILE="/app/cloud_pc.json"

# 如果有环境变量 CONFIG_JSON，直接恢复配置
if [ -n "$CONFIG_JSON" ]; then
    echo "$CONFIG_JSON" > "$CONFIG_FILE"
    echo "[entrypoint] Config restored from CONFIG_JSON env var"
fi

# 自动密码登录函数
auto_login() {
    if [ -n "$USERNAME" ] && [ -n "$PASSWORD" ]; then
        echo "[entrypoint] Auto login with password mode..."
        printf "y\n2\n${USERNAME}\n${PASSWORD}\n${CONNECT_INDEX:-0}\n" | /app/cloudpc login || true
        sleep 3
    fi
}

# 如果配置文件不存在，尝试自动登录
if [ ! -f "$CONFIG_FILE" ]; then
    auto_login
fi

# 如果提供了 LOGIN 模式，进入交互式登录
if [ "$MODE" = "login" ]; then
    echo "[entrypoint] Interactive login mode"
    exec /app/cloudpc login
fi

# 检查配置文件是否存在
if [ ! -f "$CONFIG_FILE" ]; then
    echo "[entrypoint] Login failed or no config found."
    sleep 3600
    exit 1
fi

# 带重试的保活循环：失败时重新登录再试
MAX_RETRIES=3
for i in $(seq 1 $MAX_RETRIES); do
    echo "[entrypoint] Attempt $i/$MAX_RETRIES - starting keepalive..."

    # 先重新登录刷新 token
    if [ $i -gt 1 ]; then
        echo "[entrypoint] Re-login to refresh token..."
        auto_login
        sleep 3
    fi

    /app/cloudpc keepalive --forever && break

    echo "[entrypoint] Keepalive exited, retrying in 10s..."
    sleep 10
done

echo "[entrypoint] All retries exhausted."
sleep 60
