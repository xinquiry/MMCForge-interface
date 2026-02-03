#!/bin/bash
# 分子动力学模拟运行脚本
# 用法: ./run_simulation.sh <system> <simulation_type> <temperature>
# 示例: ./run_simulation.sh Ti:TiB adhesion 100

set -e

# 默认参数
SYSTEM=${1:-"Ti:TiB"}
SIM_TYPE=${2:-"adhesion"}
TEMP=${3:-"100"}
LMP_CMD=${LMP_CMD:-"lmp_serial"}  # 可通过环境变量设置为 lmp_mpi

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ti:TiB用tension，SiC:Al用tensile
if [[ "$SYSTEM" == "Ti:TiB" && "$SIM_TYPE" == "tensile" ]]; then
    SIM_TYPE="tension"
fi

WORK_DIR="$SCRIPT_DIR/$SYSTEM/$SIM_TYPE/$TEMP"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}LAMMPS模拟运行脚本${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "体系:     ${YELLOW}$SYSTEM${NC}"
echo -e "模拟类型: ${YELLOW}$SIM_TYPE${NC}"
echo -e "温度:     ${YELLOW}${TEMP}K${NC}"
echo -e "工作目录: ${YELLOW}$WORK_DIR${NC}"
echo -e "${GREEN}========================================${NC}"

# 检查目录是否存在
if [[ ! -d "$WORK_DIR" ]]; then
    echo -e "${RED}错误: 目录不存在 $WORK_DIR${NC}"
    exit 1
fi

cd "$WORK_DIR"

# 检查输入文件
INPUT_FILE="in.interface.rerun"
if [[ ! -f "$INPUT_FILE" ]]; then
    echo -e "${RED}错误: 输入文件不存在 $INPUT_FILE${NC}"
    exit 1
fi

# 检查是否需要interface_equ_T_*.lmp (tensile/shear需要)
if [[ "$SIM_TYPE" == "tensile" || "$SIM_TYPE" == "tension" || "$SIM_TYPE" == "shear" ]]; then
    EQU_FILE="interface_equ_T_${TEMP}.lmp"
    if [[ ! -f "$EQU_FILE" ]]; then
        echo -e "${RED}错误: 缺少平衡结构文件 $EQU_FILE${NC}"
        echo -e "${YELLOW}请先运行adhesion模拟并复制生成的文件${NC}"
        exit 1
    fi
fi

# 运行模拟
echo -e "${GREEN}开始运行模拟...${NC}"
echo "命令: $LMP_CMD -in $INPUT_FILE"
echo ""

time $LMP_CMD -in $INPUT_FILE

echo ""
echo -e "${GREEN}模拟完成!${NC}"
echo -e "输出文件位于: $WORK_DIR"
ls -lh *.lmp *.profile *.txt 2>/dev/null || true
