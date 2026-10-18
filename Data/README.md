# 节假日数据更新

App 固定读取本仓库 `main` 分支的 `Data/holidays.json`：

`https://raw.githubusercontent.com/nicing/mini-calendar/main/Data/holidays.json`

只更新数据时无需发布 Release 或 DMG，也无需部署服务器。用户需先升级到支持此能力的 1.2.0 或更新版本；GitHub 暂时不可访问时不会丢失本机数据。

## 发布流程

1. 核对国务院公布的正式年度通知，在 `years` 中添加或修改对应年份。不要把推测的调休安排写入数据。
2. 每年的 `source` 填写可追溯的官方 HTTPS 通知页面（`gov.cn` 或其子域名）。`days` 必须包含该年全部已公布的放假日和补班日；同年新数据会整体替换旧数据，以便移除错误日期。未列出的日期使用节日当天的离线规则。
3. 将顶层正整数 `revision` 加一。保留已有年份；客户端拒绝同版或更旧版本覆盖当前数据。需要回滚日期时也发布更大的 revision。
4. 验证 JSON，构建并运行自检，再提交到 `main`。数据在线后可运行 `.build/MiniCalendar.app/Contents/MacOS/MiniCalendar --self-test-holiday-sync` 验证实际下载和离线缓存。

字段：`schemaVersion` 目前为 `1`；`years` 以四位年份为键。每个 `days` 条目以严格的 `YYYY-MM-DD` 为键，包含 `label` 和 `kind`。`kind` 为 `festival`（节日当天）、`dayOff`（放假）、`workday`（补班）。节日当天优先填写节日名，而非“放假”。同日多个节日可使用“国庆·中秋”。

修改一个日期无需改 App 代码。`schemaVersion` 或离线计算规则发生不兼容变化时，才需要更新 App。

## 日期来源

- [2025 年安排](https://www.gov.cn/zhengce/zhengceku/202411/content_6986383.htm)
- [2026 年安排](https://www.gov.cn/zhengce/content/202511/content_7047090.htm)
- 农历日期使用 macOS Chinese Calendar，并按中国时区的民用日期计算节日，跳过闰月中的同月同日。
- [`Resources/qingming.json`](../Resources/qingming.json) 的 2025–2100 年清明日期逐年提取自[香港天文台文字对照表](https://www.hko.gov.hk/tc/gts/time/conversion1_text.htm)，例如 [2027 年](https://www.hko.gov.hk/tc/gts/time/calendar/text/files/T2027c.txt)。此表只确定节日当天，不代表中国内地年度调休安排。
