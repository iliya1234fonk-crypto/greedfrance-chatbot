#!/bin/sh
# Запуск/остановка бота на телефоне.
#   sh start.sh        — запустить (если ещё не запущен)
#   sh start.sh stop   — остановить
#   sh start.sh log    — показать лог

cd "$(dirname "$0")" || exit 1

case "$1" in
  stop)
    pkill -f "greedfrance-bot/bot.py" && echo "остановлен" || echo "не запущен"
    ;;
  log)
    tail -n 40 bot.log
    ;;
  *)
    if pgrep -f "greedfrance-bot/bot.py" > /dev/null; then
      echo "уже запущен (pid $(pgrep -f 'greedfrance-bot/bot.py' | head -1))"
      exit 0
    fi
    nohup python3 -u bot.py >> bot.log 2>&1 &
    sleep 3
    tail -n 5 bot.log
    ;;
esac
