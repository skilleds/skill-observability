#!/usr/bin/env bash
# schematize-observability — gate da CONFIG DO OTEL COLLECTOR (references/collector.md).
#
# Motivo: o Collector é o ponto único por onde passa toda a telemetria; um defeito de config ali é um
# defeito de TODOS os serviços. Quatro coisas que o texto exige e que dá para verificar no arquivo:
#  1. TODA pipeline tem `memory_limiter` e `batch` (sem o primeiro o Collector morre por OOM sob
#     pico; sem o segundo cada span vira uma chamada de rede). Aceita-se `batch:` em `sending_queue`
#     do exporter como alternativa ao processor `batch`;
#  2. pipelines de LOGS e TRACES têm o processor `redaction` (PII/segredo se barra também no
#     Collector, não só no SDK);
#  3. endpoint de exporter sem TLS (`http://` ou `tls.insecure: true`) só para localhost/127.0.0.1/
#     ::1/`otel-collector` (rede local do próprio host);
#  4. config de hml/stg/dev (nome do arquivo ou `# obs-env: hml`) NÃO tem exporter de prd nem SaaS
#     externo (efeito externo nunca sai de não-prd).
#
# Uso:    check-otel-collector.sh [arquivo.yaml | diretório]   (default: .)
#         Em diretório, só são examinados YAMLs com `service:` + `pipelines:` no topo.
# Saída:  0 = passa · 1 = REPROVA · 2 = nada para verificar (que NÃO é aprovação).
# Waiver: `# obs-ok: <motivo>` na linha do achado ou na de cima — COM o motivo.
# Limite: parser por indentação (awk), não YAML completo: não resolve âncoras, nem `${env:X}`
#         (host desconhecido conta como não-local quando há `insecure: true`).
#
# EXCEÇÃO DECLARADA de strict mode (`schematize-shell` -> `references/piso.md` seção 1): este script é um
# COLETOR — varre tudo e SOMA os achados; com `set -e` abortaria no primeiro e esconderia os outros.
# Por isso `set -uo pipefail` sem `-e`.
set -uo pipefail

alvo="${1:-.}"
if [ ! -e "$alvo" ]; then
  echo "✖ $alvo não existe — nada para verificar." >&2
  exit 2
fi

if [ -d "$alvo" ]; then
  mapfile -t arquivos < <(find "$alvo" -type f \( -name '*.yaml' -o -name '*.yml' \) \
    -not -path '*/.git/*' -not -path '*/node_modules/*' -not -path '*/versions/*' | sort)
else
  arquivos=("$alvo")
fi

# O programa awk emite uma linha "L<n>|<mensagem>" por achado; o waiver é resolvido aqui.
analisa() {
  local f="$1" hml="$2"
  awk -v HML="$hml" '
    function ind(s) { match(s, /^ */); return RLENGTH }
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t\r]+$/, "", s); return s }
    function unq(s) { gsub(/^["\x27]|["\x27]$/, "", s); return s }
    function nome(s) { s = unq(trim(s)); sub(/\/.*/, "", s); return s }
    function achado(n, m) { print "L" n "|" m }
    { L[NR] = $0 }
    END {
      top = ""; cur = ""; inpipes = 0; pind = -1; cind = -1; prind = -1; inpr = 0; achou = 0
      for (i = 1; i <= NR; i++) {
        l = L[i]; t = trim(l)
        if (t == "" || t ~ /^#/) continue
        n = ind(l)
        if (n == 0 && t ~ /^[A-Za-z_]+:/) { top = t; sub(/:.*/, "", top); cur = ""; inpipes = 0; inpr = 0; continue }
        if (top == "exporters") {
          if (cind < 0 || (n < cind)) { if (n > 0) cind = n }
          if (n == cind && t ~ /^[^ :#-][^:]*:[ \t]*(#.*)?$/) { cur = t; sub(/:.*/, "", cur); cur = unq(cur); exl[cur] = i; continue }
          if (cur != "" && t ~ /^endpoint:/) {
            v = t; sub(/^endpoint:[ \t]*/, "", v); sub(/[ \t]+#.*/, "", v); v = unq(v)
            ep[cur] = v; epl[cur] = i
          }
          if (cur != "" && t ~ /^insecure:[ \t]*true/) { ins[cur] = 1; insl[cur] = i }
          continue
        }
        if (top == "service") {
          if (t ~ /^pipelines:/) { inpipes = 1; pind = n; cind2 = -1; continue }
          if (!inpipes) continue
          if (n <= pind) { inpipes = 0; continue }
          if (cind2 < 0) cind2 = n
          if (n == cind2 && t ~ /:[ \t]*(#.*)?$/) {
            pn = t; sub(/:.*/, "", pn); pn = unq(pn); np++; pname[np] = pn; pline[np] = i
            sig[np] = nome(pn); inpr = 0; achou = 1; continue
          }
          if (np < 1) continue
          if (inpr && (n <= prind)) inpr = 0
          if (t ~ /^processors:/) {
            prind = n; inpr = 1
            v = t; sub(/^processors:[ \t]*/, "", v); sub(/[ \t]+#.*/, "", v)
            if (v ~ /^\[/) {
              gsub(/[\[\]]/, "", v); m = split(v, a, ",")
              for (k = 1; k <= m; k++) if (trim(a[k]) != "") procs[np] = procs[np] " " nome(a[k])
              inpr = 0
            }
            has[np] = 1
            continue
          }
          if (inpr && t ~ /^-/) { v = t; sub(/^-[ \t]*/, "", v); sub(/[ \t]+#.*/, "", v); procs[np] = procs[np] " " nome(v) }
          continue
        }
        if (top == "exporters") continue
      }
      if (!achou) { print "NOPIPE"; exit }
      # sending_queue.batch como alternativa ao processor batch
      sq = 0
      for (i = 1; i <= NR; i++) if (L[i] ~ /^[ ]+batch:/ ) sq = 1
      for (p = 1; p <= np; p++) {
        pr = " " procs[p] " "
        if (pr !~ / memory_limiter /) achado(pline[p], "pipeline \"" pname[p] "\" sem processor memory_limiter — o Collector morre por OOM no primeiro pico")
        if (pr !~ / batch / && !sq) achado(pline[p], "pipeline \"" pname[p] "\" sem processor batch — cada span/ponto vira uma chamada de rede")
        if ((sig[p] == "logs" || sig[p] == "traces") && pr !~ / redaction /)
          achado(pline[p], "pipeline \"" pname[p] "\" (" sig[p] ") sem processor redaction — PII/segredo precisa ser barrado também no Collector")
      }
      for (e in exl) {
        h = ep[e]; hostpart = h; sub(/^[a-z]+:\/\//, "", hostpart); sub(/[\/:].*$/, "", hostpart)
        if (h ~ /^\[::1\]/) hostpart = "::1"
        local = (hostpart ~ /^(localhost|127\.0\.0\.1|::1|otel-collector)$/)
        if (e ~ /^otlp/ || h ~ /^http:\/\//) {
          if (h ~ /^http:\/\// && !local) achado(epl[e], "exporter \"" e "\": endpoint http:// (sem TLS) para host não-local (" hostpart ")")
          if (ins[e] && !local) achado(insl[e], "exporter \"" e "\": tls.insecure: true para host não-local (" (hostpart == "" ? "?" : hostpart) ")")
        }
        if (HML == 1) {
          s = tolower(e " " h)
          if (s ~ /(^|[^a-z])(prd|prod|production)([^a-z]|$)/)
            achado((epl[e] ? epl[e] : exl[e]), "config de hml/dev com exporter/endpoint de PRD: \"" e "\" " h)
          else if (s ~ /datadoghq|newrelic|nr-data|honeycomb|sentry\.io|grafana\.net|dynatrace|elastic-cloud|splunkcloud|signoz\.cloud|lightstep|logz\.io|coralogix|betterstack|uptrace\.dev/)
            achado((epl[e] ? epl[e] : exl[e]), "config de hml/dev apontando para SaaS externo: \"" e "\" " h)
        }
      }
    }' "$f"
}

erros=0; verificados=0
for f in "${arquivos[@]}"; do
  # em diretório, só interessa YAML de Collector (service: + pipelines:)
  if [ -d "$alvo" ] && ! { grep -qE '^service:' "$f" && grep -qE '^[[:space:]]+pipelines:' "$f"; }; then
    continue
  fi
  base="$(basename "$f")"
  hml=0
  if printf '%s' "$base" | grep -qiE '(^|[-_.])(hml|stg|staging|dev|homolog|homologacao)([-_.]|$)' \
     || grep -qiE '^[[:space:]]*#[[:space:]]*obs-env:[[:space:]]*(hml|stg|staging|dev|homolog)' "$f"; then
    hml=1
  fi
  saida="$(analisa "$f" "$hml")"
  if [ "$saida" = "NOPIPE" ]; then
    echo "· $f: sem service.pipelines — pulado" >&2
    continue
  fi
  verificados=$((verificados + 1))
  while IFS='|' read -r loc msg; do
    [ -n "${loc:-}" ] || continue
    n="${loc#L}"
    atual="$(sed -n "${n}p" "$f")"
    ant=""; [ "$n" -gt 1 ] && ant="$(sed -n "$((n - 1))p" "$f")"
    if printf '%s\n%s\n' "$atual" "$ant" | grep -qE '#[[:space:]]*obs-ok:[[:space:]]*[^[:space:]]'; then
      echo "~ $f:$n (waiver) $msg"
      continue
    fi
    echo "✖ $f:$n $msg"
    erros=$((erros + 1))
  done <<< "$saida"
done

if [ "$verificados" -eq 0 ]; then
  echo "✖ nenhuma config de Collector (service.pipelines) em $alvo — nada para verificar." >&2
  exit 2
fi
if [ "$erros" -gt 0 ]; then
  echo "REPROVA: $erros achado(s) em $verificados config(s) de Collector."
  exit 1
fi
echo "OK: $verificados config(s) de Collector sem achados."
