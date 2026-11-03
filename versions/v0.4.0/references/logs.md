# Logs — JSON estruturado, correlação, redaction e auditoria

> Parte da skill **schematize-observability**. O formato exato está em `assets/log-json.md`.

## 1. Regras

1. **JSON, uma linha por evento, em stdout.** A aplicação não grava arquivo de log nem fala com o
   backend; o Collector (ou agente) coleta de stdout/stderr do contêiner. Texto solto (`print`,
   `puts`, `console.log`) em produção é vetado.
2. **Mensagem estática, dado em atributo.** `body` = "pagamento recusado pelo provedor", não
   "pagamento 123 do user a@b.c recusado". Mensagem fixa agrega, conta e alerta; mensagem
   interpolada vira um evento único por linha.
3. **Correlação:** todo log emitido com span ativo carrega `trace_id`, `span_id` e `trace_flags`.
   Use o *log bridge/appender* do SDK OTel (ou o handler da linguagem que injeta o contexto atual),
   não concatenação à mão. É isso que leva do alerta ao trace e do trace ao log em um clique.
4. **Resource em toda linha:** `service.name`, `service.version`, `deployment.environment.name`.
5. **Níveis:** DEBUG, INFO, WARN, ERROR, FATAL (faixas OTel de `severity_number`). Todo ERROR é
   acionável. DEBUG desligado em prd por padrão e ligável **com prazo**.
6. **Erro com estrutura:** `error.type` (classe limitada) + `exception.type`/`message`/`stacktrace`.
   Stack trace só em ERROR/FATAL; é o campo mais perigoso para vazar dado — passa pela redaction.
7. **Sem tempestade:** um erro em loop não pode gerar milhões de linhas. Limite de taxa por
   chave de erro (log a cada N segundos + contador) na aplicação; o Collector tem `memory_limiter`
   como última linha.

## 2. O que NUNCA entra num log

Senha, token, JWT, cookie, header `Authorization`, chave de API, segredo de qualquer tipo; PII em
claro (nome, e-mail, CPF, telefone, endereço, IP associado a pessoa quando evitável); dado
financeiro e payload de pagamento; **request/response/headers/body inteiros "pra debugar"**.
Loga-se o **campo específico, já mascarado**. Identificador de pessoa vai como **hash** com sal
(`user.id_hash`) ou um id opaco interno, nunca e-mail/CPF.

Segredo em log é **incidente de vazamento**: rotaciona o segredo, não "apaga a linha"
(`schematize-infra -> references/segredos.md`).

## 3. Defesa em profundidade: mascarar na origem E no Collector

- **Origem (aplicação):** biblioteca de log com filtro de campos (`filter_parameters` no Rails,
  redact de campos no logger da linguagem), DTO de log próprio que não carrega o objeto de domínio
  inteiro, e teste que prova que o log do caso "login" não contém a senha.
- **Collector:** processor `redaction` com `blocked_key_patterns` (chaves como `password`, `token`,
  `authorization`, `cookie`, `cpf`, `email`) e `blocked_values` (regex de e-mail, CPF, cartão, JWT,
  bearer) em **toda pipeline de logs e traces** (`assets/otel-collector.yaml`). Atributo de span
  também vaza: `db.query.text` com literal, `url.full` com token em query string, header capturado.
  O gate `scripts/check-otel-collector.sh` reprova pipeline sem `redaction`.
- Redaction por regex **não prova ausência de PII**: é rede de segurança. O piso é não emitir.

## 4. Auditoria NÃO é log de debug

| | Log de debug/operação | Trilha de auditoria |
|---|---|---|
| Serve para | operar e depurar | provar quem fez o quê |
| Pode ser amostrado/descartado | sim | **nunca** |
| Retenção | curta (dias) | pela regulação aplicável (anos) |
| Armazenamento | Loki/similar, mutável por retenção | **append-only, imutável**, fora da tabela de domínio e fora do backend de log |
| Conteúdo | evento técnico | `actor_id`, `tenant_id`, `action`, `resource`, `timestamp`, `ip`, `user_agent`, `result` |
| Redaction | agressiva | cuidadosa: o ator **tem** de ser identificável (por id opaco) |

Campos e requisitos normativos: `schematize-engineering -> references/observabilidade.md` §16.6.
Misturar os dois produz os dois erros: auditoria perdida pela retenção do log, e PII de auditoria
espalhada num backend de debug com acesso amplo.

## 5. Retenção e custo de log

Log é o sinal mais caro por volume. Retenção por tipo (`stack-referencia.md` §4), nível de
produção INFO, sem DEBUG permanente, sem payload. Cobrar volume por serviço no dashboard de custo é
o que faz alguém notar o `INFO` dentro de laço. Log não é banco de dados: se precisa consultar por
regra de negócio, é métrica ou tabela.
