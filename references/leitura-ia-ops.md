# Como a IA lê telemetria: só por operação do ops (piso 24)

> Parte da skill **schematize-observability**. A IA é vetada de mexer na VPS direto (`ssh`, `docker logs`,
> `kubectl`, `curl` no Prometheus/Loki de prd, SQL). Ela lê telemetria **somente** por operação nomeada
> do `<projeto>_ops`, que mascara segredo/PII e deixa trilha de auditoria. Contrato machine-readable em
> `assets/sinal-operacao-ops.json` (validado por `scripts/alertas-fila.test.sh`).

## Sinal -> operação do ops

| Sinal | Pergunta que a IA faz | Operação do ops | Saída |
|---|---|---|---|
| Logs | o que o serviço disse, filtrado por `trace_id`, nível, janela | `ops logs <servico> --trace-id <id> --level error --since 30m --tail 200 --json` | JSON lines, redigido |
| Traces | caminho de um `trace_id` | `ops traces get <trace_id> --json` | JSON (spans) |
| Métricas | valor/tendência de uma métrica nomeada | `ops metrics <servico> --name <metrica> --range 1h --json` | JSON (séries) |
| Alertas | o que está disparando agora | `ops alerts --state firing --json` | JSON |
| Saúde | liveness/readiness/dependências | `ops health [<servico>] --json` | JSON |
| Filas | profundidade, item mais antigo, DLQ, lag de outbox | `ops queues [<servico>] --json` | JSON (métricas do piso 28) |
| Versão | SHA em execução por serviço | `ops versions --json` | JSON |

## Regras

1. **Leitura só por operação nomeada e versionada no git.** Não existe a operação? **cria no ops** (com
   teste) e só então a IA usa. Nunca PromQL/LogQL/SQL livre contra produção pelo agente.
2. **Saída machine-readable** (`--json`, JSON lines, exit code significativo) e **sem segredo/PII**
   (a redaction do Collector não substitui o mascaramento do ops).
3. **Reprocessar DLQ, silenciar alerta, reiniciar** são operações de **escrita**: nomeadas, idempotentes,
   com dry-run e aprovação humana (piso 24); não confunda com leitura.
4. dev/hml podem ter leitura direta local; prd nunca (piso 11 e `ambientes.md`).
