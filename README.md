# 极简日历

一个带独立窄栏窗口和菜单栏入口的原生 macOS 日历：动态日期图标、月历、农历、中国法定节假日/调休、系统日历日程，以及系统提醒事项。界面使用 AppKit 实现，无第三方依赖。

窗口会自动跟随 macOS 的亮色/暗色外观，使用实色背景。

在面板上向上滑动可将月视图收起为当周 7 天；周视图中左右箭头按周切换。向下滑动恢复月视图。事项列表较长时，列表区域优先滚动内容，滚到边缘后继续滑动可切换周/月视图。手势按触控板物理方向识别，不受“自然滚动”设置影响。

在日历区域向左滑动可切换到下一周或下一月，向右滑动可切换到上一周或上一月；一次手势只切换一个周期。

周/月视图切换使用选中周作为视觉锚点：月历行收拢或展开，待办区域同步移动；系统开启“减少动态效果”时自动改为短淡化。

## 运行

可从 [GitHub Releases](https://github.com/nicing/mini-calendar/releases) 下载 DMG，将「极简日历.app」拖入「应用程序」。App 需要 macOS 14 或更高版本。

从源码构建需要 Command Line Tools。生成可直接打开的 `.app`：

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

应用使用 `accessory` 激活策略，不显示 Dock 图标。启动后显示独立窄栏窗口，切换到其他应用时收起面板；点击菜单栏中的日期日历图标可显示或收起窗口，右下角菜单可退出。

App 会在启动后和持续运行期间每天检查一次 GitHub 上带 DMG 的正式发布版本。发现新版本时会提示并打开下载页；同一版本的自动提示只出现一次。也可以在右下角菜单中选择「检查更新…」。

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
- 每年离线标注元旦、劳动节、国庆，以及按农历计算的除夕、春节、端午、中秋。尚未获得正式安排时，只标注节日当天，不推测连休或补班。
- 清明日期采用[香港天文台对照表](https://www.hko.gov.hk/tc/gts/time/conversion1_text.htm)，内置 2025–2100 年。
- 正式放假安排保存在 [`Data/holidays.json`](Data/holidays.json)。App 启动、重新打开面板及持续运行期间会在需要时从 GitHub 检查，成功缓存后 24 小时内不重复下载；失败至少间隔一小时再试。更新后自动刷新界面。
- 数据先经过格式、日期和版本校验，再保存到 `~/Library/Application Support/MiniCalendar/holidays.json`。离线或下载失败时保留缓存；无有效缓存时使用内置安排和节日规则。
- 后续只增加或修正假期数据不需要发布 App 新版：更新 JSON 并递增 `revision` 即可。使用现有 GitHub 仓库托管，无需自建服务器；日历显示规则或数据格式变化仍需要升级 App。维护方法见 [`Data/README.md`](Data/README.md)。

跨设备同步由用户已在 macOS 中配置的 iCloud、Google 或 Exchange 等系统账户负责，App 不保存账户凭据。
