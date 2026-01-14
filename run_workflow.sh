#!/bin/bash
# 完整工作流运行脚本
# 按顺序运行: adhesion -> 复制文件 -> tensile/shear
# 用法: ./run_workflow.sh <system> <temperature>
# 示例: ./run_workflow.sh Ti:TiB 100

set -e

SYSTEM=${1:-"Ti:TiB"}
TEMP=${2:-"100"}
LMP_CMD=${LMP_CMD:-"lmp_serial"}

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ti:TiB用tension，SiC:Al用tensile
if [[ "$SYSTEM" == "Ti:TiB" ]]; then
    TENSILE_DIR="tension"
else
    TENSILE_DIR="tensile"
fi

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     完整模拟工作流 - $SYSTEM @ ${TEMP}K     ${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# Step 1: Adhesion
echo -e "${GREEN}[Step 1/4] 运行 adhesion 平衡模拟${NC}"
echo "----------------------------------------"
cd "$SCRIPT_DIR/$SYSTEM/adhesion/$TEMP"
echo "工作目录: $(pwd)"
time $LMP_CMD -in in.interface.rerun
echo -e "${GREEN}✓ adhesion 完成${NC}"
echo ""

# Step 2: 复制平衡结构
echo -e "${GREEN}[Step 2/4] 复制平衡结构文件${NC}"
echo "----------------------------------------"
EQU_FILE="interface_equ_T_${TEMP}.lmp"
if [[ -f "$EQU_FILE" ]]; then
    cp "$EQU_FILE" "$SCRIPT_DIR/$SYSTEM/$TENSILE_DIR/$TEMP/"
    cp "$EQU_FILE" "$SCRIPT_DIR/$SYSTEM/shear/$TEMP/"
    echo -e "${GREEN}✓ 已复制 $EQU_FILE 到 $TENSILE_DIR/ 和 shear/${NC}"
else
    echo -e "${RED}✗ 错误: $EQU_FILE 未生成${NC}"
    exit 1
fi
echo ""

# Step 3: Tensile
echo -e "${GREEN}[Step 3/4] 运行 tensile 拉伸模拟${NC}"
echo "----------------------------------------"
cd "$SCRIPT_DIR/$SYSTEM/$TENSILE_DIR/$TEMP"
echo "工作目录: $(pwd)"
time $LMP_CMD -in in.interface.rerun
echo -e "${GREEN}✓ tensile 完成${NC}"
echo ""

# Step 4: Shear
echo -e "${GREEN}[Step 4/4] 运行 shear 剪切模拟${NC}"
echo "----------------------------------------"
cd "$SCRIPT_DIR/$SYSTEM/shear/$TEMP"
echo "工作目录: $(pwd)"
time $LMP_CMD -in in.interface.rerun
echo -e "${GREEN}✓ shear 完成${NC}"
echo ""

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           全部模拟完成!                    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""
echo "输出文件:"
echo "  - adhesion: $SCRIPT_DIR/$SYSTEM/adhesion/$TEMP/"
echo "  - tensile:  $SCRIPT_DIR/$SYSTEM/$TENSILE_DIR/$TEMP/"
echo "  - shear:    $SCRIPT_DIR/$SYSTEM/shear/$TEMP/"
