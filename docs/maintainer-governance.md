# Theme Studio 审核与发布规则

所有人工功能、运行时注入、Provider 配置与发布流程变更使用 Pull Request，并采用 Conventional Commits 标题。审核必须确认 `./scripts/test.sh` 和 App bundle 构建通过，且不引入凭证、用户数据、遥测、官方 App 二进制修改或不必要的网络权限。

带有版本标签 `v*` 的合并提交会触发 macOS Release：校验 `VERSION`、构建并签名 App bundle、生成 ZIP 与 SHA-256、发布 GitHub Release。Gallery 下载量和收藏量由公开 Registry 驱动；App 不持久化跨用户的个人收藏状态。

单维护者仓库使用 CODEOWNERS、必过 CI 和标题校验作为审核记录。若后续加入独立维护者，应在 GitHub 分支规则中启用至少一名非作者批准；当前不强制该项，避免无人可审批时阻塞紧急修复。
