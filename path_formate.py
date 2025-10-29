# -*- coding: utf-8 -*-
import os
import platform
from pathlib import Path

# ==============================================================================
# █████████████████████████ 用户配置区 START █████████████████████████████
#
# --- 区域 1: 直接添加的完整路径 (常量路径) ---
# 将不需要任何处理的完整路径放入此列表。
DIRECT_PATHS = [
    # 示例: r"C:\Program Files\Git\bin",
]

# --- 区域 2: 定义路径拼接的 "根目录" (占位符) ---
# 在这里定义所有基础目录的占位符。
# 值是您系统上的实际根目录路径。
BASE_DIRECTORIES = {
    "CONDA_HOME": r"D:Software\miniconda3", # <-- 注意: 请确保这个路径是正确的
    "PYTHON_HOME": r"",
}

# --- 区域 3: 定义路径拼接的 "模板" ---
# 使用正斜杠 `/`, pathlib 会自动为您的系统转换。
PATH_TEMPLATES = [
    # Conda 相关路径
    "{CONDA_HOME}",
    "{CONDA_HOME}/Scripts",
    "{CONDA_HOME}/Library/bin",
    "{CONDA_HOME}/Library/mingw-w64/bin",
    "{CONDA_HOME}/condabin",

    # Python 相关路径
    "{PYTHON_HOME}",
    "{PYTHON_HOME}/Scripts",
]
# █████████████████████████ 用户配置区 END ███████████████████████████████
# ==============================================================================


def generate_and_validate_paths() -> list[Path]:
    """
    根据用户配置生成所有路径, 验证它们是否存在, 并返回一个仅包含有效路径的列表。
    """
    valid_paths = []
    processed_paths_tracker = set()

    print("\n--- 阶段 1: 验证所有已配置的路径 ---")

    # --- 处理直接路径 ---
    for path_str in DIRECT_PATHS:
        if not path_str:
            continue
        path_obj = Path(path_str)
        if path_obj.exists():
            resolved_path = path_obj.resolve()
            if resolved_path not in processed_paths_tracker:
                print(f"[ OK ] 路径存在: {resolved_path}")
                valid_paths.append(resolved_path)
                processed_paths_tracker.add(resolved_path)
        else:
            print(f"[FAIL] 路径不存在, 已忽略: {path_obj}")

    # --- 处理拼接路径 ---
    for template in PATH_TEMPLATES:
        try:
            used_bases = {
                key: val for key, val in BASE_DIRECTORIES.items()
                if f"{{{key}}}" in template and val
            }
            if not used_bases:
                continue

            formatted_path_str = template.format(**BASE_DIRECTORIES)
            path_obj = Path(formatted_path_str)

            if path_obj.exists():
                resolved_path = path_obj.resolve()
                if resolved_path not in processed_paths_tracker:
                    print(f"[ OK ] 路径存在: {resolved_path}")
                    valid_paths.append(resolved_path)
                    processed_paths_tracker.add(resolved_path)
            else:
                if any(BASE_DIRECTORIES.get(key) for key in BASE_DIRECTORIES if f"{{{key}}}" in template):
                    print(f"[FAIL] 路径不存在, 已忽略: {path_obj}")

        except KeyError as e:
            print(f"[错误] 模板 '{template}' 使用了未定义的占位符: {e}")
        except Exception as e:
            print(f"[严重错误] 处理模板 '{template}' 时出错: {e}")

    return valid_paths


def main():
    """主函数"""
    os_type = platform.system()
    path_separator = ';' if os_type == 'Windows' else ':'

    print("=" * 70)
    print(f"欢迎使用环境变量设置助手 (操作系统: {os_type})")
    print("=" * 70)

    # 阶段 1: 生成并验证所有路径
    valid_existing_paths = generate_and_validate_paths()

    # 阶段 2: 与现有环境对比 (现在总是执行)
    print("\n--- 阶段 2: 将有效路径与当前系统 PATH 对比 ---")
    current_path_env = os.environ.get('PATH', '')
    existing_paths_set = {
        str(Path(p).resolve()) for p in current_path_env.split(path_separator) if p
    }

    final_paths_to_add = [
        p for p in valid_existing_paths if str(p.resolve()) not in existing_paths_set
    ]

    # 阶段 3: 结论与操作 (基于前两阶段的综合结果)
    print("\n--- 阶段 3: 最终结论与操作 ---")

    # 检查是否有需要添加的新路径
    if not final_paths_to_add:
        # 如果没有新路径, 给出具体原因
        if not valid_existing_paths:
            print("[结论] 您的配置中没有找到任何实际存在的有效路径。")
        else:
            print("[成功] 所有在您配置中且真实存在的路径, 都已经注册在系统的 PATH 变量中。")
        print("无需执行任何操作。")
        return # 结束程序

    # 如果有新路径, 则显示分析并请求确认
    print("[分析] 以下新路径将被添加到您的 PATH 环境变量的最前端:")
    for p in final_paths_to_add:
        print(f"  - {p}")
    print("-" * 70)

    try:
        choice = input("\n[确认操作] 是否要继续并生成注册命令? (输入 y 继续, 其他任意键取消): ")
    except KeyboardInterrupt:
        print("\n\n操作被用户中断。程序退出。")
        return

    if choice.lower().strip() != 'y':
        print("\n操作已取消。程序退出。")
        return

    # 用户确认后, 生成命令
    print("\n[正在生成命令...]")
    final_path_strings = [str(p) for p in final_paths_to_add]
    new_path_segment = path_separator.join(final_path_strings)

    print("\n" + "="*25 + " 请执行以下操作 " + "="*25)

    if os_type == 'Windows':
        new_full_path = f"{new_path_segment}{path_separator}{current_path_env}"
        print("\n[操作指南 for Windows]")
        print("1. 复制下面 'setx' 开头的整条命令。")
        print("2. 打开一个新的 '命令提示符(cmd)' 或 'PowerShell' 窗口并执行。")
        print("   (此命令为当前用户永久设置, 重启终端后生效)\n")
        print("-" * 70)
        print(f'setx PATH "{new_full_path}"')
        print("-" * 70)
        print("\n[重要] 执行后, 请务必关闭并重新打开所有终端窗口。")
    else:  # macOS / Linux
        shell_name = Path(os.environ.get('SHELL', 'bash')).name
        if 'zsh' in shell_name:
            profile_file = "~/.zshrc"
        elif 'bash' in shell_name:
            profile_file = "~/.bash_profile"
        else:
            profile_file = "您的 shell 配置文件 (例如 ~/.profile)"

        print(f"\n[操作指南 for macOS / Linux (Shell: {shell_name})]")
        print(f"1. 复制下面 'echo' 开头的整条命令并执行。")
        print(f"   (此命令会将设置追加到您的配置文件 '{profile_file}')\n")

        export_command = f'export PATH="{new_path_segment}:$PATH"'
        full_command = f"echo '\n# Added by environment setup script\n{export_command}' >> {profile_file}"

        print("-" * 70)
        print(full_command)
        print("-" * 70)
        print(f"\n2. 执行后, 运行 `source {profile_file}` 或重启终端使设置生效。")

if __name__ == '__main__':
    main()