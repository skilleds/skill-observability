# Healthchecks — liveness, readiness e startup

> Parte da skill **schematize-observability**. Gate de existência dos endpoints:
> `schematize-infra -> scripts/check-observabilidade.sh` (`/infra-check`).

## 1. Três perguntas diferentes

| Probe | Pergunta | Se falhar | Endpoint da casa |
|---|---|---|---|
| **Liveness** | o processo está vivo e não travado? | o orquestrador **reinicia** | `/health` (alias aceito: `/livez`, `/healthz`) |
| **Readiness** | está pronto para receber tráfego agora? | sai do balanceador, **sem ser morto** | `/ready` (alias: `/readyz`) |
| **Startup** | já terminou de subir? | segura liveness/readiness até passar | `/startup` (alias: `/startupz`), só se a subida for lenta |

`/metrics` (Prometheus) completa o contrato de base. Os nomes `/health` e `/ready` são os da base
(`schematize-engineering -> references/observabilidade.md` §17); o resto são aliases tolerados.

## 2. O erro que derruba cascata: confundir liveness com readiness

- **Liveness NÃO checa dependência.** Se o banco pisca e a liveness falha, o orquestrador reinicia
  todo o fleet ao mesmo tempo — o banco volta e a aplicação está reiniciando, o sistema inteiro cai por
  uma dependência. Liveness testa só o que o processo controla (loop de eventos responde, não
  deadlock). Normalmente é trivial e rápida.
- **Readiness checa o que o tráfego precisa:** conexão com banco, cache essencial, migração
  concluída, configuração carregada. Falha de dependência **tira da rotação**, não mata.
- **Readiness que é apelido do liveness** (mesmo handler) é healthcheck vacuamente verdadeiro:
  o balanceador manda tráfego para quem ainda não tem banco. O gate da infra reprova.
- **Startup probe** evita que um processo de subida lenta (cache quente, migração, JIT) seja morto
  pela liveness antes de terminar.
- Readiness também sinaliza **drenagem**: no desligamento (SIGTERM) passa a falhar, espera
  conexões em curso e só então sai.

## 3. Cuidados

- Rápido (`< 1 s`), sem efeito colateral, sem autenticação, **sem expor detalhe interno** na
  resposta pública (versão de dependência, string de conexão): corpo mínimo; detalhe vai para log/métrica.
- Endpoints de probe na rede interna/porta de gestão, não na superfície pública (ou sem dado).
- Dependência **opcional** (degradação aceitável) não derruba readiness: reporta degradado por métrica.
- Todo probe tem timeout, período e limiar de falha configurados no orquestrador/IaC
  (`schematize-infra`), e o *readiness* do fleet inteiro falhando vira **alerta** (sintoma de usuário).
- O status das probes é métrica (`up`, `probe_success`): observabilidade observa o healthcheck.
