---
description: schematize-observability — define SLI/SLO/error budget do serviço em /docs/slo.md e gera as regras de burn-rate multi-window
argument-hint: "[serviço]"
---

# /obs-slo — o SLO é a definição de "funcionando"

1. **Escolha o SLI pela jornada do usuário** (disponibilidade, latência, frescor), não por componente.
   Defina evento bom e elegível.
2. **Fixe a meta e a janela** (ex.: 99,9% em 30 dias) e o **budget** (`1 - SLO`). A meta é menor que 100% de propósito
   e não pode exceder a das dependências críticas.
3. **Escreva `/docs/slo.md`:** SLI, janela, meta, dono, **política de budget** (saudável: ship; queimando
   rápido: para a feature; esgotado: freeze até recuperar).
4. **Gere as regras** a partir de `assets/alertas-slo.rules.yaml`: recording rules do SLI por serviço
   (sem label de alta cardinalidade) e alertas 14,4x (1h+5m) e 6x (6h+30m) como `page`, 3x (1d+2h) e 1x
   (3d+6h) como `ticket`; ajuste o multiplicador ao budget da meta escolhida.
5. **Cada alerta com `runbook_url`** — o runbook se escreve com `schematize-docs -> references/runbooks.md`.
6. **Prove:** `node scripts/check-alertas.mjs <regras>`; `promtool check rules`/`test rules` quando existir.
   Os buckets do histograma precisam cercar o limiar de latência do SLO.
