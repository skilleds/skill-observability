# Observabilidade em não-produção e o piso de efeito externo

> Parte da skill **schematize-observability**. Piso de origem:
> `schematize-engineering -> references/efeitos-externos.md` (efeito externo nunca sai de não-prd).

## 1. Observabilidade em dev/hml: sim, e com a mesma forma

Não-prd **tem** observabilidade, com os mesmos SDK, Collector e dashboards: é lá que a instrumentação
é validada antes de prd, e onde regressão de latência/cardinalidade aparece barato. Diferenças
permitidas: retenção menor, amostragem 100% (volume baixo), alertas que roteiam para canal e **não
acordam ninguém**, SLO informativo.

## 2. Separação por ambiente

- `deployment.environment.name` (`dev`/`hml`/`prd`) em **todo** Resource: é o que separa os sinais.
- **Collector por ambiente**, com exporters que apontam para os backends **daquele** ambiente.
  Backends separados, ou tenant separado (`X-Scope-OrgID`) com credencial própria por ambiente.
- Config do Collector de hml **não pode** conter endpoint, chave ou nome de exporter de prd, nem de
  SaaS de prd. `scripts/check-otel-collector.sh` reprova exporter de prd em config de hml (e SaaS
  conhecido em config de não-prd). Dado sintético não vira dado real por vazamento de config.
- Dashboards/alertas versionados com variável `$env`; a regra de prd não é editada para hml: é o
  mesmo arquivo com parâmetros por ambiente.

## 3. O piso de efeito externo vale para a própria telemetria

**Telemetria de hml/dev jamais vai para SaaS de prd nem para conta de prd.** Motivos reais: polui o
SLO e os dashboards de prd com tráfego de teste; mistura dado de teste (muitas vezes cópia mascarada de
produção) com o ambiente de maior confiança; e, pior, permite que um exporter mal configurado em
hml **dispare notificação real** (um webhook de alerta, e-mail do Alertmanager, página de plantão) —
o mesmo mecanismo do incidente dos 5000 e-mails.

- Alertmanager/receiver de hml: rota para canal de teste ou **sink**, nunca o integrador de
  paging/e-mail de prd. Notificação real fora de prd é página imediata (o contador de envio
  real fora de prd — `schematize-infra -> references/observabilidade.md` §9).
- Chave de API de SaaS (se houver) **por ambiente**, com escopo mínimo; a de prd não existe no
  cofre de hml (`schematize-infra -> references/segredos.md`).
- Dado de produção copiado para hml (se houver) é **mascarado antes**, e a telemetria que o
  trata passa pela mesma `redaction`.

## 4. Teste de observabilidade (com `schematize-qa`)

- O teste de integração prova que o serviço **emite** sinal: span com atributos esperados, métrica
  incrementada, log com `trace_id`, healthchecks distintos. Teste usa exporter em memória/`debug`,
  **nunca** backend real nem rede.
- Teste de carga em hml valida cardinalidade (séries antes/depois) e custo de instrumentação.
- Regras de alerta passam por `promtool check rules`/`test rules` e por `scripts/check-alertas.mjs`
  no CI; config do Collector por `scripts/check-otel-collector.sh` e `otelcol validate`.
- Teste de verdade de alerta: injete a falha em hml e veja o alerta **disparar e o runbook funcionar**
  (o equivalente do drill de DR para o caminho de alarme).
