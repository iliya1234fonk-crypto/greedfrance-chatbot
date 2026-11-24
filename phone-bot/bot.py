#!/usr/bin/env python3
"""GreedFrance moderator bot — то же, что IRIS-версия, но одним файлом.

Работает на телефоне через long polling Bot API RecodeGram.
Умеет: /help /rules /id /stats /warn /unwarn /warns /del, антифлуд, приветствие.
Баны/муты не умеет — этих методов в Bot API RecodeGram нет (METHOD_NOT_FOUND).

Запуск:  python3 bot.py
Остановка: pkill -f "greedfrance-bot/bot.py"
"""

import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

BASE = os.environ.get("BOT_API_BASE", "http://31.77.232.21:2500")
TOKEN = os.environ.get("BOT_TOKEN", "1780243564:Dv0FuwjT-0e7hCtIwGJZt6y8cRBnFeUJ3wM")

STATE_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "state.json")

FLOOD_COUNT = 6        # столько сообщений за окно = флуд
FLOOD_WINDOW = 10      # окно, секунды
WARN_LIMIT = 3

HELP = (
    "Команды GreedFrance:\n"
    "/help — этот список\n"
    "/rules — правила чата\n"
    "/id — chat_id и твой id\n"
    "/stats — статистика чата\n"
    "/warn (ответом на сообщение) — предупреждение\n"
    "/unwarn (ответом) — снять предупреждение\n"
    "/warns — у кого есть предупреждения\n"
    "/del (ответом) — удалить сообщение\n"
    "\nАнтифлуд включён: слишком частые сообщения бот удаляет."
)

RULES = (
    "Правила чата:\n"
    "1. Без спама и флуда.\n"
    "2. Без оскорблений и травли.\n"
    "3. Реклама — только с разрешения админов.\n"
    "4. Не несколько одинаковых сообщений подряд.\n"
    "\nНарушения: предупреждение (/warn), дальше — бан."
)

NO_ADMIN_API = (
    "Bot API RecodeGram не поддерживает баны, муты и пины: сервер отвечает "
    "METHOD_NOT_FOUND. Нужно, чтобы владелец сервера добавил в API "
    "banChatMember, restrictChatMember, pinChatMessage, getChatAdministrators."
)


def log(msg):
    print(f"{time.strftime('%Y-%m-%d %H:%M:%S')} {msg}", flush=True)


# ---------------------------------------------------------------- Bot API

def call(method, params=None, timeout=20):
    url = f"{BASE}/bot{TOKEN}/{method}"
    data = urllib.parse.urlencode(
        {k: v for k, v in (params or {}).items() if v is not None}
    ).encode()
    req = urllib.request.Request(
        url, data=data, headers={"Content-Type": "application/x-www-form-urlencoded"}
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return json.loads(r.read().decode("utf-8", "replace"))
    except urllib.error.HTTPError as e:
        try:
            body = json.loads(e.read().decode("utf-8", "replace"))
        except Exception:
            body = {"ok": False, "error_code": e.code, "description": str(e)}
        return body
    except Exception as e:  # сеть отвалилась
        return {"ok": False, "description": f"network: {e}"}


EMOJI_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "emoji_ids.json")


def load_emoji():
    try:
        with open(EMOJI_FILE, "r", encoding="utf-8") as f:
            raw = json.load(f)
    except Exception:
        return {}, []
    table = {}
    for k, v in raw.items():
        if not k:
            continue
        table[k] = v
        table.setdefault(k.replace("\ufe0f", ""), v)
    return table, sorted(table, key=len, reverse=True)


EMOJI, EMOJI_KEYS = load_emoji()


def premium(text):
    """Экранирует HTML и оборачивает наши эмодзи в премиум <tg-emoji>."""
    text = text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    for k in EMOJI_KEYS:
        if k in text:
            text = text.replace(k, f'<tg-emoji emoji-id="{EMOJI[k]}">{k}</tg-emoji>')
    return text


def send(chat_id, text):
    res = call(
        "sendMessage",
        {"chat_id": chat_id, "text": premium(text[:3800]), "parse_mode": "HTML"},
    )
    if not res.get("ok"):
        log(f"sendMessage failed: {res.get('description')}")
    return res.get("ok")


def delete(chat_id, message_id):
    if not message_id:
        return False
    res = call("deleteMessage", {"chat_id": chat_id, "message_id": message_id})
    if not res.get("ok"):
        log(f"deleteMessage failed: {res.get('description')}")
    return res.get("ok")


# ---------------------------------------------------------------- state

def load_state():
    try:
        with open(STATE_FILE, "r", encoding="utf-8") as f:
            st = json.load(f)
    except Exception:
        st = {}
    st.setdefault("warns", {})
    st.setdefault("stats", {})
    st.setdefault("flood", {})
    st.setdefault("offset", 0)
    return st


def save_state(st):
    tmp = STATE_FILE + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(st, f, ensure_ascii=False)
    os.replace(tmp, STATE_FILE)


# ---------------------------------------------------------------- helpers

def who(username, first_name, user_id):
    if username:
        return "@" + username
    if first_name:
        return first_name
    return f"id{user_id}"


def count_stats(st, chat_id):
    today = time.strftime("%Y-%m-%d")
    stats = st["stats"]
    stats["total"] = stats.get("total", 0) + 1
    chat = stats.setdefault(str(chat_id), {"all": 0, "days": {}})
    chat["all"] += 1
    chat["days"][today] = chat["days"].get(today, 0) + 1


def warns_of(st, chat_id, user_id):
    return st["warns"].get(str(chat_id), {}).get(str(user_id), 0)


def set_warns(st, chat_id, user_id, value):
    chat = st["warns"].setdefault(str(chat_id), {})
    if value <= 0:
        chat.pop(str(user_id), None)
    else:
        chat[str(user_id)] = value


def is_flood(st, chat_id, user_id):
    key = f"{chat_id}:{user_id}"
    now = time.time()
    win = st["flood"].get(key)
    if not win or now - win["start"] > FLOOD_WINDOW:
        st["flood"][key] = {"start": now, "count": 1}
        return False
    win["count"] += 1
    return win["count"] > FLOOD_COUNT


def stats_text(st, chat_id):
    chat = st["stats"].get(str(chat_id), {"all": 0, "days": {}})
    today = time.strftime("%Y-%m-%d")
    warns = sum(st["warns"].get(str(chat_id), {}).values())
    return (
        "Статистика:\n"
        f"сообщений в чате: {chat['all']}\n"
        f"за сегодня: {chat['days'].get(today, 0)}\n"
        f"предупреждений: {warns}\n"
        f"всего обработано ботом: {st['stats'].get('total', 0)}"
    )


# ---------------------------------------------------------------- handlers

def handle_command(st, chat_id, cmd, msg, user, reply):
    if cmd in ("start", "help"):
        send(chat_id, HELP)
        return

    if cmd == "rules":
        send(chat_id, RULES)
        return

    if cmd == "id":
        send(
            chat_id,
            f"chat_id: {chat_id}\n"
            f"твой id: {user.get('id')}\n"
            f"тип чата: {(msg.get('chat') or {}).get('type', '?')}",
        )
        return

    if cmd == "stats":
        send(chat_id, stats_text(st, chat_id))
        return

    if cmd == "warn":
        if not reply:
            send(chat_id, "Ответь командой /warn на сообщение нарушителя.")
            return
        target = reply.get("from") or {}
        target_id = target.get("id")
        if not target_id:
            send(chat_id, "Не понял, кого предупреждать.")
            return
        if target_id == user.get("id"):
            send(chat_id, "Себе предупреждение не выдам.")
            return
        count = warns_of(st, chat_id, target_id) + 1
        set_warns(st, chat_id, target_id, count)
        person = who(target.get("username"), target.get("first_name"), target_id)
        if count >= WARN_LIMIT:
            send(
                chat_id,
                f"{person} — предупреждений: {count}. Предел. "
                "Банить вручную: Bot API RecodeGram баны пока не умеет.",
            )
        else:
            send(chat_id, f"{person} получает предупреждение {count}/{WARN_LIMIT}")
        return

    if cmd == "unwarn":
        if not reply:
            send(chat_id, "Ответь командой /unwarn на сообщение участника.")
            return
        target = reply.get("from") or {}
        target_id = target.get("id")
        count = max(warns_of(st, chat_id, target_id) - 1, 0)
        set_warns(st, chat_id, target_id, count)
        person = who(target.get("username"), target.get("first_name"), target_id)
        send(chat_id, f"{person} — предупреждений: {count}")
        return

    if cmd == "warns":
        chat_warns = st["warns"].get(str(chat_id), {})
        lines = ["Предупреждения:"]
        if chat_warns:
            for uid, count in sorted(chat_warns.items(), key=lambda x: -x[1]):
                if count > 0:
                    lines.append(f"{uid}: {count}")
        if len(lines) == 1:
            lines.append("пока никого")
        send(chat_id, "\n".join(lines))
        return

    if cmd == "del":
        if not reply or not reply.get("message_id"):
            send(chat_id, "Ответь командой /del на сообщение, которое надо удалить.")
            return
        if delete(chat_id, reply["message_id"]):
            delete(chat_id, msg.get("message_id"))
        else:
            send(chat_id, "Не смог удалить: Bot API не дал (нет прав или сообщение старое).")
        return

    if cmd in ("ban", "mute", "kick", "unban", "promote", "pin"):
        send(chat_id, NO_ADMIN_API)
        return

    send(chat_id, f"Не знаю команду /{cmd}. Список команд: /help")


def handle_update(st, upd):
    msg = upd.get("message")
    if not isinstance(msg, dict):
        return

    chat = msg.get("chat") or {}
    chat_id = chat.get("id")
    chat_type = chat.get("type", "")
    user = msg.get("from") or {}
    if not chat_id or user.get("is_bot"):
        return

    count_stats(st, chat_id)

    members = msg.get("new_chat_members")
    if isinstance(members, list) and members:
        names = ", ".join(
            who(m.get("username"), m.get("first_name"), m.get("id")) for m in members
        )
        send(chat_id, f"Добро пожаловать, {names}! 👋\nПравила: /rules, команды: /help")
        return

    text = (msg.get("text") or msg.get("caption") or "").strip()
    if not text:
        return

    reply = msg.get("reply_to_message") if isinstance(msg.get("reply_to_message"), dict) else None

    if text.startswith("/"):
        word = text.split()[0]
        cmd = word.split("/", 1)[1].split("@")[0].lower()
        handle_command(st, chat_id, cmd, msg, user, reply)
        return

    if chat_type in ("group", "supergroup") and is_flood(st, chat_id, user.get("id")):
        delete(chat_id, msg.get("message_id"))
        st["flood"].pop(f"{chat_id}:{user.get('id')}", None)
        send(chat_id, "🧹 Флуд удалён. Не так быстро.")


# ---------------------------------------------------------------- main loop

def main():
    st = load_state()
    log(f"бот запущен, Bot API {BASE}")
    me = call("getMe")
    if me.get("ok"):
        log(f"подключён как @{(me['result'].get('username') or '?')}")
    else:
        log(f"getMe не сработал: {me.get('description')}")

    errors = 0
    while True:
        res = call("getUpdates", {"offset": st["offset"], "timeout": 0, "limit": 20})

        if not res.get("ok"):
            desc = res.get("description", "")
            errors += 1
            if "CONFLICT" in str(desc):
                log("409: токен уже опрашивает другой процесс (Codespace?). Жду 10 с")
                time.sleep(10)
            else:
                log(f"getUpdates: {desc} — пауза {min(errors * 2, 30)} с")
                time.sleep(min(errors * 2, 30))
            continue

        errors = 0
        updates = res.get("result") or []
        if not updates:
            time.sleep(1)
            continue

        for upd in updates:
            try:
                handle_update(st, upd)
            except Exception as e:  # noqa: BLE001
                log(f"ошибка обработки обновления: {e!r}")
            st["offset"] = max(st["offset"], int(upd.get("update_id", 0)) + 1)
        save_state(st)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(0)
