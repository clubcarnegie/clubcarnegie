#!/bin/bash
# Atualiza o dashboard com dados frescos do Circle e faz push para o GitHub Pages
# Uso: ./update_dashboard.sh
# Agendar semanalmente: crontab -e → 0 8 * * 1 /caminho/update_dashboard.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOKEN="3XWXL3vbSUspZtDsAej52Mm73U7gkeRt"
VIDEOS_DIR="/Users/ila01/Downloads/Videos"

echo "=== Club Carnegie Dashboard Update ==="
echo "$(date '+%d/%m/%Y %H:%M')"

# 1. Buscar membros atualizados
echo "→ Buscando membros do Circle..."
for P in $(seq 1 30); do
  RESP=$(curl -sf -H "Authorization: Bearer $TOKEN" \
    "https://app.circle.so/api/admin/v2/community_members?per_page=100&page=$P&include_member_tags=true")
  COUNT=$(echo "$RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('records',[])))" 2>/dev/null || echo 0)
  echo "$RESP" > "/tmp/circle_members_p${P}.json"
  [ "$COUNT" -eq 0 ] && break
  echo "  Página $P: $COUNT membros"
done

# 2. Regenerar stats
echo "→ Calculando estatísticas..."
python3 "$VIDEOS_DIR/edit/calc_stats.py"

# 3. Rebuscar space_members dos cursos principais
echo "→ Atualizando inscrições por curso..."
for CID in 1971413 1600927 1477891 2583736; do
  rm -f "/tmp/circle_course_members_${CID}.jsonl"
  TOTAL=$(curl -sf -H "Authorization: Bearer $TOKEN" \
    "https://app.circle.so/api/admin/v2/space_members?space_id=${CID}&per_page=1" \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('count',0))" 2>/dev/null || echo 0)
  PAGES=$(python3 -c "import math; print(math.ceil($TOTAL/100))")
  for P in $(seq 1 $PAGES); do
    curl -sf -H "Authorization: Bearer $TOKEN" \
      "https://app.circle.so/api/admin/v2/space_members?space_id=${CID}&per_page=100&page=$P" \
      >> "/tmp/circle_course_members_${CID}.jsonl"
  done
  echo "  Curso $CID: $TOTAL membros"
done

# 4. Gerar dashboard
echo "→ Gerando dashboard..."
python3 "$VIDEOS_DIR/edit/gen_dashboard_full.py"

# 5. Copiar para github_pages e fazer commit/push
cp "$VIDEOS_DIR/edit/dashboard_carnegie.html" "$SCRIPT_DIR/dashboard_carnegie.html"
cd "$SCRIPT_DIR"
git add dashboard_carnegie.html
git commit -m "Dashboard: atualização automática $(date '+%d/%m/%Y')"
git push origin main

echo "✓ Dashboard publicado com sucesso!"
echo "  URL: $(git remote get-url origin | sed 's/github.com\///' | sed 's/\.git//' | awk -F'/' '{print "https://"$1".github.io/"$2}')"
