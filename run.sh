#!/usr/bin/env bash
# GreedFrance: обновить код, поднять контейнер, скомпилировать, запустить production.
# Использование:
#   curl -fsSL https://raw.githubusercontent.com/iliya1234fonk-crypto/greedfrance-chatbot/main/run.sh | bash -s -- <PAT>
set -u

REPO=/workspaces/greedfrance-chatbot
PAT="${1:-}"
LOG="$REPO/diag.log"

cd "$REPO" || { echo "нет папки $REPO"; exit 1; }

{
  echo "=== $(date -u) ==="
  echo "--- git update"
  git fetch origin -q && git reset --hard origin/main -q
  git log --oneline -1
  echo "--- restart iris"
  timeout 300 docker compose restart iris 2>&1 | tail -3
  echo "--- wait healthy"
  for i in $(seq 1 24); do
    sleep 5
    if docker compose ps --format '{{.Status}}' 2>/dev/null | grep -qi healthy; then
      echo "healthy after $((i*5))s"
      break
    fi
  done
  docker compose ps
} > "$LOG" 2>&1

cat > check5.scr << 'SCR'
zn "USER"
Write "running:",##class(Ens.Director).IsProductionRunning(),!
Write "cred:",##class(Ens.Config.Credentials).%ExistsId("telegram"),!
Write "cmpEmoji:",$system.OBJ.Compile("dc.greedfrance.Emoji","ck"),!
Write "cmpModerator:",$system.OBJ.Compile("dc.greedfrance.Moderator","ck"),!
Write "cmpAPI:",$system.OBJ.Compile("Telegram.API","ck"),!
Write "render tag:",($find(##class(dc.greedfrance.Emoji).Render("x ⚠ y"),"<tg-emoji")>0),!
If '##class(Ens.Director).IsProductionRunning() {
	Set st=##class(Ens.Director).StartProduction("dc.greedfrance.GreedFranceProduction")
	If $system.Status.IsError(st) {
		Do ##class(Ens.Director).StopProduction(10,1)
		Set st=##class(Ens.Director).StartProduction("dc.greedfrance.GreedFranceProduction")
	}
	Write "start:",st,!
}
Write "running now:",##class(Ens.Director).IsProductionRunning(),!
Set q="SELECT TOP 12 TimeLogged,Type,ConfigName,Text FROM Ens_Util.Log ORDER BY ID DESC"
Set rs=##class(%SQL.Statement).%ExecDirect(,q)
While rs.%Next() { Write rs.TimeLogged,"|",rs.Type,"|",rs.ConfigName,"|",$E(rs.Text,1,200),! }
Halt
SCR

timeout 240 docker compose exec -T iris iris session IRIS < check5.scr >> "$LOG" 2>&1

{
  echo "--- git push"
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
