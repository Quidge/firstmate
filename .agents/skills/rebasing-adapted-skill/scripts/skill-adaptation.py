#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.13"
# dependencies = [
#   "pyyaml>=6.0.3,<7",
# ]
# ///
"""Scaffold, validate, and audit skill ADAPTATION.md provenance pins."""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import TYPE_CHECKING, NamedTuple

import yaml

if TYPE_CHECKING:
    from collections.abc import Sequence

EXIT_OK = 0
EXIT_INVALID = 1
EXIT_USAGE = 2
EXIT_FETCH = 3
EXIT_BAD_PATH = 128

_ADAPTATION_NAME = "ADAPTATION.md"
_SKILL_NAME = "SKILL.md"

# The literal ``## Deviations`` bullet a verbatim vendor uses to declare zero
# intentional differences. When it is the section's only bullet it means "no
# deviations" - the same as an empty section - while staying human-readable.
_NO_DEVIATIONS_SENTINEL = "no current deviations"

# Environment override: read pinned base files from a local cache tree instead
# of the network, so an audit runs deterministically and air-gapped. Layout:
# <dir>/<owner>/<repo>/<sha>/<path>/<relpath...>. Used by the offline tests.
_BASE_DIR_ENV = "SKILL_ADAPTATION_BASE_DIR"

# Full-SHA GitHub tree URL to a skill directory (no branch/tag names).
_TREE_URL = re.compile(
    r"^https://github\.com/"
    r"(?P<owner>[A-Za-z0-9_.-]+)/"
    r"(?P<repo>[A-Za-z0-9_.-]+)/"
    r"tree/"
    r"(?P<sha>[0-9a-f]{40})/"
    r"(?P<path>.+)$"
)

_HELP = """\
Scaffold, validate, and audit ADAPTATION.md for adapted agent skills.

An adapted skill pins upstream skill directories via GitHub tree URLs (full
commit SHA + path). The skill lives beside this script's own skill directory
(.agents/skills/rebasing-adapted-skill/) for rebasing onto a newer upstream tip.

Examples:
  # Print an ADAPTATION.md stub to stdout (redirect to create the file):
  skill-adaptation.py template \\
    'https://github.com/org/repo/tree/0123456789abcdef0123456789abcdef01234567/skills/foo' \\
    > /path/to/my-skill/ADAPTATION.md

  # Multiple attributions:
  skill-adaptation.py template \\
    'https://github.com/org/a/tree/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/skills/x' \\
    'https://github.com/org/b/tree/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/skills/y'

  # Validate a skill directory (human-facing; problems on stderr):
  skill-adaptation.py validate-skill-dir ~/.claude/skills/my-skill

  # Audit local files against the pinned base and the declared deviations:
  skill-adaptation.py audit ~/.claude/skills/my-skill

  # Quiet predicate (git check-ignore -q style):
  skill-adaptation.py validate-skill-dir -q /path/to/skill && echo adapted
  skill-adaptation.py audit -q /path/to/skill && echo honest

Side effects:
  - template: none (stdout only; does not write files).
  - validate-skill-dir: local filesystem read + YAML parse only; no network.
  - audit: read-only. Fetches base files at the pinned SHAs (network, or from a
    local cache tree named by the SKILL_ADAPTATION_BASE_DIR env var) and reads
    local files; never writes.

What audit does (and does not) decide:
  audit computes the deterministic per-path difference `ours - base` for every
  pinned attribution and prints it beside the `## Deviations` bullets, so the
  agent can correlate the two by hand. It does NOT match bullets to differences
  by text. Its exit code therefore flags only the two provable rot states:
    - undeclared drift: differences exist but NO deviation is declared, so every
      difference is uncovered (the next rebase would silently revert it);
    - stale deviations: deviations are declared but NO difference exists, so
      every bullet maps to nothing.
  A ## Deviations section whose only bullet is the literal line
  "- no current deviations" is the sentinel a verbatim vendor uses to declare
  zero intentional differences. It reads as no deviations (never a stale
  bullet), so a byte-for-byte vendor audits clean while keeping that
  human-readable line instead of an empty section.
  When both differences and deviations are present, the script cannot prove
  which covers which, so it presents both sides and exits 0; confirming that
  each difference has a covering bullet and each bullet a live difference is the
  agent's job.

Exit codes:
  0    success (template), validly adapted (validate), or no provable rot (audit)
  1    invalid tree URL / not validly adapted / provable drift or stale deviation
  2    argparse usage error
  3    audit: could not fetch a pinned base tree (fails loudly, never "clean")
  128  validate/audit: path missing, not a directory, or no SKILL.md
"""

_TEMPLATE_BODY = """\
## Deviations

- <intentional difference from upstream; delete this bullet if none>
"""


class FetchError(Exception):
    """A pinned base tree could not be fetched."""


class Attribution(NamedTuple):
    """A parsed attribution tree URL."""

    url: str
    owner: str
    repo: str
    sha: str
    path: str


class Drift(NamedTuple):
    """One path whose local file differs from the pinned base."""

    attribution: str
    relpath: str
    kind: str  # "modified" or "removed"


def normalize_tree_url(url: str) -> str:
    """Strip trailing slashes; return the URL unchanged otherwise."""
    return url.rstrip("/")


def parse_tree_url(url: str) -> str | None:
    """Return an error message if ``url`` is not a valid attribution tree URL."""
    normalized = normalize_tree_url(url)
    if _TREE_URL.fullmatch(normalized) is None:
        return (
            "must be a GitHub tree URL with a full 40-char commit SHA: "
            "https://github.com/<owner>/<repo>/tree/<sha>/<path>"
        )
    return None


def parse_attribution(url: str) -> Attribution:
    """Parse a validated attribution tree URL into its parts."""
    normalized = normalize_tree_url(url)
    match = _TREE_URL.fullmatch(normalized)
    if match is None:  # pragma: no cover - callers validate first
        msg = f"not an attribution tree URL: {url}"
        raise ValueError(msg)
    return Attribution(
        url=normalized,
        owner=match["owner"],
        repo=match["repo"],
        sha=match["sha"],
        path=match["path"].rstrip("/"),
    )


def render_template(urls: Sequence[str]) -> str:
    """Render ADAPTATION.md text for the given attribution tree URLs."""
    front: dict[str, list[str]] = {
        "attributions": [normalize_tree_url(u) for u in urls],
    }
    dumped = yaml.safe_dump(
        front,
        default_flow_style=False,
        sort_keys=False,
        allow_unicode=True,
    )
    return f"---\n{dumped}---\n\n{_TEMPLATE_BODY}"


def split_front_matter(text: str) -> tuple[str | None, str]:
    """Split Markdown into (yaml_text_or_None, body)."""
    if not text.startswith("---"):
        return None, text
    rest = text[3:]
    if rest.startswith("\r\n"):
        rest = rest[2:]
    elif rest.startswith("\n"):
        rest = rest[1:]
    else:
        return None, text
    for sep in ("\n---\n", "\n---\r\n", "\r\n---\r\n", "\r\n---\n"):
        idx = rest.find(sep)
        if idx != -1:
            return rest[:idx], rest[idx + len(sep) :]
    # Closing --- on final line with no trailing newline
    if rest.endswith("\n---"):
        return rest[: -len("\n---")], ""
    if rest == "---":
        return "", ""
    return None, text


def _load_adaptation_mapping(path: Path) -> dict[str, object] | list[str]:
    """Return parsed front-matter mapping, or a one-element problem list."""
    text = path.read_text(encoding="utf-8")
    yaml_text, _body = split_front_matter(text)
    if yaml_text is None:
        return [f"{_ADAPTATION_NAME}: missing YAML front matter (opening ---)"]

    try:
        data = yaml.safe_load(yaml_text)
    except yaml.YAMLError as exc:
        return [f"{_ADAPTATION_NAME}: invalid YAML front matter: {exc}"]

    if not isinstance(data, dict):
        return [f"{_ADAPTATION_NAME}: front matter must be a mapping"]
    return data


def _attribution_item_problems(attributions: list[object]) -> list[str]:
    problems: list[str] = []
    for i, item in enumerate(attributions):
        if not isinstance(item, str):
            problems.append(f"{_ADAPTATION_NAME}: attributions[{i}] must be a string")
            continue
        err = parse_tree_url(item)
        if err is not None:
            problems.append(f"{_ADAPTATION_NAME}: attributions[{i}]: {err}")
    return problems


def adaptation_problems(skill_dir: Path) -> list[str]:
    """Return human-readable problems with ADAPTATION.md, or [] if valid.

    Caller must already have established that ``skill_dir`` is a usable skill
    directory (exists, is a dir, contains SKILL.md).
    """
    path = skill_dir / _ADAPTATION_NAME
    if not path.is_file():
        return [f"missing {_ADAPTATION_NAME}"]

    loaded = _load_adaptation_mapping(path)
    if isinstance(loaded, list):
        return loaded

    if "attributions" not in loaded:
        return [f"{_ADAPTATION_NAME}: missing attributions key"]

    attributions = loaded["attributions"]
    if not isinstance(attributions, list):
        return [f"{_ADAPTATION_NAME}: attributions must be a list"]
    if len(attributions) == 0:
        return [f"{_ADAPTATION_NAME}: attributions must be non-empty"]

    return _attribution_item_problems(attributions)


def usable_skill_dir_error(path: Path) -> str | None:
    """Return an error if ``path`` is not a usable skill directory."""
    if not path.exists():
        return f"path does not exist: {path}"
    if not path.is_dir():
        return f"not a directory: {path}"
    if not (path / _SKILL_NAME).is_file():
        return f"no {_SKILL_NAME} in {path}"
    return None


def load_attributions(skill_dir: Path) -> list[Attribution]:
    """Return the parsed attributions from a valid ADAPTATION.md."""
    loaded = _load_adaptation_mapping(skill_dir / _ADAPTATION_NAME)
    if isinstance(loaded, list):  # pragma: no cover - callers validate first
        msg = "; ".join(loaded)
        raise ValueError(msg)  # noqa: TRY004 - invalid ledger, not a type error
    urls = loaded["attributions"]
    return [parse_attribution(url) for url in urls]  # type: ignore[union-attr]


def _collect_deviation_bullets(body: str) -> list[str]:
    """Return the raw ``## Deviations`` bullet texts, minus angle-bracket stubs.

    A stub bullet like ``- <describe the difference>`` is the unedited template
    placeholder, not a real declaration, so it does not count as a deviation.
    """
    bullets: list[str] = []
    in_section = False
    for raw in body.splitlines():
        if raw == "## Deviations":
            in_section = True
            continue
        if re.match(r"^#{1,6}(?:\s|$)", raw) is not None:
            in_section = False
            continue
        if not in_section:
            continue
        item = re.match(r"^[-*]\s+(.*)$", raw.strip())
        if item is None:
            continue
        text = item.group(1).strip()
        if text.startswith("<") and text.endswith(">"):
            continue
        if text:
            bullets.append(text)
    return bullets


def is_no_deviations_sentinel(bullets: Sequence[str]) -> bool:
    """Whether ``bullets`` is exactly the "no deviations" sentinel.

    A ``## Deviations`` section whose only bullet is the literal line
    ``- no current deviations`` declares that the skill is a verbatim vendor with
    zero intentional differences. It is kept as a human-readable line rather than
    an empty section, but it means the same thing: no deviations to protect.
    """
    return list(bullets) == [_NO_DEVIATIONS_SENTINEL]


def parse_deviation_bullets(body: str) -> list[str]:
    """Return the declared ``## Deviations`` bullets, or ``[]`` for none.

    Two forms declare zero deviations, both collapsing to an empty list: the
    unedited angle-bracket placeholder, and the sole ``- no current deviations``
    sentinel (see :func:`is_no_deviations_sentinel`).
    """
    bullets = _collect_deviation_bullets(body)
    if is_no_deviations_sentinel(bullets):
        return []
    return bullets


def read_deviation_ledger(skill_dir: Path) -> tuple[list[str], bool]:
    """Read a skill's ``## Deviations`` as ``(declared_bullets, is_sentinel)``.

    ``declared_bullets`` is empty when zero deviations are declared, and the
    boolean records whether that emptiness came from the ``- no current
    deviations`` sentinel so callers can echo the human-readable line.
    """
    text = (skill_dir / _ADAPTATION_NAME).read_text(encoding="utf-8")
    _front, body = split_front_matter(text)
    raw = _collect_deviation_bullets(body)
    sentinel = is_no_deviations_sentinel(raw)
    return ([] if sentinel else raw), sentinel


def read_deviation_bullets(skill_dir: Path) -> list[str]:
    """Read ``## Deviations`` bullets from a skill directory's ADAPTATION.md."""
    bullets, _sentinel = read_deviation_ledger(skill_dir)
    return bullets


def _read_base_from_cache(
    base_dir: Path,
    attribution: Attribution,
) -> dict[str, bytes]:
    """Read a pinned base subtree from a local cache directory."""
    try:
        sha_root = (
            base_dir / attribution.owner / attribution.repo / attribution.sha
        ).resolve()
        decoded_path = Path(urllib.parse.unquote(attribution.path))
        if decoded_path.is_absolute() or ".." in decoded_path.parts:
            msg = f"invalid cached base path for {attribution.url}"
            raise FetchError(msg)
        root = (sha_root / decoded_path).resolve()
        if not root.is_relative_to(sha_root):
            msg = f"cached base path escapes SHA root for {attribution.url}"
            raise FetchError(msg)
        if not root.is_dir():
            msg = f"no cached base tree at {root}"
            raise FetchError(msg)
        files: dict[str, bytes] = {}
        for path in sorted(root.rglob("*")):
            if path.is_file():
                files[path.relative_to(root).as_posix()] = path.read_bytes()
        return files
    except OSError as exc:
        msg = f"could not read cached base for {attribution.url}: {exc}"
        raise FetchError(msg) from exc


def _http_get(url: str, *, accept: str) -> bytes:
    """Fetch a URL, sending a token from the environment when present."""
    # URLs are built here from https:// literals and pinned SHAs only.
    request = urllib.request.Request(url)
    request.add_header("Accept", accept)
    request.add_header("User-Agent", "skill-adaptation")
    token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
    if token:
        request.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(request) as response:
            return response.read()
    except (urllib.error.URLError, TimeoutError) as exc:
        msg = f"fetch failed for {url}: {exc}"
        raise FetchError(msg) from exc


def _fetch_base_from_github(attribution: Attribution) -> dict[str, bytes]:
    """Fetch a pinned base subtree from GitHub at the exact commit SHA."""
    tree_url = (
        f"https://api.github.com/repos/{attribution.owner}/{attribution.repo}"
        f"/git/trees/{attribution.sha}?recursive=1"
    )
    raw = _http_get(tree_url, accept="application/vnd.github+json")
    try:
        tree = json.loads(raw)
    except json.JSONDecodeError as exc:
        msg = f"unreadable tree listing for {attribution.url}: {exc}"
        raise FetchError(msg) from exc
    if tree.get("truncated"):
        msg = f"tree listing truncated for {attribution.url}; cannot audit"
        raise FetchError(msg)

    prefix = urllib.parse.unquote(attribution.path) + "/"
    files: dict[str, bytes] = {}
    for entry in tree.get("tree", []):
        if entry.get("type") != "blob":
            continue
        full = entry.get("path", "")
        if not full.startswith(prefix):
            continue
        relpath = full[len(prefix) :]
        encoded_full = urllib.parse.quote(full, safe="/")
        content_url = (
            f"https://raw.githubusercontent.com/{attribution.owner}"
            f"/{attribution.repo}/{attribution.sha}/{encoded_full}"
        )
        files[relpath] = _http_get(content_url, accept="application/octet-stream")
    return files


def fetch_base_files(attribution: Attribution) -> dict[str, bytes]:
    """Return {relpath: bytes} for a pinned attribution's base subtree.

    Reads from the SKILL_ADAPTATION_BASE_DIR cache tree when that env var is
    set, otherwise from GitHub. Either way the content is pinned to the exact
    commit SHA, so the result is deterministic.
    """
    base_dir = os.environ.get(_BASE_DIR_ENV)
    if base_dir:
        files = _read_base_from_cache(Path(base_dir), attribution)
    else:
        files = _fetch_base_from_github(attribution)
    if _SKILL_NAME not in files:
        msg = f"pinned base tree has no {_SKILL_NAME}: {attribution.url}"
        raise FetchError(msg)
    return files


def compute_drift(
    attribution: Attribution,
    base_files: dict[str, bytes],
    skill_dir: Path,
) -> list[Drift]:
    """Return the local differences from a pinned base subtree.

    Compares only paths present in the base, because those are exactly the paths
    where the next rebase's "silence = match upstream" rule would clobber
    undeclared local work: a base file edited locally (modified) or deleted
    locally (removed). Local-only additions stay local across a rebase and carry
    no such risk, so they are out of scope. ADAPTATION.md is never merged and is
    always excluded.
    """
    drift: list[Drift] = []
    for relpath, content in base_files.items():
        if relpath == _ADAPTATION_NAME:
            continue
        local = skill_dir / relpath
        if not local.is_file():
            drift.append(Drift(attribution.url, relpath, "removed"))
        elif local.read_bytes() != content:
            drift.append(Drift(attribution.url, relpath, "modified"))
    return sorted(drift)


class AuditResult(NamedTuple):
    """The deterministic audit of a skill directory."""

    drift: list[Drift]
    bullets: list[str]
    no_deviations_sentinel: bool = False

    @property
    def undeclared_drift(self) -> list[Drift]:
        """Differences with provably no covering bullet (no bullet declared)."""
        return self.drift if not self.bullets else []

    @property
    def stale_bullets(self) -> list[str]:
        """Bullets that provably map to nothing (no difference at all)."""
        return self.bullets if not self.drift else []

    @property
    def has_rot(self) -> bool:
        """Whether a provable rot state (undeclared drift or stale) exists."""
        return bool(self.undeclared_drift or self.stale_bullets)


def audit_skill_dir(skill_dir: Path) -> AuditResult:
    """Compute the deterministic audit for a valid adapted skill directory."""
    drift: list[Drift] = []
    for attribution in load_attributions(skill_dir):
        base_files = fetch_base_files(attribution)
        drift.extend(compute_drift(attribution, base_files, skill_dir))
    bullets, sentinel = read_deviation_ledger(skill_dir)
    return AuditResult(
        drift=sorted(drift), bullets=bullets, no_deviations_sentinel=sentinel
    )


def _render_audit_report(skill_dir: Path, result: AuditResult) -> list[str]:
    """Render the both-sides presentation the agent correlates by hand."""
    lines = [f"audit: {skill_dir}", ""]

    lines.append("differences (ours - base):")
    if result.drift:
        width = max(len(d.kind) for d in result.drift)
        for d in result.drift:
            lines.append(f"  {d.kind.ljust(width)}  {d.relpath}  [{d.attribution}]")
    else:
        lines.append("  none")
    lines.append("")

    lines.append("declared deviations (## Deviations):")
    if result.bullets:
        lines.extend(f"  - {b}" for b in result.bullets)
    elif result.no_deviations_sentinel:
        lines.append(f"  - {_NO_DEVIATIONS_SENTINEL}")
        lines.append("  (sentinel: declares zero deviations - treated as match-upstream)")
    else:
        lines.append("  none")
    lines.append("")

    if result.undeclared_drift:
        n = len(result.undeclared_drift)
        lines.append(
            f"UNDECLARED DRIFT: {n} difference(s) with no declared deviation to "
            "cover them - declare each in ## Deviations or drop the local change."
        )
    elif result.stale_bullets:
        n = len(result.stale_bullets)
        lines.append(
            f"STALE DEVIATIONS: {n} declared deviation(s) map to no current "
            "difference - retire the bullet(s)."
        )
    elif result.drift:
        lines.append(
            f"correlate: {len(result.drift)} difference(s) and "
            f"{len(result.bullets)} declared deviation(s). Confirm every "
            "difference has a covering bullet (else it is undeclared drift) and "
            "every bullet a live difference (else it is stale). The script does "
            "not match these automatically."
        )
    else:
        lines.append("clean: no differences from base and no declared deviations.")
    return lines


def cmd_template(urls: Sequence[str]) -> int:
    errors: list[str] = []
    for i, url in enumerate(urls):
        err = parse_tree_url(url)
        if err is not None:
            errors.append(f"tree-url[{i}]: {err}")
    if errors:
        for line in errors:
            sys.stderr.write(f"skill-adaptation: {line}\n")
        return EXIT_INVALID
    sys.stdout.write(render_template(urls))
    return EXIT_OK


def cmd_validate_skill_dir(skill_dir: Path, *, quiet: bool) -> int:
    bad = usable_skill_dir_error(skill_dir)
    if bad is not None:
        # Hard errors always print (even with -q), matching check-ignore's
        # distinction between "no" and "cannot answer".
        sys.stderr.write(f"skill-adaptation: {bad}\n")
        return EXIT_BAD_PATH

    problems = adaptation_problems(skill_dir)
    if not problems:
        return EXIT_OK
    if not quiet:
        for problem in problems:
            sys.stderr.write(f"skill-adaptation: {problem}\n")
    return EXIT_INVALID


def cmd_audit(skill_dir: Path, *, quiet: bool) -> int:
    bad = usable_skill_dir_error(skill_dir)
    if bad is not None:
        sys.stderr.write(f"skill-adaptation: {bad}\n")
        return EXIT_BAD_PATH

    problems = adaptation_problems(skill_dir)
    if problems:
        # Cannot audit against pins that are themselves invalid.
        for problem in problems:
            sys.stderr.write(f"skill-adaptation: {problem}\n")
        return EXIT_INVALID

    try:
        result = audit_skill_dir(skill_dir)
    except FetchError as exc:
        # Fail loudly: never let an unreachable base masquerade as "clean".
        sys.stderr.write(f"skill-adaptation: {exc}\n")
        return EXIT_FETCH

    if not quiet:
        sys.stdout.write("\n".join(_render_audit_report(skill_dir, result)) + "\n")
    return EXIT_INVALID if result.has_rot else EXIT_OK


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=_HELP,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    template = subparsers.add_parser(
        "template",
        help="print an ADAPTATION.md stub to stdout for the given tree URLs",
        description=_HELP,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    template.add_argument(
        "tree_urls",
        nargs="+",
        metavar="TREE_URL",
        help="GitHub tree URL with full 40-char SHA (one or more)",
    )

    validate = subparsers.add_parser(
        "validate-skill-dir",
        help="check ADAPTATION.md provenance pins in a skill directory",
        description=_HELP,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    validate.add_argument(
        "skill_dir",
        type=Path,
        help="path to a skill directory (must contain SKILL.md)",
    )
    validate.add_argument(
        "-q",
        "--quiet",
        action="store_true",
        help="no problem lines on exit 0/1; still print hard errors (exit 128)",
    )

    audit = subparsers.add_parser(
        "audit",
        help="present local differences from pinned base beside declared deviations",
        description=_HELP,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    audit.add_argument(
        "skill_dir",
        type=Path,
        help="path to an adapted skill directory (must contain SKILL.md)",
    )
    audit.add_argument(
        "-q",
        "--quiet",
        action="store_true",
        help="print nothing; exit non-zero on provable drift or stale deviation",
    )
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = _build_parser()
    args = parser.parse_args(argv)
    if args.command == "template":
        return cmd_template(args.tree_urls)
    if args.command == "validate-skill-dir":
        return cmd_validate_skill_dir(args.skill_dir, quiet=args.quiet)
    if args.command == "audit":
        return cmd_audit(args.skill_dir, quiet=args.quiet)
    parser.error(f"unknown command {args.command!r}")
    return EXIT_USAGE  # pragma: no cover


if __name__ == "__main__":
    raise SystemExit(main())
