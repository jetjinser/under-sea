#!/usr/bin/env python3
"""Create a Forgejo pull request for a pushed automatic update branch."""
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


def api_request(url, token, method="GET", payload=None):
    data = None if payload is None else json.dumps(payload).encode()
    request = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={
            "Accept": "application/json",
            "Authorization": f"token {token}",
            "Content-Type": "application/json",
            "User-Agent": "under-sea-update-bot",
        },
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        content = response.read()
        return json.loads(content) if content else {}


def main():
    server = os.environ["GITHUB_SERVER_URL"].rstrip("/")
    repository = os.environ["GITHUB_REPOSITORY"]
    token = os.environ["GITHUB_TOKEN"]
    branch = os.environ["UPDATE_BRANCH"]
    if not token:
        raise SystemExit("GITHUB_TOKEN is empty; cannot create Forgejo pull request")

    encoded_repo = "/".join(urllib.parse.quote(part, safe="")
                              for part in repository.split("/"))
    api_root = f"{server}/api/v1/repos/{encoded_repo}"
    repo = api_request(api_root, token)
    default_branch = repo["default_branch"]
    title = os.environ.get("UPDATE_PR_TITLE")
    if not title:
        run_stamp = branch.removeprefix("automation/update-")
        date, hour, *_ = run_stamp.split("-")
        date_label = f"{date[:4]}-{date[4:6]}-{date[6:8]} {hour[:2]}:{hour[2:]} UTC"
        title = f"Automated package updates ({date_label})"
    payload = {
        "head": branch,
        "base": default_branch,
        "title": title,
        "body": (
            "This pull request contains signed package update commits produced "
            "by the under-sea update workflow. Package and declared-dependent builds "
            "passed before publication. Forgejo CI runs on the update branch; "
            "please review the changes and CI result before merging."
        ),
    }
    pull = api_request(f"{api_root}/pulls", token, "POST", payload)
    url = pull.get("html_url") or pull.get("url")
    if not url:
        raise SystemExit("Forgejo created the pull request but returned no URL")

    output_file = os.environ.get("GITHUB_OUTPUT")
    if output_file:
        with open(output_file, "a", encoding="utf-8") as stream:
            stream.write(f"url={url}\n")
    report_file = Path(os.environ.get("RUNNER_TEMP", "/var/tmp")) / "automatic-update-report.md"
    with report_file.open("a", encoding="utf-8") as stream:
        stream.write(f"- Pull request: {url}\n")
    print(f"Created pull request: {url}")

    workflow = urllib.parse.quote("repository-verify.yaml", safe="")
    dispatch_url = f"{api_root}/actions/workflows/{workflow}/dispatches"
    api_request(dispatch_url, token, "POST", {"ref": branch})
    with report_file.open("a", encoding="utf-8") as stream:
        stream.write(f"- CI workflow dispatch requested for `{branch}`.\n")
    print(f"Dispatched repository-verify.yaml for {branch}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        print(f"Forgejo API returned HTTP {error.code}: {detail}", file=sys.stderr)
        raise SystemExit(1)
    except (KeyError, urllib.error.URLError, TimeoutError, json.JSONDecodeError) as error:
        print(f"Could not create Forgejo pull request: {error}", file=sys.stderr)
        raise SystemExit(1)
