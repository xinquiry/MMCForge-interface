#!/bin/bash
# 快速测试脚本 - 只运行10步验证语法
# 用法: ./quick_test.sh

set -e

LMP_CMD=${LMP_CMD:-"lmp_serial"}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="$SCRIPT_DIR/.quick_test"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================="
echo "LAMMPS脚本快速语法测试 (10步)"
echo "========================================="

# 创建测试目录
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"

# 测试函数
test_script() {
    local system=$1
    local sim_type=$2
    local temp=$3
    local src_dir="$SCRIPT_DIR/$system/$sim_type/$temp"
    local test_name="${system}_${sim_type}_${temp}"

    echo -n "测试 $test_name ... "

    if [[ ! -d "$src_dir" ]]; then
        echo -e "${YELLOW}跳过 (目录不存在)${NC}"
        return 0
    fi

    # 复制文件到测试目录
    local work_dir="$TEST_DIR/$test_name"
    mkdir -p "$work_dir"
    cp "$src_dir"/* "$work_dir/" 2>/dev/null || true

    # 如果是tensile/shear，需要创建假的interface_equ文件
    if [[ "$sim_type" == "tensile" || "$sim_type" == "tension" || "$sim_type" == "shear" ]]; then
        # 从adhesion复制interface数据文件作为替代
        local adhesion_dir="$SCRIPT_DIR/$system/adhesion/$temp"
        if [[ -f "$adhesion_dir/TiB_Ti_interface.data" ]]; then
            cp "$adhesion_dir/TiB_Ti_interface.data" "$work_dir/interface_equ_T_${temp}.lmp"
        elif [[ -f "$adhesion_dir/SiC_C_Al_interface.lmp" ]]; then
            cp "$adhesion_dir/SiC_C_Al_interface.lmp" "$work_dir/interface_equ_T_${temp}.lmp"
        else
            echo -e "${YELLOW}跳过 (缺少interface数据)${NC}"
            return 0
        fi
    fi

    cd "$work_dir"

    # 创建修改后的输入文件，只运行10步
    local input_file="in.interface.rerun"
    if [[ -f "$input_file" ]]; then
        sed 's/run [0-9]*/run 10/' "$input_file" > "in.test"

        # 运行测试
        if $LMP_CMD -in in.test > test.log 2>&1; then
            echo -e "${GREEN}通过${NC}"
            return 0
        else
            echo -e "${RED}失败${NC}"
            echo "  错误日志: $work_dir/test.log"
            tail -10 test.log
            return 1
        fi
    else
        echo -e "${YELLOW}跳过 (无输入文件)${NC}"
        return 0
    fi
}

FAILED=0

# 测试所有配置
echo ""
echo "--- Ti:TiB 体系 ---"
test_script "Ti:TiB" "adhesion" "100" || FAILED=1
test_script "Ti:TiB" "tension" "100" || FAILED=1
test_script "Ti:TiB" "shear" "100" || FAILED=1

echo ""
echo "--- SiC:Al 体系 ---"
test_script "SiC:Al" "adhesion" "100" || FAILED=1
test_script "SiC:Al" "tensile" "100" || FAILED=1
test_script "SiC:Al" "shear" "100" || FAILED=1

echo ""
echo "========================================="
if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}所有测试通过!${NC}"
else
    echo -e "${RED}部分测试失败，请检查错误日志${NC}"
fi
echo "========================================="

# 清理
cd "$SCRIPT_DIR"
rm -rf "$TEST_DIR"

exit $FAILED
