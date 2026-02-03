# MMCForge/interface 项目说明

金属基复合材料（MMC）界面性能的分子动力学计算项目。

## 项目状态

- **Ti-TiB 界面**：已完成结合能计算和报告
- **SiC-Al 界面**：待计算

## 目录结构

```
.
├── Ti:TiB/                    # Ti-TiB 体系（已完成）
│   ├── model/                 # 模型文件和势函数
│   │   ├── TiB_Ti.lmp         # 界面模型
│   │   ├── Ti_cut.lmp         # 纯 Ti 模型
│   │   ├── TiB_cut.lmp        # 纯 TiB 模型
│   │   ├── TiB.meam           # MEAM 势参数
│   │   └── library.meam       # MEAM 库文件
│   ├── adhesion/              # 结合能计算
│   │   ├── 100/               # 100°C 计算结果
│   │   └── 200/               # 预留
│   ├── tensile/               # 拉伸模拟（预留）
│   └── shear/                 # 剪切模拟（预留）
│
├── SiC:Al/                    # SiC-Al 体系（待计算）
│   ├── model/                 # 模型文件
│   │   ├── SiC_Al_C.lmp       # C终止界面
│   │   ├── SiC_Al_Si.lmp      # Si终止界面
│   │   ├── Al99.eam.alloy     # Al EAM 势
│   │   └── SiC.tersoff        # SiC Tersoff 势
│   ├── adhesion/              # 结合能计算
│   ├── tensile/               # 拉伸模拟
│   └── shear/                 # 剪切模拟
│
├── reports/                   # 报告输出
│   └── Ti-TiB/
│       ├── REPORT_TiTiB_Adhesion.md
│       ├── REPORT_TiTiB_Adhesion.docx
│       └── figures/           # 图表（PNG + PDF）
│
└── scripts/                   # 脚本
    ├── run_adhesion.sh        # 集群提交脚本（多温度结合能）
    ├── run_cluster.sh         # 通用集群运行脚本
    ├── analyze_adhesion.py    # 结合能数据分析
    ├── generate_report_figures.py  # 报告图表生成
    └── *.sh                   # 其他辅助脚本
```

## 已完成工作

### Ti-TiB 界面结合能

- **温度范围**：100°C, 300°C, 500°C
- **结果**：5.05 - 5.92 J/m²
- **与文献 DFT 结果一致**：4.95 - 6.04 J/m²

计算公式：
```
W_ad = (E_interface - E_Ti - E_TiB) / A
```

## 待完成工作

1. **SiC-Al 界面结合能计算**
   - 需要创建 LAMMPS 输入脚本
   - 参考 Ti-TiB 的计算流程

## 计算参数

| 参数 | 数值 |
|------|------|
| 系综 | NPT |
| 时间步长 | 1 fs |
| 平衡步数 | 20,000 |
| 温度控制 | Nosé-Hoover |

## 运行命令

```bash
# 分析结合能数据
uv run python scripts/analyze_adhesion.py

# 生成报告图表
uv run python scripts/generate_report_figures.py

# 集群提交（在集群上）
nohup bash scripts/run_adhesion.sh > adhesion.log 2>&1 &
```

## 注意事项

- 使用 `uv run` 运行 Python 脚本
- 势函数文件在各体系的 `model/` 目录下
- 报告生成后保存在 `reports/` 目录
