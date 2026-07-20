# Codex Theme Studio

Codex Theme Studio 是一个独立、开源的 macOS 菜单栏应用，用来浏览、安装、切换和管理 Codex 桌面主题与宠物。

它采用搜索优先、键盘友好的原生 SwiftUI 面板，支持本地包导入、GitHub 社区 registry、SHA-256 完整性校验、原子安装、登录自启和兼容主题引擎的一键修复。

## 当前能力

- 原生 `MenuBarExtra` 应用，无 Dock 图标。
- 主题、宠物、已安装三类筛选与即时搜索。
- 方向键、回车、空格、⌘1～⌘5、⌘K 快捷操作。
- GitHub `registry-v1.json`、ETag 缓存、HTTPS 下载与哈希校验。
- 主题背景支持 PNG、JPEG、WebP 和 GIF。
- Codex V2 宠物图集校验：`1536 × 2288`、`8 × 11`、每格 `192 × 208`。
- 默认登录时启动管理器，但不会主动打开 Codex。
- 当前 macOS provider 适配器可连接已安装的 Dream Skin 引擎；项目不内置或冒充该引擎源码。
- 启动时会礼貌退出仍在运行的旧 `Codex Dream Skin` 菜单管理器，避免开机后出现两个相同的调色盘图标；旧 provider 引擎与主题数据仍保留并由 Theme Studio 接管。
- Codex 在登录后以普通方式启动、导致主题调试通道缺失时，Theme Studio 会对当前 Codex 会话自动修复一次，不会循环重启。

财神主题的 provider 兼容样式维护在 `provider-overrides/`。需要同步到本机已安装引擎时运行：

```bash
node scripts/apply-provider-overrides.mjs
```

脚本只更新兼容 provider 的 CSS/渲染载荷，并使用带标记的幂等区块同步根运行时与已构建应用副本；不会修改官方 Codex 应用。右侧文件、差异或“输出”面板打开时，财神前景装饰会自动收起，避免通过左移继续遮挡正文。财神主题的新建任务页同时提供品牌状态、主题主视觉、四个财神功能卡片和原生可用的项目/输入控件；主内容区变窄时自动切换两列或单列布局。

![财神主题公开设计预览](docs/images/gallery/fortune-coder-concept.png)

## 构建与安装

```bash
./scripts/test.sh
./scripts/install-app.sh
```

应用安装到：

```text
~/Applications/Codex Theme Studio.app
```

双击应用图标会打开主题管理窗口；关闭窗口后应用继续驻留在菜单栏，再次点击应用图标可重新打开。系统重启后的登录自启只恢复菜单栏服务，不主动弹出管理窗口。

## 社区内容仓库

主题包、宠物包、Schema、统计信息和 registry 已拆分到独立仓库：

- [Codex Theme Gallery](https://github.com/983033995/Codex-Theme-Gallery)
- [主题包与宠物包规范](https://github.com/983033995/Codex-Theme-Gallery/blob/main/docs/package-spec.md)
- [GitHub registry 规范](https://github.com/983033995/Codex-Theme-Gallery/blob/main/docs/registry-spec.md)
- [财神主题制作 Skill](https://github.com/983033995/Codex-Theme-Gallery/tree/main/skills/craft-codex-theme)

App 默认读取 Gallery 的 `registry/registry-v1.json`，也允许在设置页切换为其他兼容 HTTPS 社区源。

## 安全边界

- 只接受 HTTPS 社区资源。
- 下载后校验 SHA-256、文件大小、路径、图片编码和尺寸。
- 安装采用暂存目录、原子替换和失败回滚。
- 不修改官方 `.app`、`app.asar`、签名、API Key 或 Base URL。
- provider 调试端口必须只绑定 loopback。

## 名称与归属

本仓库是新建的独立项目，不继承其他主题项目的 Git 历史、远端仓库或品牌。兼容适配关系详见 [NOTICE.md](NOTICE.md)。
