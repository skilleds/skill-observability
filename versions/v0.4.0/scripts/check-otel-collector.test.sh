#!/usr/bin/env bash
# Teste do gate check-otel-collector.sh: 1 caso verde + 1 caso vermelho plantado por regra.
# EXCEÇÃO DECLARADA de strict mode: harness de teste — cada caso roda o gate e compara o exit code
# esperado; um caso falho não pode abortar os demais. Por isso `set -uo pipefail` sem `-e`.
set -uo pipefail
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$AQUI/check-otel-collector.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT INT TERM
ok=0; falhas=0

# base verde: tudo certo
verde() { cat <<'Y'
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
processors:
  memory_limiter:
    check_interval: 1s
    limit_percentage: 80
  redaction:
    allow_all_keys: true
    blocked_key_patterns: [".*password.*"]
  batch: {}
exporters:
  otlp/tempo:
    endpoint: tempo.internal:4317
    tls:
      ca_file: /etc/ssl/ca.pem
service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, redaction, batch]
      exporters: [otlp/tempo]
    logs:
      receivers: [otlp]
      processors:
        - memory_limiter
        - redaction
        - batch
      exporters: [otlp/tempo]
Y
}

# caso <nome> <arquivo> <exit-esperado> <regex-na-saida|->
caso() {
  local nome="$1" arq="$2" esp="$3" re="$4" saida rc
  saida="$(bash "$GATE" "$arq" 2>&1)"; rc=$?
  if [ "$rc" -eq "$esp" ] && { [ "$re" = "-" ] || printf '%s' "$saida" | grep -qE "$re"; }; then
    echo "  ok   $nome (exit $rc)"; ok=$((ok + 1))
  else
    echo "  FAIL $nome: esperava exit $esp /$re/, veio $rc"; printf '%s\n' "$saida" | sed 's/^/       /'
    falhas=$((falhas + 1))
  fi
}

verde > "$T/verde.yaml"
caso "verde: referência" "$T/verde.yaml" 0 "^OK"

verde | grep -v 'memory_limiter' | sed 's/processors: \[redaction, batch\]/processors: [redaction, batch]/' > "$T/v1.yaml"
caso "vermelho: sem memory_limiter" "$T/v1.yaml" 1 "sem processor memory_limiter"

verde | sed 's/, batch\]/]/; /^        - batch$/d' | sed '/^  batch: {}$/d' > "$T/v2.yaml"
caso "vermelho: sem batch" "$T/v2.yaml" 1 "sem processor batch"

verde | sed 's/memory_limiter, redaction, batch/memory_limiter, batch/; /^        - redaction$/d' > "$T/v3.yaml"
caso "vermelho: sem redaction (traces e logs)" "$T/v3.yaml" 1 "sem processor redaction"

verde | sed 's#endpoint: tempo.internal:4317#endpoint: http://tempo.exemplo.com:4318#' > "$T/v4.yaml"
caso "vermelho: http:// fora de localhost" "$T/v4.yaml" 1 "sem TLS"

verde | sed 's#      ca_file: /etc/ssl/ca.pem#      insecure: true#' > "$T/v5.yaml"
caso "vermelho: tls.insecure fora de localhost" "$T/v5.yaml" 1 "insecure: true"

verde | sed 's#endpoint: tempo.internal:4317#endpoint: localhost:4317#; s#      ca_file: /etc/ssl/ca.pem#      insecure: true#' > "$T/v6.yaml"
caso "verde: insecure em localhost" "$T/v6.yaml" 0 "^OK"

verde | sed 's#endpoint: tempo.internal:4317#endpoint: tempo-prd.interno:4317#' > "$T/otel-hml.yaml"
caso "vermelho: exporter de prd em config hml" "$T/otel-hml.yaml" 1 "PRD"

verde | sed 's#endpoint: tempo.internal:4317#endpoint: otlp.nr-data.net:4317#' > "$T/otel-staging.yaml"
caso "vermelho: SaaS em config staging" "$T/otel-staging.yaml" 1 "SaaS"

verde | grep -v 'memory_limiter' | sed 's#^    traces:#    traces: \# obs-ok: pipeline de bancada sem limite, volume trivial#; s#^    logs:#    logs: \# obs-ok: idem#' > "$T/v8.yaml"
caso "verde: com waiver rastreável (motivo)" "$T/v8.yaml" 0 "waiver"

mkdir "$T/vazio"
caso "nada para verificar (dir sem Collector)" "$T/vazio" 2 "nada para verificar"

echo "check-otel-collector: $ok ok, $falhas falha(s)"
[ "$falhas" -eq 0 ]
