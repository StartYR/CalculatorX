# Release 附件本地同步

GitHub 是发布源。GitHub Actions 的 `.github/scripts/sync-releases.py` 负责同步 Release 标题、说明和状态；本地的 `tools/sync-release-assets.py` 负责将 GitHub 手动上传的附件同步到 Gitee、GitCode。

运行前，目标平台必须已经存在同名 Tag 的 Release。附件工具不会创建 Release、修改说明或推送 Git 仓库，也不会把各平台自动生成的源码压缩包当作发布附件。

## 环境准备

使用 Python 3.10 或更新版本。在项目根目录执行：

```powershell
python -m venv .venv
./.venv/Scripts/python.exe -m pip install -r tools/requirements-release-sync.txt
```

虚拟环境保存在已被 Git 忽略的 `.venv/` 下，下载缓存和冲突附件备份保存在 `temp/` 下，独立于应用的 OHPM 和 Hvigor 依赖。后文命令均在项目根目录执行，无需激活虚拟环境。

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

仅下载到本机、只验证远端内容、同步最新正式版或补传全部历史版本：

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

## 校验、重跑与冲突

- 下载采用流式传输，检查源文件大小；GitHub 提供 `digest` 时进一步检查 SHA-256。
- 本地缓存记录源仓库、附件 ID、名称、大小、更新时间和摘要。每次使用缓存时重新计算哈希；缓存损坏或源附件发生变化时重新下载。
- 同名远端附件会重新下载计算 SHA-256，一致才跳过；上传后也重新下载验证。此校验会额外消耗镜像平台下载流量。
- `--dry-run` 只查询元数据，不下载、写缓存或修改远端；已有同名附件只标记为需要校验，不能据此认定内容一致。
- 下载和只读 HTTP 请求会重试；上传响应不确定时先查询远端并校验，若仍无法确认则报告失败，不盲目重复上传。稍后重新运行同一命令可以核对并补传。
- 某个平台或附件失败后继续处理其他可处理项。存在失败时退出码为 `1`，全部成功为 `0`，参数错误为 `2`，手动中止为 `130`。
- 目标 Release 缺失时先运行元数据同步工作流。工具不创建替代 Release，也不删除目标平台多余附件。
- 同一缓存目录通过 `.sync.lock` 阻止并发写入。若进程被强制终止，确认进程已结束后才能手动删除该锁；不要使用不同缓存目录同时同步相同目标 Release。

同名附件内容不一致时默认失败。明确需要替换时执行：

```powershell
./.venv/Scripts/python.exe -X utf8 tools/sync-release-assets.py --tag v1.6.5 --asset CalcX-1.6.5-release-signed.hap --replace
```

`--replace` 会先完整下载旧附件，保存 `backup-*.bin` 和包含原文件名、平台、仓库、Tag、SHA-256 的 `backup-*.json`，然后删除旧附件并上传新文件。替换不是原子操作，失败后备份仍保留；需要恢复时根据 JSON 中的原文件名重命名备份并在目标网页上传。备份文件不会自动清理。平台未提供附件 ID、存在多个同名附件或旧附件无法下载时停止替换。

大文件传输中断会在重跑时重新传输该文件，当前不实现 HTTP 字节断点续传；已经完整下载的缓存可复用。无需重新构建或重新签名安装包。

## 维护与测试

```powershell
./.venv/Scripts/python.exe -X utf8 -m unittest discover -s tools/tests -p test_release_sync.py -v
git diff --check
```

测试使用临时缓存与模拟响应，不依赖真实令牌、不写入线上仓库。真实上传验证应选择已有 GitHub Release，补传它的原始附件，并在上传后核对目标文件内容。

接口依据：[GitHub 附件 API](https://docs.github.com/en/rest/releases/assets)、[Gitee 官方 SDK 附件接口](https://gitee.com/sdk/gitee5j/releases)、[GitCode 上传地址 API](https://docs.gitcode.com/docs/apis/get-api-v-5-repos-owner-repo-releases-tag-upload-url/)、[Windows CredReadW](https://learn.microsoft.com/en-us/windows/win32/api/wincred/nf-wincred-credreadw)。

[返回项目文档](../README.md#项目文档)
