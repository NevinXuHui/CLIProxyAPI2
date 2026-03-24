#!/bin/bash

# CLI Proxy API 运行脚本
# 直接运行服务（不使用 systemd）

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 获取脚本所在目录（项目根目录）
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINARY_NAME="cliproxyapi"
BINARY_PATH="${PROJECT_DIR}/${BINARY_NAME}"
PID_FILE="${PROJECT_DIR}/${BINARY_NAME}.pid"

echo -e "${GREEN}=== CLI Proxy API 运行脚本 ===${NC}"
echo "项目目录: ${PROJECT_DIR}"
echo ""

# 检查配置文件
if [ ! -f "${PROJECT_DIR}/config.yaml" ]; then
    echo -e "${RED}错误: 未找到 config.yaml${NC}"
    if [ -f "${PROJECT_DIR}/config.example.yaml" ]; then
        echo -e "${YELLOW}提示: 请先从 config.example.yaml 复制并配置 config.yaml${NC}"
        echo "命令: cp config.example.yaml config.yaml"
    fi
    exit 1
fi

# 读取配置文件中的端口
CONFIG_PORT=$(grep -E "^port:" "${PROJECT_DIR}/config.yaml" | awk '{print $2}' | head -1)
if [ -z "$CONFIG_PORT" ]; then
    CONFIG_PORT="9008"  # 默认端口
fi
echo "配置端口: ${CONFIG_PORT}"

# 强制重新编译后端
echo -e "${YELLOW}正在重新编译后端...${NC}"

# 优先使用 /usr/local/go/bin/go（常见手工安装路径），否则回退到 PATH 中的 go
GO_BIN=""
if [ -x "/usr/local/go/bin/go" ]; then
    GO_BIN="/usr/local/go/bin/go"
elif command -v go &> /dev/null; then
    GO_BIN="$(command -v go)"
else
    echo -e "${RED}错误: 未找到 Go 编译器${NC}"
    echo "请先安装 Go: https://golang.org/dl/"
    exit 1
fi

echo "使用 Go: $("${GO_BIN}" version)"

# 删除旧的二进制文件
if [ -f "${BINARY_PATH}" ]; then
    rm -f "${BINARY_PATH}"
    echo -e "${YELLOW}已删除旧的二进制文件${NC}"
fi

cd "${PROJECT_DIR}"
"${GO_BIN}" build -o "${BINARY_NAME}" ./cmd/server/main.go

if [ ! -f "${BINARY_PATH}" ]; then
    echo -e "${RED}错误: 编译失败${NC}"
    exit 1
fi

chmod +x "${BINARY_PATH}"
echo -e "${GREEN}✓ 编译成功${NC}"

# 杀掉可能存在的旧进程（按进程名）
echo -e "${YELLOW}检查并清理旧进程...${NC}"
OLD_PIDS=$(pgrep -f "${BINARY_NAME}" || true)
if [ -n "$OLD_PIDS" ]; then
    echo "发现旧进程（按名称）: $OLD_PIDS"
    kill -9 $OLD_PIDS 2>/dev/null || true
    sleep 1
fi

# 杀掉占用配置端口的进程
PORT_PIDS=$(lsof -ti :${CONFIG_PORT} 2>/dev/null || true)
if [ -n "$PORT_PIDS" ]; then
    echo "发现占用端口 ${CONFIG_PORT} 的进程: $PORT_PIDS"
    kill -9 $PORT_PIDS 2>/dev/null || true
    sleep 1
    echo -e "${GREEN}✓ 端口已释放${NC}"
else
    echo "端口 ${CONFIG_PORT} 未被占用"
fi

# 最终确认
REMAINING_PIDS=$(pgrep -f "${BINARY_NAME}" || true)
if [ -n "$REMAINING_PIDS" ]; then
    echo -e "${YELLOW}警告: 仍有进程残留: $REMAINING_PIDS${NC}"
else
    echo -e "${GREEN}✓ 所有旧进程已清理${NC}"
fi

# 清理旧的 PID 文件
if [ -f "${PID_FILE}" ]; then
    rm -f "${PID_FILE}"
fi

# 启动服务（前台运行）
echo -e "${GREEN}正在启动服务...${NC}"
echo -e "${YELLOW}提示: 服务将在前台运行，按 Ctrl+C 停止${NC}"
echo ""
cd "${PROJECT_DIR}"

# 设置环境变量
export GIN_MODE=release

# 前台运行服务
exec "${BINARY_PATH}"
