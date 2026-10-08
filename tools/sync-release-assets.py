"""通过本机将 GitHub Release 附件同步到 Gitee 和 GitCode。"""

import argparse
import os
from pathlib import Path
import sys

from release_sync import (
    GITHUB_API, GITEE_API, GITCODE_API, SyncLock, HttpClient, Mirror, SyncError,
    downloaded_asset, get_token, release_assets, releases, repository_path, sync_asset,
)
from release_sync_terminal import report


SYNC_LOCK_PATH = Path(__file__).resolve().parents[1] / "temp/.release-sync.lock"


class SyncArgumentParser(argparse.ArgumentParser):
    def error(self, message):
        self.print_usage(sys.stderr)
        report(f"{self.prog}: 错误：{message}", "error", file=sys.stderr)
        self.exit(2)


def inventory(mirror: Mirror, tag: str) -> dict[str, dict]:
    result = {}
    for asset in mirror.assets(tag):
        name = asset["name"]
        if name in result:
            raise SyncError(f"{mirror.platform} 存在多个同名附件 {name}，请先在网页处理")
        result[name] = asset
    return result


def sync_release(client: HttpClient, mirrors: list[Mirror], release: dict, args) -> int:
    tag = release["tag_name"]
    report(f"Release：{tag}")
    # 删除以完整源清单为准，--asset 只限制上传和校验范围。
    all_assets = release_assets(client, args.source, release, [])
    source_names = {asset["name"] for asset in all_assets}
    missing = set(args.asset) - source_names
    if missing:
        raise SyncError("指定附件不存在：" + ", ".join(sorted(missing)))
    assets = [asset for asset in all_assets if not args.asset or asset["name"] in args.asset]
    if not assets:
        report("  没有上传附件")
    failures = 0
    targets = {}
    failed = set()
    for mirror in mirrors:
        try:
            targets[mirror] = inventory(mirror, tag)
        except SyncError as exc:
            failures += 1
            failed.add(mirror)
            report(f"  {mirror.platform} 读取附件失败：{exc}", "error", file=sys.stderr)
    for asset in assets:
        pending = []
        for mirror, existing in targets.items():
            same_name = asset["name"] in existing
            if same_name:
                action = "待替换" if args.force else "已有同名附件，跳过（未校验内容）"
            else:
                action = "待上传"
            if args.dry_run or (same_name and not args.force and not args.verify_only):
                report(f"  {mirror.platform}：{asset['name']} — {action}",
                       "warning" if args.dry_run and same_name and args.force else "info")
            else:
                pending.append(mirror)
        if not pending:
            continue
        try:
            with downloaded_asset(client, args.source, asset) as (path, digest):
                for mirror in pending:
                    try:
                        result = sync_asset(mirror, tag, asset, path, digest, args.force, args.verify_only)
                        report(f"  {mirror.platform}：{asset['name']} — {result}",
                               "info" if "跳过" in result else "success")
                    except (SyncError, OSError) as exc:
                        failures += 1
                        failed.add(mirror)
                        detail = str(exc) if isinstance(exc, SyncError) else "无法读取临时源文件"
                        report(f"  {mirror.platform} / {asset['name']} 失败：{detail}", "error", file=sys.stderr)
        except (SyncError, OSError) as exc:
            failures += 1
            failed.update(pending)
            detail = str(exc) if isinstance(exc, SyncError) else "无法创建、读取或清理临时文件"
            report(f"  {asset['name']} 处理源文件失败：{detail}", "error", file=sys.stderr)
    if args.verify_only:
        return failures
    for mirror in targets:
        if mirror in failed:
            report(f"  {mirror.platform}：本轮有失败，暂停删除多余附件", "warning")
            continue
        try:
            # 写入成功后刷新清单，再逐个删除多余附件；源码包已由平台适配层排除。
            current = targets[mirror] if args.dry_run else inventory(mirror, tag)
            for name, asset in current.items():
                if name not in source_names:
                    if args.dry_run:
                        report(f"  {mirror.platform}：{name} — 待删除多余附件", "warning")
                    else:
                        mirror.delete(tag, asset)
                        report(f"  {mirror.platform}：已删除多余附件 {name}", "success")
        except SyncError as exc:
            failures += 1
            report(f"  {mirror.platform} 清理失败：{exc}", "error", file=sys.stderr)
    return failures


def main(argv=None) -> int:
    parser = SyncArgumentParser(description="通过本机同步 GitHub Release 附件")
    selection = parser.add_mutually_exclusive_group(required=True)
    selection.add_argument("--tag", help="指定 GitHub Release Tag")
    selection.add_argument("--latest", action="store_true", help="最新正式版")
    selection.add_argument("--all", action="store_true", help="全部已发布版本，包含预发布版")
    parser.add_argument("--source", default="StartYR/CalculatorX", help="GitHub owner/repo")
    parser.add_argument("--asset", action="append", default=[], help="精确附件名称，可重复指定")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--dry-run", action="store_true", help="只查询计划，不下载或修改远端")
    mode.add_argument("--verify-only", action="store_true", help="下载并校验目标附件，不修改远端")
    parser.add_argument("--platform", choices=["gitee", "gitcode", "all"], default="all")
    parser.add_argument("--gitee-repo", default="StartYi/CalculatorX", help="Gitee owner/repo")
    parser.add_argument("--gitcode-repo", default="StartYi/CalculatorX", help="GitCode owner/repo")
    parser.add_argument("--gitee-credential", default="Gitee", help="Windows 普通凭据名称")
    parser.add_argument("--gitcode-credential", default="GitCode", help="Windows 普通凭据名称")
    parser.add_argument("--force", action="store_true", help="强制替换所有选中的同名附件")
    parser.add_argument("--github-proxy", help="GitHub 代理 URL；空字符串表示直连")
    parser.add_argument("--mirror-proxy", help="镜像 API 和对象存储代理 URL；空字符串表示直连")
    args = parser.parse_args(argv)
    if args.tag is not None and (not args.tag.strip() or any(ord(character) < 32 for character in args.tag)):
        parser.error("--tag 必须是非空且不包含控制字符的 Tag")
    if args.force and args.verify_only:
        parser.error("--force 不能与 --verify-only 同时使用")
    client = HttpClient(GITHUB_API, os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN", ""), args.github_proxy)
    mirrors = []
    lock = None
    failures = 0
    try:
        repository_path(args.source)
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
                report(f"{platform} 初始化失败：{exc}", "error", file=sys.stderr)
        if not mirrors:
            raise SyncError("没有可用的目标平台")
        if not args.dry_run:
            lock = SyncLock(SYNC_LOCK_PATH)
        selected = releases(client, args.source, args.tag, args.latest)
        if not selected:
            raise SyncError("没有找到已发布的 GitHub Release")
        for release in selected:
            try:
                failures += sync_release(client, mirrors, release, args)
            except SyncError as exc:
                failures += 1
                report(f"  {release['tag_name']} 读取源附件失败：{exc}", "error", file=sys.stderr)
                continue
        report(f"{'预览' if args.dry_run else '处理'}结束：{failures} 项失败", "error" if failures else "success")
        return 1 if failures else 0
    except SyncError as exc:
        report(f"失败：{exc}", "error", file=sys.stderr)
        return 1
    except OSError:
        report("失败：无法处理临时文件或同步锁，请检查磁盘空间和目录权限", "error", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        report("已中止，临时文件已清理", "warning", file=sys.stderr)
        return 130
    finally:
        client.close()
        for mirror in mirrors:
            mirror.client.close()
        if lock:
            lock.close()


if __name__ == "__main__":
    sys.exit(main())
