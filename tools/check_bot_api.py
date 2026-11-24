#!/usr/bin/env python3
"""Проверка, какие методы поддерживает Bot API RecodeGram.

Запуск:
    python3 tools/check_bot_api.py 1780243564:ТОКЕН
    BOT_TOKEN=1780243564:ТОКЕН python3 tools/check_bot_api.py

Скрипт дёргает каждый метод с пустыми параметрами и смотрит на ответ сервера:
    METHOD_NOT_FOUND -> метода на сервере нет
    любой другой ответ (400/403/...) -> метод есть, просто не хватает параметров
"""

import os
import sys
import urllib.error
import urllib.request

BASE = os.environ.get("BOT_API_BASE", "http://31.77.232.21:2500")

METHODS = [
    # сообщения — нужны нашему боту
    "sendMessage", "editMessageText", "deleteMessage",
    "sendPhoto", "sendDocument", "sendSticker", "sendVideo", "sendVoice",
    "getFile", "getUpdates", "setWebhook",
    # модерация — этого не хватает для /ban и /mute
    "banChatMember", "unbanChatMember", "restrictChatMember",
    "getChatAdministrators", "getChatMember", "getChat",
    "pinChatMessage", "unpinChatMessage",
    "promoteChatMember", "setChatPermissions", "leaveChat",
    "kickChatMember", "getChatMemberCount",
]


def probe(token: str, method: str) -> str:
    url = f"{BASE}/bot{token}/{method}"
    req = urllib.request.Request(
        url, data=b"", headers={"Content-Type": "application/x-www-form-urlencoded"}
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            return "есть"
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "replace")
        if "METHOD_NOT_FOUND" in body:
            return "НЕТ"
        return f"есть ({e.code})"
    except Exception as e:  # noqa: BLE001
        return f"ошибка сети: {e}"


def main() -> int:
    token = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("BOT_TOKEN", "")
    if not token:
        print("Нужен токен: python3 tools/check_bot_api.py <токен>")
        return 2

    print(f"Bot API: {BASE}")
    print(f"Бот: {token.split(':')[0]}")
    print()

    missing = []
    for method in METHODS:
        result = probe(token, method)
        print(f"  {method:24} {result}")
        if result == "НЕТ":
            missing.append(method)

    print()
    if missing:
        print("Сервер не поддерживает:", ", ".join(missing))
        print("Пока их нет — бот не может банить, мутить и закреплять сообщения.")
        return 1
    print("Все методы на месте, модерация возможна.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
