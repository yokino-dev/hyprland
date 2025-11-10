#!/usr/bin/env bash
# Alterna mute/unmute do microfone (compatível PulseAudio / pipewire-pulse)
# Uso: ./toggle-mic.sh

set -u
# 1) Tenta obter default source de formas diferentes
DEFAULT_SOURCE="$(pactl get-default-source 2>/dev/null || true)"
if [ -z "$DEFAULT_SOURCE" ]; then
  DEFAULT_SOURCE="$(pactl info 2>/dev/null | awk -F': ' '/Default Source/{print $2}' || true)"
fi
# 2) Fallback: pega a primeira fonte que não seja monitor
if [ -z "$DEFAULT_SOURCE" ]; then
  DEFAULT_SOURCE="$(pactl list short sources 2>/dev/null | awk '!/monitor/ {print $2; exit}' || true)"
fi

if [ -z "$DEFAULT_SOURCE" ]; then
  echo "Erro: não consegui identificar a fonte (microfone) padrão." >&2
  echo "Tente: pactl list short sources" >&2
  exit 1
fi

# 3) Pega o status de mute de forma mais tolerante
IS_MUTED="$(pactl get-source-mute "$DEFAULT_SOURCE" 2>/dev/null | awk -F': ' '{print $2}' | tr -d '\r\n' | tr '[:upper:]' '[:lower:]' || true)"

# 4) Interpreta vários formatos possíveis e alterna
case "$IS_MUTED" in
  yes|1|muted)
    pactl set-source-mute "$DEFAULT_SOURCE" 0
    echo "Desmutado: $DEFAULT_SOURCE"
    ;;
  no|0|unmuted|"" )
    pactl set-source-mute "$DEFAULT_SOURCE" 1
    echo "Mutado: $DEFAULT_SOURCE"
    ;;
  *)
    # Se IS_MUTED contiver mensagem de erro, mostra para debug e tenta alternar por índice
    echo "Aviso: status de mute inesperado: '$IS_MUTED'." >&2
    echo "Tentando alternar por índice..." >&2
    # tenta obter índice
    SRC_INDEX="$(pactl list short sources 2>/dev/null | awk -v s="$DEFAULT_SOURCE" '$2==s {print $1; exit}')"
    if [ -n "$SRC_INDEX" ]; then
      pactl set-source-mute "$SRC_INDEX" toggle 2>/dev/null || pactl set-source-mute "$SRC_INDEX" 1
      echo "Alternado por índice: $SRC_INDEX"
    else
      echo "Não foi possível alternar." >&2
      exit 2
    fi
    ;;
esac
