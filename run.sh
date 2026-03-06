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

# 检查二进制文件是否存在
if [ ! -f "${BINARY_PATH}" ]; then
    echo -e "${YELLOW}未找到编译后的二进制文件，正在编译...${NC}"

    # 检查 Go 是否安装
    if ! command -v go &> /dev/null; then
        echo -e "${RED}错误: 未找到 Go 编译器${NC}"
        echo "请先安装 Go: https://golang.org/dl/"
        exit 1
    fi

    cd "${PROJECT_DIR}"
    go build -o "${BINARY_NAME}" ./cmd/server/main.go

    if [ ! -f "${BINARY_PATH}" ]; then
        echo -e "${RED}错误: 编译失败${NC}"
        exit 1
    fi

    chmod +x "${BINARY_PATH}"
    echo -e "${GREEN}✓ 编译成功${NC}"
fi

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

# 启动服务
echo -e "${GREEN}正在启动服务...${NC}"
cd "${PROJECT_DIR}"

# 设置环境变量
export GIN_MODE=release

# 启动服务并保存 PID
nohup "${BINARY_PATH}" > "${PROJECT_DIR}/cliproxyapi.log" 2>&1 &
PID=$!
echo $PID > "${PID_FILE}"

# 等待服务启动
sleep 2

# 检查进程是否还在运行
if kill -0 $PID 2>/dev/null; then
    echo -e "${GREEN}✓ 服务启动成功${NC}"
    echo "PID: $PID"
    echo "日志文件: ${PROJECT_DIR}/cliproxyapi.log"
    echo ""
    echo "管理命令:"
    echo "  查看日志: tail -f ${PROJECT_DIR}/cliproxyapi.log"
    echo "  停止服务: kill $PID 或 kill \$(cat ${PID_FILE})"
    echo "  查看进程: ps aux | grep ${BINARY_NAME}"
else
    echo -e "${RED}错误: 服务启动失败${NC}"
    echo "请查看日志: cat ${PROJECT_DIR}/cliproxyapi.log"
    rm -f "${PID_FILE}"
    exit 1
fi
