import json
import os
import subprocess
import sys
from pathlib import Path


def test_habits(tmp_path: Path) -> None:
    path = tmp_path / "habits.json"

    def habits(*args: str) -> dict | list:
        result = subprocess.run([sys.executable, Path(__file__).with_name("habits.py"), *args], env={**os.environ, "HABITS_FILE": str(path)}, capture_output=True, text=True, check=True)
        return json.loads(result.stdout)

    water = habits("add", "💧", "Вода", "--step", "1", "--weight", "2")["id"]
    run = habits("add", "🏃", "Бег")["id"]
    assert habits("edit", water, "--name", "Water", "--weight", "none") == {"id": water, "icon": "💧", "name": "Water", "step": 1, "archived": False}

    habits("archive", water)
    assert [habit["id"] for habit in habits("list")] == [run, water]
    habits("restore", water)
    assert [(habit["id"], habit["archived"]) for habit in habits("list")] == [(run, False), (water, False)]

    morning = habits("add", "🌅", "Утро", "--group")["id"]
    assert habits("edit", run, "--parent", morning)["parent"] == morning
    habits("delete", morning)
    assert "parent" not in habits("list")[0]

    store = json.loads(path.read_text())
    store["habits"][0]["log"] = [1]
    path.write_text(json.dumps(store))
    habits("delete", water)
    store = json.loads(path.read_text())
    assert [habit["id"] for habit in store["habits"]] == [run] and store["habits"][0]["log"] == [1] and water in store["deleted"]
