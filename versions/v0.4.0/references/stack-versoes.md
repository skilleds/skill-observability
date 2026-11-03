# Anexo volátil — versões, estabilidade e fontes (observabilidade)

> Parte da skill **schematize-observability**. **Fonte volátil:** tudo aqui tem prazo de validade e
> é atualizado **à parte** do corpo normativo, que não crava número.
>
> **Verificado em: 2026-10-14.** Cadência: trimestral e antes de cada release da skill.
> Método: API de releases do GitHub (`releases/latest`), registries (crates.io, hex.pm, RubyGems,
> NuGet, proxy.golang.org) e as páginas oficiais citadas. `<!-- reverificar -->` = não confirmado em fonte primária.

## 1. Estabilidade dos sinais OpenTelemetry (por SDK)

Fonte: https://opentelemetry.io/status/ (2026-10-14). A página reporta por SDK; o rol da casa:

| SDK | Traces | Métricas | Logs |
|---|---|---|---|
| Go | Stable | Stable | Release candidate |
| C#/.NET | Stable | Stable | Stable |
| Erlang/Elixir | Stable | Development | Development |
| Rust | Beta | Stable | Stable |
| Ruby | Stable | Development | Development |
| Zig | sem SDK oficial estável (ver exemplos) | | |

- **Profiles:** Alpha na especificação/doc (https://opentelemetry.io/docs/concepts/signals/profiles/);
  nenhum SDK além do Java listado em Development. Há um profiler eBPF do OTel para Linux. Por isso a
  casa usa Pyroscope/pprof hoje (`amostragem-profiling.md`).
- **Baggage:** estável na especificação <!-- reverificar -->. **Eventos:** não verificado <!-- reverificar -->.
- Implicação prática: em **Elixir e Ruby, métricas/logs de OTel ainda estão em Development** — para
  métricas nesses dois, o caminho robusto é Prometheus nativo (PromEx/`yabeda`) lido pelo Collector
  (receiver `prometheus`) até a estabilização; o trace via OTel continua o padrão.

## 2. Versões de referência (últimas estáveis em 2026-10-14)

| Componente | Versão | Fonte |
|---|---|---|
| OTel Collector (contrib/releases) | v0.162.0 (2026-09-29) | github.com/open-telemetry/opentelemetry-collector-releases |
| Especificação OTel | v1.61.0 (2026-09-14) | github.com/open-telemetry/opentelemetry-specification |
| Semantic conventions | v1.44.0 (2026-08-04) | github.com/open-telemetry/semantic-conventions |
| Prometheus | v3.15.0 (2026-09-25) | github.com/prometheus/prometheus |
| Grafana | v13.2.4 (2026-10-13) | github.com/grafana/grafana |
| Loki | v3.7.8 | github.com/grafana/loki |
| Tempo | v3.1.0 | github.com/grafana/tempo |
| Mimir | 3.2.2 | github.com/grafana/mimir |
| Alloy | v1.20.1 | github.com/grafana/alloy |
| Pyroscope | v2.4.0 | github.com/grafana/pyroscope |
| VictoriaMetrics | v1.154.0 | github.com/VictoriaMetrics/VictoriaMetrics |

SDKs e instrumentações pinados nos exemplos (`assets/exemplos/`): Go `go.opentelemetry.io/otel` v1.47.0;
Rust `opentelemetry`/`opentelemetry_sdk`/`opentelemetry-otlp` 0.33.1, `tracing-opentelemetry` 0.34.0;
Elixir `opentelemetry` 1.7.0, `opentelemetry_exporter` 1.11.0; .NET `OpenTelemetry.*` 1.19.x;
Ruby `opentelemetry-sdk` 1.13.1, `opentelemetry-exporter-otlp` 0.37.0. Cada exemplo registra seu
próprio pin e o que foi compilado.

## 3. Fatos específicos sujeitos a revisão

- **Processor `batch` do Collector:** continua Beta e é o recomendado depois de `memory_limiter` e
  amostragem; há trabalho no Collector para mover o batching para o exporter (`sending_queue`) — o
  gate `check-otel-collector.sh` aceita `batch` no processor **ou** no `sending_queue`. <!-- reverificar -->
- **`redaction`:** Beta em traces, **Alpha** em logs e métricas (README do processor, 2026-10-14):
  a config pode mudar entre versões; por isso a versão do Collector é pinada.
- **`tail_sampling`:** Beta, só traces; vive no distro contrib.
- **Histogramas nativos do Prometheus:** reportados como estáveis a partir da 3.8, com coleta por
  opt-in (`scrape_native_histograms`) e receiver OTLP via flag `--web.enable-otlp-receiver`;
  confirmado só por fontes secundárias <!-- reverificar --> (https://prometheus.io/docs/practices/histograms/).
  A spec OTel de mapeamento exponencial->nativo ainda está em Development.
- **Semconv HTTP:** `http.server.request.duration`, `http.request.method`,
  `http.response.status_code`, `http.route` estáveis; `url.template` em Development
  (https://opentelemetry.io/docs/specs/semconv/http/http-metrics/). **`gen_ai.*`:** em evolução <!-- reverificar -->.
  Renomeação conhecida: `deployment.environment` -> `deployment.environment.name`.
- **Licenças:** a stack Grafana (Grafana, Loki, Tempo, Mimir, Pyroscope) é AGPL-3.0 <!-- reverificar -->:
  consumir como serviço interno é ok; **modificar e oferecer como serviço a terceiros** exige
  conformidade — decisão jurídica humana.
- **Alternativas** (VictoriaLogs, SigNoz, OpenObserve, Jaeger, Parca): estado e licença não
  verificados nesta passagem <!-- reverificar -->.
- **SDK de Zig:** `open-telemetry/opentelemetry-zig` (oficial, em desenvolvimento) e
  `zig-o11y/opentelemetry-sdk` (comunidade) existem; sem release estável confirmado — ver `assets/exemplos/zig.md`.

## Regra que NÃO é volátil

O **piso** (OTel + Collector, correlação por `trace_id`, sem PII, baixa cardinalidade, SLO com
burn-rate, alerta com runbook, ambientes separados) vale independente da versão.
