#!/usr/bin/env python3

"""Build a Telegram release caption within the Bot API length limit."""

from __future__ import annotations

import argparse
from pathlib import Path


CAPTION_LIMIT = 1024


def telegram_length(text: str) -> int:
    return len(text.encode("utf-16-le")) // 2


def compose_caption(
    project: str,
    version: str,
    details: list[str],
    release_url: str,
) -> str:
    lines = [f"{project}版本{version}更新"]
    if details:
        lines.extend(["", "更新明细：", *details])
    lines.extend(
        [
            "",
            f"仓库发版地址：{release_url}",
            f"欢迎将{project}推荐给其他人！",
        ]
    )
    return "\n".join(lines)


def fit_caption(
    project: str,
    version: str,
    details: list[str],
    release_url: str,
) -> str:
    full_caption = compose_caption(project, version, details, release_url)
    if telegram_length(full_caption) <= CAPTION_LIMIT:
        return full_caption

    visible_details: list[str] = []
    for detail in details:
        candidate_details = [*visible_details, detail]
        omitted_count = len(details) - len(candidate_details)
        if omitted_count:
            candidate_details.append(f"- ……另有 {omitted_count} 条更新，详见 Release")
        if telegram_length(compose_caption(project, version, candidate_details, release_url)) > CAPTION_LIMIT:
            break
        visible_details.append(detail)

    omitted_count = len(details) - len(visible_details)
    if omitted_count:
        visible_details.append(f"- ……另有 {omitted_count} 条更新，详见 Release")
    return compose_caption(project, version, visible_details, release_url)


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--details-file", required=True, type=Path)
    parser.add_argument("--release-url", required=True)
    parser.add_argument("--output", required=True, type=Path)
    return parser.parse_args()


def main() -> int:
    arguments = parse_arguments()
    details = [
        line.strip()
        for line in arguments.details_file.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]
    caption = fit_caption(
        arguments.project,
        arguments.version,
        details,
        arguments.release_url,
    )
    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    arguments.output.write_text(f"{caption}\n", encoding="utf-8")
    print(caption)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
