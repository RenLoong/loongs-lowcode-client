# client

LOONGS platform uuims client（Flutter）

打包目标：**Windows、Linux、macOS、Android 平板、iOS 平板**。不构建 web。

## 打包

按所在系统选用脚本（需本机已按 `.fvmrc` 安装 FVM / Flutter，脚本不会自动 `fvm install`）：

| 脚本 | 系统 | 产物 |
|------|------|------|
| `.\pack.ps1` | Windows | `dist/uuims-pc-windows.zip`（可选 Inno 安装包）+ `dist/uuims-android-tablet.apk` |
| `./pack.sh` | Linux / WSL | `dist/uuims-pc-linux.zip` + `dist/uuims-android-tablet.apk` |
| `./pack.command` | macOS | `dist/uuims-pc-macos.zip` + `dist/uuims-ios-tablet.zip` + `dist/uuims-android-tablet.apk` |

平板限制：Android 要求最小宽度 600dp（large/xlarge）；iOS 仅 iPad。Android 需本机 SDK；iOS 仅 macOS + Xcode，默认未签名。

可用 `--skip-windows` / `-SkipWindows`、`--skip-linux`、`--skip-macos`、`--skip-android`、`--skip-ios` 跳过对应目标。
