# Release 附件本地同步

GitHub 是发布源。GitHub Actions 的 `.github/scripts/sync-releases.py` 负责同步 Release 标题、说明和状态；本地的 `tools/sync-release-assets.py` 负责将 GitHub 手动上传的附件同步到 Gitee、GitCode。

运行前，目标平台必须已经存在同名 Tag 的 Release。附件工具不会创建 Release、修改说明或推送 Git 仓库，也不会把各平台自动生成的源码压缩包当作发布附件。

## 交互入口

Windows 下双击根目录 `sync-release.cmd`，或在项目根目录执行：

```powershell
.\sync-release.cmd
```

菜单提供“1. 同步附件”“2. 预览同步计划”“0. 退出”。选择操作后输入 Tag，例如 `v1.6.5`；直接回车会处理全部已发布版本，包含预发布版。随后选择是否替换同名附件，直接回车默认不替换。

运行前会显示版本范围、同名处理方式以及补传、删除规则；完成或失败后返回菜单。首次启动或环境不可用时，询问是否创建或修复 `.venv` 并联网安装依赖，直接回车默认同意；安装失败可选择重试或退出。没有 Python 3.10+ 时提示安装系统 Python。

跳板优先使用项目的 `.venv`，健康环境不依赖全局 Python 或重复安装；启动路径不受当前工作目录影响。也支持直接传递命令行参数：

```powershell
.\sync-release.cmd --tag v1.6.5 --dry-run
.\sync-release.cmd --tag v1.6.5
.\sync-release.cmd --tag v1.6.5 --force
```

## 环境准备

使用 Python 3.10 或更新版本。在项目根目录执行：

```powershell
python -X utf8 tools/setup-release-sync.py
```

虚拟环境保存在已被 Git 忽略的 `.venv/` 下，下载缓存保存在 `temp/` 下，独立于应用的 OHPM 和 Hvigor 依赖。后文命令均在项目根目录执行，无需激活虚拟环境。初始化脚本会检查 Python 版本和依赖，健康环境不会重复安装；换电脑时重新运行初始化，不复制 `.venv/`。安装失败后检查网络和目录权限再重试；若 `.venv` 已存在但不是虚拟环境，需先重命名该目录，脚本不会清空它。

## 令牌

Windows 推荐在“凭据管理器 → Windows 凭据 → 添加普通凭据”中配置：

| 平台 | Internet 地址或网络地址 | 用户名 | 密码 |
| --- | --- | --- | --- |
| Gitee | `Gitee` | 对应平台用户名 | Gitee 访问令牌 |
| GitCode | `GitCode` | 对应平台用户名 | GitCode 访问令牌 |

脚本使用 `CredReadW` 读取密码字段，运行时必须使用保存凭据的 Windows 用户。用户名字段用于标识账号，脚本认证使用令牌。选择具备目标仓库 Release 附件读写权限的令牌，不需要账号资料、Issue 或其他无关权限。GitCode 账号信息接口失败不代表 Release 接口不可用，脚本直接使用相关仓库接口。

也支持 `GITEE_TOKEN`、`GITCODE_TOKEN` 环境变量；非空环境变量优先于 Windows 凭据。非 Windows 环境必须通过环境变量提供令牌。公开 GitHub Release 可以匿名下载；私有仓库或需要提高 API 请求额度时可提供 `GITHUB_TOKEN`，也兼容 `GH_TOKEN`。

不要把令牌写入仓库文件、命令行参数或聊天。凭据管理器的普通凭据可被同一 Windows 用户的进程读取，不能防御该用户环境中的恶意程序。

## 常用命令

先查看某个版本的同步计划：

```powershell
./.venv/Scripts/python.exe -X utf8 tools/sync-release-assets.py --tag v1.6.5 --dry-run
```

同步这个版本的全部附件到两个平台：

```powershell
./.venv/Scripts/python.exe -X utf8 tools/sync-release-assets.py --tag v1.6.5
```

只处理 GitCode，或只选一个附件：

```powershell
./.venv/Scripts/python.exe -X utf8 tools/sync-release-assets.py --tag v1.6.5 --platform gitcode
./.venv/Scripts/python.exe -X utf8 tools/sync-release-assets.py --tag v1.6.5 --asset CalcX-1.6.5-release-signed.hap
```

仅下载到本机、只验证远端内容、同步最新正式版或全部历史版本：

```powershell
./.venv/Scripts/python.exe -X utf8 tools/sync-release-assets.py --tag v1.6.5 --download-only
./.venv/Scripts/python.exe -X utf8 tools/sync-release-assets.py --tag v1.6.5 --verify-only
./.venv/Scripts/python.exe -X utf8 tools/sync-release-assets.py --latest
./.venv/Scripts/python.exe -X utf8 tools/sync-release-assets.py --all --dry-run
./.venv/Scripts/python.exe -X utf8 tools/sync-release-assets.py --all
```

`--all` 包含已发布的预发布版本，排除草稿；`--latest` 使用 GitHub 最新正式 Release 接口。`--asset` 可重复指定，使用精确文件名；如果某个 Release 缺少指定附件，该 Release 会报告失败。

## 网络与跨项目复用

默认遵循 Requests 的代理环境配置。可单独指定 GitHub 与镜像平台的代理，下面的空字符串表示国内平台直连：

```powershell
./.venv/Scripts/python.exe -X utf8 tools/sync-release-assets.py --tag v1.6.5 --github-proxy http://127.0.0.1:7890 --mirror-proxy ""
```

自定义仓库、凭据名称和缓存目录：

```powershell
./.venv/Scripts/python.exe -X utf8 tools/sync-release-assets.py --tag v1.0.0 --source owner/project --gitee-repo owner/project --gitcode-repo owner/project --gitee-credential Gitee --gitcode-credential GitCode --cache-dir temp/other-release-assets
```

平台令牌仅发送给该平台的 API；跨域下载和 GitCode 对象存储上传不会携带平台令牌。错误信息不输出原始 HTTP 异常、响应正文和签名 URL。

## 同步规则与校验

默认按完整附件清单同步：同名附件直接跳过，不下载或校验内容；仅在需要上传时下载 GitHub 附件，两个平台共享同一份源缓存。补齐缺失附件后，删除目标平台中 GitHub 没有的上传附件。各平台自动生成的源码包不参与同步或删除。

需要覆盖同名附件时使用 `--force`：

```powershell
./.venv/Scripts/python.exe -X utf8 tools/sync-release-assets.py --tag v1.6.5 --force
```

`--force` 会替换所有选中的同名附件，无论内容是否一致。先完整下载并校验 GitHub 源文件，再删除目标同名附件并上传；不下载旧附件或保存旧附件备份。替换不是原子操作，上传失败时可复用本地源缓存重新补传。原来的 `--replace` 参数已移除。

- 删除多余附件放在该平台所有补传、替换成功后执行。读取清单、下载或上传失败时，暂停该平台的多余附件删除，其他平台继续处理。
- `--asset` 只限制补传、替换和内容校验，删除仍以 GitHub 完整清单为准；GitHub 上未选中的合法附件会保留。GitHub Release 没有上传附件时，目标所有上传附件均视为多余。
- `--dry-run` 展示跳过、上传、替换、删除计划，只查询元数据，不下载、写缓存或修改远端。
- `--verify-only` 显式下载源附件和目标附件比对 SHA-256，不补传、替换或删除。默认同名跳过不表示内容已验证；同名文件发生变化时需使用 `--force`。
- 源下载检查大小和 GitHub 提供的 SHA-256；缓存使用前重新检查本地哈希。上传后会下载新目标附件校验 SHA-256，因此首次上传和强制替换仍有校验流量。
- 下载与只读请求可重试；上传响应不确定时查询远端并校验，不盲目重复上传。
- 存在失败时退出码为 `1`，全部成功为 `0`，参数错误为 `2`，手动中止为 `130`。
- 目标 Release 必须已存在，缺失时先运行元数据同步工作流。
- `.sync.lock` 阻止使用同一缓存的并发进程。强制终止后，确认进程已结束再手动删除锁；不要使用不同缓存同时同步同一目标 Release，也应避免同步时在网页修改附件。

大文件传输中断后重跑会重新传输该文件，尚未实现字节断点续传；完整缓存可以复用，无需重新构建或签名安装包。

## 维护与测试

```powershell
./.venv/Scripts/python.exe -X utf8 -m unittest discover -s tools/tests -p 'test_release_sync*.py' -v
git diff --check
```

测试使用临时缓存与模拟响应，不依赖真实令牌、不写入线上仓库。真实上传验证应选择已有 GitHub Release，补传它的原始附件，并在上传后核对目标文件内容。

接口依据：[GitHub 附件 API](https://docs.github.com/en/rest/releases/assets)、[Gitee 官方 SDK 附件接口](https://gitee.com/sdk/gitee5j/releases)、[GitCode 上传地址 API](https://docs.gitcode.com/docs/apis/get-api-v-5-repos-owner-repo-releases-tag-upload-url/)、[Windows CredReadW](https://learn.microsoft.com/en-us/windows/win32/api/wincred/nf-wincred-credreadw)。

[返回项目文档](../README.md#项目文档)
