#!/bin/bash
# 检查模拟进度和结果
# 用法: bash check_status.sh

BASE_DIR="${BASE_DIR:-$(pwd)}"

echo "========================================"
echo "模拟状态检查 - $(date)"
echo "========================================"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_adhesion() {
    local system=$1
    local dir="$BASE_DIR/$system/adhesion/100"

    echo ""
    echo "--- $system adhesion ---"

    # 检查平衡结构是否生成
    if [[ -f "$dir/interface_equ_T_100.lmp" ]]; then
        echo -e "${GREEN}✓ 平衡结构已生成${NC}"
        ls -lh "$dir/interface_equ_T_100.lmp"
    else
        echo -e "${RED}✗ 平衡结构未生成${NC}"
        # 检查当前进度
        if [[ -f "$dir/log.lammps" ]]; then
            local last_step=$(grep "^[[:space:]]*[0-9]" "$dir/log.lammps" | tail -1 | awk '{print $1}')
            echo "  当前步数: $last_step / 100000"
        fi
        return 1
    fi

    # 检查势能数据
    if [[ -f "$dir/"*"_pe.profile" ]]; then
        local pe_file=$(ls "$dir/"*"_pe.profile" 2>/dev/null | head -1)
        local pe_lines=$(wc -l < "$pe_file")
        echo "  势能数据: $pe_lines 行"
    fi
    return 0
}

check_mechanical() {
    local system=$1
    local test_type=$2  # tensile, tension, or shear
    local dir="$BASE_DIR/$system/$test_type/100"

    echo ""
    echo "--- $system $test_type ---"

    local ss_file="$dir/stress_strain.txt"

    if [[ ! -f "$ss_file" ]]; then
        echo -e "${YELLOW}! 应力应变文件不存在${NC}"
        # 检查是否在运行
        if [[ -f "$dir/log.lammps" ]]; then
            local last_step=$(grep "^[[:space:]]*[0-9]" "$dir/log.lammps" | tail -1 | awk '{print $1}')
            echo "  当前步数: $last_step"
        fi
        return 1
    fi

    # 统计数据点
    local data_points=$(wc -l < "$ss_file")
    echo "  数据点数: $data_points"

    if [[ $data_points -lt 5 ]]; then
        echo -e "${YELLOW}! 数据点太少，无法分析${NC}"
        return 1
    fi

    # 提取应力数据并分析
    echo "  应力应变数据 (前10行):"
    head -10 "$ss_file" | while read line; do
        echo "    $line"
    done

    echo "  ..."
    echo "  应力应变数据 (后5行):"
    tail -5 "$ss_file" | while read line; do
        echo "    $line"
    done

    # 简单分析：找最大应力和当前应力
    local max_stress=$(awk '{if($2>max || NR==1) max=$2} END{print max}' "$ss_file")
    local last_stress=$(tail -1 "$ss_file" | awk '{print $2}')
    local last_strain=$(tail -1 "$ss_file" | awk '{print $1}')

    echo ""
    echo "  最大应力: $max_stress"
    echo "  当前应力: $last_stress"
    echo "  当前应变: $last_strain"

    # 判断是否过了屈服点
    if command -v python3 &> /dev/null; then
        python3 << EOF
import sys
max_s = float("$max_stress")
last_s = float("$last_stress")

if max_s > 0 and last_s < max_s * 0.9:
    print("  \033[0;32m✓ 已过屈服点 (应力下降超过10%)\033[0m")
    print("  → 可以停止此模拟")
elif max_s > 0 and last_s < max_s * 0.95:
    print("  \033[1;33m~ 接近屈服点 (应力下降5-10%)\033[0m")
    print("  → 建议再跑一段时间")
else:
    print("  \033[1;33m! 尚未到达屈服点\033[0m")
    print("  → 继续运行")
EOF
    fi

    return 0
}

# 检查进程状态
echo ""
echo "=== 运行中的LAMMPS进程 ==="
if pgrep -f "lmp" > /dev/null; then
    ps aux | grep "lmp -in" | grep -v grep | head -5
    echo "..."
else
    echo -e "${YELLOW}没有正在运行的LAMMPS进程${NC}"
fi

# 检查Ti:TiB
echo ""
echo "========================================"
echo "Ti:TiB 体系"
echo "========================================"
check_adhesion "Ti:TiB"
TITIB_ADH=$?

# Ti:TiB用的是tension不是tensile
if [[ -d "$BASE_DIR/Ti:TiB/tension/100" ]]; then
    check_mechanical "Ti:TiB" "tension"
fi
check_mechanical "Ti:TiB" "shear"

# 检查SiC:Al
echo ""
echo "========================================"
echo "SiC:Al 体系"
echo "========================================"
check_adhesion "SiC:Al"
SICAL_ADH=$?

check_mechanical "SiC:Al" "tensile"
check_mechanical "SiC:Al" "shear"

# 总结
echo ""
echo "========================================"
echo "总结"
echo "========================================"

if [[ $TITIB_ADH -eq 0 ]] && [[ $SICAL_ADH -eq 0 ]]; then
    echo -e "${GREEN}✓ 两个体系的adhesion都已完成${NC}"
else
    echo -e "${YELLOW}! 部分adhesion未完成${NC}"
fi

echo ""
echo "提示: 根据师兄的要求，只需要:"
echo "  1. adhesion完成 (计算粘附能)"
echo "  2. tensile/shear看到屈服点 (曲线下降)"
echo ""
echo "如果应力已经下降，可以停止对应的模拟。"
