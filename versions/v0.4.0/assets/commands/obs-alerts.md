---
description: schematize-observability — audita ou escreve alertas (sintoma de usuário, severity, for, runbook_url, sem alta cardinalidade) e roda o gate check-alertas.mjs
argument-hint: "[arquivo ou diretório de regras]"
---

# /obs-alerts — alerta que ninguém age vira ruído

```bash
node .claude/skills/schematize-observability/scripts/check-alertas.mjs <regras>
```

Reprova: alerta sem `runbook_url`, sem `severity`, sem `for` (`for: 0m` só explícito), expressão com
label de alta cardinalidade, regra de SLO sem burn-rate multi-window.

Depois leia o que a máquina não lê, por alerta:

1. **É sintoma de usuário?** "CPU a 80%" e "pod reiniciou" são causa: viram painel/drill-down do runbook.
2. **Quem age e o quê?** O runbook diz significado, impacto, confirmação, mitigação, escalonamento? Foi testado?
3. **`page` ou `ticket`?** Só vira página o que exige ação humana imediata.
4. **Disparou e foi ignorado nos últimos 30 dias?** Apague ou rebaixe.
5. **Hml:** roteia para canal e não acorda ninguém (`references/ambientes.md`).
6. Versionado e revisado em PR, entregue com o serviço.

Referência: `references/slo-alertas.md` §3 e §4.
