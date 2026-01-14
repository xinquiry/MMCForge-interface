#!/bin/bash
# 集群并行运行脚本 - 两个体系同时跑
# 使用方法: nohup bash run_cluster.sh > run.log 2>&1 &

set -e

# 配置
BASE_DIR="${BASE_DIR:-$HOME/MMCForge-interface}"
CORES_PER_SYSTEM=64  # 每个体系用64核，共128核

cd "$BASE_DIR"
echo "========================================"
echo "开始时间: $(date)"
echo "工作目录: $BASE_DIR"
echo "每体系核心数: $CORES_PER_SYSTEM"
echo "========================================"

# 定义Ti:TiB工作流函数
run_TiTiB() {
    echo "[Ti:TiB] 开始 $(date)"

    echo "[Ti:TiB] adhesion"
    cd "$BASE_DIR/Ti:TiB/adhesion/100"
    mpirun -np $CORES_PER_SYSTEM lmp -in in.interface.rerun

    echo "[Ti:TiB] 复制平衡结构"
    cp interface_equ_T_100.lmp "$BASE_DIR/Ti:TiB/tension/100/"
    cp interface_equ_T_100.lmp "$BASE_DIR/Ti:TiB/shear/100/"

    echo "[Ti:TiB] tension"
    cd "$BASE_DIR/Ti:TiB/tension/100"
    mpirun -np $CORES_PER_SYSTEM lmp -in in.interface.rerun

    echo "[Ti:TiB] shear"
    cd "$BASE_DIR/Ti:TiB/shear/100"
    mpirun -np $CORES_PER_SYSTEM lmp -in in.interface.rerun

    echo "[Ti:TiB] 完成 $(date)"
}

# 定义SiC:Al工作流函数
run_SiCAl() {
    echo "[SiC:Al] 开始 $(date)"

    echo "[SiC:Al] adhesion"
    cd "$BASE_DIR/SiC:Al/adhesion/100"
    mpirun -np $CORES_PER_SYSTEM lmp -in in.interface.rerun

    echo "[SiC:Al] 复制平衡结构"
    cp interface_equ_T_100.lmp "$BASE_DIR/SiC:Al/tensile/100/"
    cp interface_equ_T_100.lmp "$BASE_DIR/SiC:Al/shear/100/"

    echo "[SiC:Al] tensile"
    cd "$BASE_DIR/SiC:Al/tensile/100"
    mpirun -np $CORES_PER_SYSTEM lmp -in in.interface.rerun

    echo "[SiC:Al] shear"
    cd "$BASE_DIR/SiC:Al/shear/100"
    mpirun -np $CORES_PER_SYSTEM lmp -in in.interface.rerun

    echo "[SiC:Al] 完成 $(date)"
}

# 并行运行两个体系
echo "启动并行任务..."
run_TiTiB > "$BASE_DIR/Ti_TiB.log" 2>&1 &
PID_TiTiB=$!

run_SiCAl > "$BASE_DIR/SiC_Al.log" 2>&1 &
PID_SiCAl=$!

echo "Ti:TiB PID: $PID_TiTiB"
echo "SiC:Al PID: $PID_SiCAl"

# 等待两个任务完成
echo "等待任务完成..."
wait $PID_TiTiB
echo "Ti:TiB 已完成"

wait $PID_SiCAl
echo "SiC:Al 已完成"

echo ""
echo "========================================"
echo "全部完成! $(date)"
echo "========================================"
echo "日志文件:"
echo "  - Ti:TiB: $BASE_DIR/Ti_TiB.log"
echo "  - SiC:Al: $BASE_DIR/SiC_Al.log"
