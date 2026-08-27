#!/usr/bin/env python3
"""Статус-строка Claude Code: модель, папка, ветка, контекст, стоимость сессии.

На вход приходит JSON с данными сессии, на выход — одна строка для нижней
панели терминала. Всё считает сам Claude Code, здесь только оформление.
"""
import json
import os
import subprocess
import sys

# Цвета терминала
DIM = "\033[2m"
RESET = "\033[0m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
RED = "\033[31m"
CYAN = "\033[36m"
SEP = f"{DIM} · {RESET}"


def git_branch(cwd):
    """Текущая ветка, если это git-проект."""
    try:
        out = subprocess.run(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"],
            cwd=cwd, capture_output=True, text=True, timeout=1,
        )
        if out.returncode == 0:
            branch = out.stdout.strip()
            return branch if branch != "HEAD" else None
    except Exception:
        pass
    return None


def context_bar(used_pct):
    """Полоска заполнения контекста: зелёная → жёлтая → красная."""
    used = max(0, min(100, int(round(used_pct))))
    filled = round(used / 10)
    color = GREEN if used < 60 else (YELLOW if used < 85 else RED)
    bar = "▓" * filled + "░" * (10 - filled)
    return f"{color}{bar} {used}%{RESET}"


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        return

    parts = []

    # Модель
    model = (data.get("model") or {}).get("display_name")
    if model:
        parts.append(f"{CYAN}{model}{RESET}")

    # Папка проекта + ветка
    cwd = (data.get("workspace") or {}).get("current_dir") or data.get("cwd") or ""
    if cwd:
        name = os.path.basename(cwd.rstrip("/")) or cwd
        branch = git_branch(cwd)
        parts.append(f"{name} {DIM}⎇ {branch}{RESET}" if branch else name)

    # Контекст — главное, ради чего всё затевалось
    ctx = data.get("context_window") or {}
    used_pct = ctx.get("used_percentage")
    if used_pct is not None:
        parts.append(f"{DIM}контекст{RESET} {context_bar(used_pct)}")

    # Режим правок: показываем, только когда он не обычный
    mode = data.get("permission_mode") or data.get("permissionMode")
    labels = {"acceptEdits": "авто-правки", "plan": "план", "bypassPermissions": "без спроса"}
    if mode in labels:
        parts.append(f"{YELLOW}{labels[mode]}{RESET}")

    # Стоимость сессии
    cost = (data.get("cost") or {}).get("total_cost_usd")
    if isinstance(cost, (int, float)) and cost > 0:
        parts.append(f"{DIM}${cost:.2f}{RESET}")

    sys.stdout.write(SEP.join(parts))


if __name__ == "__main__":
    main()
