---
description: schematize-observability — carrega à força TODO o corpo normativo (OTel, sinais, SLO, alertas, healthchecks, stack, ambientes) e passa a aplicá-lo nesta sessão.
---
Carregue **agora** o corpo normativo da skill `schematize-observability`. A partir daqui, nesta
sessão, isto **não é opcional**.

1. **Leia na íntegra, sem trabalhar de memória.** Caminho:
   `.claude/skills/schematize-observability/references/*.md` (projeto) ou
   `~/.claude/skills/schematize-observability/references/*.md` (global):
   - `padrao-otel.md` — SDK + Collector, OTLP, Resource, semconv, propagação W3C, baggage sem dado sensível.
   - `logs.md` — JSON, correlação, redaction, auditoria != debug.
   - `metricas.md` — RED/USE, cardinalidade (labels proibidos), histogramas, exemplars.
   - `amostragem-profiling.md` — head vs tail (100% de erros), profiling contínuo.
   - `slo-alertas.md` — SLO, error budget, burn-rate multi-window, runbook, dashboards como código.
   - `healthchecks.md` — liveness != readiness != startup.
   - `stack-referencia.md` — stack self-hosted, retenção e custo.
   - `ambientes.md` — não-prd e o piso de efeito externo.
   - `front-llm.md` — fronteiras com web e ai.
   - `stack-versoes.md` — anexo volátil com data de verificação.
2. **Rode os gates no repo atual** antes de opinar:
   `bash .claude/skills/schematize-observability/scripts/check-otel-collector.sh .` e
   `node .claude/skills/schematize-observability/scripts/check-alertas.mjs .`
3. **Aplique daqui em diante** a todo serviço, config de Collector, regra de alerta ou dashboard que
   você escrever ou tocar, e diga qual piso está aplicando quando ele mudar o que você ia fazer.
