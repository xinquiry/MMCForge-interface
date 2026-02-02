#!/usr/bin/env python3
"""
Ti:TiB 结合能分析脚本
计算不同温度下的界面结合能 (adhesion energy)
"""

import os
import re

# 界面尺寸 (从 TiB_Ti_interface.data 文件)
# x: 0-300 Å (界面法向)
# y: 0-250.2353 Å
# z: 0-177.84663 Å
Y_SIZE = 250.2353  # Å
Z_SIZE = 177.84663  # Å
AREA = Y_SIZE * Z_SIZE  # Å²

# 单位转换: 1 eV/Å² = 16.0218 J/m²
EV_A2_TO_J_M2 = 16.0218

# 温度列表
TEMPS = [373, 573, 773]
TEMPS_C = [100, 300, 500]

def read_energy(filepath):
    """从results.txt或log文件读取能量"""
    if not os.path.exists(filepath):
        return None
    with open(filepath, 'r') as f:
        content = f.read()
    # 匹配 FINAL_PE_xxx 格式
    match = re.search(r'FINAL_PE_\w+\s+([-\d.]+)', content)
    if match:
        return float(match.group(1))
    return None

def main():
    base_dir = os.path.dirname(os.path.abspath(__file__))

    print("=" * 60)
    print("Ti:TiB 界面结合能分析")
    print("=" * 60)
    print(f"\n界面面积: {AREA:.2f} Å² ({AREA/100:.2f} nm²)")
    print()

    # 收集数据
    results = []

    print("-" * 60)
    print(f"{'温度':^12} {'E_interface':^16} {'E_Ti':^16} {'E_TiB':^16}")
    print(f"{'':^12} {'(eV)':^16} {'(eV)':^16} {'(eV)':^16}")
    print("-" * 60)

    for T, T_C in zip(TEMPS, TEMPS_C):
        work_dir = os.path.join(base_dir, f"Ti:TiB/adhesion/{T}K")

        E_interface = read_energy(os.path.join(work_dir, "interface.log"))
        E_Ti = read_energy(os.path.join(work_dir, "Ti.log"))
        E_TiB = read_energy(os.path.join(work_dir, "TiB.log"))

        print(f"{T_C}°C ({T}K)  ", end="")
        print(f"{E_interface if E_interface else 'N/A':^16}", end="")
        print(f"{E_Ti if E_Ti else 'N/A':^16}", end="")
        print(f"{E_TiB if E_TiB else 'N/A':^16}")

        if E_interface and E_Ti and E_TiB:
            results.append({
                'T': T,
                'T_C': T_C,
                'E_interface': E_interface,
                'E_Ti': E_Ti,
                'E_TiB': E_TiB
            })

    print("-" * 60)
    print()

    if not results:
        print("没有完整的数据可以计算结合能")
        return

    # 计算结合能
    print("=" * 60)
    print("结合能计算结果")
    print("公式: W_ad = (E_interface - E_Ti - E_TiB) / A")
    print("=" * 60)
    print()
    print("-" * 60)
    print(f"{'温度':^12} {'ΔE (eV)':^16} {'W_ad (eV/Å²)':^16} {'W_ad (J/m²)':^16}")
    print("-" * 60)

    for r in results:
        delta_E = r['E_interface'] - r['E_Ti'] - r['E_TiB']
        W_ad_eV = delta_E / AREA  # eV/Å²
        W_ad_J = W_ad_eV * EV_A2_TO_J_M2  # J/m²

        r['delta_E'] = delta_E
        r['W_ad_eV'] = W_ad_eV
        r['W_ad_J'] = W_ad_J

        print(f"{r['T_C']}°C ({r['T']}K)  {delta_E:^16.2f} {W_ad_eV:^16.6f} {W_ad_J:^16.4f}")

    print("-" * 60)
    print()

    # 输出报告格式
    print("=" * 60)
    print("报告用表格 (Markdown格式)")
    print("=" * 60)
    print()
    print("| 温度 (°C) | 温度 (K) | 结合能 (J/m²) |")
    print("|-----------|----------|---------------|")
    for r in results:
        print(f"| {r['T_C']} | {r['T']} | {r['W_ad_J']:.4f} |")
    print()

    # 分析趋势
    if len(results) >= 2:
        print("=" * 60)
        print("趋势分析")
        print("=" * 60)
        W_values = [r['W_ad_J'] for r in results]
        if W_values[0] < W_values[-1]:
            trend = "随温度升高而增加"
        else:
            trend = "随温度升高而降低"
        print(f"结合能{trend}")
        print(f"最大值: {max(W_values):.4f} J/m² @ {results[W_values.index(max(W_values))]['T_C']}°C")
        print(f"最小值: {min(W_values):.4f} J/m² @ {results[W_values.index(min(W_values))]['T_C']}°C")

if __name__ == "__main__":
    main()
