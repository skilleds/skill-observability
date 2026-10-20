# Stack de referência self-hosted da casa

> Parte da skill **schematize-observability**. Números de versão e licenças: `stack-versoes.md`.
> Item marcado **[volátil]** muda com o mercado: reavalie a cada trimestre.

## 1. A stack e a justificativa

| Camada | Escolha da casa | Por quê | Alternativa aceita (com ADR) |
|---|---|---|---|
| Instrumentação | **OpenTelemetry SDK** por linguagem | padrão aberto, neutro de vendor, mesma API em todo o rol | — (SDK de vendor: vetado) |
| Coleta/política | **OpenTelemetry Collector (contrib)** | redaction, amostragem de cauda e roteamento num lugar só; config é o contrato | **Grafana Alloy** (distribuição que embute componentes do Collector); a base cita Alloy — equivalente |
| Métricas | **Prometheus** (curto prazo/scrape) + **Mimir** (longo prazo, HA, multi-tenant) | PromQL, ecossistema de alertas; Mimir escala e isola tenants | **VictoriaMetrics** (single-node ou cluster) quando a escala é pequena/média: um binário, menos peças, PromQL-compatível **[volátil]** |
| Logs | **Loki** | indexa só labels (barato), consulta LogQL, recebe OTLP | VictoriaLogs; **ClickHouse**-based (SigNoz, OpenObserve) **[volátil]** |
| Traces | **Tempo** | armazenamento em objeto, barato, TraceQL, liga a métrica/log | Jaeger (v2 é Collector) **[volátil]** |
| Profiles | **Pyroscope** | profiling contínuo integrado ao Grafana | Parca |
| Visualização/alerta | **Grafana** (+ Alertmanager ou alerta do Grafana) | um painel para os 4 sinais, exemplar -> trace -> log -> perfil | — |
| Entrega | chart/IaC **versionado por serviço**, com dashboard e regras | um serviço só está pronto se sobe com o seu (`engineering` §16) | — |

**Por que self-hosted:** dado de telemetria carrega o que a casa mais protege (identificadores,
payloads quando algo escapa à redaction), custo previsível, sem lock-in de preço por GB/série, e o
mesmo conjunto roda em dev, hml e prd. SaaS é aceitável **por ADR** (e nunca atravessando ambiente
— `ambientes.md`).

**Escala:** comece pelo menor que atende. Um host: Collector + (Prometheus ou VictoriaMetrics) +
Loki + Tempo + Grafana em modo monolítico. Mimir/Loki/Tempo em modo distribuído só quando o volume,
a HA ou o multi-tenant exigirem — operar o distribuído tem custo de pessoa.

## 2. Topologia mínima

```
apps --OTLP--> Collector --> Mimir/VM (métricas)   --> Grafana
                         --> Loki (logs)           -->   (4 sinais + alertas)
                         --> Tempo (traces)        --> Alertmanager --> on-call
                         --> Pyroscope (perfis)
```

Collector por ambiente; backends por ambiente ou **tenant** por ambiente (`X-Scope-OrgID`), nunca
um tenant compartilhado entre hml e prd. Os backends são **serviços com isolamento próprio**
(`schematize-infra`): rede interna, TLS, autenticação entre componentes, backup do que importa
(dashboards e regras estão no git; a telemetria em si é efêmera).

## 3. Segurança da própria stack

TLS entre Collector e backends (o gate reprova OTLP sem TLS fora de localhost); autenticação do
Grafana via IdP da casa (SSO), papéis por equipe/tenant — o Grafana lê tudo; segredo de datasource fora do
repo; porta OTLP não exposta à internet; acesso a log/trace é acesso a dado de produção (auditado).

## 4. Retenção e custo

Retenção por **tipo**, definida por serviço e registrada no `/docs/slo.md` ou no chart:

| Dado | Retenção típica de partida | Observação |
|---|---|---|
| Métricas brutas | 15-30 dias no Prometheus; 13 meses no Mimir/VM (com downsampling/agregação) | 13 meses cobre comparação ano a ano |
| Logs | 14-30 dias (INFO), 90 dias ERROR se necessário | o sinal mais caro por volume |
| Traces | 7-14 dias | já amostrados (`amostragem-profiling.md`) |
| Perfis | 7-14 dias | |
| **Auditoria** | **pela regulação (anos)** | **fora** deste pipeline (`logs.md` §4) |

Os valores são ponto de partida, não norma: o piso é **definir, registrar e aplicar**. Alavancas de
custo, em ordem de retorno: **cardinalidade** (`metricas.md` §3) > **amostragem** > **nível/volume de
log** > retenção > downsampling. Meça custo por serviço/tenant (série ativa, GB de log, spans/s) e
mostre no dashboard — o desvio aparece antes da fatura (FinOps: `schematize-engineering ->
references/observabilidade.md` §33).

## 5. Quando o SaaS entra

Só por ADR: motivo (equipe sem capacidade de operar a stack, necessidade pontual), **um provedor por
ambiente-classe**, chave/endpoint **separados** por ambiente, redaction no Collector **antes** de
exportar (dado sai da sua rede), contrato de dados/DPA/região, plano de saída (OTLP facilita: troca-se o
exporter). Front/RUM de terceiro idem (`front-llm.md`).
