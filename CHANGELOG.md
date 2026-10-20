# Changelog — schematize-observability

Todas as mudanças relevantes deste pacote, no formato [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/),
com versionamento [SemVer](https://semver.org/lang/pt-BR/).
## [0.3.0] — 2026-10-20
### Adicionado
- `references/honeypot.md`: padrão de honeypot defensivo (campo, rota, endpoint-isca com fake 201 sem efeito real, credencial-canário), captura por comportamento e nunca por país, bloqueio com TTL, evento `honeypot.hit`, LGPD e testes.
- Gate `scripts/check-honeypot.sh` (+ teste) que valida o `honeypots.yml` e proíbe bloqueio por país.


## [0.2.1] — 2026-10-14
Ponteiro para a skill nova `schematize-bots` (piso curto, sem duplicar).

### Alterado
- ponteiro para métricas de ack, 429 e shard de bot.

## [0.2.0] — 2026-10-14
Fecha o gate da skill-dev e aponta para as irmãs novas.

### Alterado
- `scripts/check-otel-collector.test.sh`: rótulos dos casos passam a `vermelho:`/`verde:` (o gate da skill-dev não reconhecia os casos plantados em maiúsculas); sem mudança de comportamento, 11 casos.
- `description` reduzida a <=190 caracteres (orçamento do catálogo).
- Ponteiros: alerta SEV1/SEV2 e resposta -> `schematize-incident`; "telemetria de operação não é analytics de produto" -> `schematize-analytics` (fronteiras do `SKILL.md`, §6 de `slo-alertas.md`).

## [0.1.1] — 2026-10-14
Integração ao catálogo (grafo, skills.json, herdados) e correção do texto de precedência herdado.

### Alterado
- Description reduzida (≤235 chars) para caber no orçamento de listagem de skills (soma ≤8300); mesmo território, fronteiras com as irmãs preservadas.
- Blocos herdados ressincronizados com a `schematize-engineering` v0.27.0 (`tools/sync-herdados.mjs`): orquestração com a regra de imagem (nunca pelo Claude; detecta Codex/Gemini e pergunta ao usuário qual usar, Codex como sugestão) e `schematize overdev delegar` (comando do app) no lugar do falso nome de skill `schematize-overdev`.
- Bloco "Precedência e herança" passa à variante `dominio`: o texto antigo dizia que os comandos `/obs-*` "cobrem só o piso da linguagem", o que é falso para skill de domínio/ferramenta.

## [0.1.0] — 2026-10-14
Primeira versão: o tema observabilidade estava espalhado em quatro lugares com versões diferentes (base, infra, front §49 e sete skills de linguagem) e sem dono — ninguém cobria o padrão OpenTelemetry de ponta a ponta, amostragem, cardinalidade, burn-rate, redaction no Collector nem o piso de ambiente (telemetria de hml indo para SaaS de prd).

### Adicionado
- `SKILL.md` com 13 pisos inegociáveis e fronteiras com engineering, infra, web, ai, docs, qa e pentest.
- `references/`: `padrao-otel`, `logs`, `metricas`, `amostragem-profiling`, `slo-alertas`, `healthchecks`, `stack-referencia`, `ambientes`, `front-llm` e o anexo volátil `stack-versoes` (verificado em 2026-10-14).
- Gates com testes vermelhos plantados: `scripts/check-otel-collector.sh` (memory_limiter/batch/redaction, OTLP sem TLS fora de localhost, exporter de prd em config de hml) e `scripts/check-alertas.mjs` (runbook_url, severity, for, alta cardinalidade, SLO sem burn-rate).
- `assets/`: `otel-collector.yaml`, `alertas-slo.rules.yaml` (multi-window multi-burn-rate), `log-json.md`, `exemplos/{go,rust,elixir,csharp,zig,ruby}.md`, `CLAUDE.md`.
- Comandos `/obs-help`, `/obs-load`, `/obs-review`, `/obs-instrument`, `/obs-slo`, `/obs-alerts`, `/obs-dashboard`, `/obs-claude`, `/obs-handoff`, `/obs-cc`.
