# OpenTelemetry como padrão — SDK, Collector, OTLP e semantic conventions

> Parte da skill **schematize-observability**. Versões e estabilidade por sinal mudam: ficam em
> `stack-versoes.md` (anexo volátil, com data). Aqui mora a regra que não muda.

## 1. A tese

**Instrumente uma vez, em OpenTelemetry; escolha o backend depois.** O SDK da aplicação fala **OTLP**
com um **Collector**; o Collector decide para onde cada sinal vai. Trocar Tempo por outro backend,
ou Mimir por VictoriaMetrics, vira mudança de **config do Collector** — não de código de serviço.
Vendor SDK proprietário dentro da aplicação é acoplamento que a casa não aceita.

## 2. Arquitetura

```
app (SDK OTel) --OTLP--> Collector (por ambiente) --> Tempo / Mimir|VictoriaMetrics / Loki / Pyroscope
                              |-- memory_limiter, redaction, amostragem, batch
```

1. **SDK na aplicação:** só instrumenta e exporta OTLP (gRPC `:4317` ou HTTP `:4318`) para o
   Collector **local** (sidecar, DaemonSet ou o Collector do host). Nunca direto ao backend.
2. **Collector** é o ponto único de política: `memory_limiter` primeiro, `redaction`, amostragem,
   `batch` por último (`assets/otel-collector.yaml`). Gate: `scripts/check-otel-collector.sh`.
3. **Agente vs gateway:** Collector perto da aplicação (coleta, enriquecimento de Resource) e, se o
   volume pedir, gateway central (amostragem por cauda, roteamento por tenant). Comece com um só.
4. **Collector indisponível não derruba a aplicação:** exportação é assíncrona, com fila limitada e
   descarte; telemetria é importante, mas **nunca** caminho crítico de request.

## 3. Os sinais e o que a casa faz com cada um

| Sinal | Para quê | Regra da casa |
|---|---|---|
| **Traces** | caminho de uma requisição entre serviços | toda chamada externa, fila, banco e fluxo crítico vira span |
| **Métricas** | tendência, SLO, alerta | RED/USE, baixa cardinalidade (`metricas.md`) |
| **Logs** | o que aconteceu, em detalhe | JSON, correlacionado por `trace_id` (`logs.md`) |
| **Profiles** | onde o CPU/memória vão | profiling contínuo, `amostragem-profiling.md` |

Os três primeiros são o piso; profiling é SHOULD até haver um problema de custo/latência que só ele
explica. Estabilidade de cada sinal **por linguagem** muda e está no anexo volátil.

## 4. Resource: quem emitiu

Todo sinal carrega o mesmo Resource, definido uma vez no bootstrap (ou por `OTEL_RESOURCE_ATTRIBUTES`):

- `service.name` (estável, baixa cardinalidade, igual ao nome do deploy), `service.version`,
  `service.instance.id`;
- `deployment.environment.name` (`dev`/`hml`/`prd`) — **obrigatório**, é o que separa ambientes
  (`ambientes.md`);
- `service.namespace` quando houver mais de um produto.

## 5. Semantic conventions: use o nome do padrão

- Atributo e métrica com **nome da semconv**, não inventado: `http.request.method`,
  `http.response.status_code`, `http.route`, `http.server.request.duration` (histograma em segundos),
  `db.system.name`, `error.type`, `exception.*`, `messaging.*`, `gen_ai.*` (LLM — em evolução).
- A parte HTTP é **estável**; outras áreas ainda estão em Development — a versão da semconv que o
  projeto adota fica registrada (ADR curto ou `stack-versoes.md` do projeto) para a troca de versão ser
  deliberada (renomeações como `deployment.environment` -> `deployment.environment.name` já mordem).
- Atributo próprio do domínio vai em namespace da casa (`app.pedido.canal`), **nunca** reusando prefixo da semconv.
- Auto-instrumentação (HTTP server/client, banco, fila) primeiro; span manual só para regra de negócio.

## 6. Propagação: W3C Trace Context e Baggage

- **W3C Trace Context** (`traceparent`, `tracestate`) é o padrão em todo salto: HTTP, fila (header/
  atributo da mensagem), job assíncrono. `traceparent` = `00-<trace-id 32 hex>-<span-id 16 hex>-<flags>`.
- Propagador configurado explicitamente (`tracecontext,baggage`) — não confie no default da lib.
- **Fronteira de confiança:** o que entra de fora (cliente, parceiro) é **não confiável**: o
  `traceparent` externo pode ser aceito como pai, mas a decisão de amostragem e o `tracestate` de
  terceiros não mandam em você. Em API pública, abra um **trace novo** e ligue o externo por *link*.
- **Baggage vai em header HTTP, para todo serviço a jusante, inclusive de terceiro.** Portanto:
  **nunca** dado sensível (PII, token, e-mail, ID de usuário cru) em baggage; só chave pequena e
  não sensível (`tenant_id` se o tenant não for segredo, `feature_flag`). Limite o tamanho.
  Baggage **não** vira atributo automaticamente: copie explicitamente os poucos itens úteis.
- Mensageria: injete o contexto no envio e extraia no consumo; o span do consumidor é filho (ou
  *link*, em batch). Sem isso, o trace quebra no broker.

## 7. Anti-padrões

- SDK de vendor no código do serviço; exportar direto da aplicação para SaaS.
- Span por linha de código; span sem fim (vaza memória); atributo com payload inteiro.
- `service.name` com versão ou hostname dentro; `environment` só como label de dashboard, sem Resource.
- Telemetria no caminho crítico (exportação síncrona que trava request quando o Collector cai).
- Metade dos serviços sem propagação: o trace aparece cortado e ninguém confia nele.
