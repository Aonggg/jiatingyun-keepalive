FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:99
ENV LANG=zh_CN.UTF-8
ENV LC_ALL=zh_CN.UTF-8
ENV TZ=Asia/Shanghai

# 1. 配置镜像源 + 安装基础依赖（去掉 VNC/noVNC/Openbox）
RUN echo "deb http://mirrors.ustc.edu.cn/ubuntu/ focal main restricted universe multiverse" > /etc/apt/sources.list && \
    echo "deb http://mirrors.ustc.edu.cn/ubuntu/ focal-security main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb http://mirrors.ustc.edu.cn/ubuntu/ focal-updates main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb http://mirrors.ustc.edu.cn/ubuntu/ focal-backports main restricted universe multiverse" >> /etc/apt/sources.list && \
    apt-get update && apt-get install -y ca-certificates && \
    echo "deb https://mirrors.ustc.edu.cn/ubuntu/ focal main restricted universe multiverse" > /etc/apt/sources.list && \
    echo "deb https://mirrors.ustc.edu.cn/ubuntu/ focal-security main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb https://mirrors.ustc.edu.cn/ubuntu/ focal-updates main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb https://mirrors.ustc.edu.cn/ubuntu/ focal-backports main restricted universe multiverse" >> /etc/apt/sources.list

RUN apt-get update && apt-get install -y --no-install-recommends \
    xvfb \
    supervisor \
    python3 \
    python3-pip \
    curl \
    locales \
    libgtk-3-0 \
    libglib2.0-0 \
    libnss3 \
    libx11-6 \
    libxcomposite1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxrandr2 \
    libxrender1 \
    libxtst6 \
    libpango-1.0-0 \
    libcairo2 \
    libasound2 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdbus-1-3 \
    libdrm2 \
    libgbm1 \
    libpulse0 \
    fonts-wqy-zenhei \
    gcc \
    libc6-dev \
    && rm -rf /var/lib/apt/lists/*

# 2. 设置中文 locale
RUN locale-gen zh_CN.UTF-8

# 3. 安装 Python 依赖
RUN pip3 install --no-cache-dir websocket-client==1.8.0

# 4. 创建工作目录
RUN mkdir -p /app/automation /app/scripts /app/config /app/libs /pkg /var/log

# 5. 编译 stealth 注入库
COPY src/stealth_injector.c /tmp/stealth_injector.c
RUN gcc -fPIC -shared -fno-stack-protector -s -o /usr/local/lib/libudev-shim.so /tmp/stealth_injector.c -ldl && \
    rm /tmp/stealth_injector.c && \
    apt-get purge -y gcc libc6-dev && apt-get autoremove -y

# 6. 复制保活脚本
COPY automation/ /app/automation/
COPY scripts/ /app/scripts/
COPY config/ /app/config/

# 7. 创建精简版 supervisord 配置
RUN cat > /etc/supervisor/conf.d/keepalive.conf << 'SEOF'
[supervisord]
nodaemon=true
logfile=/var/log/supervisord.log
pidfile=/var/run/supervisord.pid

[program:xvfb]
command=/usr/bin/Xvfb :99 -screen 0 1920x1080x24 -ac
priority=100
autorestart=true
stdout_logfile=/var/log/xvfb.stdout.log
stderr_logfile=/var/log/xvfb.stderr.log
stdout_logfile_maxbytes=1MB
stderr_logfile_maxbytes=1MB

[program:vdi]
command=/app/scripts/entrypoint-vdi_jty.sh
priority=500
startsecs=5
autorestart=true
environment=DISPLAY=":99",LANG="zh_CN.UTF-8"
stdout_logfile=/var/log/vdi.stdout.log
stderr_logfile=/var/log/vdi.stderr.log
stdout_logfile_maxbytes=5MB
stderr_logfile_maxbytes=5MB

[program:automation]
command=/app/scripts/run_automation_wrapper.sh
priority=600
startsecs=16
autorestart=true
environment=DISPLAY=":99",LANG="zh_CN.UTF-8"
stdout_logfile=/var/log/automation.stdout.log
stderr_logfile=/var/log/automation.stderr.log
stdout_logfile_maxbytes=5MB
stderr_logfile_maxbytes=5MB
SEOF

# 8. 创建自动化包装脚本
RUN cat > /app/scripts/run_automation_wrapper.sh << 'SEOF'
#!/bin/bash
export DISPLAY=:99

# 等待 X 服务器就绪
for i in $(seq 1 30); do
    if xdpyinfo -display :99 > /dev/null 2>&1; then
        break
    fi
    sleep 1
done

sleep 10
exec python3 /app/automation/vdi_automation_jty.py
SEOF

RUN chmod +x /app/scripts/*.sh /app/automation/*.sh 2>/dev/null; true

# 9. 创建入口脚本
RUN cat > /entrypoint.sh << 'SEOF'
#!/bin/bash
set -e

mkdir -p /var/log /config

# 从环境变量生成 credentials.conf
if [ -n "$PHONE" ] && [ -n "$PASSWORD" ]; then
    cat > /config/credentials.conf << EOF
login_method=${LOGIN_METHOD:-password}
phone=${PHONE}
password=${PASSWORD}
connect_index=${CONNECT_INDEX:-0}
keepalive_min_seconds=${KEEPALIVE_MIN:-600}
keepalive_max_seconds=${KEEPALIVE_MAX:-900}
keepalive_method=mouse_move
conflict_wait_seconds=300
enable_vnc=false
enable_novnc=false
EOF
    echo "[entrypoint] credentials.conf generated from env vars"
fi

# 反容器检测
export XDG_CURRENT_DESKTOP=Deepin
export DESKTOP_SESSION=deepin
unset container
RANDOM_HOST="jty-$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 8 | head -n 1)"
hostname "$RANDOM_HOST" 2>/dev/null || true
rm -f /.dockerenv 2>/dev/null || true

exec /usr/bin/supervisord -c /etc/supervisor/conf.d/keepalive.conf
SEOF

RUN chmod +x /entrypoint.sh

CMD ["/entrypoint.sh"]
