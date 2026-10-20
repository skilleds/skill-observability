---
name: schematize-observability
metadata:
  version: 0.3.0
description: >-
  Observabilidade OpenTelemetry: traces, métricas, logs correlacionados, SLO com burn-rate, alerta com runbook, Collector. Use ao instrumentar ou definir SLO/alerta. Gates. Produto: analytics.
---
<!-- cross-skill: efeitos-externos.md, observabilidade.md -> schematize-engineering -->

# Observabilidade da casa (schematize-observability)

Sistema que você não enxerga, você não opera — você reza. Esta skill é a **DONA** do tema
observabilidade: o **padrão** (OpenTelemetry), os **três sinais + profiling**, a **correlação**, o
**SLO com error budget**, o **alerta que dói no usuário e aponta runbook**, o **dashboard como
código**, os **healthchecks** e a **stack self-hosted de referência**. As demais skills (base, infra,
web, linguagens) mantêm só o que é **específico do contexto** e apontam para cá.

**Versão:** skill `schematize-observability` v0.3.0. Changelog em `CHANGELOG.md`.

## Precedência e herança (leia antes de divergir)

<!-- herdado:engineering/precedencia:dominio intro="Esta skill é **transversal** (não é linguagem): detalha a observabilidade que a base exige (`schematize-engineering` → `references/observabilidade.md`, a numeração da base é o §16 em diante). **Onde divergir da base em piso, a base manda**; aqui mora o *como*, o padrão e os gates." cmd="obs" -->Esta skill é **transversal** (não é linguagem): detalha a observabilidade que a base exige (`schematize-engineering` → `references/observabilidade.md`, a numeração da base é o §16 em diante). **Onde divergir da base em piso, a base manda**; aqui mora o *como*, o padrão e os gates.

1. **Onde esta skill divergir da base, a BASE MANDA.** Aqui mora a especialização do domínio ou da
   ferramenta — o como, o padrão, o gate. Divergência de *piso* é defeito desta skill, não variante local.
2. **O que não está repetido aqui é HERDADO, não dispensado.** Esta skill herda os pisos da base e
   os comandos dela cobrem o **domínio**, não o piso geral. Valem integralmente, sem cópia local:
   - **§28 Archive** — `<projeto>/<projeto>_archive/` é **repositório git próprio, PRIVADO e
     obrigatório**, criticidade 0 (`schematize-archive`).
   - **§35 Definition of Done** e a lista de anti-padrões (citada por **título**, nunca por número).
   - **§39 Índice/MAPA** — enumeração exaustiva (uma entrada por unidade chamável, `M == N`) e grafo
     com arestas em ASCII (`A -> B`), nunca a seta unicode.
   - **IAM** (`schematize-engineering` → `references/iam.md`): identidade ≠ email, ≥2 fatores, ReBAC
     multi-tenant, argon2id-only para senha nova, sessão longa e logout irreversível.
   - **Efeito externo** nunca sai de não-produção (`schematize-engineering` →
     `references/efeitos-externos.md`).
   - **Orquestração** (`schematize-engineering` → `references/orquestracao.md` §9): o principal não
     desenvolve (é Claude Opus); executor mais barato que resolve — `haiku`/`sonnet` → Codex Terra → Cursor → `opus` só após falha; visual direto ao Codex; imagem nunca pelo Claude: detecta Codex/Gemini e pergunta ao usuário qual usar (Codex é a sugestão, não automática), nunca API paga.
3. **QA, ops, IAM e índice não têm comando próprio aqui:** vêm da base `/eng-*`. Para trabalho
   contínuo use `/eng-overdev`; para planejar `/eng-plan`; para varrer a base `/eng-scan`; para
   revisão geral `/eng-review` (e `/eng-ops`, `/eng-iam`, `/eng-index`). Os comandos
   `/obs-*` cobrem o domínio desta skill; o piso geral é o da base.<!-- /herdado -->

## Por que ela nasceu

A observabilidade vivia em quatro lugares com versões diferentes: a base (stack em 6 linhas), a infra
(SLO e alertas), o front e sete skills de linguagem (cópias ou recortes). Nenhum lugar cobria o
padrão OpenTelemetry de ponta a ponta, **amostragem**, **cardinalidade**, **burn-rate**, **redaction no
Collector** nem o **piso de ambiente** (telemetria de hml indo para SaaS de prd). Tema espalhado
vira tema sem dono — e sem dono, ninguém lê o alerta que disparou às 3h.

## Comandos (Claude Code)

| Comando | O que faz |
|---|---|
| `/obs-help` | lista os comandos |
| `/obs-load` | carrega à força o corpo normativo e passa a aplicá-lo |
| `/obs-review` | revisa a observabilidade de um serviço (sinais, correlação, PII, cardinalidade, probes, SLO) e roda os gates |
| `/obs-instrument` | instrumenta um serviço no padrão (SDK -> Collector, semconv, log JSON, healthchecks), na linguagem do rol |
| `/obs-slo` | define SLI/SLO/error budget em `/docs/slo.md` e gera as regras de burn-rate |
| `/obs-alerts` | audita/escreve alertas (sintoma de usuário, severity, for, runbook) e roda `check-alertas.mjs` |
| `/obs-dashboard` | dashboard como código (SLO + RED + USE + links) |
| `/obs-claude` | cria/mescla o `CLAUDE.md` sempre-on de observabilidade |
| `/obs-cc` · `/obs-handoff` | context compact / handoff arquivado |

## Como usar

1. **Rode os gates antes de discutir estilo:**
   `bash scripts/check-otel-collector.sh <config.yaml|dir>` e `node scripts/check-alertas.mjs <regras.yaml|dir>`
   (e `bash scripts/check-honeypot.sh [--routes inventario.txt] honeypots.yml` se houver honeypot)
   — `0` passa · `1` reprova · `2` **nada para verificar** (que não é aprovação).
2. **Leia o padrão** (`references/padrao-otel.md`), depois o sinal em questão.
3. **Copie o ponto de partida** de `assets/` (Collector, regras de SLO, convenção de log, exemplo da sua linguagem).
4. **Veja o que é volátil** em `references/stack-versoes.md` antes de pinar versão.

| Tarefa | Reference |
|---|---|
| OTel como padrão: SDK + Collector, OTLP, Resource, semconv, propagação W3C, baggage | `references/padrao-otel.md` |
| Log JSON, correlação por `trace_id`, níveis, redaction, auditoria != debug | `references/logs.md` |
| RED/USE, cardinalidade (labels proibidos), histogramas exponenciais/nativos, exemplars | `references/metricas.md` |
| Head vs tail sampling (100% de erros), profiling contínuo | `references/amostragem-profiling.md` |
| SLI/SLO, error budget, burn-rate multi-window, anatomia do alerta, dashboards como código | `references/slo-alertas.md` |
| Liveness != readiness != startup | `references/healthchecks.md` |
| Stack self-hosted, justificativa, segurança, retenção e custo | `references/stack-referencia.md` |
| Não-prd: separação por ambiente, piso de efeito externo, teste de observabilidade | `references/ambientes.md` |
| Honeypot defensivo: iscas, FAKE 201, score, contenção com TTL, LGPD, teste (gate `check-honeypot.sh`) | `references/honeypot.md` |
| Fronteiras com front (RUM) e LLM | `references/front-llm.md` |
| Versões, estabilidade dos sinais, fontes (anexo volátil) | `references/stack-versoes.md` |

Assets prontos para copiar: `assets/otel-collector.yaml` · `assets/alertas-slo.rules.yaml` ·
`assets/log-json.md` · `assets/exemplos/{go,rust,elixir,csharp,zig,ruby}.md` · `assets/CLAUDE.md`.

## Pisos inegociáveis (vetam o atalho)

1. **OpenTelemetry é o padrão; SDK fala OTLP com um Collector, nunca com o backend.** SDK de vendor
   no código do serviço é vetado.
2. **Observabilidade nasce com o serviço**, não "depois": um serviço só está pronto se emite logs
   estruturados, métricas e traces, expõe probes e sobe com dashboard + alertas + SLO versionados.
3. **Correlação por `trace_id`/`span_id` em todo log** (JSON em stdout, mensagem estática, dado em
   atributo). `deployment.environment.name` em todo Resource.
4. **Sem PII nem segredo em telemetria:** mascarar na origem **e** `redaction` no Collector em toda
   pipeline de logs e traces. Baggage nunca carrega dado sensível.
5. **Cardinalidade é orçamento:** `user_id`, e-mail, IP, URL crua e ids de requisição **nunca** são
   label de métrica; rota é `http.route`. Isso vai para trace/log.
6. **Amostragem nunca perde erro:** 100% dos traces com erro (e dos lentos) — tail sampling no
   Collector. Métrica RED não deriva de trace amostrado.
7. **Todo serviço tem SLO** (`/docs/slo.md`) e alerta por **burn-rate multi-window**; error budget
   esgotado trava feature.
8. **Alerta é sintoma de usuário, não causa**, tem `severity`, `for` e **`runbook_url`** (runbook:
   `schematize-docs`). Alerta que ninguém age é apagado.
9. **Liveness != readiness != startup.** Liveness não checa dependência; readiness que é apelido do
   liveness é healthcheck vacuamente verdadeiro.
10. **Auditoria não é log de debug:** append-only, imune a amostragem e retenção de log.
11. **Ambiente separado:** telemetria de dev/hml jamais vai para backend ou SaaS de prd; hml não acorda ninguém.
12. **Retenção e custo definidos por tipo**, cobrados por serviço; stack com TLS entre componentes.
13. <!-- herdado:engineering/orquestracao:bullet -->**Orquestrador não desenvolve; subagent barato executa** (`schematize-engineering` → `references/orquestracao.md` §9). O principal só planeja/decompõe/despacha/supervisiona/revisa; ação onerosa vira micro-tasks; principal = Claude Opus; executor mais barato que resolve: `haiku` (mecânico) / `sonnet` (código, até 2 rodadas de correção pelo mesmo subagent) → Codex `gpt-5.6-terra` → Cursor → subagent `opus` (motivo no checkpoint) → `park`; **visual direto ao Codex; imagem nunca pelo Claude (pergunta ao usuário: Codex sugerido, ou Gemini), API de imagem paga PROIBIDA**; papéis configuráveis em `agentes.toml` (aba "Agentes" do overdev). No `overdev`, cada item do checklist é executado pelo papel adequado e revisado pelo principal (diff + gate) antes do `- [x]`. **Sem frota ociosa:** agent idle com pendência executável volta ao trabalho; pendência que depende de outro agent → mata e enfileira com gatilho de dependência; terminou → mata (§9.6).<!-- /herdado -->

## Fronteiras com outras skills

- **`schematize-engineering`** — a base: DoD, FinOps, performance (`references/observabilidade.md`
  mantém só os ganchos §16/§17/§30/§33 apontando para cá), efeito externo
  (`references/efeitos-externos.md`) e auditoria normativa (§16.6).
- **`schematize-infra`** — a stack **sobe** na IaC dela (isolamento, TLS, backup, chart);
  `references/observabilidade.md` dela guarda o que é de infra e a **métrica/alerta de reputação de
  envio** (§9). O gate `check-observabilidade.sh` (existência de probes) continua lá.
- **`schematize-web`** — RUM, Web Vitals, erro de cliente e **consentimento** (§49);
  `schematize-observability -> references/front-llm.md` dá o que o front herda.
- **`schematize-ai`** — span por chamada de LLM, tokens, custo e qualidade
  (`references/observabilidade-llm.md`); a base OTel é daqui.
- **`schematize-incident`** — o que acontece **depois** que o alerta SEV1/SEV2 dispara: declarar,
  papéis, mitigar, comunicar, postmortem. Aqui nasce o sinal; lá, a resposta.
- **`schematize-analytics`** — telemetria de **operação** não é analytics de **produto**: funil,
  evento de negócio e experimento são de lá (consentimento/LGPD próprios); aqui, RED/USE/SLO.
- **`schematize-docs`** — runbook, ADR, `/docs/slo.md` (`references/runbooks.md`).
- **`schematize-qa`** — o teste que prova que o sinal é emitido; **`schematize-pentest`** — telemetria
  que vaza PII/segredo é achado dela.
- **Linguagens (`go`, `rust`, `elixir`, `csharp`, `zig`, `ruby`, `node`)** — mantêm só o recorte da
  linguagem (qual lib, qual handler de log); o padrão é daqui. Exemplos mínimos em `assets/exemplos/`.
- **Regra de mídia:** esta skill não gera imagem; dashboard é JSON/código, não print.
