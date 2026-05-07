# 显示器控制方案

## 硬件配置

- 设备：Raspberry Pi 4B（官方 5V 3A 电源）
- 显示屏：YXStar YX Display（1200x1080 驱动板）
- 连接方式：HDMI 视频信号 + USB 供电，两根线接树莓派
- 显示系统：Raspberry Pi OS Bookworm，Wayland（labwc compositor）

## 方案结论

### 为什么不用软件控制 HDMI 信号

最初尝试了 `wlopm`（DPMS 软关屏）和 `wlr-randr`（禁用输出），均不可靠：

- `wlopm --off` 可以关屏，但 `wlopm --on` 在 labwc 下有已知 bug，无法可靠唤醒
- `wlr-randr --off` 会完全禁用输出，唤醒后分辨率错误，且可能触发登录锁屏
- 上述问题是 labwc compositor 的已知 bug，与树莓派固件无关

### 最终方案：uhubctl 控制 USB 供电

驱动板通过 USB 供电，直接切断 USB 供电即可完全关闭显示器，恢复供电后驱动板自动重启并重新检测 HDMI 信号。

**Pi 4B USB 说明：**
- USB hub 所有 4 个口是绑定的（ganged），无法单独控制某一个口
- 必须整组断电：`uhubctl -l 1-1 -a off` + `uhubctl -l 2 -a off`
- 单独切某个口（`-p 1/2/3/4`）只断数据连接，不断物理供电

**供电能力：**
- Pi 4B USB 总供电上限 1.2A，驱动板需要最多 1A，满足要求
- 官方 5V 3A 电源，throttled=0x0，无欠压限流

## 分辨率配置说明

### 问题根因

YXS YX Display 的 EDID 数据不稳定，多数情况下读取为空（`/sys/class/drm/card1-HDMI-A-1/edid` size=0），驱动退化为默认 CEA 模式列表，preferred 模式为 1920x1080@60Hz，屏幕物理面板 1200x1080@90Hz 不在列表内。直接结果是系统以 1920x1080 输出，屏幕硬件缩放后画面拉伸变形、刷新率错误。

### 为什么不用 cmdline.txt 强制

`video=HDMI-A-1:1200x1080MR@90` 让内核用 CVT-RB 算出 137.9 MHz pixel clock 并注入模式列表，但 vc4-hdmi 的 `mode_valid` 拒绝了它（`User-defined mode not supported`），首次启动黑屏。该参数只解决了"模式出现在列表里"的问题，没解决"驱动接受该 timing"的问题，且引入了每次冷启动黑屏的代价，故放弃。

副作用：加了这个参数的那次启动，EDID 偶然读取成功（上电时序不同导致），由此拿到了屏幕 detailed timing 里的精确刷新率 89.973Hz。

### 为什么不用 labwc autostart 写 wlr-randr

labwc 文档说用户级 `~/.config/labwc/autostart` 存在时完全覆盖系统级，但实测两者都执行了，行为不符——具体机制不明，不可依赖。更根本的问题是：wlr-randr 要求 EDID 模式列表里存在目标模式才能切换，而 EDID 不稳定，该模式不一定出现。autostart 时机也早于 kanshi 稳定，竞态无法消除。

### 最终方案：kanshi --custom-mode

kanshi 是事件驱动的 Wayland 输出配置守护进程，已在系统级 autostart（`/etc/xdg/labwc/autostart`）中随 labwc 启动。配置文件写入 `~/.config/kanshi/config`，监听到 HDMI-A-1 接入后立即应用：

```
profile {
    output HDMI-A-1 enable mode --custom 1200x1080@89.973Hz position 0,0 scale 1.0 transform normal
}
```

`--custom` 标志让 kanshi 绕过 EDID 模式列表，直接以 CVT-RB timing 驱动输出。vc4-hdmi 在 KMS 层接受该 timing，屏幕正常显示 1200x1080@89.973Hz。

**注意事项：**
- 不要在 `~/.config/labwc/autostart` 放 wlr-randr 切换命令：labwc 若发现用户级 autostart 文件存在会覆盖系统级，导致 panel/kanshi 等不启动
- kanshi 配置改动后，无需重启，`pkill -HUP -x kanshi` 即可重载

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

两个命令可从 SSH 远程执行，无需输入密码。
