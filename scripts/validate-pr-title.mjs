#!/usr/bin/env node

const title = process.argv[2]?.trim() ?? "";
const conventional = /^(build|chore|ci|docs|feat|fix|perf|refactor|revert|test)(\([a-z0-9][a-z0-9-]*\))?!?: .{1,120}$/;

if (!conventional.test(title)) {
  throw new Error(
    "PR 标题必须遵循 Conventional Commits，例如：feat(app): 支持社区收藏统计"
  );
}

console.log(`PASS: conventional PR title: ${title}`);
