# Fronteiras: observabilidade de front (RUM) e de LLM

> Parte da skill **schematize-observability**. Esta skill é a dona do **padrão** (OTel, semconv,
> redaction, amostragem, SLO); o que é **específico** de cada domínio fica com a skill do domínio.

## 1. Front (RUM, Web Vitals) -> `schematize-web`

Quem manda no front: `schematize-web -> references/observabilidade.md` §49 (captura de erro, Web
Vitals de campo LCP/INP/CLS, log sem PII, **consentimento**, Faro/OTel-JS). Daqui, o que o front herda:

- telemetria do browser entra pelo **mesmo Collector** (receiver OTLP/HTTP atrás de CORS restrito e
  limite de taxa), com `deployment.environment.name`, `service.name` (o app web) e `service.version`
  (release);
- **propagação W3C** do browser até o backend para um trace único front -> BFF -> serviço;
  o `traceparent` que vem do browser é **não confiável** (`padrao-otel.md` §6): é pai opcional, não
  decisão de amostragem;
- a endpoint pública do Collector é superfície de ataque (qualquer um posta telemetria): autenticação
  leve por token de app público, limite por origem, tamanho máximo, **redaction** no Collector;
- Web Vitals como métrica de campo (p75) com **cardinalidade baixa** (rota por template, não URL;
  versão; sem `user_id`); SLO de experiência (p75 de INP) segue a mesma matemática de budget;
- RUM só **após consentimento** onde a lei exige — nada dispara antes da escolha.

## 2. LLM (tokens, custo, latência) -> `schematize-ai`

Quem manda: `schematize-ai -> references/observabilidade-llm.md` (span por chamada, tokens com
cache read/write, custo, TTFT, `finish_reason`, qualidade em produção, fallback). Daqui, o que o LLM herda:

- a chamada ao modelo é **um span** OTel como o de um banco, filho do request, com atributos da
  semconv de GenAI (`gen_ai.*`, ainda em evolução: `stack-versoes.md`);
- **prompt e resposta são dado sensível**: por padrão **não** vão em atributo/log; se forem
  capturados (debug, eval), só em amostra, com redaction e acesso restrito, nunca em baggage;
- métricas de custo/token com labels **limitados** (modelo, feature, tenant só se agregável) — o
  custo por request vai no trace/log, não em label;
- SLO de LLM mistura latência (TTFT, total) e qualidade (taxa de falha de validação/guardrail);
  burn-rate vale igual;
- orçamento de custo é alerta (ticket) com runbook, como qualquer budget.
