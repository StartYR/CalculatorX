"""GitHub Release 附件的本地缓存、凭据读取与平台同步。"""

from __future__ import annotations

import ctypes
from ctypes import wintypes
import hashlib
import json
import os
from pathlib import Path
import re
import time
from urllib.parse import quote, urljoin, urlsplit

import requests


GITHUB_API = "https://api.github.com"
GITEE_API = "https://gitee.com/api/v5"
GITCODE_API = "https://api.gitcode.com/api/v5"
CHUNK_SIZE = 1024 * 1024


class SyncError(RuntimeError):
    """仅包含可安全输出的操作信息，不包含 HTTP 原始异常或响应。"""


def read_windows_credential(target: str) -> str:
    if os.name != "nt":
        raise SyncError(f"凭据 {target} 需要 Windows；其他系统请使用环境变量")

    class Credential(ctypes.Structure):
        _fields_ = [
            ("Flags", wintypes.DWORD),
            ("Type", wintypes.DWORD),
            ("TargetName", wintypes.LPWSTR),
            ("Comment", wintypes.LPWSTR),
            ("LastWritten", wintypes.FILETIME),
            ("CredentialBlobSize", wintypes.DWORD),
            ("CredentialBlob", ctypes.POINTER(ctypes.c_ubyte)),
            ("Persist", wintypes.DWORD),
            ("AttributeCount", wintypes.DWORD),
            ("Attributes", ctypes.c_void_p),
            ("TargetAlias", wintypes.LPWSTR),
            ("UserName", wintypes.LPWSTR),
        ]

    library = ctypes.WinDLL("Advapi32.dll", use_last_error=True)
    library.CredReadW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD,
                                   ctypes.POINTER(ctypes.POINTER(Credential))]
    library.CredReadW.restype = wintypes.BOOL
    library.CredFree.argtypes = [ctypes.c_void_p]
    library.CredFree.restype = None
    credential = ctypes.POINTER(Credential)()
    if not library.CredReadW(target, 1, 0, ctypes.byref(credential)):
        code = ctypes.get_last_error()
        raise SyncError(f"无法读取普通凭据 {target}（Windows 错误 {code}），请检查名称和登录用户")
    try:
        # 凭据管理器 GUI 将密码保存为 UTF-16LE；兼容以 UTF-8 写入的普通凭据。
        value = ctypes.string_at(credential.contents.CredentialBlob, credential.contents.CredentialBlobSize)
        token = value.decode("utf-16-le" if b"\x00" in value else "utf-8").rstrip("\x00")
        if not token or any(character.isspace() for character in token):
            raise SyncError(f"普通凭据 {target} 的密码为空或含空白，请保存完整的访问令牌")
        return token
    except UnicodeError:
        raise SyncError(f"普通凭据 {target} 的密码编码无效") from None
    finally:
        library.CredFree(credential)


def get_token(platform: str, credential_name: str) -> str:
    value = os.environ.get(f"{platform.upper()}_TOKEN", "").strip()
    if value:
        return value
    return read_windows_credential(credential_name)


def repository_path(repository: str) -> str:
    parts = repository.split("/")
    if len(parts) != 2 or any(not re.fullmatch(r"[A-Za-z0-9_.-]+", part) or part in (".", "..") for part in parts):
        raise SyncError("仓库必须使用 owner/repo 格式")
    return "/".join(quote(part, safe="") for part in parts)


def secure_url(url: str) -> str:
    if not isinstance(url, str):
        raise SyncError("平台返回了无效的文件地址")
    parsed = urlsplit(url)
    if parsed.scheme != "https" or not parsed.hostname or parsed.username or parsed.password:
        raise SyncError("文件地址必须为 HTTPS，且不能包含用户名或密码")
    return url


class HttpClient:
    def __init__(self, api: str, token: str = "", proxy: str | None = None, attempts: int = 3):
        self.api = api
        self.token = token
        self.attempts = attempts
        self.session = requests.Session()
        # 显式设置代理时忽略系统环境，空字符串表示直连。
        if proxy is not None:
            self.session.trust_env = False
            if proxy:
                self.session.proxies = {"http": proxy, "https": proxy}

    def close(self) -> None:
        self.session.close()

    def headers(self, url: str, binary: bool = False) -> dict:
        headers = {"Accept": "application/octet-stream" if binary else "application/json"}
        # 授权头只发送到平台 API；跨域下载、对象存储上传均不携带平台令牌。
        if urlsplit(url).netloc == urlsplit(self.api).netloc:
            if self.token:
                headers["Authorization"] = f"Bearer {self.token}"
            if self.api == GITHUB_API:
                headers["Accept"] = "application/octet-stream" if binary else "application/vnd.github+json"
                headers["X-GitHub-Api-Version"] = "2022-11-28"
        return headers

    def request(self, method: str, url: str, action: str, **kwargs) -> requests.Response:
        secure_url(url)
        attempts = self.attempts if method == "GET" else 1
        for attempt in range(attempts):
            try:
                response = self.session.request(method, url, timeout=(15, 120), allow_redirects=False, **kwargs)
            except requests.RequestException as exc:
                # 原始异常可能包含 access_token 或签名 URL，禁止直接输出。
                if attempt + 1 == attempts:
                    raise SyncError(f"{action}：网络失败（{type(exc).__name__}）") from None
            else:
                if response.status_code not in (429, 500, 502, 503, 504) or attempt + 1 == attempts:
                    return response
                response.close()
            time.sleep(min(2 ** attempt, 8))
        raise SyncError(f"{action}：重试失败")

    def json(self, path: str, action: str, **kwargs):
        url = f"{self.api}{path}"
        with self.request("GET", url, action, headers=self.headers(url), **kwargs) as response:
            if response.status_code == 404:
                raise SyncError(f"{action}：HTTP 404，请确认仓库和 Release 存在，且令牌有访问权限")
            if response.status_code != 200:
                raise SyncError(f"{action}：HTTP {response.status_code}，请检查令牌权限或稍后重试")
            try:
                return response.json()
            except ValueError:
                raise SyncError(f"{action}：平台返回了无效 JSON") from None

    def binary(self, url: str, action: str) -> requests.Response:
        # 手动处理重定向，每一跳重新判断是否允许携带认证信息。
        for _ in range(8):
            response = self.request("GET", url, action, headers=self.headers(url, binary=True), stream=True)
            if response.status_code in (301, 302, 303, 307, 308):
                destination = response.headers.get("Location")
                response.close()
                if not destination:
                    raise SyncError(f"{action}：重定向缺少目标地址")
                url = secure_url(urljoin(url, destination))
                continue
            if response.status_code != 200:
                status = response.status_code
                response.close()
                raise SyncError(f"{action}：下载 HTTP {status}")
            return response
        raise SyncError(f"{action}：重定向次数过多")


def validate_asset(asset: dict) -> dict:
    if not isinstance(asset, dict):
        raise SyncError("GitHub 附件元数据无效")
    name = asset.get("name")
    if (not isinstance(name, str) or not name or len(name) > 255
            or any(ord(character) < 32 or character in '/\\"' for character in name)):
        raise SyncError("GitHub 附件名称无效或包含路径、控制字符")
    if type(asset.get("id")) is not int or asset["id"] <= 0:
        raise SyncError(f"附件 {name} 的 ID 无效")
    if type(asset.get("size")) is not int or asset["size"] < 0:
        raise SyncError(f"附件 {name} 的大小无效")
    digest = asset.get("digest")
    if digest and not re.fullmatch(r"sha256:[a-fA-F0-9]{64}", digest):
        raise SyncError(f"附件 {name} 的 SHA-256 摘要无效")
    return asset


def releases(client: HttpClient, repository: str, tag: str | None, latest: bool) -> list[dict]:
    base = f"/repos/{repository_path(repository)}/releases"
    if tag or latest:
        path = f"{base}/tags/{quote(tag, safe='')}" if tag else f"{base}/latest"
        result = [client.json(path, "读取 GitHub Release")]
    else:
        result = []
        for page in range(1, 1001):
            batch = client.json(base, "列出 GitHub Releases", params={"page": page, "per_page": 100})
            if not isinstance(batch, list):
                raise SyncError("GitHub Release 列表无效")
            result.extend(batch)
            if len(batch) < 100:
                break
        else:
            raise SyncError("GitHub Release 分页超出限制")
        result.reverse()
    for release in result:
        if not isinstance(release, dict) or not isinstance(release.get("tag_name"), str):
            raise SyncError("GitHub Release 元数据无效")
    return [release for release in result if not release.get("draft")]


def release_assets(client: HttpClient, repository: str, release: dict, names: list[str]) -> list[dict]:
    # 独立分页读取附件，避免 Release 内嵌列表在附件较多时被截断。
    release_id = release.get("id")
    if type(release_id) is not int or release_id <= 0:
        raise SyncError("GitHub Release ID 无效")
    result = []
    path = f"/repos/{repository_path(repository)}/releases/{release_id}/assets"
    for page in range(1, 1001):
        batch = client.json(path, "列出 GitHub 附件", params={"page": page, "per_page": 100})
        if not isinstance(batch, list):
            raise SyncError("GitHub 附件列表无效")
        result.extend(validate_asset(asset) for asset in batch)
        if len(batch) < 100:
            break
    else:
        raise SyncError("GitHub 附件分页超出限制")
    if len({asset["name"] for asset in result}) != len(result):
        raise SyncError("GitHub Release 中有重复附件名称")
    if names:
        missing = set(names) - {asset["name"] for asset in result}
        if missing:
            raise SyncError("指定附件不存在：" + ", ".join(sorted(missing)))
        result = [asset for asset in result if asset["name"] in names]
    return result


def hash_file(path: Path) -> tuple[int, str]:
    digest = hashlib.sha256()
    size = 0
    with path.open("rb") as file:
        while chunk := file.read(CHUNK_SIZE):
            size += len(chunk)
            digest.update(chunk)
    return size, digest.hexdigest()


def consume_binary(client: HttpClient, url: str, action: str, expected_size: int | None, file=None) -> str:
    digest = hashlib.sha256()
    size = 0
    try:
        with client.binary(url, action) as response:
            for chunk in response.iter_content(CHUNK_SIZE):
                size += len(chunk)
                if expected_size is not None and size > expected_size:
                    raise SyncError(f"{action}：文件超过预期大小")
                digest.update(chunk)
                if file is not None:
                    file.write(chunk)
    except requests.RequestException as exc:
        raise SyncError(f"{action}：下载中断（{type(exc).__name__}）") from None
    if expected_size is not None and size != expected_size:
        raise SyncError(f"{action}：文件大小不符（预期 {expected_size}，实际 {size}）")
    return digest.hexdigest()


def cache_asset(client: HttpClient, repository: str, asset: dict, cache: Path) -> tuple[Path, str]:
    validate_asset(asset)
    identity = {key: asset.get(key) for key in ("id", "name", "size", "updated_at", "digest")}
    identity["repository"] = repository
    # 路径只使用哈希，不把远端文件名或 Tag 用作本地路径。
    key = hashlib.sha256(json.dumps(identity, sort_keys=True).encode()).hexdigest()
    path = cache / f"{key}.bin"
    manifest = cache / f"{key}.json"
    if path.is_file() and manifest.is_file():
        try:
            recorded = json.loads(manifest.read_text(encoding="utf-8"))
            size, digest = hash_file(path)
            if (recorded.get("source") == identity and size == asset["size"]
                    and digest == recorded.get("sha256")
                    and (not asset.get("digest") or f"sha256:{digest}" == asset["digest"].lower())):
                print(f"  缓存有效：{asset['name']}", flush=True)
                return path, digest
        except (ValueError, AttributeError):
            pass
    cache.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(".part")
    url = f"{GITHUB_API}/repos/{repository_path(repository)}/releases/assets/{asset['id']}"
    try:
        for attempt in range(client.attempts):
            print(f"  下载：{asset['name']}（{asset['size']} 字节，第 {attempt + 1} 次）", flush=True)
            try:
                with temporary.open("wb") as file:
                    digest = consume_binary(client, url, "下载 GitHub 附件", asset["size"], file)
                if asset.get("digest") and f"sha256:{digest}" != asset["digest"].lower():
                    raise SyncError(f"附件 {asset['name']} 的 SHA-256 不符")
                break
            except SyncError:
                if attempt + 1 == client.attempts:
                    raise
                time.sleep(min(2 ** attempt, 8))
        temporary.replace(path)
        manifest_temporary = manifest.with_suffix(".part")
        manifest_temporary.write_text(json.dumps({"source": identity, "sha256": digest}, indent=2), encoding="utf-8")
        manifest_temporary.replace(manifest)
        return path, digest
    finally:
        temporary.unlink(missing_ok=True)


class CacheLock:
    """同一缓存目录只允许一个写入进程，避免重复上传和缓存覆盖。"""

    def __init__(self, cache: Path):
        cache.mkdir(parents=True, exist_ok=True)
        self.path = cache / ".sync.lock"
        try:
            with self.path.open("x", encoding="utf-8") as file:
                file.write(str(os.getpid()))
        except FileExistsError:
            raise SyncError("缓存正在被另一个同步进程使用；若上次异常退出，请确认进程结束后删除 .sync.lock") from None

    def close(self) -> None:
        self.path.unlink(missing_ok=True)


class Mirror:
    def __init__(self, platform: str, repository: str, client: HttpClient):
        self.platform = platform
        self.repository = repository
        self.client = client
        self.base = f"/repos/{repository_path(repository)}"

    def release(self, tag: str) -> dict:
        result = self.client.json(f"{self.base}/releases/tags/{quote(tag, safe='')}", f"读取 {self.platform} Release")
        if not isinstance(result, dict) or result.get("tag_name") != tag:
            raise SyncError(f"{self.platform} 返回的 Release Tag 不符")
        return result

    def assets(self, tag: str) -> list[dict]:
        release = self.release(tag)
        if self.platform == "gitee":
            release_id = release.get("id")
            if type(release_id) is not int or release_id <= 0:
                raise SyncError("Gitee Release ID 无效")
            result = []
            for page in range(1, 1001):
                batch = self.client.json(f"{self.base}/releases/{release_id}/attach_files", "列出 Gitee 附件",
                                         params={"page": page, "per_page": 100})
                if not isinstance(batch, list):
                    raise SyncError("Gitee 附件列表无效")
                result.extend(batch)
                if len(batch) < 100:
                    break
            else:
                raise SyncError("Gitee 附件分页超出限制")
        else:
            # GitCode 的列表混有自动生成的源码压缩包，它们不属于上传附件。
            result = release.get("assets")
            if not isinstance(result, list):
                raise SyncError("GitCode 附件列表无效")
            result = [asset for asset in result if isinstance(asset, dict) and asset.get("type") != "source"]
        if any(not isinstance(asset, dict) or not isinstance(asset.get("name"), str) for asset in result):
            raise SyncError(f"{self.platform} 附件元数据无效")
        return result

    def find(self, tag: str, name: str) -> dict | None:
        matches = [asset for asset in self.assets(tag) if asset["name"] == name]
        if len(matches) > 1:
            raise SyncError(f"{self.platform} 存在多个同名附件 {name}，请先在网页处理")
        return matches[0] if matches else None

    def upload(self, tag: str, asset: dict, path: Path) -> None:
        action = f"上传 {self.platform} 附件"
        if self.platform == "gitee":
            # requests 的 files 参数会把整个文件读入内存，使用流式 multipart 编码器。
            from requests_toolbelt.multipart.encoder import MultipartEncoder

            release = self.release(tag)
            url = f"{self.client.api}{self.base}/releases/{release['id']}/attach_files"
            with path.open("rb") as file:
                body = MultipartEncoder(fields={"file": (asset["name"], file, "application/octet-stream")})
                headers = {**self.client.headers(url), "Content-Type": body.content_type}
                with self.client.request("POST", url, action, headers=headers, data=body) as response:
                    if response.status_code not in (200, 201):
                        raise SyncError(f"{action}：HTTP {response.status_code}")
        else:
            upload = self.client.json(f"{self.base}/releases/{quote(tag, safe='')}/upload_url",
                                      "获取 GitCode 上传地址", params={"file_name": asset["name"]})
            if not isinstance(upload, dict) or not isinstance(upload.get("headers"), dict):
                raise SyncError("GitCode 上传地址响应无效")
            url = secure_url(upload.get("url"))
            headers = upload["headers"]
            if any(not isinstance(key, str) or not isinstance(value, str) for key, value in headers.items()):
                raise SyncError("GitCode 上传请求头无效")
            with path.open("rb") as file:
                # 只携带上传接口返回的签名头，禁止加入平台令牌，也不跟随上传重定向。
                with self.client.request("PUT", url, action, headers=headers, data=file) as response:
                    if response.status_code not in (200, 201, 204):
                        raise SyncError(f"{action}：HTTP {response.status_code}")

    def delete(self, tag: str, asset: dict) -> None:
        attachment_id = asset.get("id")
        if not isinstance(attachment_id, (int, str)) or not str(attachment_id):
            raise SyncError(f"{self.platform} 没有提供附件 ID，无法安全替换")
        release_key = str(self.release(tag)["id"]) if self.platform == "gitee" else quote(tag, safe="")
        url = f"{self.client.api}{self.base}/releases/{release_key}/attach_files/{quote(str(attachment_id), safe='')}"
        with self.client.request("DELETE", url, f"删除 {self.platform} 冲突附件",
                                 headers=self.client.headers(url)) as response:
            if response.status_code not in (200, 204):
                raise SyncError(f"删除 {self.platform} 冲突附件：HTTP {response.status_code}；本地备份已保留")


def remote_digest(mirror: Mirror, asset: dict, backup: Path | None = None) -> str:
    url = secure_url(asset.get("browser_download_url"))
    if backup is None:
        return consume_binary(mirror.client, url, f"验证 {mirror.platform} 附件", None)
    with backup.open("wb") as file:
        return consume_binary(mirror.client, url, f"备份 {mirror.platform} 冲突附件", None, file)


def sync_asset(mirror: Mirror, tag: str, asset: dict, path: Path, digest: str, cache: Path,
               replace: bool = False, verify_only: bool = False) -> str:
    existing = mirror.find(tag, asset["name"])
    if existing:
        if replace and not verify_only:
            # 删除前完整下载旧附件。备份不含签名 URL，可在上传失败后用于人工恢复。
            backup_key = hashlib.sha256(json.dumps([mirror.platform, mirror.repository, tag, existing.get("id"),
                                                    asset["name"], time.time_ns()]).encode()).hexdigest()
            backup = cache / f"backup-{backup_key}.bin"
            temporary = backup.with_suffix(".part")
            try:
                old_digest = remote_digest(mirror, existing, temporary)
                if old_digest == digest:
                    return "一致，跳过"
                temporary.replace(backup)
                backup.with_suffix(".json").write_text(json.dumps({"platform": mirror.platform,
                    "repository": mirror.repository, "tag": tag, "name": asset["name"],
                    "sha256": old_digest}, ensure_ascii=False, indent=2), encoding="utf-8")
                print(f"    旧附件已备份：{backup.name}", flush=True)
                mirror.delete(tag, existing)
            finally:
                temporary.unlink(missing_ok=True)
        elif remote_digest(mirror, existing) == digest:
            return "一致，跳过"
        else:
            raise SyncError("同名附件内容不同；使用 --replace 才会备份并替换，请先确认计划")
    elif verify_only:
        raise SyncError("目标附件缺失")

    print(f"    上传：{mirror.platform} / {asset['name']}", flush=True)
    upload_error = None
    try:
        mirror.upload(tag, asset, path)
    except SyncError as exc:
        upload_error = exc
        print("    上传响应未确认，查询远端附件状态", flush=True)
    # 处理超时和回调延迟：先重新查询并校验，禁止盲目重试 POST/PUT。
    for attempt in range(4):
        if attempt:
            time.sleep(2)
        uploaded = mirror.find(tag, asset["name"])
        if uploaded:
            if remote_digest(mirror, uploaded) != digest:
                raise SyncError("上传后的附件 SHA-256 不符，请检查网页端文件")
            return "上传成功，SHA-256 已验证"
    if upload_error:
        raise SyncError(f"{upload_error}；远端尚未确认，请稍后重新运行以核对并补传")
    raise SyncError("上传接口成功，但附件暂未出现在列表中；请稍后重新运行或检查网页")
