# 金属基复合材料界面分子动力学模拟

## 项目概述

本项目用于研究金属基复合材料(MMC)界面的力学性能，包含两个材料体系：
- **SiC:Al** - 碳化硅增强铝基复合材料
- **Ti:TiB** - 硼化钛增强钛基复合材料

通过LAMMPS进行分子动力学模拟，计算界面粘附能、拉伸强度和剪切强度。

---

## 目录结构

```
interface/
├── SiC:Al/                    # 碳化硅/铝界面体系
│   ├── model/                 # 模型构建与能量最小化
│   ├── adhesion/              # 粘附能计算
│   │   ├── 100/               # 100K温度
│   │   └── 200/               # 200K温度
│   ├── tensile/100/           # 拉伸模拟
│   └── shear/100/             # 剪切模拟
│
└── Ti:TiB/                    # 钛/硼化钛界面体系
    ├── model/                 # 模型构建
    ├── adhesion/              # 粘附能计算
    │   ├── 100/
    │   └── 200/
    ├── tension/100/           # 拉伸模拟
    └── shear/100/             # 剪切模拟
```

---

## 势函数说明

### SiC:Al 体系

| 相互作用 | 势函数类型 | 势函数文件 |
|----------|-----------|-----------|
| Si-C | Tersoff | `SiC.tersoff` |
| Al-Al | EAM | `Al99.eam.alloy` |
| Si-Al | Morse | D=0.4824, α=1.322, r₀=2.92 |
| C-Al | Morse | D=0.4691, α=1.738, r₀=2.246 |

### Ti:TiB 体系

| 相互作用 | 势函数类型 | 势函数文件 |
|----------|-----------|-----------|
| Ti-Ti | MEAM | `library_Ti.meam`, `Ti.meam` |
| Ti-B, B-B | MEAM | `library.meam`, `TiB.meam` |

---

## 模拟工作流程

```
                    ┌─────────────────────────────────────┐
                    │         Step 1: adhesion/           │
                    │   NPT平衡 + 粘附能计算 (100 ps)      │
                    └─────────────────┬───────────────────┘
                                      │
                                      ▼
                          interface_equ_T_100.lmp
                           (平衡后的界面结构)
                                      │
                    ┌─────────────────┼─────────────────┐
                    │                 │                 │
                    ▼                 ▼                 ▼
           ┌───────────────┐ ┌───────────────┐ ┌───────────────┐
           │   tensile/    │ │    shear/     │ │  adhesion/    │
           │  拉伸强度测试  │ │  剪切强度测试  │ │  (其他温度)   │
           │   (2 ns)      │ │   (2 ns)      │ │               │
           └───────────────┘ └───────────────┘ └───────────────┘
```

---

## 脚本详细说明

### adhesion/100/ 目录

| 脚本文件 | 功能 | 说明 |
|---------|------|------|
| `in.interface.rerun` | 界面NPT平衡 | **主脚本**，生成 `interface_equ_T_100.lmp` |
| `in.Ti.rerun` / `in.Al.rerun` | 单相平衡 | 计算粘附能所需的单相能量 |
| `in.TiB.rerun` / `in.SiC.rerun` | 单相平衡 | 计算粘附能所需的单相能量 |

**粘附能计算公式**：
```
W_ad = (E_interface - E_phase1 - E_phase2) / A
```

### tensile/ 和 shear/ 目录

| 脚本文件 | 功能 | 加载方式 |
|---------|------|---------|
| `in.interface.rerun` | 力学性能测试 | 固定底部，顶部恒速移动 |

- **拉伸**：上部原子沿界面法向移动
- **剪切**：上部原子沿界面切向移动
- 加载速度：0.03 Å/ps

---

## 模拟参数

| 参数 | 值 | 说明 |
|------|-----|------|
| 单位制 | metal | Å, eV, ps, K |
| 时间步长 | 0.001 ps | 1 fs |
| 温度 | 100 K / 200 K | 可通过变量T修改 |
| 平衡步数 | 100,000 | 100 ps |
| 加载步数 | 2,000,000 | 2 ns |
| 系综(平衡) | NPT | 控温控压 |
| 系综(加载) | NVT | 控温 |

---

## 输出文件

| 文件名 | 内容 | 来源 |
|--------|------|------|
| `interface_equ_T_100.lmp` | 平衡后的界面结构 | adhesion |
| `*_pe.profile` | 势能随时间变化 | adhesion |
| `stress_strain.txt` | 应力-应变数据 | tensile/shear |
| `dump.*.atom` | 原子轨迹 | 所有模拟 |
| `log.lammps` | LAMMPS日志 | 所有模拟 |

---

## 运行指南

### 运行顺序

**必须按以下顺序执行**：

1. **adhesion** (平衡) → 生成 `interface_equ_T_100.lmp`
2. 复制结构文件到 tensile/ 和 shear/
3. **tensile** 和 **shear** (可并行)

### 本地测试 (Mac)

```bash
# 以 Ti:TiB 100K 为例

# Step 1: 运行adhesion平衡
cd Ti:TiB/adhesion/100/
lmp -in in.interface.rerun

# Step 2: 复制平衡结构
cp interface_equ_T_100.lmp ../../tension/100/
cp interface_equ_T_100.lmp ../../shear/100/

# Step 3: 运行力学测试
cd ../../tension/100/
lmp -in in.interface.rerun

cd ../shear/100/
lmp -in in.interface.rerun
```

### 集群运行

```bash
# 使用MPI并行
mpirun -np 55 lmp -in in.interface.rerun

# 或使用作业调度系统 (如SLURM)
sbatch run.slurm
```

---

## 预计运行时间

| 模拟类型 | 步数 | Mac单核 | 集群55核 |
|---------|------|---------|---------|
| adhesion (平衡) | 100,000 | ~5-10 min | ~1 min |
| tensile/shear | 2,000,000 | ~2-4 hours | ~10-20 min |

---

## 已知问题

### 1. 变量未定义问题

在 `tensile/` 和 `shear/` 的脚本中：
```lammps
fix out all print 10000 "${eps}   ${pr}" append stress_strain.txt screen no
```

`${pr}` 变量未定义，应修改为 `${s}` (对应 `compute s`)。

### 2. 边界条件差异

| 体系 | adhesion | tensile/shear |
|------|----------|---------------|
| SiC:Al | `p p f` | `p p f` |
| Ti:TiB | `f p p` | `f p p` |

界面法向方向使用固定边界(f)，其他方向周期边界(p)。

---

## 数据分析建议

1. **粘附能**：从 `*_pe.profile` 提取平衡后的势能值
2. **强度曲线**：绘制 `stress_strain.txt` 中的应力-应变关系
3. **断裂分析**：使用OVITO可视化 `dump.*.atom` 轨迹文件
