#!/usr/bin/env python3
"""
SiC:Al 结合能分析脚本
计算不同温度和界面类型下的界面结合能 (adhesion energy)
"""

import os
import re

# 界面尺寸 (从 SiC_Al_C.lmp 文件)
# x: 0-246.299 Å
# y: 0-213.301 Å
# z: -100 to 401.65 Å (界面法向)
X_SIZE = 246.299052  # Å
Y_SIZE = 213.301236  # Å
AREA = X_SIZE * Y_SIZE  # Å²

# 单位转换: 1 eV/Å² = 16.0218 J/m²
EV_A2_TO_J_M2 = 16.0218

# 温度列表
TEMPS = [373, 573, 773]
TEMPS_C = [100, 300, 500]

# 界面类型
INTERFACE_TYPES = ["C", "Si"]


def read_energy(filepath, key):
    """从results.txt或log文件读取能量"""
    if not os.path.exists(filepath):
        return None
    with open(filepath, 'r') as f:
        content = f.read()
    # 匹配 FINAL_PE_xxx 格式
    match = re.search(rf'FINAL_PE_{key}\s+([-\d.eE+]+)', content)
    if match:
        return float(match.group(1))
    return None


def main():
    base_dir = os.path.dirname(os.path.abspath(__file__))

    print("=" * 70)
    print("SiC:Al 界面结合能分析")
    print("=" * 70)
    print(f"\n界面面积: {AREA:.2f} Å² ({AREA/100:.2f} nm²)")
    print()

    # 收集所有数据
    all_results = {}

    for itype in INTERFACE_TYPES:
        print("-" * 70)
        print(f"界面类型: {itype}终止")
        print("-" * 70)
        print(f"{'温度':^12} {'E_interface':^18} {'E_Al':^18} {'E_SiC':^18}")
        print(f"{'':^12} {'(eV)':^18} {'(eV)':^18} {'(eV)':^18}")
        print("-" * 70)

        results = []

        for T, T_C in zip(TEMPS, TEMPS_C):
            work_dir = os.path.join(base_dir, f"SiC:Al/adhesion/{T}K_{itype}")

            # 读取能量数据
            results_file = os.path.join(work_dir, "results.txt")

            E_interface = read_energy(results_file, "INTERFACE")
            E_Al = read_energy(results_file, "AL")
            E_SiC = read_energy(results_file, "SIC")

            print(f"{T_C}°C ({T}K)  ", end="")
            print(f"{E_interface if E_interface else 'N/A':^18}", end="")
            print(f"{E_Al if E_Al else 'N/A':^18}", end="")
            print(f"{E_SiC if E_SiC else 'N/A':^18}")

            if E_interface and E_Al and E_SiC:
                results.append({
                    'T': T,
                    'T_C': T_C,
                    'E_interface': E_interface,
                    'E_Al': E_Al,
                    'E_SiC': E_SiC
                })

        print("-" * 70)
        all_results[itype] = results
        print()

    # 计算结合能
    print("=" * 70)
    print("结合能计算结果")
    print("公式: W_ad = (E_interface - E_Al - E_SiC) / A")
    print("=" * 70)
    print()

    for itype in INTERFACE_TYPES:
        results = all_results[itype]
        if not results:
            print(f"{itype}终止: 没有完整的数据")
            continue

        print("-" * 70)
        print(f"界面类型: {itype}终止")
        print("-" * 70)
        print(f"{'温度':^12} {'ΔE (eV)':^16} {'W_ad (eV/Å²)':^18} {'W_ad (J/m²)':^16}")
        print("-" * 70)

        for r in results:
            delta_E = r['E_interface'] - r['E_Al'] - r['E_SiC']
            W_ad_eV = delta_E / AREA  # eV/Å²
            W_ad_J = W_ad_eV * EV_A2_TO_J_M2  # J/m²

            r['delta_E'] = delta_E
            r['W_ad_eV'] = W_ad_eV
            r['W_ad_J'] = W_ad_J

            print(f"{r['T_C']}°C ({r['T']}K)  {delta_E:^16.2f} {W_ad_eV:^18.6f} {W_ad_J:^16.4f}")

        print("-" * 70)
        print()

    # 输出报告格式
    print("=" * 70)
    print("报告用表格 (Markdown格式)")
    print("=" * 70)
    print()
    print("| 界面类型 | 温度 (°C) | 温度 (K) | 结合能 (J/m²) |")
    print("|----------|-----------|----------|---------------|")
    for itype in INTERFACE_TYPES:
        for r in all_results[itype]:
            print(f"| {itype}终止 | {r['T_C']} | {r['T']} | {r['W_ad_J']:.4f} |")
    print()

    # 对比分析
    if all(len(all_results[t]) >= 2 for t in INTERFACE_TYPES):
        print("=" * 70)
        print("对比分析")
        print("=" * 70)

        for itype in INTERFACE_TYPES:
            W_values = [r['W_ad_J'] for r in all_results[itype]]
            if W_values:
                print(f"\n{itype}终止界面:")
                print(f"  平均结合能: {sum(W_values)/len(W_values):.4f} J/m²")
                print(f"  最大值: {max(W_values):.4f} J/m²")
                print(f"  最小值: {min(W_values):.4f} J/m²")


if __name__ == "__main__":
    main()
