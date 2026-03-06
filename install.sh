#!/bin/bash

# CLI Proxy API 安装脚本
# 使用 systemd 方式安装服务

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 获取脚本所在目录（项目根目录）
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_NAME="cliproxyapi"
SERVICE_FILE="${PROJECT_DIR}/${SERVICE_NAME}.service"
SYSTEMD_DIR="/etc/systemd/system"
BINARY_NAME="${SERVICE_NAME}"
BINARY_PATH="${PROJECT_DIR}/${BINARY_NAME}"

echo -e "${GREEN}=== CLI Proxy API 安装脚本 ===${NC}"
echo "项目目录: ${PROJECT_DIR}"
echo ""

# 检查是否以 root 权限运行
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}错误: 请使用 root 权限运行此脚本${NC}"
    echo "使用: sudo ./install.sh"
    exit 1
fi

# 检查 Go 是否安装
if ! command -v go &> /dev/null; then
    echo -e "${RED}错误: 未找到 Go 编译器${NC}"
    echo "请先安装 Go: https://golang.org/dl/"
    exit 1
fi

# 检查配置文件
if [ ! -f "${PROJECT_DIR}/config.yaml" ]; then
    echo -e "${YELLOW}警告: 未找到 config.yaml${NC}"
    if [ -f "${PROJECT_DIR}/config.example.yaml" ]; then
        echo "是否从 config.example.yaml 复制配置文件? (y/n)"
        read -r response
        if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            cp "${PROJECT_DIR}/config.example.yaml" "${PROJECT_DIR}/config.yaml"
            echo -e "${GREEN}✓ 已创建 config.yaml${NC}"
            echo -e "${YELLOW}请编辑 config.yaml 配置文件后重新运行安装脚本${NC}"
            exit 0
        else
            echo -e "${RED}安装已取消${NC}"
            exit 1
        fi
    else
        echo -e "${RED}错误: 未找到配置文件${NC}"
        exit 1
    fi
fi

# 编译项目
echo -e "${YELLOW}正在编译项目...${NC}"
cd "${PROJECT_DIR}"
go build -o "${BINARY_NAME}" ./cmd/server/main.go

if [ ! -f "${BINARY_PATH}" ]; then
    echo -e "${RED}错误: 编译失败${NC}"
    exit 1
fi

echo -e "${GREEN}✓ 编译成功${NC}"

# 赋予执行权限
chmod +x "${BINARY_PATH}"

# 检查 service 文件是否存在
if [ ! -f "${SERVICE_FILE}" ]; then
    echo -e "${RED}错误: 未找到 ${SERVICE_FILE}${NC}"
    exit 1
fi

# 停止现有服务（如果正在运行）
if systemctl is-active --quiet "${SERVICE_NAME}"; then
    echo -e "${YELLOW}停止现有服务...${NC}"
    systemctl stop "${SERVICE_NAME}"
    echo -e "${GREEN}✓ 服务已停止${NC}"
fi

# 复制 service 文件到 systemd 目录
echo -e "${YELLOW}安装 systemd 服务...${NC}"
cp "${SERVICE_FILE}" "${SYSTEMD_DIR}/${SERVICE_NAME}.service"

# 重新加载 systemd
systemctl daemon-reload

# 启用服务（开机自启）
systemctl enable "${SERVICE_NAME}"

# 启动服务
systemctl start "${SERVICE_NAME}"

# 检查服务状态
sleep 2
if systemctl is-active --quiet "${SERVICE_NAME}"; then
    echo -e "${GREEN}✓ 服务安装成功并已启动${NC}"
    echo ""
    echo "服务管理命令:"
    echo "  查看状态: systemctl status ${SERVICE_NAME}"
    echo "  查看日志: journalctl -u ${SERVICE_NAME} -f"
    echo "  停止服务: systemctl stop ${SERVICE_NAME}"
    echo "  启动服务: systemctl start ${SERVICE_NAME}"
    echo "  重启服务: systemctl restart ${SERVICE_NAME}"
    echo "  禁用开机自启: systemctl disable ${SERVICE_NAME}"
    echo ""
    echo -e "${GREEN}安装完成！${NC}"
else
    echo -e "${RED}错误: 服务启动失败${NC}"
    echo "请查看日志: journalctl -u ${SERVICE_NAME} -n 50"
    exit 1
fi
