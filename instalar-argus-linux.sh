#!/bin/bash
# =============================================================================
#  instalar-argus-linux.sh — Discador Argus em Ubuntu / Linux Mint
#
#  Uso:  sudo bash instalar-argus-linux.sh            (instala tudo)
#        sudo bash instalar-argus-linux.sh --nvidia   (idem + driver NVIDIA, pede reinício)
#
#  O que faz (idempotente — pode rodar de novo sem estragar nada):
#   1. Repositório WineHQ + wine-stable 11 (o Wine 10 da Ubuntu quebra o Chromium do Argus)
#   2. Deixa `wine` disponível no PATH (/usr/local/bin → /opt/wine-stable)
#   3. Prefixo WoW64 em ~/.wine-argus11 do usuário (sem diálogo de Mono/Gecko)
#   4. corefonts + vcrun2013 (winetricks)
#   5. Baixa o instalador oficial (https://argus.app.br/download) e instala silencioso
#   6. Atalho "Argus" no menu de aplicativos
#  No fim mostra a chave de ativação a digitar no primeiro uso.
#
#  Testado em: Ubuntu 26.04 (resolute) com WineHQ 11.0 — 08/10/2026
# =============================================================================
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

ARGUS_URL="https://argus.app.br/download"
WINEHQ_KEY_URL="https://dl.winehq.org/wine-builds/winehq.key"
WINE_BIN=/opt/wine-stable/bin
PREFIX_NAME=".wine-argus11"
CACHE=/var/cache/argus-install
COM_NVIDIA=0
[ "${1:-}" = "--nvidia" ] && COM_NVIDIA=1

log()  { echo -e "\n\033[1;36m>> $*\033[0m"; }
erro() { echo -e "\n\033[1;31mERRO: $*\033[0m" >&2; exit 1; }

[ "$(id -u)" = 0 ] || erro "rode com sudo: sudo bash $0"
U="${SUDO_USER:-}"; [ -n "$U" ] && [ "$U" != root ] || erro "rode com sudo a partir do usuário normal (não como root direto)"
H="$(getent passwd "$U" | cut -d: -f6)"
[ "$(dpkg --print-architecture)" = amd64 ] || erro "só amd64 (64 bits)"

# ---------------------------------------------------------------- 0. distro
. /etc/os-release
case "${ID:-}" in
  ubuntu)    CODENAME="${VERSION_CODENAME:-}";;
  linuxmint) CODENAME="${UBUNTU_CODENAME:-}";;   # Mint 22 = noble, Mint 21 = jammy...
  *)         erro "distro '$ID' não suportada (só Ubuntu e Linux Mint baseado em Ubuntu; LMDE não)";;
esac
[ -n "$CODENAME" ] || erro "não achei o codinome Ubuntu em /etc/os-release"
log "Distro: $PRETTY_NAME  → base Ubuntu '$CODENAME'  usuário: $U"

# ---------------------------------------------------------------- 1. WineHQ
log "Repositório WineHQ ($CODENAME)"
apt-get install -y -qq ca-certificates curl gnupg >/dev/null
mkdir -pm755 /etc/apt/keyrings
# apt ≥ 3 só aceita a chave em BINÁRIO num arquivo .key (armored dá "unsupported filetype")
curl -fsSL "$WINEHQ_KEY_URL" | gpg --dearmor > /etc/apt/keyrings/winehq-archive.key
chmod 644 /etc/apt/keyrings/winehq-archive.key
SRC="https://dl.winehq.org/wine-builds/ubuntu/dists/$CODENAME/winehq-$CODENAME.sources"
curl -fsSL -o /etc/apt/sources.list.d/winehq-$CODENAME.sources "$SRC" \
  || erro "WineHQ não tem build para '$CODENAME' ($SRC)"
# distros mais antigas (jammy/noble) ainda usam pacotes i386; nas novas é só amd64 (WoW64)
if grep -q i386 /etc/apt/sources.list.d/winehq-$CODENAME.sources; then dpkg --add-architecture i386; fi
# remove o wine da distro (conflita e é o que quebra o Argus)
apt-get remove -y -qq wine wine32:i386 wine64 wine-common libwine libwine:i386 2>/dev/null || true
apt-get update -qq
log "Instalando winehq-stable (pode demorar alguns minutos)"
apt-get install -y -qq --install-recommends winehq-stable winetricks cabextract
"$WINE_BIN/wine" --version

# ---------------------------------------------------------------- 2. PATH
log "Links do wine em /usr/local/bin"
for b in wine wineboot winecfg wineserver winedbg winepath winefile; do
  [ -x "$WINE_BIN/$b" ] && ln -sfn "$WINE_BIN/$b" /usr/local/bin/$b
done
ln -sfn "$WINE_BIN/wine" /usr/local/bin/wine-stable

# ---------------------------------------------------------------- 3. instalador
log "Instalador oficial do Argus"
mkdir -p "$CACHE"
if [ ! -s "$CACHE/ArgusInstall.exe" ]; then
  curl -fL --retry 3 -o "$CACHE/ArgusInstall.exe.part" "$ARGUS_URL"
  mv "$CACHE/ArgusInstall.exe.part" "$CACHE/ArgusInstall.exe"
fi
chmod 644 "$CACHE/ArgusInstall.exe"; ls -la "$CACHE/ArgusInstall.exe" | awk '{print $5" bytes"}'

# ---------------------------------------------------------------- 4..6 como o usuário
PREFIX="$H/$PREFIX_NAME"
log "Prefixo $PREFIX"
# mscoree/mshtml desligados só aqui: pula os diálogos "instalar Wine Mono / Gecko" (Argus é Delphi+CEF, não precisa)
sudo -u "$U" env HOME="$H" WINEPREFIX="$PREFIX" WINEDEBUG=-all WINEDLLOVERRIDES="mscoree=d;mshtml=d" \
  "$WINE_BIN/wineboot" -i >/dev/null 2>&1 || true
# (sem `wineserver -w` aqui: ele esperaria um Argus já aberto fechar e travaria a reinstalação)

log "corefonts + vcrun2013 (winetricks)"
sudo -u "$U" env HOME="$H" WINEPREFIX="$PREFIX" WINE="$WINE_BIN/wine" PATH="$WINE_BIN:$PATH" WINEDEBUG=-all \
  winetricks -q corefonts vcrun2013 >"$CACHE/winetricks.log" 2>&1 || echo "   (winetricks avisou algo — ver $CACHE/winetricks.log; o Argus traz as DLLs do VC++ junto)"

if [ ! -x "$PREFIX/drive_c/Argus/Argus.exe" ]; then
  log "Instalando o Argus (silencioso)"
  sudo -u "$U" env HOME="$H" WINEPREFIX="$PREFIX" WINEDEBUG=-all \
    "$WINE_BIN/wine" "$CACHE/ArgusInstall.exe" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /LOG="C:\\argus-install.log" \
    >"$CACHE/argus-install.log" 2>&1 || true
  [ -x "$PREFIX/drive_c/Argus/Argus.exe" ] || erro "instalador não deixou C:\\Argus\\Argus.exe — ver $PREFIX/drive_c/argus-install.log"
else
  echo "   Argus já instalado em $PREFIX/drive_c/Argus — mantido"
fi

log "Atalho no menu"
APPS="$H/.local/share/applications"; mkdir -p "$APPS"
cat > "$APPS/argus.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Argus
Comment=Discador Argus (Wine 11 / WineHQ)
Exec=env WINEPREFIX=$PREFIX WINEDEBUG=-all $WINE_BIN/wine C:\\\\Argus\\\\Argus.exe
Path=$PREFIX/drive_c/Argus
Icon=$PREFIX/drive_c/Argus/favicon.ico
Terminal=false
Categories=Network;
StartupNotify=true
EOF
chown -R "$U:" "$APPS/argus.desktop" "$PREFIX"
sudo -u "$U" env HOME="$H" update-desktop-database "$APPS" 2>/dev/null || true

# ---------------------------------------------------------------- opcional: NVIDIA
if [ "$COM_NVIDIA" = 1 ]; then
  log "Driver NVIDIA (ubuntu-drivers autoinstall)"
  apt-get install -y -qq ubuntu-drivers-common >/dev/null
  ubuntu-drivers autoinstall || echo "   (sem placa NVIDIA ou nada a instalar)"
  echo "   ⚠️ reinicie o PC para o driver entrar"
fi

# ---------------------------------------------------------------- fim
cat <<EOF

=============================================================
 ✅ PRONTO — Argus instalado para o usuário $U
   Abra pelo menu de aplicativos ("Argus") ou:
   env WINEPREFIX=$PREFIX $WINE_BIN/wine C:\\\\Argus\\\\Argus.exe

 No primeiro uso o Argus pede a chave de ativação:
   Domínio: VIEIRACRED
   Chave:   659-730-772
=============================================================
EOF
echo "ok $(date +%F) wine=$("$WINE_BIN/wine" --version) base=$CODENAME" > "$H/instalar-argus-linux.ok"; chown "$U:" "$H/instalar-argus-linux.ok"
