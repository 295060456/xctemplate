#!/usr/bin/env bash
#
# 将当前目录下的 *.xctemplate 模板复制到 Xcode 的 iOS 源文件模板目录中，
# 并强制关闭 Xcode。复制成功后自动在 Finder 中打开目标目录。

set -euo pipefail

# ================================== 基本配置 ==================================
SCRIPT_BASENAME=$(basename "$0" | sed 's/\.[^.]*$//')   # 当前脚本名（去掉扩展名）
LOG_FILE="/tmp/${SCRIPT_BASENAME}.log"                  # 日志文件路径（按脚本名区分）

# 每次运行前清空旧日志（如果不想清空，可删掉这一行）
: > "$LOG_FILE"

# ✅ 彩色输出函数
log()            { echo -e "$1" | tee -a "$LOG_FILE"; }
color_echo()     { log "\033[1;32m$1\033[0m"; }        # ✅ 正常绿色输出
info_echo()      { log "\033[1;34mℹ $1\033[0m"; }      # ℹ 信息
success_echo()   { log "\033[1;32m✔ $1\033[0m"; }      # ✔ 成功
warn_echo()      { log "\033[1;33m⚠ $1\033[0m"; }      # ⚠ 警告
warm_echo()      { log "\033[1;33m$1\033[0m"; }        # 🟡 温馨提示（无图标）
note_echo()      { log "\033[1;35m➤ $1\033[0m"; }      # ➤ 说明
error_echo()     { log "\033[1;31m✖ $1\033[0m"; }      # ✖ 错误
err_echo()       { log "\033[1;31m$1\033[0m"; }        # 🔴 错误纯文本
debug_echo()     { log "\033[1;35m🐞 $1\033[0m"; }     # 🐞 调试
highlight_echo() { log "\033[1;36m🔹 $1\033[0m"; }     # 🔹 高亮
gray_echo()      { log "\033[0;90m$1\033[0m"; }        # ⚫ 次要信息
bold_echo()      { log "\033[1m$1\033[0m"; }           # 📝 加粗
underline_echo() { log "\033[4m$1\033[0m"; }           # 🔗 下划线

# ================================== 目标目录与脚本目录 ==================================
# Xcode iOS 源文件模板的目标目录
DEST_DIR="/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/Library/Xcode/Templates/File Templates/iOS/Source"

# 脚本自身所在目录（而不是执行时所在目录）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# 存放当前目录中发现的 xctemplate 目录
declare -a TEMPLATES=()

# ================================== 打印自述并等待确认 ==================================
print_readme() {
  # 自述全文用 color_echo 打印（绿色 + 写日志）
  color_echo "$(cat <<'EOF'
============================================================
📄 脚本自述（请仔细阅读后再继续）
============================================================
1. 脚本运行后，会先切换到“脚本自身所在的目录”，
   而不是你当前终端所在的目录。

2. 然后会在该目录下查找所有“后缀为 .xctemplate 的文件夹”，
   也就是形如：
       MyTemplate.xctemplate
       AwesomeTemplate.xctemplate
   这类“目录名称以 .xctemplate 结尾的文件夹”。

   - 如果没有找到任何 *.xctemplate 目录，脚本会直接结束。
   - 如果找到了，则继续下一步。

3. 对于找到的每一个 *.xctemplate 目录，脚本会使用 sudo 复制到：
       /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/Library/Xcode/Templates/File Templates/iOS/Source/

   注意：
   - 因为目标目录在 /Applications 下，属于系统路径，
     所以必须使用 sudo，终端会提示你输入当前登录账号的密码。
   - 如果目标目录中已存在同名模板，cp -R 可能会覆盖/合并，
     请自行确保模板名称不会误覆盖已有内容。

4. 复制完成后，脚本会“强制关闭 Xcode”：
   - 先尝试通过 AppleScript 让 Xcode 正常退出；
   - 如 Xcode 仍在运行，则使用 killall Xcode 强制结束进程。

5. 复制成功后，脚本还会自动在 Finder 中打开：
       /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/Library/Xcode/Templates/File Templates/iOS/Source/
   方便你立刻确认模板是否已就位。

⚠️ 风险提示：
- 模板一旦复制到 Xcode 模板目录，会影响 Xcode 的“新建文件”面板。
- 强制关闭 Xcode 可能会导致未保存的工程修改丢失，请务必先保存好。

============================================================
按回车键继续执行脚本，或按 Ctrl + C 立即取消……
EOF
)"
  # 等待用户确认
  read -r _
  note_echo "已确认继续执行脚本。"
}

# ================================== 初始化：切换到脚本所在目录 ==================================
init_workdir() {
  cd "$SCRIPT_DIR"
  info_echo "已切换到脚本所在目录：$SCRIPT_DIR"
}

# ================================== 查找本地 xctemplate 模板 ==================================
find_local_templates() {
  TEMPLATES=()

  # 使用 find 查找当前目录下的 *.xctemplate 目录（仅一层）
  while IFS= read -r -d '' dir; do
    TEMPLATES+=("$dir")
  done < <(find "$SCRIPT_DIR" -maxdepth 1 -type d -name '*.xctemplate' -print0)

  if [[ ${#TEMPLATES[@]} -eq 0 ]]; then
    warn_echo "当前目录下未发现任何 *.xctemplate 目录，脚本结束。"
    exit 0
  fi

  info_echo "发现以下 xctemplate 模板目录："
  for tpl in "${TEMPLATES[@]}"; do
    gray_echo "   - $(basename "$tpl")"
  done
}

# ================================== 复制模板到 Xcode 目录 ==================================
copy_templates_to_xcode() {
  # 确认目标目录存在
  if [[ ! -d "$DEST_DIR" ]]; then
    error_echo "目标目录不存在：$DEST_DIR"
    error_echo "请确认 Xcode 是否安装在默认路径 /Applications/Xcode.app 下。"
    exit 1
  fi

  info_echo "即将使用 sudo 将模板复制到 Xcode 目录："
  underline_echo "目标目录：$DEST_DIR"
  warm_echo "可能会提示你输入当前登录用户的密码（sudo）。"

  for tpl in "${TEMPLATES[@]}"; do
    local name
    name="$(basename "$tpl")"
    sudo cp -R "$tpl" "$DEST_DIR/"
    success_echo "已复制模板：$name -> $DEST_DIR"
  done

  # ✅ 复制成功后在 Finder 中打开目标目录
  if command -v open >/dev/null 2>&1; then
    open "$DEST_DIR"
    highlight_echo "已在 Finder 中打开模板目录：$DEST_DIR"
  else
    warn_echo "系统中未找到 open 命令，请手动打开：$DEST_DIR"
  fi
}

# ================================== 强制关闭 Xcode ==================================
close_xcode() {
  info_echo "准备关闭 Xcode ..."

  if ! pgrep -x "Xcode" >/dev/null 2>&1; then
    gray_echo "检测到 Xcode 当前未运行，无需关闭。"
    return 0
  fi

  # 先尝试正常退出
  info_echo "尝试通过 AppleScript 正常退出 Xcode ..."
  if command -v osascript >/dev/null 2>&1; then
    osascript -e 'tell application "Xcode" to quit' || true
    sleep 2
  fi

  # 如果仍在运行，则强制 killall
  if pgrep -x "Xcode" >/dev/null 2>&1; then
    warn_echo "Xcode 仍在运行，使用 killall 强制结束 Xcode 进程 ..."
    killall Xcode || true
  fi

  if pgrep -x "Xcode" >/dev/null 2>&1; then
    warn_echo "Xcode 似乎仍在运行，请手动检查并关闭。"
  else
    success_echo "Xcode 已关闭。"
  fi
}

# ================================== 主函数 ==================================
main() {
  print_readme             # 打印自述并等待用户回车（用 color_echo）
  init_workdir             # 切换到脚本所在目录
  find_local_templates     # 查找当前目录下的 *.xctemplate 目录
  copy_templates_to_xcode  # 使用 sudo 复制到 Xcode 模板目录，并打开目标目录
  close_xcode              # 强制关闭 Xcode
  success_echo "全部操作已完成，可重新打开 Xcode 验证模板是否生效。"
  note_echo "本次运行日志已保存到：$LOG_FILE"
}

# 入口
main "$@"
