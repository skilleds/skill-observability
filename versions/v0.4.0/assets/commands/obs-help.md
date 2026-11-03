---
description: Mapa da skill schematize-observability (OpenTelemetry, três sinais + profiling, SLO e alertas, dashboards como código, healthchecks).
---
**schematize-observability** — a dona do tema observabilidade na casa.

| Comando | O que faz |
|---|---|
| `/obs-help` | esta lista |
| `/obs-load` | carrega à força TODO o corpo normativo e passa a aplicá-lo |
| `/obs-review` | revisa a observabilidade de um serviço e roda os gates |
| `/obs-instrument` | instrumenta um serviço no padrão (SDK -> Collector, semconv, log JSON, probes) |
| `/obs-slo` | define SLI/SLO/error budget e gera as regras de burn-rate |
| `/obs-alerts` | audita/escreve alertas (sintoma, severity, for, runbook) e roda `check-alertas.mjs` |
| `/obs-dashboard` | dashboard como código (SLO + RED + USE + links) |
| `/obs-claude` | cria ou mescla o `CLAUDE.md` sempre-on de observabilidade |
| `/obs-cc` · `/obs-handoff` | context compact / handoff no archive |

Pareia com: `schematize-engineering` (DoD, FinOps, auditoria), `schematize-infra` (a stack sobe na IaC),
`schematize-web` (RUM), `schematize-ai` (LLM), `schematize-docs` (runbook, ADR), `schematize-qa`
(teste do sinal), `schematize-pentest` (vazamento em telemetria).
