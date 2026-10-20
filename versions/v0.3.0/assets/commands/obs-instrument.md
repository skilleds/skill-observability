---
description: schematize-observability — instrumenta um serviço no padrão da casa (SDK OTel -> Collector, semconv, log JSON correlacionado, métricas RED, probes) na linguagem do rol
argument-hint: "[linguagem ou diretório do serviço]"
---

# /obs-instrument — observabilidade nasce com o serviço

1. **Detecte a linguagem** (`go.mod`, `Cargo.toml`, `mix.exs`, `*.csproj`, `build.zig`, `Gemfile`) e leia
   `assets/exemplos/<linguagem>.md` + `references/padrao-otel.md`. Linguagem fora do rol: pare e diga
   (stack por fit + ADR, `schematize-engineering`).
2. **Bootstrap do SDK** em um único lugar: Resource (`service.name`, `service.version`,
   `deployment.environment.name`), exportador OTLP para o Collector local por `OTEL_EXPORTER_OTLP_ENDPOINT`,
   propagadores `tracecontext,baggage`, shutdown limpo. Versões: `references/stack-versoes.md`.
3. **Auto-instrumentação** de HTTP server/client, banco e fila; span manual só para regra de negócio,
   com atributo da semconv.
4. **Métricas:** `http.server.request.duration` (histograma em segundos, buckets em torno do SLO),
   contador de negócio; **nenhum label de alta cardinalidade** (`references/metricas.md` §3).
5. **Log:** JSON em stdout no formato de `assets/log-json.md`, com `trace_id`/`span_id` do span ativo,
   sem PII/segredo.
6. **Probes:** `/health` (liveness, sem dependência), `/ready` (readiness com dependências), `/startup`
   se a subida é lenta, `/metrics` quando houver scrape.
7. **Prove:** teste que roda com exporter em memória e verifica span, métrica e `trace_id` no log;
   depois `/obs-review`. Sem rede e sem backend real.
8. **Entregue junto:** `/docs/slo.md` e regras (`/obs-slo`), dashboard (`/obs-dashboard`), config do Collector.
