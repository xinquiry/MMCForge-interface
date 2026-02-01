#!/bin/bash
# Ti:TiB 结合能计算 - 多温度并行
# 温度: 100°C(373K), 300°C(573K), 500°C(773K)
# 使用方法: nohup bash run_adhesion.sh > adhesion.log 2>&1 &

set -e

# 配置
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
CORES_PER_TEMP=18  # 55核限制，18×3=54
STEPS=20000  # 减少步数加速（原100000）

# 允许以root运行
export OMPI_ALLOW_RUN_AS_ROOT=1
export OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1

# 温度列表 (开尔文)
TEMPS=(373 573 773)
TEMPS_C=(100 300 500)

echo "========================================"
echo "Ti:TiB 结合能计算"
echo "开始时间: $(date)"
echo "温度: 100°C(373K), 300°C(573K), 500°C(773K)"
echo "每温度核心数: $CORES_PER_TEMP"
echo "平衡步数: $STEPS"
echo "========================================"

# 源文件目录
SRC_DIR="$BASE_DIR/Ti:TiB/adhesion/100"

# 为每个温度运行计算的函数
run_temperature() {
    local T=$1
    local T_C=$2
    local WORK_DIR="$BASE_DIR/Ti:TiB/adhesion/${T}K"

    echo "[${T}K/${T_C}°C] 开始 $(date)"

    # 创建工作目录
    mkdir -p "$WORK_DIR"

    # 复制必要文件
    cp "$SRC_DIR"/*.meam "$WORK_DIR/" 2>/dev/null || true
    cp "$SRC_DIR"/*.lmp "$WORK_DIR/" 2>/dev/null || true
    cp "$SRC_DIR"/*.data "$WORK_DIR/" 2>/dev/null || true

    cd "$WORK_DIR"

    # 1. 界面体系
    echo "[${T}K] 计算界面能量..."
    cat > in.interface.rerun << EOF
units metal
boundary f p p
atom_style atomic
read_data TiB_Ti_interface.data

pair_style meam
pair_coeff * * library.meam B Ti TiB.meam B Ti

fix wall_lo all wall/reflect xlo EDGE
fix wall_hi all wall/reflect xhi EDGE

minimize 1.0e-6 1.0e-8 10000 100000
reset_timestep 0

variable T equal $T

compute Temp all temp
compute ppe all pe

thermo 1000
thermo_style custom step temp pe ke etotal
timestep 0.001
velocity all create \$T 12345 dist gaussian
fix npt all npt temp \$T \$T 0.1 y 0 0 0.1 z 0 0 0.1
fix 1 all ave/time 10 100 1000 c_ppe file interface_pe.dat
run $STEPS

print "FINAL_PE_INTERFACE \$(c_ppe)" append results.txt
EOF
    mpirun -np $CORES_PER_TEMP lmp -in in.interface.rerun > interface.log 2>&1

    # 2. 纯Ti
    echo "[${T}K] 计算Ti能量..."
    cat > in.Ti.rerun << EOF
units metal
boundary f p p
atom_style atomic
read_data Ti_cut.lmp

pair_style meam
pair_coeff * * library_Ti.meam Ti Ti.meam Ti

variable T equal $T

compute Temp all temp
compute ppe all pe

thermo 1000
thermo_style custom step temp pe ke etotal
timestep 0.001
velocity all create \$T 12345 dist gaussian
fix npt all npt temp \$T \$T 0.1 y 0 0 0.1 z 0 0 0.1
fix 1 all ave/time 10 100 1000 c_ppe file Ti_pe.dat
run $STEPS

print "FINAL_PE_TI \$(c_ppe)" append results.txt
EOF
    mpirun -np $CORES_PER_TEMP lmp -in in.Ti.rerun > Ti.log 2>&1

    # 3. 纯TiB
    echo "[${T}K] 计算TiB能量..."
    cat > in.TiB.rerun << EOF
units metal
boundary f p p
atom_style atomic
read_data TiB_cut.lmp

pair_style meam
pair_coeff * * library.meam B Ti TiB.meam B Ti

variable T equal $T

compute Temp all temp
compute ppe all pe

thermo 1000
thermo_style custom step temp pe ke etotal
timestep 0.001
velocity all create \$T 12345 dist gaussian
fix npt all npt temp \$T \$T 0.1 y 0 0 0.1 z 0 0 0.1
fix 1 all ave/time 10 100 1000 c_ppe file TiB_pe.dat
run $STEPS

print "FINAL_PE_TIB \$(c_ppe)" append results.txt
EOF
    mpirun -np $CORES_PER_TEMP lmp -in in.TiB.rerun > TiB.log 2>&1

    echo "[${T}K/${T_C}°C] 完成 $(date)"
}

# 并行运行3个温度
echo "启动3个温度的并行计算..."

for i in "${!TEMPS[@]}"; do
    run_temperature "${TEMPS[$i]}" "${TEMPS_C[$i]}" > "$BASE_DIR/Ti:TiB/adhesion/${TEMPS[$i]}K.log" 2>&1 &
    PIDS[$i]=$!
    echo "温度 ${TEMPS_C[$i]}°C (${TEMPS[$i]}K) PID: ${PIDS[$i]}"
done

# 等待所有任务完成
echo "等待计算完成..."
for i in "${!PIDS[@]}"; do
    wait ${PIDS[$i]}
    echo "温度 ${TEMPS_C[$i]}°C 完成"
done

echo ""
echo "========================================"
echo "全部完成! $(date)"
echo "========================================"
echo ""
echo "结果文件位置:"
for i in "${!TEMPS[@]}"; do
    echo "  ${TEMPS_C[$i]}°C: Ti:TiB/adhesion/${TEMPS[$i]}K/results.txt"
done
