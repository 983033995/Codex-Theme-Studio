# Changelog

## 0.2.2 - 2026-07-20

- 将侧边栏项目文件夹统一替换为红金钱袋：收起状态显示普通钱袋，展开状态显示向外喷金元宝的钱袋并带轻量弹出动画。
- 修复首页首次生成早于侧边栏图标时，品牌、功德、统计和四张能力卡图标永久留空的问题。
- 修正历史对话右侧侧边栏状态判断：右栏展开时隐藏聚宝盆，右栏收起时恢复显示。
- 新增两张透明钱袋项目图标资产，并通过 Provider 同步脚本内联注入。

## 0.2.1 - 2026-07-20

- 恢复财神首页右下角的小型招财进宝盆，并在右侧内容面板打开或窗口高度不足时自动隐藏。
- 将首页主视觉拆分为宣纸底图与透明财神前景层，帽冠和头部可自然突破 Hero 上边框。
- 新增功德簿、金币、连续签到、效率统计图标与轻量浮动金币细节。
- 新增两张项目内置视觉资产，并在 Provider 同步时安全转换为 Data URL 注入。

## 0.2.0 - 2026-07-19

- 新增财神主题的新建任务工作台首页。
- 快捷能力卡片可将对应任务提示写入原生输入框。
- 右侧文件、差异或输出面板打开时自动隐藏招财进宝盆。
- 优化首页图标、输入区位置、侧边栏 hover 和项目标题样式。
- 修复 Theme Studio 重复进程与旧登录项迁移问题。
# 0.3.1

- Refresh the configured Gallery registry once at startup so a first-time installation can discover community themes without a manual refresh.

# 0.3.0

- Split community themes, pets, schemas, stats, and reusable theme skills into `Codex-Theme-Gallery`.
- Configure the official Gallery registry URL as the default community source.
- Decode and display contributor, download, and favorite metadata from registry entries.
- Remove bundled community registry content from the App release artifact.
