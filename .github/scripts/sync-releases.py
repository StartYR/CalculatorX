from __future__ import annotations
from requests_toolbelt.multipart.encoder import MultipartEncoder

import mimetypes
import os
import pathlib
import tempfile
from urllib.parse import quote

import requests


GITHUB_API = "https://api.github.com"
GITEE_API = "https://gitee.com/api/v5"
GITCODE_API = "https://api.gitcode.com/api/v5"


def required_env(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return value


SOURCE_REPOSITORY = required_env("SOURCE_REPOSITORY")
GITHUB_TOKEN = required_env("GITHUB_TOKEN")

GITEE_TOKEN = required_env("GITEE_TOKEN")
GITEE_OWNER = required_env("GITEE_OWNER")
GITEE_REPO = required_env("GITEE_REPO")

GITCODE_TOKEN = required_env("GITCODE_TOKEN")
GITCODE_OWNER = required_env("GITCODE_OWNER")
GITCODE_REPO = required_env("GITCODE_REPO")

SYNC_TAG = os.environ.get("SYNC_TAG", "").strip()

REPLACE_ASSETS = (
    os.environ.get("REPLACE_ASSETS", "false").strip().lower()
    in {"1", "true", "yes", "on"}
)

GITEE_MAX_ASSET_BYTES = int(
    os.environ.get("GITEE_MAX_ASSET_BYTES", "104857600")
)

GITHUB_HEADERS = {
    "Authorization": f"Bearer {GITHUB_TOKEN}",
    "Accept": "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28",
}


def enc(value: str) -> str:
    return quote(str(value), safe="")


def warn(message: str) -> None:
    print(f"::warning::{message}")


def checked(response: requests.Response, action: str) -> requests.Response:
    if 200 <= response.status_code < 300:
        return response

    detail = response.text[:1500].replace("\n", " ")
    raise RuntimeError(
        f"{action} failed: HTTP {response.status_code}: {detail}"
    )


# ---------------------------------------------------------------------------
# GitHub
# ---------------------------------------------------------------------------

def github_releases() -> list[dict]:
    if SYNC_TAG:
        url = (
            f"{GITHUB_API}/repos/{SOURCE_REPOSITORY}"
            f"/releases/tags/{enc(SYNC_TAG)}"
        )

        response = requests.get(
            url,
            headers=GITHUB_HEADERS,
            timeout=60,
        )
        checked(response, f"Get GitHub release {SYNC_TAG}")

        release = response.json()
        return [] if release.get("draft") else [release]

    releases: list[dict] = []
    page = 1

    while True:
        response = requests.get(
            f"{GITHUB_API}/repos/{SOURCE_REPOSITORY}/releases",
            headers=GITHUB_HEADERS,
            params={
                "per_page": 100,
                "page": page,
            },
            timeout=60,
        )
        checked(response, "List GitHub releases")

        batch = response.json()

        if not batch:
            break

        releases.extend(
            release
            for release in batch
            if not release.get("draft")
        )

        if len(batch) < 100:
            break

        page += 1

    # 历史补同步时按发布时间从旧到新执行。
    releases.sort(
        key=lambda release: (
            release.get("published_at")
            or release.get("created_at")
            or ""
        )
    )

    return releases


def download_github_asset(asset: dict, directory: pathlib.Path) -> pathlib.Path:
    name = asset["name"]

    path = directory / f'{asset["id"]}-{name}'

    headers = dict(GITHUB_HEADERS)
    headers["Accept"] = "application/octet-stream"

    print(
        f'  Download GitHub asset: {name} '
        f'({asset.get("size", 0)} bytes)'
    )

    with requests.get(
        asset["url"],
        headers=headers,
        stream=True,
        allow_redirects=True,
        timeout=(60, 3600),
    ) as response:
        checked(response, f"Download GitHub asset {name}")

        with path.open("wb") as output:
            for chunk in response.iter_content(chunk_size=1024 * 1024):
                if chunk:
                    output.write(chunk)

    expected_size = int(asset.get("size") or 0)

    if expected_size and path.stat().st_size != expected_size:
        raise RuntimeError(
            f"Asset size mismatch for {name}: "
            f'expected {expected_size}, got {path.stat().st_size}'
        )

    return path


# ---------------------------------------------------------------------------
# Gitee
# ---------------------------------------------------------------------------

def gitee_base() -> str:
    return (
        f"{GITEE_API}/repos/"
        f"{enc(GITEE_OWNER)}/{enc(GITEE_REPO)}"
    )


def gitee_get_release(tag: str) -> dict | None:
    response = requests.get(
        f"{gitee_base()}/releases/tags/{enc(tag)}",
        params={"access_token": GITEE_TOKEN},
        timeout=60,
    )

    if response.status_code == 404:
        return None

    checked(response, f"Get Gitee release {tag}")
    return response.json()


def gitee_upsert_release(release: dict) -> dict:
    tag = release["tag_name"]

    name = release.get("name") or tag
    body = release.get("body") or ""

    existing = gitee_get_release(tag)

    payload = {
        "tag_name": tag,
        "name": name,
        "body": body,
        "prerelease": str(bool(release.get("prerelease"))).lower(),
    }

    if existing:
        print(f"  Update Gitee release: {tag}")

        response = requests.patch(
            f'{gitee_base()}/releases/{existing["id"]}',
            data={
                **payload,
                "access_token": GITEE_TOKEN,
            },
            timeout=60,
        )

        checked(response, f"Update Gitee release {tag}")
        return response.json()

    print(f"  Create Gitee release: {tag}")

    payload["target_commitish"] = (
        release.get("target_commitish") or "main"
    )

    response = requests.post(
        f"{gitee_base()}/releases",
        data={
            **payload,
            "access_token": GITEE_TOKEN,
        },
        timeout=60,
    )

    checked(response, f"Create Gitee release {tag}")
    return response.json()


def gitee_assets(release_id: int | str) -> list[dict]:
    assets: list[dict] = []
    page = 1

    while True:
        response = requests.get(
            f"{gitee_base()}/releases/{release_id}/attach_files",
            params={
                "access_token": GITEE_TOKEN,
                "page": page,
                "per_page": 100,
            },
            timeout=60,
        )

        checked(response, "List Gitee release assets")

        batch = response.json()

        if not batch:
            break

        assets.extend(batch)

        if len(batch) < 100:
            break

        page += 1

    return assets


def gitee_delete_asset(release_id: int | str, asset: dict) -> None:
    asset_id = asset.get("id")

    if not asset_id:
        warn(
            f'Cannot replace Gitee asset "{asset.get("name")}" '
            "because its attachment ID is unavailable."
        )
        return

    response = requests.delete(
        (
            f"{gitee_base()}/releases/{release_id}"
            f"/attach_files/{asset_id}"
        ),
        params={"access_token": GITEE_TOKEN},
        timeout=60,
    )

    checked(
        response,
        f'Delete Gitee asset {asset.get("name")}',
    )


def gitee_upload_asset(
    release_id: int | str,
    name: str,
    path: pathlib.Path,
) -> None:
    content_type = (
        mimetypes.guess_type(name)[0]
        or "application/octet-stream"
    )

    print(
        f"  Upload to Gitee: {name} "
        f"({path.stat().st_size} bytes)"
    )

    url = (
        f"{gitee_base()}/releases/"
        f"{release_id}/attach_files"
    )

    with path.open("rb") as file:
        multipart = MultipartEncoder(
            fields={
                "file": (
                    name,
                    file,
                    content_type,
                )
            }
        )

        response = requests.post(
            url,
            headers={
                "Authorization": f"Bearer {GITEE_TOKEN}",
                "Content-Type": multipart.content_type,
                "Accept": "application/json",
            },
            data=multipart,
            timeout=(60, 3600),
        )

    checked(response, f"Upload Gitee asset {name}")


# ---------------------------------------------------------------------------
# GitCode
# ---------------------------------------------------------------------------

def gitcode_base() -> str:
    return (
        f"{GITCODE_API}/repos/"
        f"{enc(GITCODE_OWNER)}/{enc(GITCODE_REPO)}"
    )


def gitcode_params(**extra) -> dict:
    return {
        "access_token": GITCODE_TOKEN,
        **extra,
    }


def gitcode_get_release(tag: str) -> dict | None:
    response = requests.get(
        f"{gitcode_base()}/releases/tags/{enc(tag)}",
        params=gitcode_params(),
        timeout=60,
    )

    if response.status_code == 404:
        return None

    checked(response, f"Get GitCode release {tag}")
    return response.json()


def gitcode_upsert_release(release: dict) -> dict:
    tag = release["tag_name"]

    name = release.get("name") or tag
    body = release.get("body") or ""

    release_status = (
        "pre"
        if release.get("prerelease")
        else "latest"
    )

    existing = gitcode_get_release(tag)

    if existing:
        print(f"  Update GitCode release: {tag}")

        response = requests.patch(
            f"{gitcode_base()}/releases/{enc(tag)}",
            params=gitcode_params(),
            json={
                "name": name,
                "body": body,
                "release_status": release_status,
            },
            timeout=60,
        )

        checked(response, f"Update GitCode release {tag}")

    else:
        print(f"  Create GitCode release: {tag}")

        response = requests.post(
            f"{gitcode_base()}/releases",
            params=gitcode_params(),
            json={
                "tag_name": tag,
                "name": name,
                "body": body,
                "target_commitish": (
                    release.get("target_commitish") or "main"
                ),
                "release_status": release_status,
            },
            timeout=60,
        )

        checked(response, f"Create GitCode release {tag}")

    refreshed = gitcode_get_release(tag)

    if refreshed is None:
        raise RuntimeError(
            f"GitCode release {tag} was not found after upsert."
        )

    return refreshed


def gitcode_delete_asset(tag: str, asset: dict) -> bool:
    asset_id = asset.get("id")

    if asset_id is None:
        warn(
            f'Cannot replace GitCode asset "{asset.get("name")}" '
            "because its attachment ID is unavailable."
        )
        return False

    response = requests.delete(
        (
            f"{gitcode_base()}/releases/{enc(tag)}"
            f"/attach_files/{asset_id}"
        ),
        params=gitcode_params(),
        timeout=60,
    )

    checked(
        response,
        f'Delete GitCode asset {asset.get("name")}',
    )

    return True


def gitcode_upload_asset(
    tag: str,
    name: str,
    path: pathlib.Path,
) -> None:
    print(f"  Request GitCode upload URL: {name}")

    response = requests.get(
        f"{gitcode_base()}/releases/{enc(tag)}/upload_url",
        params=gitcode_params(file_name=name),
        timeout=60,
    )

    checked(
        response,
        f"Get GitCode upload URL for {name}",
    )

    upload = response.json()

    upload_url = upload["url"]
    upload_headers = upload.get("headers") or {}

    print(f"  Upload to GitCode: {name}")

    with path.open("rb") as file:
        response = requests.put(
            upload_url,
            headers=upload_headers,
            data=file,
            timeout=(1200, 3600),
        )

    checked(response, f"Upload GitCode asset {name}")


# ---------------------------------------------------------------------------
# Sync
# ---------------------------------------------------------------------------

def sync_release(
    release: dict,
    temp_directory: pathlib.Path,
) -> None:
    tag = release["tag_name"]

    print("")
    print(f"=== Sync release: {tag} ===")

    gitee_release = gitee_upsert_release(release)
    gitcode_release = gitcode_upsert_release(release)

    gitee_release_id = gitee_release["id"]

    current_gitee_assets = {
        asset.get("name"): asset
        for asset in gitee_assets(gitee_release_id)
        if asset.get("name")
    }

    current_gitcode_assets = {
        asset.get("name"): asset
        for asset in gitcode_release.get("assets", [])
        if asset.get("name")
    }

    for asset in release.get("assets", []):
        name = asset["name"]
        size = int(asset.get("size") or 0)

        gitee_too_large = (
            size > GITEE_MAX_ASSET_BYTES
        )

        if gitee_too_large:
            warn(
                f'Gitee skipped "{name}" from {tag}: '
                f"{size} bytes exceeds configured "
                f"{GITEE_MAX_ASSET_BYTES}-byte Release asset limit."
            )

        gitee_needed = (
            not gitee_too_large
            and (
                REPLACE_ASSETS
                or name not in current_gitee_assets
            )
        )

        gitcode_needed = (
            REPLACE_ASSETS
            or name not in current_gitcode_assets
        )

        if not gitee_needed and not gitcode_needed:
            print(f"  Asset already synced: {name}")
            continue

        path = download_github_asset(
            asset,
            temp_directory,
        )

        if gitee_needed:
            existing = current_gitee_assets.get(name)

            if REPLACE_ASSETS and existing:
                gitee_delete_asset(
                    gitee_release_id,
                    existing,
                )

            gitee_upload_asset(
                gitee_release_id,
                name,
                path,
            )

        if gitcode_needed:
            existing = current_gitcode_assets.get(name)

            can_upload = True

            if REPLACE_ASSETS and existing:
                can_upload = gitcode_delete_asset(
                    tag,
                    existing,
                )

            if can_upload:
                gitcode_upload_asset(
                    tag,
                    name,
                    path,
                )

        path.unlink(missing_ok=True)


def main() -> None:
    releases = github_releases()

    if not releases:
        print("No published GitHub Releases found.")
        return

    print(
        f"Found {len(releases)} GitHub release(s) to sync."
    )

    with tempfile.TemporaryDirectory(
        prefix="calcx-release-sync-"
    ) as directory:
        temp_directory = pathlib.Path(directory)

        for release in releases:
            sync_release(
                release,
                temp_directory,
            )

    print("")
    print("Release synchronization completed.")


if __name__ == "__main__":
    main()