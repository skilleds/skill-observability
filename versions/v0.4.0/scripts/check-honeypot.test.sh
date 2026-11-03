#!/usr/bin/env bash
# Teste do gate check-honeypot.sh: VERDE + VERMELHO plantado por regra.
# Casos: verde (esperar 0) e vermelho (esperar 1 ou 2), um vermelho plantado por regra.
# EXCEÇÃO DECLARADA de strict mode: harness de teste — um caso falho não pode abortar os demais.
set -uo pipefail
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$AQUI/check-honeypot.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT INT TERM
ok=0; falhas=0

caso() { # nome esperado regex args...
  local nome="$1" esp="$2" re="$3"; shift 3
  local saida rc
  saida="$(bash "$GATE" "$@" 2>&1)"; rc=$?
  if [ "$rc" -eq "$esp" ] && printf '%s' "$saida" | grep -qE "$re"; then
    echo "  ok   $nome (exit $rc)"; ok=$((ok + 1))
  else
    echo "  FAIL $nome: esperava exit $esp /$re/, veio $rc"; printf '%s\n' "$saida" | sed 's/^/       /'
    falhas=$((falhas + 1))
  fi
}

base() { cat <<'Y'
honeypots:
  - id: hp-register-legacy
    tipo: endpoint-isca
    rota: POST /api/v1/register-legacy
    dono: seguranca
    justificativa: imita cadastro antigo para queimar bots de cadastro em massa
    block_ttl: 24h
  - id: hp-canario-email
    tipo: email-canario
    dono: seguranca
    justificativa: detecta vazamento de base
    sink: sink.teste.invalid
    block_ttl: 24h
Y
}
printf '/api/v1/register\nPOST /api/v1/users\n' > "$T/rotas.txt"

base > "$T/ok.yml";                                  caso "VERDE allowlist completa" 0 "^OK" "$T/ok.yml"
caso "VERDE com --routes sem colisão" 0 "^OK" --routes "$T/rotas.txt" "$T/ok.yml"
base | grep -v 'dono: seguranca' | head -n 5 > "$T/v1.yml"; sed -i '$a\    block_ttl: 1h' "$T/v1.yml"
caso "VERMELHO sem dono" 1 "\[dono\]" "$T/v1.yml"
base | sed 's/^    justificativa:.*//' > "$T/v2.yml";  caso "VERMELHO sem justificativa" 1 "\[justificativa\]" "$T/v2.yml"
base | sed 's/tipo: endpoint-isca/tipo: armadilha/' > "$T/v3.yml"; caso "VERMELHO tipo inválido" 1 "\[tipo\]" "$T/v3.yml"
base | sed 's/block_ttl: 24h//' > "$T/v4.yml";       caso "VERMELHO sem TTL" 1 "\[ttl\]" "$T/v4.yml"
{ base; echo '    country_block: [RU, SA]'; } > "$T/v5.yml"; caso "VERMELHO bloqueio por país" 1 "\[pais\]" "$T/v5.yml"
base | sed 's#/api/v1/register-legacy#/api/v1/register#' > "$T/v6.yml"
caso "VERMELHO colide com rota real" 1 "\[colisao\]" --routes "$T/rotas.txt" "$T/v6.yml"
base | sed 's/^    sink:.*//' > "$T/v7.yml";           caso "VERMELHO e-mail-canário sem sink" 1 "\[sink\]" "$T/v7.yml"
base | sed 's/^    rota:.*//' > "$T/v8.yml";           caso "VERMELHO endpoint-isca sem rota" 1 "\[rota\]" "$T/v8.yml"
: > "$T/vazio.yml";                                  caso "nada para verificar" 2 "nada para verificar" "$T/vazio.yml"

echo "check-honeypot: $ok ok, $falhas falha(s)"
[ "$falhas" -eq 0 ]
