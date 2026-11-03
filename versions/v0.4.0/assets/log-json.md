# Convenção de log JSON da casa

> Parte da skill **schematize-observability**. Copie para o repo do serviço (ou aponte para ela).
> Racional e regras: `references/logs.md`.

Uma linha JSON por evento, em **stdout** (o coletor lê de lá; a aplicação não escreve arquivo de log
nem fala com o backend de log). UTF-8, sem quebra de linha dentro do valor.

## Campos obrigatórios

| Campo | Tipo | Regra |
|---|---|---|
| `timestamp` | string | RFC 3339 em UTC com fração (`2026-10-14T12:00:00.123Z`) |
| `severity_text` | string | `DEBUG` · `INFO` · `WARN` · `ERROR` · `FATAL` |
| `severity_number` | int | faixa OTel: DEBUG 5-8 · INFO 9-12 · WARN 13-16 · ERROR 17-20 · FATAL 21-24 |
| `body` | string | mensagem **estática** (sem interpolar dado variável; ele vai nos atributos) |
| `service.name` | string | igual ao `service.name` do Resource OTel |
| `service.version` | string | versão/commit do deploy |
| `deployment.environment.name` | string | `dev` · `hml` · `prd` |
| `trace_id` | string | 32 hex; **presente sempre que houver span ativo** |
| `span_id` | string | 16 hex; idem |
| `trace_flags` | string | 2 hex (`01` = amostrado) |

## Campos condicionais

`tenant_id` (multi-tenant) · `request_id`/`correlation_id` (entrada sem trace) · `error.type` (classe
**limitada**, ex. `timeout`, `validation`) · `exception.type` / `exception.message` /
`exception.stacktrace` (só em `ERROR`/`FATAL`, com a mensagem já mascarada) · `user.id_hash`
(hash, nunca o identificador cru) · `http.request.method` · `http.route` (template) ·
`http.response.status_code` · `duration_ms`.

## Exemplo

```json
{"timestamp":"2026-10-14T12:00:00.123Z","severity_text":"ERROR","severity_number":17,"body":"pagamento recusado pelo provedor","service.name":"checkout","service.version":"1.8.2","deployment.environment.name":"prd","trace_id":"4bf92f3577b34da6a3ce929d0e0e4736","span_id":"00f067aa0ba902b7","trace_flags":"01","tenant_id":"t_42","error.type":"provider_declined","http.route":"/pedidos/{id}/pagar","http.response.status_code":502,"duration_ms":812}
```

## Proibido (vira incidente de vazamento)

senha, token, JWT, cookie, `Authorization`, chave de API, PII em claro (nome, e-mail, CPF, telefone,
endereço), dado financeiro, payload de pagamento, request/response/headers/body inteiros. Mascare
**na origem**; o Collector (`redaction`) é a rede de segurança, não a primeira linha.

## Níveis

`DEBUG` desligado em prd por padrão (liga por tenant/rota por tempo limitado) · `INFO` fato de
negócio ou ciclo de vida, não um por linha de código · `WARN` degradação que se recupera sozinha ·
`ERROR` operação falhou e o usuário/chamador sentiu · `FATAL` o processo vai encerrar.
Todo `ERROR` é acionável: se ninguém age, é `WARN` ou `INFO`.
