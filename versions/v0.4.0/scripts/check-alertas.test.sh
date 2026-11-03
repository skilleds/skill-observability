#!/usr/bin/env bash
# Teste do gate check-alertas.mjs: 1 caso VERDE + 1 caso VERMELHO plantado por regra.
# EXCEÇÃO DECLARADA de strict mode: harness de teste — um caso falho não pode abortar os demais.
set -uo pipefail
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$AQUI/check-alertas.mjs"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT INT TERM
ok=0; falhas=0

# regra <alert> <expr> [for] [severity] [runbook]  -> arquivo completo com 1 grupo
gera() {
  local alert="$1" expr="$2" for_="${3-5m}" sev="${4-page}" rb="${5-https://runbooks.exemplo/x}"
  echo "groups:"; echo "  - name: t"; echo "    rules:"
  echo "      - alert: $alert"; echo "        expr: '$expr'"
  [ -n "$for_" ] && echo "        for: $for_"
  echo "        labels:"; echo "          team: core"
  [ -n "$sev" ] && echo "          severity: $sev"
  echo "        annotations:"; echo "          summary: teste"
  [ -n "$rb" ] && echo "          runbook_url: $rb"
  return 0
}

caso() {
  local nome="$1" arq="$2" esp="$3" re="$4" saida rc
  saida="$(node "$GATE" "$arq" 2>&1)"; rc=$?
  if [ "$rc" -eq "$esp" ] && { [ "$re" = "-" ] || printf '%s' "$saida" | grep -qE "$re"; }; then
    echo "  ok   $nome (exit $rc)"; ok=$((ok + 1))
  else
    echo "  FAIL $nome: esperava exit $esp /$re/, veio $rc"; printf '%s\n' "$saida" | sed 's/^/       /'
    falhas=$((falhas + 1))
  fi
}

SLO_OK='(sum(rate(errors[1h])) / sum(rate(total[1h])) > (14.4 * 0.001)) and (sum(rate(errors[5m])) / sum(rate(total[5m])) > (14.4 * 0.001))'

gera ErroAlto "sum(rate(http_requests_total[5m])) > 0.05" > "$T/verde.yaml"
caso "VERDE alerta completo" "$T/verde.yaml" 0 "^OK"

gera SloBurnRapido "$SLO_OK" > "$T/slo-ok.yaml"
caso "VERDE SLO multi-window burn-rate" "$T/slo-ok.yaml" 0 "^OK"

gera ErroAlto "vector(1) > 0" 5m page "" > "$T/v1.yaml"
caso "VERMELHO sem runbook_url" "$T/v1.yaml" 1 "\[runbook\]"

gera ErroAlto "vector(1) > 0" 5m "" > "$T/v2.yaml"
caso "VERMELHO sem severity" "$T/v2.yaml" 1 "\[severity\]"

gera ErroAlto "vector(1) > 0" "" > "$T/v3.yaml"
caso "VERMELHO sem for" "$T/v3.yaml" 1 "\[for\]"

gera ErroAlto "vector(1) > 0" 0m > "$T/v3b.yaml"
caso "VERDE for: 0m explícito" "$T/v3b.yaml" 0 "^OK"

gera ErroAlto "sum by (user_id) (rate(http_requests_total[5m])) > 1" > "$T/v4.yaml"
caso "VERMELHO label de alta cardinalidade em by()" "$T/v4.yaml" 1 "\[cardinal\].*user_id"

gera ErroAlto "sum(rate(http_requests_total{path=\\\"/a/1\\\"}[5m])) > 1" > "$T/v4b.yaml"
caso "VERMELHO path cru em seletor" "$T/v4b.yaml" 1 "\[cardinal\].*path"

gera SloBurnSimples "sum(rate(errors[1h])) / sum(rate(total[1h])) > 0.014" > "$T/v5.yaml"
caso "VERMELHO SLO com janela única" "$T/v5.yaml" 1 "\[slo\]"

{ gera ErroAlto "vector(1) > 0" 5m page ""; echo "        # obs-ok: runbook em redação, ticket OBS-12"; } > "$T/w.yaml"
caso "VERDE waiver rastreável" "$T/w.yaml" 0 "waiver"

printf 'groups:\n  - name: g\n    rules:\n      - record: a:b\n        expr: sum(up)\n' > "$T/so-record.yaml"
caso "nada para verificar (sem alert:)" "$T/so-record.yaml" 2 "nada para verificar"

echo "check-alertas: $ok ok, $falhas falha(s)"
[ "$falhas" -eq 0 ]
