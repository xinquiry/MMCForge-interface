#!/bin/bash
# SiC:Al 结合能计算 - 多温度
# 温度: 100°C(373K), 300°C(573K), 500°C(773K)
# 界面类型: C终止 和 Si终止
# 使用方法: nohup bash run_SiC_Al_adhesion.sh > SiC_Al_adhesion.log 2>&1 &

set -e

# 配置
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CORES_PER_TEMP=50  # 每个计算的核心数
STEPS=20000  # 平衡步数

# 允许以root运行
export OMPI_ALLOW_RUN_AS_ROOT=1
export OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1

# 温度列表 (开尔文)
TEMPS=(373 573 773)
TEMPS_C=(100 300 500)

# 界面类型
INTERFACE_TYPES=("C" "Si")

echo "========================================"
echo "SiC:Al 结合能计算"
echo "开始时间: $(date)"
echo "温度: 100°C(373K), 300°C(573K), 500°C(773K)"
echo "界面类型: C终止, Si终止"
echo "每计算核心数: $CORES_PER_TEMP"
echo "平衡步数: $STEPS"
echo "========================================"

# 源文件目录
SRC_DIR="$BASE_DIR/SiC:Al/model"

# 为每个温度和界面类型运行计算的函数
run_calculation() {
    local T=$1
    local T_C=$2
    local ITYPE=$3
    local WORK_DIR="$BASE_DIR/SiC:Al/adhesion/${T}K_${ITYPE}"

    echo "[${T}K/${T_C}°C/${ITYPE}终止] 开始 $(date)"

    # 创建工作目录
    mkdir -p "$WORK_DIR"

    # 复制势函数文件
    cp "$SRC_DIR/SiC.tersoff" "$WORK_DIR/"
    cp "$SRC_DIR/Al99.eam.alloy" "$WORK_DIR/"

    # 根据界面类型复制模型文件
    cp "$SRC_DIR/SiC_Al_${ITYPE}.lmp" "$WORK_DIR/interface.lmp"

    cd "$WORK_DIR"

    # 1. 界面体系
    echo "[${T}K/${ITYPE}] 计算界面能量..."
    cat > in.interface.rerun << EOF
units metal
boundary p p f
atom_style atomic
read_data interface.lmp

# 混合势: Tersoff(SiC) + EAM(Al) + Morse(界面相互作用)
pair_style hybrid tersoff eam/alloy morse 3.0
pair_coeff * * tersoff SiC.tersoff C Si NULL
pair_coeff * * eam/alloy Al99.eam.alloy NULL NULL Al
pair_coeff 1 3 morse 0.4691 1.738 2.246
pair_coeff 2 3 morse 0.4824 1.322 2.92

# 添加wall防止原子飞出z方向边界
fix wall_lo all wall/reflect zlo EDGE
fix wall_hi all wall/reflect zhi EDGE

# 能量最小化
minimize 1.0e-6 1.0e-8 10000 100000
reset_timestep 0

variable T equal $T

compute Temp all temp
compute ppe all pe

thermo 1000
thermo_style custom step temp pe ke etotal
timestep 0.001
velocity all create \$T 12345 dist gaussian
fix npt all npt temp \$T \$T 0.1 x 0 0 0.1 y 0 0 0.1
fix 1 all ave/time 10 100 1000 c_ppe file interface_pe.dat
run $STEPS

print "FINAL_PE_INTERFACE \$(c_ppe)" append results.txt
EOF
    mpirun -np $CORES_PER_TEMP lmp -in in.interface.rerun > interface.log 2>&1

    # 2. 提取并计算纯Al (type 3)
    echo "[${T}K/${ITYPE}] 计算Al能量..."
    cat > in.Al.rerun << EOF
units metal
boundary p p f
atom_style atomic
read_data interface.lmp

# 只保留Al原子
group Al type 3
group others type 1 2
delete_atoms group others

pair_style eam/alloy
pair_coeff * * Al99.eam.alloy Al Al Al

variable T equal $T

compute Temp all temp
compute ppe all pe

thermo 1000
thermo_style custom step temp pe ke etotal
timestep 0.001
velocity all create \$T 12345 dist gaussian
fix npt all npt temp \$T \$T 0.1 x 0 0 0.1 y 0 0 0.1
fix 1 all ave/time 10 100 1000 c_ppe file Al_pe.dat
run $STEPS

print "FINAL_PE_AL \$(c_ppe)" append results.txt
EOF
    mpirun -np $CORES_PER_TEMP lmp -in in.Al.rerun > Al.log 2>&1

    # 3. 提取并计算纯SiC (type 1,2)
    echo "[${T}K/${ITYPE}] 计算SiC能量..."
    cat > in.SiC.rerun << EOF
units metal
boundary p p f
atom_style atomic
read_data interface.lmp

# 只保留SiC原子
group SiC type 1 2
group Al type 3
delete_atoms group Al

pair_style tersoff
pair_coeff * * SiC.tersoff C Si NULL

variable T equal $T

compute Temp all temp
compute ppe all pe

thermo 1000
thermo_style custom step temp pe ke etotal
timestep 0.001
velocity all create \$T 12345 dist gaussian
fix npt all npt temp \$T \$T 0.1 x 0 0 0.1 y 0 0 0.1
fix 1 all ave/time 10 100 1000 c_ppe file SiC_pe.dat
run $STEPS

print "FINAL_PE_SIC \$(c_ppe)" append results.txt
EOF
    mpirun -np $CORES_PER_TEMP lmp -in in.SiC.rerun > SiC.log 2>&1

    echo "[${T}K/${T_C}°C/${ITYPE}终止] 完成 $(date)"
}

# 运行所有计算
for ITYPE in "${INTERFACE_TYPES[@]}"; do
    echo ""
    echo "========================================"
    echo "界面类型: ${ITYPE}终止"
    echo "========================================"

    for i in "${!TEMPS[@]}"; do
        echo ""
        echo "----------------------------------------"
        echo "温度: ${TEMPS_C[$i]}°C (${TEMPS[$i]}K)"
        echo "----------------------------------------"
        run_calculation "${TEMPS[$i]}" "${TEMPS_C[$i]}" "${ITYPE}" 2>&1 | tee "$BASE_DIR/SiC:Al/adhesion/${TEMPS[$i]}K_${ITYPE}.log"
    done
done

echo ""
echo "========================================"
echo "全部完成! $(date)"
echo "========================================"
echo ""
echo "结果文件位置:"
for ITYPE in "${INTERFACE_TYPES[@]}"; do
    for i in "${!TEMPS[@]}"; do
        echo "  ${TEMPS_C[$i]}°C ${ITYPE}终止: SiC:Al/adhesion/${TEMPS[$i]}K_${ITYPE}/results.txt"
    done
done
