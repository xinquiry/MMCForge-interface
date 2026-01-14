# 脚本测试报告

## 测试环境

- **平台**: macOS Darwin 24.6.0
- **LAMMPS版本**: 22 Jul 2025 - Update 2
- **可执行文件**: `lmp_serial`, `lmp_mpi`

---

## 测试结果汇总

| 体系 | adhesion | tensile/tension | shear |
|------|----------|-----------------|-------|
| Ti:TiB | ✅ 通过 | ❌ 失败 | ❌ 失败 |
| SiC:Al | ✅ 通过 | ❌ 失败 | ❌ 失败 |

---

## 发现的问题

### 问题 1: compute reduce 语法错误 (严重)

**位置**: 所有 tensile/shear 脚本

**错误信息**:
```
ERROR: Illegal compute reduce argument: c_st[1]/vol/10000 (src/compute_reduce.cpp:190)
Last input line: compute s all reduce sum c_st[1]/vol/10000
```

**原因**: `compute reduce` 不支持在参数中直接进行数学运算

**错误代码**:
```lammps
compute s all reduce sum c_st[1]/vol/10000  # 错误!
```

**修复方案**:
```lammps
compute s_raw all reduce sum c_st[1]
variable s equal c_s_raw/vol/10000
```

### 问题 2: 变量 ${pr} 未定义 (严重)

**位置**: 所有 tensile/shear 脚本

**错误代码**:
```lammps
fix out all print 10000 "${eps}   ${pr}" append stress_strain.txt screen no
```

**原因**: `${pr}` 从未定义，应该使用计算得到的应力变量

**修复方案**:
```lammps
fix out all print 10000 "${eps}   ${s}" append stress_strain.txt screen no
```

---

## 需要修复的文件

### Ti:TiB 体系

1. `Ti:TiB/tension/100/in.interface.rerun`
2. `Ti:TiB/shear/100/in.interface.rerun`

### SiC:Al 体系

1. `SiC:Al/tensile/100/in.interface.rerun`
2. `SiC:Al/shear/100/in.interface.rerun`

---

## 修复后的脚本示例

以 `Ti:TiB/tension/100/in.interface.rerun` 为例：

```lammps
# ... 前面的代码不变 ...

compute Temp all temp
compute ppe all pe
compute st all stress/atom NULL

# 修复: 分两步计算应力
compute s_raw all reduce sum c_st[1]
variable s equal c_s_raw/vol/10000

variable eps equal (step)*1e-7

#Compression
thermo 1000
thermo_style custom step temp pe ke etotal pxx pyy pzz lx ly lz
fix nvt all nvt temp $T $T 0.1
fix shearfix upper move linear 3e-2 0 0
fix freezee lower move linear 0 0 0

# 修复: 使用正确的变量名 ${s}
fix out all print 10000 "${eps}   ${s}" append stress_strain.txt screen no

dump 1 all atom 25000 dump.*.atom
timestep 0.001
run 2000000
```

---

## 下一步操作

1. 修复上述4个脚本文件
2. 重新运行 `./quick_test.sh` 验证修复
3. 在Mac上完整运行 adhesion 测试（约10-15分钟）
4. 同步到集群运行完整工作流

---

## 运行时间估算

基于测试观察（Ti:TiB体系约100万原子）：

| 模拟类型 | 步数 | Mac单核预估 |
|---------|------|------------|
| adhesion | 100,000 | 15-20 分钟 |
| tensile | 2,000,000 | 5-6 小时 |
| shear | 2,000,000 | 5-6 小时 |

**建议**: tensile 和 shear 在集群上运行
