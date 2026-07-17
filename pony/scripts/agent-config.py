#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import subprocess
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)

    write_session = subparsers.add_parser("write-session")
    write_session.add_argument("--agent", required=True)
    write_session.add_argument("--project-root", required=True)
    write_session.add_argument("--output", required=True)
    write_session.add_argument("--registry-path", required=True)
    write_session.add_argument("--message-log-path", required=True)

    return parser.parse_args()


def normalize(value: str) -> str:
    return value.strip().upper().replace("-", "_").replace(" ", "_")


def slugify(value: str) -> str:
    return "".join(ch.lower() if ch.isalnum() else "-" for ch in value).strip("-")


def read_project_label(project_root: Path) -> str:
    config_path = project_root / "pony" / "pony.system.config.yaml"
    if config_path.exists():
        for line in config_path.read_text(encoding="utf-8").splitlines():
            if line.startswith("project_name:"):
                label = line.split(":", 1)[1].strip()
                if label:
                    return label
    return project_root.name


def read_config_value(project_root: Path, key: str) -> str:
    config_path = project_root / "pony" / "pony.system.config.yaml"
    if config_path.exists():
        for line in config_path.read_text(encoding="utf-8").splitlines():
            if line.startswith(f"{key}:"):
                value = line.split(":", 1)[1].strip()
                if value:
                    return value
    return ""


def read_system_root(project_root: Path) -> Path:
    configured = read_config_value(project_root, "agenic_system_root")
    if configured:
        return Path(configured).resolve()
    return Path(__file__).resolve().parents[2]


def read_branch(project_root: Path) -> str:
    try:
        result = subprocess.run(
            ["git", "-C", str(project_root), "symbolic-ref", "--quiet", "--short", "HEAD"],
            check=True,
            capture_output=True,
            text=True,
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError:
        try:
            result = subprocess.run(
                ["git", "-C", str(project_root), "rev-parse", "--short", "HEAD"],
                check=True,
                capture_output=True,
                text=True,
            )
            return f"detached-{result.stdout.strip()}"
        except subprocess.CalledProcessError:
            return "no-git-branch"


def default_runtime_registry_path(project_root: Path) -> Path:
    return project_root / "pony" / "runtime" / "pony.registry.jsonl"


def default_runtime_message_log_path(project_root: Path) -> Path:
    return project_root / "pony" / "runtime" / "pony.chat.jsonl"


@dataclass(frozen=True)
class AgentMeta:
    personality: str
    worker_slug: str
    label: str
    short_label: str
    route_base: str
    icon: str
    accent: str
    runtime_role: str
    terminal_title: str
    prompt_label: str
    aliases: list[str]
    global_singleton: bool = False


def load_roster(script_path: Path) -> dict[str, AgentMeta]:
    roster_path = script_path.resolve().parents[1] / "launch.configs" / "pony-agent-roster.json"
    payload = json.loads(roster_path.read_text(encoding="utf-8"))
    result: dict[str, AgentMeta] = {}
    for raw in payload["agents"]:
        meta = AgentMeta(
            personality=raw["personality"],
            worker_slug=raw["workerSlug"],
            label=raw["label"],
            short_label=raw["shortLabel"],
            route_base=raw["routeBase"],
            icon=raw["icon"],
            accent=raw["accent"],
            runtime_role=raw["runtimeRole"],
            terminal_title=raw["terminalTitle"],
            prompt_label=raw["promptLabel"],
            aliases=list(raw["aliases"]),
            global_singleton=bool(raw.get("globalSingleton", False)),
        )
        result[meta.personality] = meta
    return result


def read_live_registry(registry_path: Path, roster: dict[str, AgentMeta]) -> list[dict[str, str]]:
    if not registry_path.exists():
        return []
    cutoff = datetime.now(timezone.utc) - timedelta(hours=1)
    latest: dict[tuple[str, str], dict[str, str]] = {}
    for raw in registry_path.read_text(encoding="utf-8").splitlines():
        raw = raw.strip()
        if not raw:
            continue
        try:
            entry = json.loads(raw)
        except json.JSONDecodeError:
            continue
        if not isinstance(entry, dict):
            continue
        personality = normalize(entry.get("pony_name", ""))
        if personality not in roster:
            continue
        try:
            seen = datetime.fromisoformat(entry["last_seen_at"].replace("Z", "+00:00"))
        except Exception:
            continue
        if seen < cutoff:
            continue
        project_root = entry.get("path", "")
        if not project_root:
            continue
        latest[(personality, project_root)] = {
            "personality": personality,
            "project_root": project_root,
            "branch_label": entry.get("git_branch") or "no-git-branch",
            "instance_id": entry.get("uuid") or "",
        }
    return list(latest.values())


def read_live_chat_targets(
    message_log_path: Path,
    roster: dict[str, AgentMeta],
    *,
    current_project_root: Path,
) -> list[dict[str, str]]:
    if not message_log_path.exists():
        return []
    cutoff = datetime.now(timezone.utc) - timedelta(hours=6)
    latest: dict[tuple[str, str], dict[str, str]] = {}
    for raw in message_log_path.read_text(encoding="utf-8").splitlines():
        raw = raw.strip()
        if not raw:
            continue
        try:
            entry = json.loads(raw)
        except json.JSONDecodeError:
            continue
        if not isinstance(entry, dict):
            continue
        try:
            created_at = datetime.fromisoformat(entry["created_at"].replace("Z", "+00:00"))
        except Exception:
            continue
        if created_at < cutoff:
            continue
        remote_personality = normalize(entry.get("from_agent_id", ""))
        remote_project_root = entry.get("project_root", "")
        remote_instance_id = entry.get("from_instance_id", "")
        if remote_project_root and Path(remote_project_root).resolve() == current_project_root:
            remote_project_root = ""
        if remote_personality not in roster or not remote_project_root:
            remote_personality = normalize(entry.get("to_agent_id", ""))
            remote_project_root = entry.get("to_project_root", "")
            remote_instance_id = entry.get("to_instance_id", "")
        if not remote_project_root:
            continue
        if remote_personality not in roster:
            continue
        remote_root = Path(remote_project_root).resolve()
        if remote_root == current_project_root:
            continue
        latest[(remote_personality, str(remote_root))] = {
            "personality": remote_personality,
            "project_root": str(remote_root),
            "branch_label": read_branch(remote_root),
            "instance_id": remote_instance_id,
        }
    return list(latest.values())


def alias_set(meta: AgentMeta, project_label: str, include_unqualified: bool) -> list[str]:
    aliases: list[str] = []
    candidates = [meta.label, meta.short_label, *meta.aliases]
    seen: set[str] = set()
    project_forms = {project_label, slugify(project_label), project_label.upper()}
    for candidate in candidates:
        text = candidate.strip()
        if not text:
            continue
        if include_unqualified and text.casefold() not in seen:
            aliases.append(text)
            seen.add(text.casefold())
        for project_form in project_forms:
            qualified = f"{project_form}:{text}"
            if qualified.casefold() not in seen:
                aliases.append(qualified)
                seen.add(qualified.casefold())
    return aliases


def route_id_for(meta: AgentMeta, project_label: str) -> str:
    if meta.global_singleton:
        return meta.route_base
    return f"{slugify(project_label).upper()}:{meta.route_base}"


def session_entry(
    meta: AgentMeta,
    *,
    project_root: Path,
    project_label: str,
    branch_label: str,
    registry_path: Path,
    message_log_path: Path,
    include_unqualified: bool,
    instance_id: str = "",
) -> dict[str, Any]:
    return {
        "agentId": meta.personality,
        "routeId": route_id_for(meta, project_label),
        "label": meta.label,
        "shortLabel": meta.short_label,
        "icon": meta.icon,
        "accent": meta.accent,
        "aliases": alias_set(meta, project_label, include_unqualified),
        "projectRoot": str(project_root),
        "projectLabel": project_label,
        "branchLabel": branch_label,
        "registryPath": str(registry_path),
        "messageLogPath": str(message_log_path),
        "runtimeRole": meta.runtime_role,
        "terminalTitle": meta.terminal_title,
        "promptLabel": meta.prompt_label,
        "workerSlug": meta.worker_slug,
        "instanceId": instance_id,
        "globalSingleton": meta.global_singleton,
    }


def build_session_config(args: argparse.Namespace, roster: dict[str, AgentMeta]) -> dict[str, Any]:
    current_personality = normalize(args.agent)
    if current_personality not in roster:
        raise SystemExit(f"Unknown agent personality: {args.agent}")

    project_root = Path(args.project_root).resolve()
    project_label = read_project_label(project_root)
    branch_label = read_branch(project_root)
    registry_path = Path(args.registry_path).expanduser()
    message_log_path = Path(args.message_log_path).expanduser()
    current_meta = roster[current_personality]
    source_repo_session = (
        current_personality == "PRINCESS_CELESTIA_SOL_INVICTUS"
        and project_label == "agenic-pony-system"
    )

    current_entry = session_entry(
        current_meta,
        project_root=project_root,
        project_label=project_label,
        branch_label=branch_label,
        registry_path=registry_path,
        message_log_path=message_log_path,
        include_unqualified=True,
    )

    agents: list[dict[str, Any]] = []
    seen_routes: set[str] = set()
    source_root = read_system_root(project_root)
    source_label = read_project_label(source_root)
    source_branch = read_branch(source_root)

    for meta in roster.values():
        if source_repo_session and meta.personality != current_personality:
            continue
        if meta.global_singleton and meta.personality != current_personality:
            continue
        entry = session_entry(
            meta,
            project_root=project_root,
            project_label=project_label,
            branch_label=branch_label,
            registry_path=registry_path,
            message_log_path=message_log_path,
            include_unqualified=True,
        )
        agents.append(entry)
        seen_routes.add(entry["routeId"])

    live_entries = read_live_registry(registry_path, roster)
    live_entries.extend(
        read_live_chat_targets(
            message_log_path,
            roster,
            current_project_root=project_root,
        )
    )
    for live in live_entries:
        personality = live["personality"]
        meta = roster[personality]
        live_project_root = Path(live["project_root"]).resolve()
        live_project_label = read_project_label(live_project_root)
        route_id = route_id_for(meta, live_project_label)
        if route_id in seen_routes:
            continue
        agents.append(
            session_entry(
                meta,
                project_root=live_project_root,
                project_label=live_project_label,
                branch_label=live["branch_label"],
                registry_path=default_runtime_registry_path(live_project_root),
                message_log_path=default_runtime_message_log_path(live_project_root),
                include_unqualified=meta.global_singleton,
                instance_id=live["instance_id"],
            )
        )
        seen_routes.add(route_id)

    for meta in roster.values():
        if not meta.global_singleton:
            continue
        singleton_root = project_root if current_personality == meta.personality else source_root
        singleton_label = project_label if singleton_root == project_root else source_label
        singleton_branch = branch_label if singleton_root == project_root else source_branch
        singleton_registry_path = (
            registry_path
            if singleton_root == project_root
            else default_runtime_registry_path(singleton_root)
        )
        singleton_message_log_path = (
            message_log_path
            if singleton_root == project_root
            else default_runtime_message_log_path(singleton_root)
        )
        route_id = route_id_for(meta, singleton_label)
        if route_id in seen_routes:
            continue
        entry = session_entry(
            meta,
            project_root=singleton_root,
            project_label=singleton_label,
            branch_label=singleton_branch,
            registry_path=singleton_registry_path,
            message_log_path=singleton_message_log_path,
            include_unqualified=True,
        )
        agents.append(entry)
        seen_routes.add(entry["routeId"])

    return {
        **current_entry,
        "agents": agents,
    }


def main() -> None:
    args = parse_args()
    roster = load_roster(Path(__file__))
    if args.command == "write-session":
        payload = build_session_config(args, roster)
        output_path = Path(args.output)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        return
    raise SystemExit(f"Unsupported command: {args.command}")


if __name__ == "__main__":
    main()
