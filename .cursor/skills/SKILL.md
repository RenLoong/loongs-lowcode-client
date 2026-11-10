---
name: 统一用户身份管理系统（UUIMS）客户端
description: >-
  在 loongs-uuims-client（Flutter：windows/macos/linux + Android 平板 / iOS 平板）项目根下开发界面、
  OAuth PKCE、API_BASE_URL/{host}、以及 pack.sh / pack.ps1 / pack.command 打包。
  不构建 web。项目根即本仓库根。不要用本技能改后端或 uni-app 仓库。
---

# 统一用户身份管理系统（UUIMS）客户端（Flutter）

作用范围：**当前仓库根**（`RenLoong/loongs-uuims-client`：含 `lib/`、`pack.*`、`.fvmrc`）。

对接后端默认 HTTP **21000**。打包目标是桌面与平板，**不构建 web**，也不会把产物拷到后端 `public/web`。

## 何时用

- 改 `lib/`（登录、Render、Shell、健康检查、窗口标题栏）
- 改打包脚本或 FVM / `.fvmrc`
- `{host}`、PKCE loopback、Geist 字体重命名钩子

## 技术约定

- Flutter + **FVM**；版本**只认** `.fvmrc`（勿在脚本硬编码版本号）
- UI：shadcn_ui；业务字体以项目为准（Geist `[wght]` 由 `tools/fix_geist_font_names.py` 在需要时改 ASCII 名）
- API：`--dart-define=API_BASE_URL=…`
  - 源码默认 fallback：`http://127.0.0.1:21000`（见 `lib/core/config.dart`）
- OAuth：授权码 + PKCE；桌面 loopback；**close 前缓存 `redirectUri`**（否则 `HttpServer is not bound`）
- 平板：Android 仅 large/xlarge（`requiresSmallestWidthDp=600`）；iOS 仅 iPad（`UIDeviceFamily=2`，`TARGETED_DEVICE_FAMILY=2`）。不打手机包。

## 打包（按 OS，勿混用）

| 脚本 | 系统 | 产物 |
|------|------|------|
| `./pack.sh` | Linux / WSL | linux + Android 平板 APK（SDK 可用时） |
| `.\pack.ps1` | Windows | windows（可选 Inno）+ Android 平板 APK（SDK 可用时） |
| `./pack.command` | macOS | macos + iOS 平板（未签名 .app zip）+ Android 平板 APK（SDK 可用时） |

规则：

1. **只用本机原生 fvm**。`pack.sh` 拒绝 Windows `fvm.exe` 包装；WSL 不打 Windows 包。iOS 只在 macOS 上构建。
2. **禁止**自动 `fvm install`；SDK 缺失则中断并提示手动安装。
3. **不构建 web**。`--skip-web` / `-SkipWeb` / `--web` 已移除。
4. Android SDK 或 Xcode 缺失时跳过对应平板包并告警，不中断已完成的桌面包。
5. bash 陷阱：不要写 `${VAR:-http://{host}:21000}`（会变成 `http://{host:21000}`）。正确：

```bash
_DEFAULT_API_BASE_URL='http://{host}:21000'
API_BASE_URL="${API_BASE_URL:-$_DEFAULT_API_BASE_URL}"
```

6. Windows 从 `\\wsl$\…` 跑需 NTFS 暂存（脚本已处理）。

## 常见故障（客户端）

| 现象 | 处理 |
|------|------|
| `FormatException: Invalid port` + `{host:21000}` | 修 pack 默认值 / 重建 |
| WSL fvm 走 Windows 缓存 | 去掉 fvm.exe 包装，装 Linux fvm，或改用 `pack.ps1` |
| 桌面登录 unbound | loopback 保存 redirectUri |
| Skip Android tablet | 安装 Android SDK 并设置 `ANDROID_HOME` |
| Skip iOS tablet | 在 macOS 上安装 Xcode；真机分发需另行签名出 IPA |

## Agent 习惯

- 不提交 `build/`、`dist/`、`.dart_tool/`；保留 `.fvmrc`。
- 跨平台打包提示去对应脚本，不要在 WSL 硬编 Windows。
