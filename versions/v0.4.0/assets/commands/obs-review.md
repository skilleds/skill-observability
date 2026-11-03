---
description: schematize-observability — revisa a observabilidade de um serviço (sinais, correlação, PII, cardinalidade, probes, SLO, alertas) rodando os gates e lendo o que a máquina não lê
argument-hint: "[serviço, diretório ou config]"
---

# /obs-review — se caiu e você foi olhar o dashboard, ele já tinha que estar lá

## 1. A máquina primeiro

```bash
bash .claude/skills/schematize-observability/scripts/check-otel-collector.sh <config-do-collector>
node .claude/skills/schematize-observability/scripts/check-alertas.mjs <regras-de-alerta>
bash .claude/skills/schematize-infra/scripts/check-observabilidade.sh .   # probes distintas, log sem PII, SLO escrito
```

`0` passa · `1` reprova · `2` **nada para verificar** — que não é aprovação.

## 2. Depois, o que a máquina não lê

- **Sinais:** emite traces, métricas e logs via OTLP para o Collector (não para o backend)? Há
  `deployment.environment.name`, `service.name`, `service.version`?
- **Correlação:** o log tem `trace_id`/`span_id` do span ativo? A propagação W3C cobre fila e job?
- **PII/segredo:** o que vai em atributo de span, log, baggage? Há request/response inteiro?
- **Cardinalidade:** algum label de métrica é id, e-mail, IP ou URL crua? Os buckets cercam o SLO?
- **Amostragem:** erros em 100%? RED vem de métrica, não de trace amostrado?
- **SLO:** existe `/docs/slo.md`? O alerta é burn-rate multi-window? Cada alerta tem runbook que alguém testou?
- **Alerta:** é sintoma de usuário? Algum disparou e foi ignorado (apague ou rebaixe)?
- **Probes:** liveness não checa dependência; readiness é distinta; startup onde a subida é lenta.
- **Auditoria:** fora do pipeline de debug, append-only?
- **Ambiente:** o Collector de hml aponta só para hml? Nada acorda ninguém em hml?
- **Custo:** retenção definida por tipo? volume/série por serviço visível?

## 3. Feche

Achado vira correção no mesmo PR ou item de checklist com dono. Rode os vermelhos dos gates quando
mexer neles: `bash scripts/check-otel-collector.test.sh` e `bash scripts/check-alertas.test.sh`.
