#!/bin/bash
# 重装系统后运行此脚本，自动恢复显示器控制配置
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "1. 安装 uhubctl..."
sudo apt-get install -y uhubctl

echo "2. 配置 sudo 免密..."
echo 'one-week ALL=(ALL) NOPASSWD: /usr/bin/uhubctl' | sudo tee /etc/sudoers.d/uhubctl

echo "3. 安装控制脚本..."
mkdir -p ~/.local/bin
cp "$SCRIPT_DIR/display-off" "$SCRIPT_DIR/display-on" ~/.local/bin/
chmod +x ~/.local/bin/display-off ~/.local/bin/display-on

echo "4. 添加 ~/.local/bin 到 PATH..."
fish -c "fish_add_path ~/.local/bin" 2>/dev/null || echo "  (非 fish shell，请手动将 ~/.local/bin 加入 PATH)"

echo "5. 配置 kanshi 分辨率..."
mkdir -p ~/.config/kanshi
cp "$SCRIPT_DIR/kanshi-config" ~/.config/kanshi/config

echo "完成。重新登录后即可使用 display-off / display-on 命令。"
