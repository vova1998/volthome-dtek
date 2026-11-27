#!/data/data/com.termux/files/usr/bin/bash
# VoltHome — перенесення бота на цей телефон з резервної копії, без введення токенів і паролів.
# Запуск у Termux:  curl -fsSL https://raw.githubusercontent.com/vova1998/volthome-dtek/main/get.sh | bash
# Потрібно: файл deye_backup_….zip з чату бота у «Завантаженнях». Секретів у цьому скрипті немає —
# токен для завантаження програми береться з самої копії.
set -e
G='\033[1;32m'; Y='\033[1;33m'; R='\033[1;31m'; N='\033[0m'
echo -e "${G}▶ VoltHome: перенесення з резервної копії${N}"
if [ ! -d ~/storage/downloads ]; then
  echo -e "${Y}Дозвольте Termux доступ до файлів — натисніть «Дозволити».${N}"
  termux-setup-storage || true
  for i in $(seq 90); do [ -d ~/storage/downloads ] && break; sleep 1; done
fi
mapfile -t ALL < <(ls -t ~/storage/downloads/deye_backup_*.zip ~/storage/downloads/Telegram/deye_backup_*.zip 2>/dev/null)
if [ ${#ALL[@]} -eq 0 ]; then
  echo -e "${R}У «Завантаженнях» немає файлу deye_backup_….zip.${N}"
  echo "Відкрийте чат бота → натисніть на останню резервну копію → ⋮ → «Зберегти в завантаження» і запустіть команду ще раз."
  exit 1
fi
# найсвіжіша копія кожного об'єкта (deye_backup_<об'єкт>_<дата>.zip)
declare -A SEEN; L=()
for f in "${ALL[@]}"; do
  n=$(basename "$f" .zip); site=$(echo "$n" | sed -E 's/^deye_backup_//; s/_?[0-9]{4}-[0-9]{2}-[0-9]{2}$//')
  [ -n "${SEEN[x$site]}" ] && continue; SEEN[x$site]=1; L+=("$f")
done
B="${L[0]}"
if [ ${#L[@]} -gt 1 ]; then
  echo "Знайшов копії кількох об'єктів — який переносимо на цей телефон?"
  for i in "${!L[@]}"; do echo "  $((i+1)). $(basename "${L[$i]}")"; done
  read -rp "Номер: " K < /dev/tty
  B="${L[$((K-1))]}"
fi
[ -f "$B" ] || { echo -e "${R}Немає такого номера.${N}"; exit 1; }
echo -e "   копія: ${Y}$(basename "$B")${N}"
cp "$B" "$HOME/volthome_restore.zip"; B="$HOME/volthome_restore.zip"

echo -e "\n${G}▶ Встановлюю Python (кілька хвилин)…${N}"
pkg update -y -o Dpkg::Options::="--force-confnew" >/dev/null 2>&1 || true
pkg install -y python curl >/dev/null
T=$(python - "$B" <<'PY'
import sys, zipfile, json
t = ""
try:
    st = json.loads(zipfile.ZipFile(sys.argv[1]).read("settings.json"))
    t = st.get("gh_token") or st.get("gh_backup_token") or ""
except Exception:
    pass
print(t.strip())
PY
)
if [ -z "$T" ]; then
  echo -e "${R}У цій копії немає токена GitHub.${N} На іншому об'єкті надішліть боту /move — там є інструкція."
  exit 1
fi
curl -fsSL -H "Authorization: Bearer $T" -H "Accept: application/vnd.github.raw" \
  https://api.github.com/repos/vova1998/campi-deye-widget/contents/server/volthome_install.sh -o "$HOME/volthome_install.sh" \
  || { echo -e "${R}Не вдалося завантажити встановлювач — перевірте інтернет.${N}"; exit 1; }
GH_TOKEN="$T" VH_RESTORE="$B" bash "$HOME/volthome_install.sh"
rm -f "$HOME/volthome_install.sh"
