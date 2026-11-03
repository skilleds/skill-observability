# Piso de observabilidade (schematize-observability) — sempre-on

Sistema que você não enxerga, você não opera. Observabilidade nasce **com** o serviço.

1. **OpenTelemetry é o padrão:** SDK -> **OTLP** -> **Collector** -> backends. Nunca SDK de vendor
   no serviço, nunca exportar direto ao backend.
2. **Um serviço só está pronto** com logs estruturados, métricas, traces, probes e **dashboard +
   alertas + SLO versionados** junto do código.
3. **Log JSON em stdout, mensagem estática, `trace_id`/`span_id` em toda linha**, `deployment.environment.name` no Resource.
4. **Sem PII/segredo em telemetria:** mascare na origem **e** `redaction` no Collector (logs e traces).
   Baggage nunca leva dado sensível. Proibido logar request/response/headers/body inteiros.
5. **Cardinalidade é orçamento:** `user_id`, e-mail, IP, URL crua, request_id **nunca** viram label;
   rota = `http.route`. O detalhe vai para trace/log.
6. **Amostragem nunca perde erro:** 100% dos traces com erro e dos lentos (tail sampling no Collector);
   RED não deriva de trace amostrado. Histograma exponencial/nativo onde houver suporte.
7. **SLO por serviço** em `/docs/slo.md` + alerta **multi-window multi-burn-rate**; budget esgotado = freeze de feature.
8. **Alerta = sintoma de usuário**, com `severity`, `for` e `runbook_url` (runbook: schematize-docs).
   Sem ação possível, apague o alerta.
9. **Liveness != readiness != startup:** liveness não checa dependência; readiness distinta da liveness.
10. **Auditoria != log de debug:** append-only, fora de amostragem e da retenção de log.
11. **Dev/hml nunca exportam para backend ou SaaS de prd;** hml não acorda ninguém.
12. **Retenção e custo definidos por tipo de dado**; TLS entre Collector e backends.
13. <!-- herdado:engineering/orquestracao:curto -->**Orquestrador não desenvolve; subagent barato executa.** O agent principal só planeja, despacha e revisa; ação onerosa vira micro-tasks para o executor mais barato que resolve: `haiku` (mecânico) / `sonnet` (código; falhou → mesmo subagent corrige, até 2 rodadas) → Codex `gpt-5.6-terra` → Cursor → subagent `opus` (motivo) → `park`; **visual vai direto ao Codex**; **imagem nunca pelo Claude: detectar Codex/Gemini e perguntar ao usuário qual usar (Codex é a sugestão), nunca API de imagem paga**; papéis em `agentes.toml`. No overdev, cada item do checklist vai a um subagent e o principal revisa antes do `- [x]`. **Sem frota ociosa:** idle com pendência volta ao trabalho; dependente de outro agent → mata e enfileira com gatilho; terminou → mata (§9.6). Detalhe: `schematize-engineering` → `references/orquestracao.md` §9.<!-- /herdado -->

Gates: `bash .claude/skills/schematize-observability/scripts/check-otel-collector.sh <config>` ·
`node .claude/skills/schematize-observability/scripts/check-alertas.mjs <regras>` — waiver
rastreável `# obs-ok: <motivo>`.

<!-- herdado:engineering/pisos-22-29:bloco -->**Herda os pisos 22–29 da `schematize-engineering`** (texto completo em `assets/CLAUDE.md` dela): 22 tudo no git — sem remote, push falho ou HEAD≠origin a demanda NÃO se conclui; 23 deploy só do git (VETADO scp/rsync/tar|ssh/docker save|load/git bundle); 24 o ops é o gate da IA — a IA nunca muda a VPS direto nem escreve SQL, só operação nomeada (`ssh vps "ops <op>"`); 25 sem agents inúteis (entregou, morreu); 26 relatório a cada 30 min e handoff a cada 6 h; 27 CI remoto só antes do hml, a pedido ou em tag (`workflow_dispatch` + `hml-*`/`v*`; VETADO `pull_request`, `push` em branch, `workflow_run`, cron sem justificativa); 28 microserviço autônomo (fila durável + 7 testes de resiliência); 29 build/teste na máquina dev/hml quando existe (ponte só no workspace de build, nunca prd) + higiene (`scripts/higiene.sh`).<!-- /herdado -->
