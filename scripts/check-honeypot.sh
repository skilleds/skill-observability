#!/usr/bin/env bash
# schematize-observability — gate do honeypots.yml (references/honeypot.md).
#
# Motivo: a allowlist é o que impede o FAKE 201 de vazar para rota real e o bloqueio de virar
# discriminação. O que o texto exige e dá para verificar no arquivo:
#  1. toda entrada tem id, tipo válido, dono e justificativa;
#  2. tipos rota-isca/endpoint-isca/campo-isca têm `rota`; email-canario tem `sink`;
#  3. `block_ttl` definido (bloqueio sempre com expiração);
#  4. proibido qualquer chave country_block / block_by_country / bloqueio_por_pais;
#  5. com --routes <arquivo> (uma rota real por linha, "METHOD /path" ou "/path"), nenhuma isca
#     colide com rota real (o fake 201 nunca responde por rota real).
#
# Uso:   check-honeypot.sh [--routes inventario.txt] honeypots.yml
# Saída: 0 passa · 1 reprova · 2 nada para verificar (que NÃO é aprovação).
#
# EXCEÇÃO DECLARADA de strict mode (`schematize-shell` -> `references/piso.md`): COLETOR — soma os
# achados; com `set -e` abortaria no primeiro. Por isso `set -uo pipefail` sem `-e`.
set -uo pipefail

routes=""
if [ "${1:-}" = "--routes" ]; then routes="${2:-}"; shift 2 || true; fi
arq="${1:-}"
if [ -z "$arq" ] || [ ! -f "$arq" ]; then echo "✖ honeypots.yml não encontrado — nada para verificar." >&2; exit 2; fi
if [ -n "$routes" ] && [ ! -f "$routes" ]; then echo "✖ --routes $routes não existe." >&2; exit 2; fi
if ! grep -qE '^[[:space:]]*-[[:space:]]+id:' "$arq"; then echo "✖ nenhuma entrada (- id:) em $arq — nada para verificar." >&2; exit 2; fi

erros=0
falha() { echo "$arq: [$1] $2"; erros=$((erros + 1)); }

while IFS= read -r l; do
  [ -n "$l" ] && falha pais "proibido bloquear por país: $l"
done < <(grep -nEi '^[[:space:]-]*(country_block|block_by_country|bloqueio_por_pais|geo_block)[[:space:]]*:' "$arq")

TIPOS="campo-isca rota-isca endpoint-isca credencial-canario arquivo-canario email-canario"

# Quebra em entradas e valida cada uma
entradas="$(awk '
  /^[[:space:]]*-[[:space:]]+id:/ { if (n) print ""; n=1 }
  n { sub(/^[[:space:]]*-?[[:space:]]*/, ""); if ($0 !~ /^#/) printf "%s\x1f", $0 }
  END { print "" }' "$arq")"

while IFS= read -r ent; do
  [ -z "$ent" ] && continue
  campo() { printf '%s' "$ent" | tr '\037' '\n' | sed -n "s/^$1:[[:space:]]*//p" | head -1 | sed 's/^["'\'']//; s/["'\'']$//; s/[[:space:]]*#.*$//'; }
  id="$(campo id)"; tipo="$(campo tipo)"; rota="$(campo rota)"
  [ -z "$(campo dono)" ] && falha dono "$id: sem dono"
  [ -z "$(campo justificativa)" ] && falha justificativa "$id: sem justificativa"
  [ -z "$(campo block_ttl)" ] && falha ttl "$id: sem block_ttl (bloqueio sem expiração é vetado)"
  case " $TIPOS " in *" $tipo "*) ;; *) falha tipo "$id: tipo '$tipo' inválido (use: $TIPOS)";; esac
  case "$tipo" in
    rota-isca|endpoint-isca|campo-isca) [ -z "$rota" ] && falha rota "$id: tipo $tipo exige rota";;
    email-canario) [ -z "$(campo sink)" ] && falha sink "$id: e-mail-canário só com sink (nunca e-mail real)";;
  esac
  if [ -n "$routes" ] && [ -n "$rota" ]; then
    caminho="${rota#* }"; [ "$caminho" = "$rota" ] && caminho="$rota"
    while IFS= read -r r; do
      r="${r%%#*}"; [ -z "${r// }" ] && continue
      rp="${r#* }"; [ "$rp" = "$r" ] && rp="$r"
      [ "$rp" = "$caminho" ] && falha colisao "$id: rota-isca '$caminho' colide com rota real '$r'"
    done <"$routes"
  fi
done <<<"$entradas"

if [ "$erros" -gt 0 ]; then echo "✖ check-honeypot: $erros achado(s)"; exit 1; fi
echo "OK check-honeypot: $arq"
