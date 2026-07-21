#!/usr/bin/env python3

"""Generate a single Telegram CI caption from successful build history."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import quote, urlencode
from urllib.request import Request, urlopen


BUILD_JOB_NAME = "Build unsigned iOS IPA"
CAPTION_LIMIT = 1024
DEFAULT_API_URL = "https://api.github.com"
PAGE_SIZE = 100
MAX_PAGES = 5
SHA_PATTERN = re.compile(r"^[0-9a-fA-F]{40}$")


def git(*arguments: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *arguments],
        check=check,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )


def resolve_commit(commit_sha: str) -> str | None:
    if not SHA_PATTERN.fullmatch(commit_sha):
        return None
    result = git("rev-parse", "--verify", f"{commit_sha}^{{commit}}", check=False)
    return result.stdout.strip() if result.returncode == 0 else None


def is_ancestor(ancestor_sha: str, current_sha: str) -> bool:
    return (
        git("merge-base", "--is-ancestor", ancestor_sha, current_sha, check=False).returncode
        == 0
    )


def github_api_get(
    api_url: str,
    repository: str,
    token: str,
    endpoint: str,
    query: dict[str, str | int] | None = None,
) -> dict[str, Any]:
    repository_path = quote(repository, safe="/")
    url = f"{api_url.rstrip('/')}/repos/{repository_path}/{endpoint.lstrip('/')}"
    if query:
        url = f"{url}?{urlencode(query)}"

    request = Request(
        url,
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "User-Agent": "MeloX-CI-Commit-Summary",
            "X-GitHub-Api-Version": "2022-11-28",
        },
    )
    try:
        with urlopen(request, timeout=30) as response:
            return json.load(response)
    except HTTPError as error:
        try:
            response = json.load(error)
            message = response.get("message", str(error))
        except (OSError, ValueError):
            message = str(error)
        raise RuntimeError(f"GitHub API 请求失败：{message}") from error
    except URLError as error:
        raise RuntimeError(f"GitHub API 连接失败：{error.reason}") from error


def run_has_successful_build(
    api_url: str,
    repository: str,
    token: str,
    run_id: int,
) -> bool:
    payload = github_api_get(
        api_url,
        repository,
        token,
        f"actions/runs/{run_id}/jobs",
        {"filter": "latest", "per_page": PAGE_SIZE},
    )
    return any(
        job.get("name") == BUILD_JOB_NAME and job.get("conclusion") == "success"
        for job in payload.get("jobs", [])
    )


def find_previous_successful_build(
    api_url: str,
    repository: str,
    token: str,
    workflow: str,
    current_run_id: int,
    current_sha: str,
) -> tuple[str | None, int | None]:
    workflow_id = quote(workflow, safe="")
    for page in range(1, MAX_PAGES + 1):
        payload = github_api_get(
            api_url,
            repository,
            token,
            f"actions/workflows/{workflow_id}/runs",
            {"status": "completed", "per_page": PAGE_SIZE, "page": page},
        )
        runs = payload.get("workflow_runs", [])
        for workflow_run in runs:
            run_id = workflow_run.get("id")
            if not isinstance(run_id, int) or run_id == current_run_id:
                continue
            candidate_sha = resolve_commit(workflow_run.get("head_sha", ""))
            if candidate_sha is None or not is_ancestor(candidate_sha, current_sha):
                continue
            if run_has_successful_build(api_url, repository, token, run_id):
                return candidate_sha, workflow_run.get("run_number")
        if len(runs) < PAGE_SIZE:
            break
    return None, None


def fallback_baseline(fallback_sha: str, current_sha: str) -> str | None:
    if fallback_sha == "0" * 40:
        return None
    resolved_fallback = resolve_commit(fallback_sha)
    if resolved_fallback is None or not is_ancestor(resolved_fallback, current_sha):
        return None
    return resolved_fallback


def read_commits(
    previous_sha: str | None,
    current_sha: str,
) -> list[tuple[str, str, str]]:
    log_format = "%H%x1f%s%x1f%an"
    if previous_sha is None:
        result = git("show", "-s", f"--format={log_format}", current_sha)
    else:
        result = git(
            "log",
            "--reverse",
            f"--format={log_format}",
            f"{previous_sha}..{current_sha}",
        )
    commits: list[tuple[str, str, str]] = []
    for line in result.stdout.splitlines():
        fields = line.split("\x1f", maxsplit=2)
        if len(fields) == 3:
            commits.append((fields[0], fields[1], fields[2]))
    return commits


def telegram_length(text: str) -> int:
    return len(text.encode("utf-16-le")) // 2


def compose_caption(
    header: list[str],
    commit_lines: list[str],
    footer: list[str],
) -> str:
    return "\n".join([*header, "", *commit_lines, "", *footer])


def fit_caption(
    header: list[str],
    commit_lines: list[str],
    footer: list[str],
) -> str:
    full_caption = compose_caption(header, commit_lines, footer)
    if telegram_length(full_caption) <= CAPTION_LIMIT:
        return full_caption

    visible_commits: list[str] = []
    for commit_line in commit_lines:
        candidate_commits = [*visible_commits, commit_line]
        omitted_count = len(commit_lines) - len(candidate_commits)
        if omitted_count:
            candidate_commits.append(f"• ……另有 {omitted_count} 条 Commit，详见 Actions")
        if telegram_length(compose_caption(header, candidate_commits, footer)) > CAPTION_LIMIT:
            break
        visible_commits.append(commit_line)

    omitted_count = len(commit_lines) - len(visible_commits)
    if omitted_count:
        visible_commits.append(f"• ……另有 {omitted_count} 条 Commit，详见 Actions")
    return compose_caption(header, visible_commits, footer)


def format_summary(
    commits: list[tuple[str, str, str]],
    previous_sha: str | None,
    previous_run_number: int | None,
    current_sha: str,
    current_run_number: int,
    repository: str,
    run_url: str,
) -> str:
    header = ["MeloX CI 构建完成"]
    if previous_sha is None:
        header.append(f"范围：首次 CI → CI #{current_run_number} ({current_sha[:7]})")
    else:
        previous_run = (
            f"CI #{previous_run_number}" if previous_run_number else "上一次成功 CI"
        )
        header.append(
            f"范围：{previous_run} ({previous_sha[:7]}) → "
            f"CI #{current_run_number} ({current_sha[:7]})"
        )
    header.append(f"共 {len(commits)} 条 Commit")
    commit_lines = (
        [
            f"• {commit_sha[:7]} {subject} — {author}"
            for commit_sha, subject, author in commits
        ]
        if commits
        else ["• 本次没有新增 Commit"]
    )
    footer = [f"仓库：{repository}", f"详情：{run_url}"]
    return fit_caption(header, commit_lines, footer)


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--current-sha", required=True)
    parser.add_argument("--current-run-id", required=True, type=int)
    parser.add_argument("--current-run-number", required=True, type=int)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--workflow", default="build-unsigned.yml")
    parser.add_argument("--fallback-sha", default="")
    parser.add_argument("--previous-sha")
    parser.add_argument("--run-url", required=True)
    parser.add_argument("--output", required=True, type=Path)
    return parser.parse_args()


def main() -> int:
    arguments = parse_arguments()
    current_sha = resolve_commit(arguments.current_sha)
    if current_sha is None:
        print(f"无法解析当前 Commit：{arguments.current_sha}", file=sys.stderr)
        return 1

    previous_sha: str | None = None
    previous_run_number: int | None = None
    if arguments.previous_sha:
        previous_sha = fallback_baseline(arguments.previous_sha, current_sha)
        if previous_sha is None:
            print(f"无法解析指定的基线 Commit：{arguments.previous_sha}", file=sys.stderr)
            return 1
    else:
        token = os.environ.get("GITHUB_TOKEN", "")
        api_url = os.environ.get("GITHUB_API_URL", DEFAULT_API_URL)
        try:
            if not token:
                raise RuntimeError("缺少 GITHUB_TOKEN")
            previous_sha, previous_run_number = find_previous_successful_build(
                api_url,
                arguments.repository,
                token,
                arguments.workflow,
                arguments.current_run_id,
                current_sha,
            )
        except RuntimeError as error:
            print(f"::warning::{error}，将尝试使用事件 before SHA。", file=sys.stderr)
        if previous_sha is None:
            previous_sha = fallback_baseline(arguments.fallback_sha, current_sha)

    caption = format_summary(
        read_commits(previous_sha, current_sha),
        previous_sha,
        previous_run_number,
        current_sha,
        arguments.current_run_number,
        arguments.repository,
        arguments.run_url,
    )
    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    arguments.output.write_text(f"{caption}\n", encoding="utf-8")
    print(caption)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
