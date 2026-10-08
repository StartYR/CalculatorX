"""通过本机将 GitHub Release 附件同步到 Gitee 和 GitCode。"""

import argparse
import os
from pathlib import Path
import sys

from release_sync import (
    GITHUB_API, GITEE_API, GITCODE_API, CacheLock, HttpClient, Mirror, SyncError,
    cache_asset, get_token, release_assets, releases, repository_path, sync_asset,
)


def main() -> int:
    parser = argparse.ArgumentParser(description="通过本机同步 GitHub Release 附件")
    selection = parser.add_mutually_exclusive_group(required=True)
    selection.add_argument("--tag", help="指定 GitHub Release Tag")
    selection.add_argument("--latest", action="store_true", help="最新正式版")
    selection.add_argument("--all", action="store_true", help="全部已发布版本，包含预发布版")
    parser.add_argument("--source", default="StartYR/CalculatorX", help="GitHub owner/repo")
    parser.add_argument("--asset", action="append", default=[], help="精确附件名称，可重复指定")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--dry-run", action="store_true", help="只查询计划，不下载或修改远端")
    mode.add_argument("--download-only", action="store_true", help="仅下载，不访问镜像平台")
    mode.add_argument("--verify-only", action="store_true", help="下载并校验目标附件，不修改远端")
    parser.add_argument("--platform", choices=["gitee", "gitcode", "all"], default="all")
    parser.add_argument("--gitee-repo", default="StartYi/CalculatorX", help="Gitee owner/repo")
    parser.add_argument("--gitcode-repo", default="StartYi/CalculatorX", help="GitCode owner/repo")
    parser.add_argument("--gitee-credential", default="Gitee", help="Windows 普通凭据名称")
    parser.add_argument("--gitcode-credential", default="GitCode", help="Windows 普通凭据名称")
    parser.add_argument("--replace", action="store_true", help="备份后替换同名且内容不同的附件")
    parser.add_argument("--cache-dir", type=Path, default=Path(__file__).resolve().parents[1] / "temp/release-assets")
    parser.add_argument("--github-proxy", help="GitHub 代理 URL；空字符串表示直连")
    parser.add_argument("--mirror-proxy", help="镜像 API 和对象存储代理 URL；空字符串表示直连")
    args = parser.parse_args()
    if args.replace and (args.download_only or args.verify_only):
        parser.error("--replace 不能与 --download-only 或 --verify-only 同时使用")
    client = HttpClient(GITHUB_API, os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN", ""), args.github_proxy)
    mirrors = []
    lock = None
    failures = 0
    try:
        repository_path(args.source)
        if not args.download_only:
            for platform, api in (("gitee", GITEE_API), ("gitcode", GITCODE_API)):
                if args.platform not in ("all", platform):
                    continue
                try:
                    repository = getattr(args, f"{platform}_repo")
                    repository_path(repository)
                    token = get_token(platform, getattr(args, f"{platform}_credential"))
                    mirrors.append(Mirror(platform, repository, HttpClient(api, token, args.mirror_proxy)))
                except SyncError as exc:
                    failures += 1
                    print(f"{platform} 初始化失败：{exc}", file=sys.stderr)
            if not mirrors:
                raise SyncError("没有可用的目标平台")
        if not args.dry_run:
            lock = CacheLock(args.cache_dir)
        selected = releases(client, args.source, args.tag, args.latest)
        if not selected:
            raise SyncError("没有找到已发布的 GitHub Release")
        for release in selected:
            print(f"Release：{release['tag_name']}", flush=True)
            try:
                assets = release_assets(client, args.source, release, args.asset)
            except SyncError as exc:
                failures += 1
                print(f"  读取附件失败：{exc}", file=sys.stderr)
                continue
            if not assets:
                print("  没有上传附件")
            for asset in assets:
                if args.dry_run:
                    for mirror in mirrors:
                        try:
                            existing = mirror.find(release["tag_name"], asset["name"])
                            action = "已有同名附件，实际运行时核验内容" if existing else "待上传"
                            print(f"  {mirror.platform}：{asset['name']}（{asset['size']} 字节）— {action}")
                        except SyncError as exc:
                            failures += 1
                            print(f"  {mirror.platform} 计划失败：{exc}", file=sys.stderr)
                    continue
                try:
                    path, digest = cache_asset(client, args.source, asset, args.cache_dir)
                except SyncError as exc:
                    failures += 1
                    print(f"  下载失败：{exc}", file=sys.stderr)
                    continue
                print(f"  源附件 SHA-256：{digest}", flush=True)
                for mirror in mirrors:
                    try:
                        result = sync_asset(mirror, release["tag_name"], asset, path, digest, args.cache_dir,
                                            args.replace, args.verify_only)
                        print(f"  {mirror.platform}：{result}", flush=True)
                    except SyncError as exc:
                        failures += 1
                        print(f"  {mirror.platform} / {asset['name']} 失败：{exc}", file=sys.stderr)
        print(f"{'预览' if args.dry_run else '处理'}结束：{failures} 项失败", flush=True)
        return 1 if failures else 0
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
        for mirror in mirrors:
            mirror.client.close()
        if lock:
            lock.close()


if __name__ == "__main__":
    sys.exit(main())
