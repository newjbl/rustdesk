# Fork 工作流（newjbl/rustdesk）

本仓库是 [rustdesk/rustdesk](https://github.com/rustdesk/rustdesk) 的私有 fork，用来承载自研改动，同时保持对上游的可同步性。

## 分支模型

| 分支 | 作用 | 规则 |
|---|---|---|
| `master` | **上游镜像**，只跟随 `upstream/master` | ❌ 永远不要在上面直接提交 |
| `custom` | 我们的全部改动 | ✅ 日常开发都在这里 |

> 好处：`master` 永远是上游原样，`custom` 变基到 `master` 上不会碰上游历史，冲突范围只落在我们改过的那几个文件。

## 远端

```
origin    https://github.com/newjbl/rustdesk.git   ← 自己的 fork
upstream  https://github.com/rustdesk/rustdesk.git ← 上游
```

## 日常：把上游更新合进来

```powershell
git switch custom
git fetch upstream
git rebase upstream/master        # 把我们的提交搬到上游最新提交之上
git submodule update --init --recursive
```

有冲突时：

```powershell
# 逐个解决冲突后
git add <冲突文件>
git rebase --continue

# 搞砸了想重来
git rebase --abort
```

推送（rebase 改写了历史，需要强推自己的分支）：

```powershell
git push origin custom --force-with-lease
```

> `--force-with-lease` 比 `--force` 安全：如果远端有别人新推的提交会拒绝覆盖。

## 同步上游前的自检

```powershell
git fetch upstream
git log --oneline custom..upstream/master        # 上游多了哪些提交
git log --oneline upstream/master..custom        # 我们有哪些提交（应当只有白标/构建类）
git diff --stat upstream/master...custom        # 我们改了多少文件
```

**我们的改动应当始终是"少量、集中"的**。如果 `git diff --stat` 里出现 `client.rs`、`server/connection.rs` 这类大文件，说明改动侵入过深，后续每次上游更新都会痛苦。

## 目录约定

| 路径 | 是否入库 | 说明 |
|---|---|---|
| `_local/` | ❌ | 本地分析文档、脚本（通过 `.git/info/exclude` 排除） |
| `dist/` | ❌ | 构建产物（APK/MSI/EXE） |
| `flutter/android/app/src/main/jniLibs/` | ❌ | 交叉编译出的 `.so` |
| `rustdesk/` | ❌ | MSI 打包用的 payload 目录 |

## 子模块 `libs/hbb_common`

**当前是上游的子模块，没有改动。** 一旦需要改它（例如改默认服务器 `RENDEZVOUS_SERVERS`、`RS_PUB_KEY`），有两种做法：

1. **fork 子模块**（推荐）：fork `rustdesk/hbb_common` → 改 `.gitmodules` 指向自己的 fork → 子模块里提交 → 回父仓库 `git add libs/hbb_common` 更新指针
2. **并入主仓库**：删除 `.gitmodules`，把子模块内容变成普通目录（历史会变复杂，但以后只维护一个仓库）

⚠️ 改 `hbb_common` 会影响与 `rustdesk-server` 的协议兼容性，动之前先确认服务端版本。

## 改动清单（截至 2026-11-20）

### 构建与环境

| 提交 | 内容 |
|---|---|
| `build: 修复 Windows 主机交叉编译 Android…` | `build.rs` 目标判断、`res/vcpkg/aom` 汇编器 |
| `build: 国内构建改用镜像源` | gradle 发行包 / maven 镜像 |

### 白标

| 提交 | 内容 |
|---|---|
| `android: 白标为独立包名 RDClient` | `applicationId` = com.jbl.rdclient、`android:label` |
| `android: 改为纯控制端…` | 移除无障碍/投屏/录音/开机自启；`conn-type=outgoing` |
| `android: 恢复悬浮窗…` | 恢复 `SYSTEM_ALERT_WINDOW`（控制端需要），摄像头仍禁用 |

### Android 会话界面（自定义重点）

| 提交 | 内容 |
|---|---|
| `android: 默认横屏（sensorLandscape）` | 锁定横屏，随重力翻转 180° |
| `mobile: 会话快捷操作栏移到窗口右侧竖排` | 底栏 → 右栏 |
| `mobile: 手势模型改为 单指平移 / 双指滚动 / 三指拖选` | 手势重映射 |
| `mobile: 键盘辅助面板默认收起并缩小` | `_more=false`，按钮/字号收紧，展开限高可滚 |
| `mobile: 左侧增加快捷键面板占位列` | 左栏占位，待填内容 |
| `android: 窗口层真全屏…` | `setDecorFitsSystemWindows(false)` + 隐藏系统栏 + 刘海延伸 |
| `mobile: 画面铺满屏幕（cover）+ 刘海区强制延伸` | `minScale=max()`，`LAYOUT_ALWAYS` |
| `mobile: 会话页改为固定三栏布局` | 中栏宽度 = 屏高×远端比例，剩余平分给左右栏 |
| `mobile: 中间显示窗口加 ClipRect` | 平移/缩放不再溢出到两侧栏 |

