# 方案决策记录

## 为什么不用软件控制 HDMI 信号

最初试了 `wlopm`（DPMS 软关屏）和 `wlr-randr`（禁用输出），都不靠谱：

- `wlopm --off` 能关屏，但 `wlopm --on` 在 labwc 下有已知 bug，唤不醒
- `wlr-randr --off` 会彻底禁用输出，唤醒后分辨率错乱，还可能触发登录锁屏
- 这些都是 labwc compositor 的已知问题，跟树莓派固件没关系

## 为什么用 uhubctl 控制 USB 供电

驱动板由 USB 供电，直接断掉电源就能彻底关闭显示器。恢复供电后驱动板自动重启，重新检测 HDMI 信号。

### Pi 4B USB 供电细节

USB hub 所有 4 个口是绑定的（ganged），没法单控某一个口：

- 必须整组断电：`uhubctl -l 1-1 -a off` + `uhubctl -l 2 -a off`
- 单独切某个口（`-p 1/2/3/4`）只断数据连接，物理供电不会断

Pi 4B USB 总供电上限 1.2A，驱动板峰值 1A，够用。官方 5V 3A 电源下 throttled=0x0，没有欠压限流。

## 分辨率问题根因

YXS YX Display 的 EDID 数据很不稳定，多数时候读出来是空的（`/sys/class/drm/card1-HDMI-A-1/edid` size=0）。驱动退化为默认 CEA 模式列表，preferred 模式变成 1920x1080@60Hz，而屏幕物理面板是 1200x1080@90Hz，不在列表里。系统就以 1920x1080 输出，屏幕硬件缩放后画面拉伸变形，刷新率也不对。

## 为什么不用 cmdline.txt 强制分辨率

`video=HDMI-A-1:1200x1080MR@90` 会让内核用 CVT-RB 算出 137.9 MHz pixel clock 并注入模式列表，但 vc4-hdmi 的 `mode_valid` 直接拒掉了（`User-defined mode not supported`），首次启动黑屏。这个参数只解决了"模式出现在列表里"，没解决"驱动接受该 timing"。更麻烦的是它还引入每次冷启动黑屏的风险，所以放弃。

副作用：加了参数的那次启动，EDID 偶然读成功了（上电时序不同），拿到了屏幕 detailed timing 里的精确刷新率 89.973Hz。

## 为什么不用 labwc autostart 写 wlr-randr

labwc 文档说用户级 `~/.config/labwc/autostart` 存在时会完全覆盖系统级，但实测两边都执行了，行为跟文档不一致。具体机制不明，不能依赖。更根本的问题是 wlr-randr 要求目标模式必须在 EDID 模式列表里，而 EDID 不稳定，该模式不一定出现。autostart 时机也早于 kanshi 稳定，竞态消不掉。

## 为什么用 kanshi --custom-mode

kanshi 是事件驱动的 Wayland 输出配置守护进程，已在系统级 autostart（`/etc/xdg/labwc/autostart`）中随 labwc 启动。配置文件写入 `~/.config/kanshi/config`，监听到 HDMI-A-1 接入后立即应用：

```
profile {
    output HDMI-A-1 enable mode --custom 1200x1080@89.973Hz position 0,0 scale 1.0 transform normal
}
```

`--custom` 标志让 kanshi 绕过 EDID 模式列表，直接以 CVT-RB timing 驱动输出。vc4-hdmi 在 KMS 层接受该 timing，屏幕正常显示 1200x1080@89.973Hz。

### 注意事项

不要在 `~/.config/labwc/autostart` 里放 wlr-randr 切换命令。labwc 若发现用户级 autostart 文件存在会覆盖系统级，导致 panel/kanshi 等不启动。kanshi 配置改动后不用重启，`pkill -HUP -x kanshi` 即可重载。
