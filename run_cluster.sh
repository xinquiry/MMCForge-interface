#!/bin/bash
# 集群完整运行脚本 - 后台运行版本
# 使用方法: nohup bash run_cluster.sh > run.log 2>&1 &

set -e

# 配置
BASE_DIR="${BASE_DIR:-$HOME/MMCForge-interface}"
CORES_PER_JOB=60

cd "$BASE_DIR"
echo "========================================"
echo "开始时间: $(date)"
echo "工作目录: $BASE_DIR"
echo "每任务核心数: $CORES_PER_JOB"
echo "========================================"

# ========== Ti:TiB 体系 ==========
echo ""
echo "[1/6] Ti:TiB adhesion"
cd "$BASE_DIR/Ti:TiB/adhesion/100"
pwd
mpirun -np $CORES_PER_JOB lmp -in in.interface.rerun
echo "完成时间: $(date)"

echo ""
echo "[2/6] 复制 Ti:TiB 平衡结构"
cp interface_equ_T_100.lmp "$BASE_DIR/Ti:TiB/tension/100/"
cp interface_equ_T_100.lmp "$BASE_DIR/Ti:TiB/shear/100/"
echo "已复制到 tension/100 和 shear/100"

echo ""
echo "[3/6] Ti:TiB tension"
cd "$BASE_DIR/Ti:TiB/tension/100"
pwd
mpirun -np $CORES_PER_JOB lmp -in in.interface.rerun
echo "完成时间: $(date)"

echo ""
echo "[4/6] Ti:TiB shear"
cd "$BASE_DIR/Ti:TiB/shear/100"
pwd
mpirun -np $CORES_PER_JOB lmp -in in.interface.rerun
echo "完成时间: $(date)"

# ========== SiC:Al 体系 ==========
echo ""
echo "[5/6] SiC:Al adhesion"
cd "$BASE_DIR/SiC:Al/adhesion/100"
pwd
mpirun -np $CORES_PER_JOB lmp -in in.interface.rerun
echo "完成时间: $(date)"

echo ""
echo "复制 SiC:Al 平衡结构"
cp interface_equ_T_100.lmp "$BASE_DIR/SiC:Al/tensile/100/"
cp interface_equ_T_100.lmp "$BASE_DIR/SiC:Al/shear/100/"
echo "已复制到 tensile/100 和 shear/100"

echo ""
echo "[6/6] SiC:Al tensile"
cd "$BASE_DIR/SiC:Al/tensile/100"
pwd
mpirun -np $CORES_PER_JOB lmp -in in.interface.rerun
echo "完成时间: $(date)"

echo ""
echo "[7/8] SiC:Al shear"
cd "$BASE_DIR/SiC:Al/shear/100"
pwd
mpirun -np $CORES_PER_JOB lmp -in in.interface.rerun
echo "完成时间: $(date)"

echo ""
echo "========================================"
echo "全部完成! $(date)"
echo "========================================"
