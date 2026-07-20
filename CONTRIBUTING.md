# 贡献指南

本仓库只接收 Theme Studio App、macOS 生命周期、Provider 适配、安装安全和 GitHub 投稿客户端相关代码。

主题、宠物、预览图和内容包规范请提交到 [Codex Theme Gallery](https://github.com/983033995/Codex-Theme-Gallery)。

## 开发检查

```bash
./scripts/test.sh
./scripts/build-app.sh
```

- Swift 与 Shell 保持现有两空格缩进。
- 不修改官方 Codex `.app`、`app.asar`、签名、API Key 或 Base URL。
- GitHub Token 必须来自用户授权并存入 macOS Keychain；禁止内置维护者 Token。
- 用户内容上传必须进入贡献者 Fork 和 Pull Request，不能直接写 Gallery 主分支。

## 提交格式

```text
feat(app): add GitHub contribution flow
fix(registry): preserve cached community metadata
fix(provider): protect right-panel safe area
```
