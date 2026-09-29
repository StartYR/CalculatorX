from __future__ import annotations

import os
from urllib.parse import quote

import requests


GITHUB_API = "https://api.github.com"
GITEE_API = "https://gitee.com/api/v5"
GITCODE_API = "https://api.gitcode.com/api/v5"


def required_env(name: str) -> str:
    value = os.environ.get(name)

    if not value:
        raise RuntimeError(
            f"Missing required environment variable: {name}"
        )

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


GITHUB_HEADERS = {
    "Authorization": f"Bearer {GITHUB_TOKEN}",
    "Accept": "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28",
}


def enc(value: str) -> str:
    return quote(str(value), safe="")


def checked(
    response: requests.Response,
    action: str,
) -> requests.Response:
    if 200 <= response.status_code < 300:
        return response

    detail = response.text[:1500].replace("\n", " ")

    raise RuntimeError(
        f"{action} failed: "
        f"HTTP {response.status_code}: {detail}"
    )


# ---------------------------------------------------------------------------
# GitHub
# ---------------------------------------------------------------------------

def github_releases() -> list[dict]:
    if SYNC_TAG:
        response = requests.get(
            (
                f"{GITHUB_API}/repos/{SOURCE_REPOSITORY}"
                f"/releases/tags/{enc(SYNC_TAG)}"
            ),
            headers=GITHUB_HEADERS,
            timeout=60,
        )

        checked(
            response,
            f"Get GitHub release {SYNC_TAG}",
        )

        release = response.json()

        return [] if release.get("draft") else [release]

    releases: list[dict] = []
    page = 1

    while True:
        response = requests.get(
            (
                f"{GITHUB_API}/repos/"
                f"{SOURCE_REPOSITORY}/releases"
            ),
            headers=GITHUB_HEADERS,
            params={
                "per_page": 100,
                "page": page,
            },
            timeout=60,
        )

        checked(
            response,
            "List GitHub releases",
        )

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

    releases.sort(
        key=lambda release: (
            release.get("published_at")
            or release.get("created_at")
            or ""
        )
    )

    return releases


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
        params={
            "access_token": GITEE_TOKEN,
        },
        timeout=60,
    )

    if response.status_code == 404:
        return None

    checked(
        response,
        f"Get Gitee release {tag}",
    )

    return response.json()


def gitee_upsert_release(release: dict) -> None:
    tag = release["tag_name"]
    name = release.get("name") or tag
    body = release.get("body") or ""

    existing = gitee_get_release(tag)

    payload = {
        "tag_name": tag,
        "name": name,
        "body": body,
        "prerelease": str(
            bool(release.get("prerelease"))
        ).lower(),
    }

    if existing:
        print(f"  Update Gitee release: {tag}")

        response = requests.patch(
            (
                f"{gitee_base()}/releases/"
                f'{existing["id"]}'
            ),
            data={
                **payload,
                "access_token": GITEE_TOKEN,
            },
            timeout=60,
        )

        checked(
            response,
            f"Update Gitee release {tag}",
        )

        return

    print(f"  Create Gitee release: {tag}")

    payload["target_commitish"] = (
        release.get("target_commitish")
        or "main"
    )

    response = requests.post(
        f"{gitee_base()}/releases",
        data={
            **payload,
            "access_token": GITEE_TOKEN,
        },
        timeout=60,
    )

    checked(
        response,
        f"Create Gitee release {tag}",
    )


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
        (
            f"{gitcode_base()}/releases/"
            f"tags/{enc(tag)}"
        ),
        params=gitcode_params(),
        timeout=60,
    )

    if response.status_code == 404:
        return None

    checked(
        response,
        f"Get GitCode release {tag}",
    )

    return response.json()


def gitcode_upsert_release(release: dict) -> None:
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
            (
                f"{gitcode_base()}/releases/"
                f"{enc(tag)}"
            ),
            params=gitcode_params(),
            json={
                "name": name,
                "body": body,
                "release_status": release_status,
            },
            timeout=60,
        )

        checked(
            response,
            f"Update GitCode release {tag}",
        )

        return

    print(f"  Create GitCode release: {tag}")

    response = requests.post(
        f"{gitcode_base()}/releases",
        params=gitcode_params(),
        json={
            "tag_name": tag,
            "name": name,
            "body": body,
            "target_commitish": (
                release.get("target_commitish")
                or "main"
            ),
            "release_status": release_status,
        },
        timeout=60,
    )

    checked(
        response,
        f"Create GitCode release {tag}",
    )


# ---------------------------------------------------------------------------
# Sync
# ---------------------------------------------------------------------------

def sync_release(release: dict) -> None:
    tag = release["tag_name"]

    print("")
    print(f"=== Sync release metadata: {tag} ===")

    errors: list[str] = []

    try:
        gitee_upsert_release(release)
        print(f"  Gitee: OK")
    except Exception as exc:
        print(f"  Gitee: FAILED: {exc}")
        errors.append(f"Gitee: {exc}")

    try:
        gitcode_upsert_release(release)
        print(f"  GitCode: OK")
    except Exception as exc:
        print(f"  GitCode: FAILED: {exc}")
        errors.append(f"GitCode: {exc}")

    if errors:
        raise RuntimeError(
            f"Release metadata sync failed for {tag}:\n"
            + "\n".join(errors)
        )


def main() -> None:
    releases = github_releases()

    if not releases:
        print(
            "No published GitHub Releases found."
        )
        return

    print(
        f"Found {len(releases)} "
        "GitHub release(s) to sync."
    )

    for release in releases:
        sync_release(release)

    print("")
    print(
        "Release metadata synchronization completed."
    )


if __name__ == "__main__":
    main()