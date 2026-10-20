# Métricas — RED/USE, cardinalidade e histogramas

> Parte da skill **schematize-observability**. Versões de Prometheus e do suporte a histogramas
> nativos: `stack-versoes.md`.

## 1. O que medir

- **RED por endpoint/handler/consumidor** (serviços que atendem requisição): **R**ate, **E**rrors,
  **D**uration. Base: `http.server.request.duration` (histograma, segundos) com
  `http.request.method`, `http.route`, `http.response.status_code` — de onde saem taxa (contagem),
  erro (status 5xx / `error.type`) e latência (quantis) sem métrica extra.
- **USE por recurso** (CPU, memória, disco, rede, pool de conexões, fila): **U**tilization,
  **S**aturation, **E**rrors. Saturação (fila crescendo, pool esgotado, throttling) é o que avisa
  antes do erro.
- **Fila/worker:** profundidade, idade da mensagem mais antiga (a métrica que importa), taxa de
  processamento, reprocessos/DLQ.
- **Negócio** (SHOULD): pedidos/min, conversão — dashboard separado do técnico, instrumentado desde o dia 1.
- **Efeito externo:** contador de envio por provedor/ambiente/status (`mail_sent_total` etc.),
  inclusive o sinkado — ver `schematize-infra -> references/observabilidade.md` §9 (alertas de
  reputação) e `ambientes.md`.

## 2. Nomes, unidades, tipos

- Semconv quando existe; senão `dominio_objeto_unidade_total` (counter), `_seconds`/`_bytes`
  (unidade no nome ao exportar para Prometheus). **Segundos**, não milissegundos.
- **Counter** só cresce (`rate()` sobre ele); **Gauge** sobe e desce (estado atual); **Histogram**
  para distribuição. Média de latência esconde a cauda: use histograma e olhe p95/p99.
- Nunca calcule quantil **no cliente** para depois "tirar a média dos p99" — quantis não se agregam.
  Histograma agrega; o quantil sai na consulta (`histogram_quantile`).

## 3. Cardinalidade — o custo que ninguém vê

Cada combinação de valores de label é **uma série temporal**. Série custa memória/disco/CPU no
backend e a conta chega no final do mês (ou derruba o Prometheus). Regra: **valor de label vem de
conjunto pequeno, conhecido e limitado**.

**Labels PROIBIDOS** (ilimitados ou identificadores de pessoa): `user_id`, `email`, `client_ip`,
`session_id`, `request_id`, `trace_id`, `order_id`, **URL crua** (`url.full`, `path` com id/query).
Para rota use **`http.route`** (template `/pedidos/{id}`), nunca o caminho real. Erro: `error.type`
de enum limitado, nunca a mensagem. Esses dados, se úteis, vão para **trace** ou **log**, que
suportam alta cardinalidade; a ponte métrica -> trace é o **exemplar**.

Orçamento: defina um teto de séries ativas por métrica (ex.: poucas milhares) e **alerte** quando
uma métrica o exceder (`count by (__name__)` no backend / limites por tenant no Mimir). O gate
`scripts/check-alertas.mjs` reprova alerta que agrega ou filtra por label de alta cardinalidade.
Estouro de cardinalidade é incidente, não otimização: o backend rejeita ou degrada para todos.

## 4. Histogramas

- **Explícito (classic):** buckets fixos. Escolha buckets que **cercam o SLO** (se o SLO é 300 ms,
  precisa de bucket em 0.25 e 0.5 — senão o SLO não é medível). A semconv HTTP recomenda
  `0.005, 0.01, 0.025, 0.05, 0.075, 0.1, 0.25, 0.5, 0.75, 1, 2.5, 5, 7.5, 10` s. Cada bucket é uma
  série: histograma com 15 buckets x labels multiplica.
- **Exponencial (OTel) / nativo (Prometheus):** resolução automática, bucket por escala, **uma série
  por histograma** em vez de N, muito menor custo e erro de quantil controlado. É o **default de
  novos serviços** quando backend e SDK suportam (OTel exponential histogram -> Prometheus native
  histogram); no meio do caminho exige Collector/Prometheus/Mimir em versões que o aceitem
  (`stack-versoes.md`). Onde não suporta, volte ao explícito com buckets em torno do SLO.
- Temporalidade: Prometheus é **cumulativo**; SDK em delta precisa de conversão no Collector.

## 5. Exemplars

Anexe `trace_id` de uma amostra à observação do histograma (exemplar): no Grafana o ponto do gráfico
vira link para o trace. É a forma correta de ligar métrica e trace sem pôr `trace_id` em label.

## 6. Spanmetrics e amostragem

Métrica RED derivada de span (`spanmetrics` connector) tem de ser calculada **antes** da amostragem
de cauda — senão a taxa e a latência saem enviesadas. Preferível: o SDK mede a métrica direto
(contador/histograma) e a amostragem só atinge traces.

## 7. Anti-padrões

Label com id de usuário; `path` cru; métrica por tenant quando há milhares de tenants (use
agregado + tenant só em quem pagou por isso); histograma com buckets que não cercam o SLO; média no
lugar de quantil; métrica criada em loop com nome dinâmico; counter que reinicia sem `rate()`
tratar; gauge de "último valor" usado como contador.

Métricas de bot de chat (latência de ack, 429, shard caído): o que medir em `schematize-bots → references/prazo-fila-rate-limit.md`.
