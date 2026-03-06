#!/usr/bin/env bash
#
# run.sh - 快速启动脚本
#
# 直接运行 CLIProxyAPI 服务（非 Docker 模式）

set -euo pipefail

echo "正在启动 CLIProxyAPI 服务..."
echo ""

# 检查配置文件
if [ ! -f "config.yaml" ]; then
    echo "⚠️  未找到 config.yaml，正在从示例文件复制..."
    if [ -f "config.example.yaml" ]; then
        cp config.example.yaml config.yaml
        echo "✓ 已创建 config.yaml，请根据需要修改配置"
    else
        echo "❌ 未找到 config.example.yaml"
        exit 1
    fi
fi

# 运行服务
echo "启动服务中..."
go run cmd/server/main.go
