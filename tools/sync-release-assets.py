"""下载 GitHub Release 附件到本机，供镜像平台同步使用。"""

import argparse
import os
from pathlib import Path
import sys

from release_sync import GITHUB_API, HttpClient, SyncError, cache_asset, release_assets, releases


def main() -> int:
    parser = argparse.ArgumentParser(description="通过本机同步 GitHub Release 附件")
    selection = parser.add_mutually_exclusive_group(required=True)
    selection.add_argument("--tag", help="指定 GitHub Release Tag")
    selection.add_argument("--latest", action="store_true", help="最新正式版")
    selection.add_argument("--all", action="store_true", help="全部已发布版本，包含预发布版")
    parser.add_argument("--source", default="StartYR/CalculatorX", help="GitHub owner/repo")
    parser.add_argument("--asset", action="append", default=[], help="精确附件名称，可重复指定")
    parser.add_argument("--dry-run", action="store_true", help="只读取元数据，不下载文件")
    parser.add_argument("--download-only", action="store_true", help="仅下载，不访问镜像平台")
    parser.add_argument("--cache-dir", type=Path, default=Path(__file__).resolve().parents[1] / "temp/release-assets")
    parser.add_argument("--github-proxy", help="GitHub 代理 URL；空字符串表示直连")
    args = parser.parse_args()
    if not args.dry_run and not args.download_only:
        parser.error("当前下载入口需要 --download-only 或 --dry-run")
    client = HttpClient(GITHUB_API, os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN", ""), args.github_proxy)
    try:
        selected = releases(client, args.source, args.tag, args.latest)
        if not selected:
            raise SyncError("没有找到已发布的 GitHub Release")
        for release in selected:
            print(f"Release：{release['tag_name']}", flush=True)
            for asset in release_assets(client, args.source, release, args.asset):
                if args.dry_run:
                    print(f"  下载计划：{asset['name']}（{asset['size']} 字节）")
                else:
                    _, digest = cache_asset(client, args.source, asset, args.cache_dir)
                    print(f"  已验证 SHA-256：{digest}")
        return 0
    except SyncError as exc:
        print(f"失败：{exc}", file=sys.stderr)
        return 1
    except OSError:
        print("失败：无法读写缓存，请检查磁盘空间和目录权限", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("已中止；完整缓存可在下次运行时复用", file=sys.stderr)
        return 130
    finally:
        client.close()


if __name__ == "__main__":
    sys.exit(main())
