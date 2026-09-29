---
name: notes-memo
version: 1.0.0
description: 在 macOS「备忘录」App 快速写备忘录：AppleScript 直连（约 1–2 秒写入，比 UI 自动化快一个数量级），正文可自动润色后再写入，写入后回读硬校验，支持查找/更新/按 id 删除；触发词：写一篇备忘录、记个备忘录、存到备忘录、把这段整理成备忘录
author: Qoder
tags: [macos, notes, 备忘录, applescript, memo]
tools: [bash, osascript]
---

# 备忘录写作（macOS 备忘录 App）

把「给一段内容 → 自动润色 → 存进备忘录」变成秒级流程。**不走 UI 自动化**：用 AppleScript 直连备忘录数据层，不要求窗口在前台，写入后回读校验，失败会明确报错。

## 触发条件
当用户提出以下请求时激活此技能：
- "写一篇备忘录" / "记个备忘录" / "帮我记一下"
- "存到备忘录" / "把这段整理成备忘录" / "润色一下存备忘录"

## 前置条件
- macOS 简体中文环境；已登录 iCloud 且「备忘录」App 可用
- 首次运行若报 `-1743`（未授权自动化）：系统设置 → 隐私与安全性 → 自动化 → 允许终端 / Qoder 控制「备忘录」；无法授权时按「失败恢复」走 computer-use 兜底

## 参数
- body_file（必填）：正文文本文件（UTF-8）。**第一行 = 标题**，其余为正文；空行会保留
- folder（可选）：目标文件夹，默认 iCloud 下 "Notes"（中文界面显示为「备忘录」）
- account（可选）：账户名，默认 "iCloud"
- note_id（可选）：传入则**更新**该条目（而不是新建）

## 执行流程

### 第 1 步：自动润色，写入正文文件
把用户给的内容润色成适合备忘录的中文，写入 /tmp/memo_body.txt：

- 第一行：短标题（≤ 20 字）
- 默认整理为结构化清单：`一、二、三` 分节，节内用 `1. 2. 3.`；节与节之间空一行
- 保留用户全部原始事实（时间、地点、数字）；只改表达不改信息，**不编造细节**
- 内容是成稿 → 只做轻量润色（错别字、标点、换行）；用户说"原样写入/别润色" → 一字不改
- 内容很短（一两句）→ 精简润色即可，不要为格式强行分节
- 随笔/感想类保持口语风格，不强加分节
- 不写敏感信息（证件号、账号、卡号）；不加 emoji（除非用户要求）

用 heredoc 写入（避免转义问题）：
```bash
cat > /tmp/memo_body.txt << 'EOF'
个人生活计划

一、健康
1. 每周跑步三次，每次 30 分钟
2. 晚上 11 点前睡
EOF
```

### 第 2 步：写入备忘录（硬校验）
```bash
osascript ~/.qoder-cn/skills/notes-memo/scripts/memo_write.applescript /tmp/memo_body.txt
```
- 成功输出 `MEMO_OK id=… name=… folder=… chars=…`
- 输出 `MEMO_FAIL ...` **绝不能当成功**；按「错误处理」表处理
- 只有看到 MEMO_OK 才能向用户报"已写入"

### 第 3 步：回报用户
汇报标题、所在文件夹、字数；如用户要改，带 note_id 重跑第 2 步（见「更新」）。

## 查找 / 更新 / 删除

查找（按标题或正文关键词）：
```bash
osascript ~/.qoder-cn/skills/notes-memo/scripts/memo_find.applescript "关键词"
```
输出 `HIT id=… | 标题 | folder: … | account: … | modified: …`；无结果输出 `NO_HIT`。
（结果里 folder 为 `Recently Deleted` 的是「最近删除」里的条目）

更新（正文文件换成新内容，第 4 参数传 id；第 2、3 参数用 `""` 占位走默认文件夹/账户）：
```bash
osascript ~/.qoder-cn/skills/notes-memo/scripts/memo_write.applescript /tmp/memo_body.txt "" "" "x-coredata://…/ICNote/p66"
```

删除（仅接受精确 id）：
```bash
osascript ~/.qoder-cn/skills/notes-memo/scripts/memo_delete.applescript "x-coredata://…/ICNote/p66"
```
- 默认删除 = 移入「最近删除」（30 天内可恢复），输出 `DELETE_OK … trash=Recently Deleted/iCloud`
- 彻底清除（不可恢复）：追加第 2 参数 `purge`——**仅当用户明确要求"彻底删除"时**使用
- **仅当用户明确要求删除时执行**；脚本拒绝非 `x-coredata://…/ICNote/p…` 格式，绝不按标题模糊删

## 错误处理
| 场景 | 处理 |
|------|------|
| -1743（未授权自动化） | 引导一次系统设置授权；或走「失败恢复」的 computer-use 兜底 |
| MEMO_FAIL reason=folder_not_found | 确认文件夹名；中文界面 iCloud 默认夹在 AppleScript 里名为 "Notes"，也可不传 folder 用默认 |
| MEMO_FAIL reason=empty_body / read_file_failed | 正文文件没写成或路径不对：检查第 1 步的 heredoc |
| MEMO_FAIL reason=account_not_found | 账户名传错；默认 iCloud 即可 |
| MEMO_FAIL reason=mismatch … id=… | 已写入但回读不一致：用 find 查看实际内容，再用该 id 重写或删除重来 |
| MEMO_FAIL reason=note_not_found | 更新用的 id 失效：先 find 拿最新 id |
| DELETE_UNCONFIRMED still_in=… | 删除后仍留在普通文件夹（或 purge 后仍能查到）：重试一次；仍失败如实告知用户 |
| AppleScript 超时 -1712 | iCloud 同步中：重试一次；仍失败告知用户稍后再试 |

## 失败恢复
- 写错内容 → `memo_find 关键词` 拿 id → `memo_delete id` → 重新第 1、2 步
- AppleScript 完全不可用 → computer-use 兜底：Cmd+N 新建 → 剪贴板粘贴（**中文必须走剪贴板**，keystroke 直输中文不可靠）→ 截图验证。详见 memory「Notes 备忘录 macOS Automation」

## 技术要点（维护脚本时看）
- **HTML `<div>` 每行一个**是唯一可靠的多行写入格式：纯文本 `\n` 会把所有行并成一段（标题也被合并）；空行 = `<div><br></div>`；写入前转义 `&` `<` `>`
- 第一行自动成为条目标题（备忘录用首个段落作名称）
- 写入后**回读 plaintext 硬校验**（逐行 trim + 压缩空白 + 去首尾空行后比对）；读取失败绝不能当成功
- 新建 = `make new note at folder X with properties {body:html}`；更新 = `set body of note id … to html`；删除 = `delete note id …`
- 删除语义（实测）：第一次 `delete` 只是移入「Recently Deleted」回收站；对回收站里的条目再删一次才彻底清除（对应脚本第 2 参数 `purge`）
- 账户默认 iCloud；iCloud 默认文件夹 AppleScript 名是 "Notes"（不是「备忘录」），脚本已做中英文回退
- 读 UTF-8 文件：`read (POSIX file path) as «class utf8»`
- 速度基准：查/写/删单步 1–2 秒；整条链路（润色 + 写入 + 校验）约 5 秒

## 安全说明
- 只在用户确认后写入；更新/删除必须用户明确要求且带精确 id；彻底清除（purge）仅限用户明确要求"彻底删除"时使用
- 不修改备忘录设置；不碰用户已有条目的内容（除用户指定 id 的更新/删除）
- 不写敏感信息（证件、账号、卡号）；润色不臆造事实
- 测试产生的条目用 memo_delete 按 id 清理
