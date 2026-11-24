#!/usr/bin/env bash
# Диагностика и запуск GreedFrance в Codespace.
# Использование:
#   curl -fsSL https://raw.githubusercontent.com/iliya1234fonk-crypto/greedfrance-chatbot/main/run.sh | bash -s -- <PAT>
set -u

REPO=/workspaces/greedfrance-chatbot
PAT="${1:-}"
LOG="$REPO/diag.log"

cd "$REPO" || { echo "нет папки $REPO"; exit 1; }

{
  echo "=== $(date -u) ==="
  echo "--- ps before"
  docker ps -a
  echo "--- up"
  timeout 300 docker compose up -d --no-build 2>&1 | tail -10
  echo "--- wait"
  for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
    sleep 5
    if docker compose ps --format '{{.State}}' 2>/dev/null | grep -qi running; then
      echo "container running after $((i*5))s"
      break
    fi
  done
  echo "--- ps after"
  docker compose ps
} > "$LOG" 2>&1

cat > check4.scr << 'SCR'
zn "USER"
Write "running:",##class(Ens.Director).IsProductionRunning(),!
Write "cred:",##class(Ens.Config.Credentials).%ExistsId("telegram"),!
Write "cmpEmoji:",$system.OBJ.Compile("dc.greedfrance.Emoji","ck"),!
Write "cmpModerator:",$system.OBJ.Compile("dc.greedfrance.Moderator","ck"),!
Write "render:",##class(dc.greedfrance.Emoji).Render("x ⚠ y"),!
If '##class(Ens.Director).IsProductionRunning() { Write "start:",##class(Ens.Director).StartProduction("dc.greedfrance.GreedFranceProduction"),! }
Write "running now:",##class(Ens.Director).IsProductionRunning(),!
Set q="SELECT TOP 12 TimeLogged,Type,ConfigName,Text FROM Ens_Util.Log ORDER BY ID DESC"
Set rs=##class(%SQL.Statement).%ExecDirect(,q)
While rs.%Next() { Write rs.TimeLogged,"|",rs.Type,"|",rs.ConfigName,"|",$E(rs.Text,1,200),! }
Halt
SCR

timeout 180 docker compose exec -T iris iris session IRIS < check4.scr >> "$LOG" 2>&1

{
  echo "--- git"
  git add -A
  git commit -q -m diag || true
  git pull --rebase -q || true
  if [ -n "$PAT" ]; then
    git remote set-url origin "https://$PAT@github.com/iliya1234fonk-crypto/greedfrance-chatbot.git"
    git push -q || echo "push failed"
    git remote set-url origin https://github.com/iliya1234fonk-crypto/greedfrance-chatbot.git
  else
    echo "no PAT, skipped push"
  fi
} >> "$LOG" 2>&1

echo DONE
