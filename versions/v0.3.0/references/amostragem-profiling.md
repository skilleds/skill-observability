# Amostragem de traces e profiling contínuo

> Parte da skill **schematize-observability**. Estado de maturidade do sinal de profiles: `stack-versoes.md`.

## 1. Por que amostrar

Trace de 100% das requisições é caro (armazenamento e rede) e quase tudo é "uma requisição normal
e rápida" que ninguém vai abrir. Amostrar é decisão de **custo**, e o critério é: **manter o que
explica incidente** — erro, lentidão, caminho raro.

## 2. Head vs tail

| | **Head** (no SDK) | **Tail** (no Collector) |
|---|---|---|
| Decide | no início do trace, sem saber o resultado | depois de ver o trace completo |
| Custo | quase zero | memória (espera `decision_wait`) e roteamento por trace |
| Sabe se deu erro/lento | **não** | **sim** |
| Típico | `parentbased_traceidratio` | `tail_sampling` com políticas |

**Regra:** o piso é **100% de traces com erro e 100% dos lentos** (acima do limiar do SLO); o
resto por probabilidade. Isso só é possível com **tail sampling**. Head sampling sozinho descarta
erro às cegas — aceitável só em serviço de baixíssimo risco e volume, ou como pré-filtro grosso
(ex.: 100% no SDK e deixar o Collector decidir).

Configuração de referência: `assets/otel-collector.yaml` (políticas `erros-sempre`, `lentas`,
`amostra-do-resto`). Pontos que quebram em silêncio:

- **Todos os spans de um trace têm de chegar ao MESMO Collector** que decide. Com mais de uma
  réplica, coloque na frente um balanceador por `trace_id` (exporter `loadbalancing`) — sem isso
  cada réplica vê pedaços e decide errado.
- `decision_wait` menor que a duração real dos traces corta trace no meio; dimensione `num_traces`
  e a memória (e o `memory_limiter` protege o Collector).
- **Consistência head->tail:** se o SDK amostra a 10% e o tail decide "manter erros", você só
  recebe 10% dos erros. Com tail no Collector, o SDK exporta **100%** (`always_on`) e o Collector reduz.
- Métricas RED **não** derivam de trace amostrado (`metricas.md` §6).
- `tracestate`/flag `sampled` de origem externa não manda na sua política (`padrao-otel.md` §6).

## 3. Amostragem de logs

Log de erro e de auditoria: 100%. Log de INFO de alto volume: reduza na **origem** (taxa por chave)
ou no Collector, mas nunca por probabilidade cega sobre erro. Auditoria **nunca** é amostrada
(`logs.md` §4).

## 4. Profiling contínuo

- Perfil de CPU/memória/alocação **sempre ligado em produção** com sobrecarga baixa (amostragem
  de ~100 Hz), consultável por serviço/versão/janela de tempo. Responde "por que ficou lento
  depois do deploy" e "onde vai o dinheiro de CPU" — coisas que métrica e trace não respondem.
- **Pyroscope** (Grafana) como backend de referência; coleta por **SDK da linguagem**, por
  **eBPF** (profiler do OTel/Beyla/Alloy, sem tocar no código, Linux) ou pelo `pprof` nativo (Go) /
  equivalentes. O sinal **profiles do OTel** ainda não é estável: prefira o caminho Pyroscope/pprof
  hoje e deixe o OTLP profiles para quando estabilizar (`stack-versoes.md`).
- Vincule perfil a trace por *span profile* (rótulo `span_id`) quando a ferramenta suportar.
- Perfil não carrega dado de usuário, mas os **labels** podem: mesmas regras de cardinalidade e PII.
- Profiling pontual de investigação (pprof sob demanda, `perf`, flame graph) continua válido; o
  contínuo é para ter o **antes** quando o problema aparece.
