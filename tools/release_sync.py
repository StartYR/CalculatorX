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


def consume_binary(client: HttpClient, url: str, action: str, expected_size: int, file=None) -> str:
    digest = hashlib.sha256()
    size = 0
    try:
        with client.binary(url, action) as response:
            for chunk in response.iter_content(CHUNK_SIZE):
                size += len(chunk)
                if size > expected_size:
                    raise SyncError(f"{action}：文件超过预期大小")
                digest.update(chunk)
                if file is not None:
                    file.write(chunk)
    except requests.RequestException as exc:
        raise SyncError(f"{action}：下载中断（{type(exc).__name__}）") from None
    if size != expected_size:
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
