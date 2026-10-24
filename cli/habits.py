# /// script
# requires-python = ">=3.10"
# ///
"""`habits`: the habits in `habits.json`, managed from the Mac"""

import argparse
import json
import os
import secrets
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timezone
from pathlib import Path

BUNDLE_ID = os.environ.get("BUNDLE_ID", "com.example.habits")
PATH = Path(
    os.environ.get(
        "HABITS_FILE",
        f"~/Library/Mobile Documents/iCloud~{BUNDLE_ID.replace('.', '~')}/Documents/habits.json",
    )
).expanduser()
FIELDS = ["id", "icon", "name", "parent", "group", "step", "weight", "archived"]


def now() -> str:
    return datetime.now(tz=timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")


def read() -> tuple[dict, int | None]:
    placeholder = PATH.with_name(f".{PATH.name}.icloud")
    if placeholder.exists():
        subprocess.run(["brctl", "download", str(PATH)], check=False)
        for _ in range(60):
            if PATH.exists():
                break
            time.sleep(1)
        else:
            sys.exit(f"not downloaded from iCloud: {PATH}")

    if not PATH.exists():
        return {"v": 1, "color": "#8fa2ff", "modified": now(), "habits": [], "deleted": {}}, None
    return json.loads(PATH.read_bytes()), PATH.stat().st_mtime_ns


def write(
    store: dict,
    mtime: int | None,
) -> bool:
    """Atomically, False where the file moved since `mtime`"""
    PATH.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=PATH.parent, prefix=".habits-", delete=False) as file:
        json.dump(store, file, ensure_ascii=False, separators=(",", ":"))
    if (PATH.stat().st_mtime_ns if PATH.exists() else None) != mtime:
        os.unlink(file.name)
        return False
    os.replace(file.name, PATH)
    return True


def find(
    store: dict,
    id: str,
) -> dict:
    habit = next((habit for habit in store["habits"] if habit["id"] == id), None)
    if habit is None:
        sys.exit(f"no such habit: {id}")
    return habit


def place(
    store: dict,
    habit: dict,
) -> None:
    """Last among the active"""
    store["habits"] = [other for other in store["habits"] if other["id"] != habit["id"]]
    active = sum(not other["archived"] for other in store["habits"])
    store["habits"].insert(active, habit)
    store["modified"] = now()


def change(
    store: dict,
    args: argparse.Namespace,
) -> dict | None:
    """The command applied to `store`, the habit it touched back"""
    if args.command == "add":
        ids = {habit["id"] for habit in store["habits"]} | set(store["deleted"])
        habit = {"id": next(id for id in iter(lambda: secrets.token_hex(4), None) if id not in ids), "icon": args.icon, "name": args.name, "step": 0, "archived": False}
        if args.group:
            habit["group"] = True
        args.icon = args.name = None
        place(
            store=store,
            habit=habit,
        )
    else:
        habit = find(
            store=store,
            id=args.id,
        )
    if args.command in ("add", "edit"):
        for field in ["icon", "name", "step", "weight"]:
            value = getattr(args, field, None)
            if value == "none" and field == "weight":
                habit.pop(field, None)
            elif value is not None:
                habit[field] = int(value) if field in ("step", "weight") else value
        if args.parent == "":
            habit.pop("parent", None)
        elif args.parent is not None:
            habit["parent"] = find(
                store=store,
                id=args.parent,
            )["id"]
    elif args.command in ("archive", "restore"):
        habit["archived"] = args.command == "archive"
        place(
            store=store,
            habit=habit,
        )
    elif args.command == "delete":
        for child in store["habits"]:
            if child.get("parent") == habit["id"]:
                child["parent"] = habit.get("parent")
                child["modified"] = now()
                if child["parent"] is None:
                    child.pop("parent")
        store["habits"].remove(habit)
        store["deleted"][habit["id"]] = now()
        return None
    habit["modified"] = now()
    return habit


def main() -> None:
    parser = argparse.ArgumentParser(prog="habits")
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("list", help="every habit, the archived too")
    add = commands.add_parser("add", help="last in the grid")
    add.add_argument("icon")
    add.add_argument("name")
    edit = commands.add_parser("edit")
    edit.add_argument("id")
    edit.add_argument("--icon")
    edit.add_argument("--name")
    for command in (add, edit):
        command.add_argument("--step", help="0 — binary, else a counter")
        command.add_argument("--weight", help="`none` clears it")
        command.add_argument("--parent", help="its group's id, `\"\"` — the top level")
    add.add_argument("--group", action="store_true", help="a group: icon and name alone")
    for name, help in [("archive", "out of the grid"), ("restore", "back, last"), ("delete", "with its history, for good")]:
        commands.add_parser(name, help=help).add_argument("id")
    args = parser.parse_args()

    if args.command == "list":
        store, _ = read()
        print(json.dumps([{field: habit[field] for field in FIELDS if field in habit} for habit in store["habits"]], ensure_ascii=False, indent=2))
        return

    while True:
        store, mtime = read()
        store.setdefault("deleted", {})
        habit = change(
            store=store,
            args=argparse.Namespace(**vars(args)),
        )
        if write(
            store=store,
            mtime=mtime,
        ):
            break
    print(json.dumps({field: habit[field] for field in FIELDS if field in habit} if habit else {"deleted": args.id}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
