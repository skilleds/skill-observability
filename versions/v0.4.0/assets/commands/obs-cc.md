---
description: schematize-observability — context compact: grava o handoff no archive e roda /compact.
---
Antes de compactar, **grave o handoff** em `<projeto>/<projeto>_archive/context/` no par
**context + checklist** do padrão da `schematize-archive` (prefixo `AAAA-MM-DD-<slug>-`) (FEITO vs
ABERTO). Inclua: serviços instrumentados, SLOs definidos, achados dos gates que ficaram abertos e
alertas ainda sem runbook. Só então rode `/compact`.
