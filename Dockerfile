FROM golang:1.23-alpine AS builder

RUN apk add --no-cache git

WORKDIR /build
RUN git clone https://github.com/Swilder-M/cloud-computer-keepalive.git . && \
    CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /cloudpc .

FROM alpine:3.19

RUN apk add --no-cache ca-certificates tzdata bash && \
    cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" > /etc/timezone

WORKDIR /app
COPY --from=builder /cloudpc /app/cloudpc
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/cloudpc /app/entrypoint.sh

VOLUME ["/app/data"]

ENTRYPOINT ["/app/entrypoint.sh"]
