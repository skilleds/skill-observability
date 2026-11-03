# ADR-modelo: OpenTelemetry Collector (contrib) vs Grafana Alloy

> Parte da skill **schematize-observability**. Modelo para copiar para `<projeto>_archive/adr/`. A skill
> recomenda o Collector contrib (`stack-referencia.md` §1); a base da casa também cita Alloy. Esta ADR
> registra a decisão em vez de deixar duas stacks sem escolha. Versões: `stack-versoes.md`.

## ADR-NNNN: coletor de telemetria do projeto <nome>

- **Status:** proposed | accepted | superseded
- **Data / decisor:** AAAA-MM-DD / <nome>
- **Contexto:** serviços emitem OTLP; é preciso um ponto único de redaction, amostragem de cauda e
  roteamento por ambiente (piso 1, 4, 6). Backends: <Mimir|VictoriaMetrics>, Loki, Tempo, <Pyroscope>.

### Opções

| Critério | Collector contrib | Grafana Alloy |
|---|---|---|
| Padrão aberto, neutro de vendor | sim (CNCF OpenTelemetry) | distribuição da Grafana que embute componentes do Collector |
| Redaction + tail sampling | processors `redaction`, `tail_sampling` | via componentes `otelcol.*` equivalentes |
| Scrape Prometheus, profiling (Pyroscope), Loki nativo | receiver `prometheus`; profiling à parte | integrado (`prometheus.*`, `loki.*`, `pyroscope.*`) |
| Config | YAML do Collector (o gate `check-otel-collector.sh` valida) | linguagem própria (River/Alloy config); **o gate da casa não cobre** |
| Lock-in | baixo | médio (config não portável) |
| Operação | um binário, ecossistema largo | um binário, integração forte com stack Grafana |

### Decisão (preencher)
- Escolha: <Collector contrib | Alloy>. Padrão da casa: **Collector contrib**, porque o gate cobre a config e ela é portável.
- Alloy só se: a stack já é 100% Grafana e o time quer scrape/profiling no mesmo agente. Então **portar as 6 regras
  do gate à mão** (TLS, redaction em logs/traces, tail sampling com 100% de erro, sem backend de prd em dev/hml, `memory_limiter`, fila de saída persistente) e registrar o que o gate não verifica.
- Nunca os dois no mesmo caminho de dados do mesmo ambiente.

### Consequências
- Positivas/negativas: <preencher>.
- Revisão: a cada trimestre junto com `stack-versoes.md` ou quando o gate deixar de cobrir.
