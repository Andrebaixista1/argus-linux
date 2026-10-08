# argus-linux — Discador Argus em Ubuntu / Linux Mint

Instalador em um comando para rodar o **Argus** (discador, Windows) em Linux via Wine,
usado na migração da operação de ligação do Windows para Linux (Vieiracred).

## Instalar (PC novo)

```bash
git clone https://github.com/Andrebaixista1/argus-linux.git
sudo bash argus-linux/instalar-argus-linux.sh          # instala tudo
sudo bash argus-linux/instalar-argus-linux.sh --nvidia # idem + driver NVIDIA (pede reinício)
```

Ao terminar, abra **Argus** no menu de aplicativos. No primeiro uso ele pede a chave de
ativação — o script mostra domínio e chave no final.

## O que o script faz

| Passo | Detalhe |
|---|---|
| Repositório WineHQ | `wine-stable` 11 em `/opt/wine-stable`. Chave gravada em **binário** (`gpg --dearmor`) — o apt 3 do Ubuntu 25.04+ recusa chave armored em `.key`. |
| Remove o Wine da distro | O `wine 10.0~repack` da Ubuntu **quebra o Argus** (ver abaixo). |
| `wine` no PATH | Links em `/usr/local/bin` (o pacote WineHQ não registra alternatives por causa do grupo `wine.collection` da Ubuntu). |
| Prefixo | `~/.wine-argus11` do usuário, WoW64, sem diálogos de Mono/Gecko (`mscoree=d;mshtml=d` só no `wineboot`). |
| winetricks | `corefonts` + `vcrun2013`. |
| Argus | Baixa `https://argus.app.br/download` (Inno Setup) para `/var/cache/argus-install` e instala silencioso em `C:\Argus`. |
| Atalho | `~/.local/share/applications/argus.desktop`. |

Idempotente: rodar de novo só confere/atualiza. Grava `~/instalar-argus-linux.ok` no fim.

## Por que não o Wine da Ubuntu

O Argus é Delphi com **Chromium (CEF 109)** embutido. Ao abrir, uma thread do CEF chama
`CaptureStackBackTrace`; no `ntdll` 32-bit do pacote `wine 10.0~repack-12ubuntu1` essa função
usa `ebp` como registrador comum e em seguida chama `RtlCaptureContext`, que lê `[ebp]` →
**page fault em `0x000000FB`** ("O programa Argus.exe encontrou um problema sério").
É bug de compilação do pacote da distro (i386 sem frame pointer); o build do WineHQ não tem.

Sintoma no `winedbg`: `=>0 ntdll+0x5813d (RtlCaptureContext)` chamado por `libcef`.

## Requisitos / limites

- Ubuntu (amd64) ou Linux Mint baseado em Ubuntu (usa `UBUNTU_CODENAME`). **LMDE não.**
- WineHQ precisa ter build para o codinome — o script avisa se não tiver.
- Distros mais antigas (jammy/noble) ainda instalam pacotes i386; nas novas é só amd64 (novo WoW64).
- Testado: Ubuntu 26.04 (resolute), WineHQ 11.0, GeForce GTX 960 — 08/10/2026.

## Arquivos gerados

- `/var/cache/argus-install/` — instalador baixado, logs do winetricks e do Inno.
- `~/.wine-argus11/drive_c/argus-install.log` — log do instalador do Argus.
