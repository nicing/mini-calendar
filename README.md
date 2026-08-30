# 极简日历

一个带独立窄栏窗口和菜单栏入口的原生 macOS 日历：动态日期图标、月历、农历、中国法定节假日/调休、系统日历日程，以及系统提醒事项。界面使用 AppKit 实现，无第三方依赖。

窗口会自动跟随 macOS 的亮色/暗色外观。macOS 26 及以上使用原生 Liquid Glass，macOS 14–15 使用系统模糊半透明材质回退。

在日历区域向上滑动可将月视图收起为当周 7 天；周视图中左右箭头按周切换。向下滑动恢复月视图。手势按触控板物理方向识别，不受“自然滚动”设置影响。

在日历区域向左滑动可切换到下一周或下一月，向右滑动可切换到上一周或上一月；一次手势只切换一个周期。

周/月视图切换使用选中周作为视觉锚点：月历行收拢或展开，待办区域同步移动；系统开启“减少动态效果”时自动改为短淡化。

## 运行

需要 macOS 14 或更高版本和 Command Line Tools。生成可直接打开的 `.app`：

界面中的数字和英文使用 MiSans Latin。请先从[小米官方页面](https://hyperos.mi.com/font/en/download/)下载字体，将可变字体文件 `MiSansLatinVF.ttf` 放入 `Resources/`。字体文件受[小米 MiSans 字体知识产权许可协议](https://hyperos.mi.com/font-download/MiSans%E5%AD%97%E4%BD%93%E7%9F%A5%E8%AF%86%E4%BA%A7%E6%9D%83%E8%AE%B8%E5%8F%AF%E5%8D%8F%E8%AE%AE.pdf)约束，不包含在本仓库中。

```bash
chmod +x Scripts/build-app.sh
Scripts/build-app.sh
open .build/MiniCalendar.app
```

运行内置的数据与日期回归测试：

```bash
.build/MiniCalendar.app/Contents/MacOS/MiniCalendar --self-test
```

应用使用 `accessory` 激活策略，不显示 Dock 图标。启动后显示独立窄栏窗口，切换到其他应用时不会自动关闭；点击菜单栏中的日期日历图标可显示或收起窗口，右下角菜单可退出。

如果使用 Hidden Bar、Ice 或 Bartender 等菜单栏整理工具，新安装的图标可能会自动进入隐藏区。先展开隐藏区，再按住 `⌘` 将日期日历图标拖到常驻区域即可。

## 系统日历与提醒事项

- 首次启动时，macOS 会分别请求“提醒事项”和“日历”权限。
- App 中新增、完成和删除的待办直接写入系统“提醒事项”，优先使用名为“极简日历”的提醒列表。
- App 会读取所有系统提醒列表；没有日期的未完成提醒显示在“今天”。
- 系统日历中的日程按所选日期只读展示，App 不提供创建、修改或删除日程的功能。
- 系统数据发生变化时，App 会通过 EventKit 变更通知自动刷新。
- 升级前保存在 `UserDefaults` 的本地待办，会在首次获得提醒事项权限后迁移到系统提醒事项并删除本地副本。

## 日期数据

- 农历由 macOS 自带的 `Calendar(identifier: .chinese)` 离线计算。
- 2025 年放假与调休来自[国务院办公厅通知（国办发明电〔2024〕12号）](https://www.gov.cn/zhengce/zhengceku/202411/content_6986383.htm)。
- 2026 年放假与调休来自[国务院办公厅通知（国办发明电〔2025〕7号）](https://www.gov.cn/zhengce/content/202511/content_7047090.htm)。
- 尚未公布的年份只显示农历，不猜测调休安排。

跨设备同步由用户已在 macOS 中配置的 iCloud、Google 或 Exchange 等系统账户负责，App 不保存账户凭据。
