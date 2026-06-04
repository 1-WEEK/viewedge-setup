# 显示器控制方案

## 硬件配置

- 设备：Raspberry Pi 4B（官方 5V 3A 电源）
- 显示屏：YXStar YX Display（1200x1080 驱动板）
- 连接方式：HDMI 视频信号 + USB 供电，两根线接树莓派
- 显示系统：Raspberry Pi OS Bookworm，Wayland（labwc compositor）

## 方案概述

### 显示器开关

驱动板由 USB 供电，uhubctl 整组断电就能关闭显示器。恢复供电后驱动板自动重启，重新检测 HDMI 信号。

### 分辨率配置

kanshi 监听 HDMI 接入事件，用 `--custom` 模式强制输出 1200x1080@89.973Hz，绕过不稳定的 EDID。

详细原因和排障过程见 [DECISIONS.md](DECISIONS.md)。

## 文件说明

| 文件 | 说明 |
|------|------|
| `display-off` | 关闭显示器（断 USB 供电） |
| `display-on` | 开启显示器（恢复 USB 供电） |
| `kanshi-config` | 显示器分辨率配置（1200x1080@89.973Hz 自定义模式） |
| `setup.sh` | 重装系统后一键恢复所有配置 |

## 重装系统后恢复步骤

```bash
bash ~/Documents/viewedge-setup/setup.sh
```

setup.sh 会自动完成：

1. 安装 uhubctl
2. 配置 sudo 免密（`/etc/sudoers.d/uhubctl`）
3. 安装 display-off / display-on 到 `~/.local/bin/`
4. 添加 `~/.local/bin` 到 fish PATH
5. 复制 kanshi 分辨率配置到 `~/.config/kanshi/config`

## 日常使用

```bash
display-off   # 关闭显示器
display-on    # 开启显示器
```

两个命令可以从 SSH 远程执行，无需输入密码。
