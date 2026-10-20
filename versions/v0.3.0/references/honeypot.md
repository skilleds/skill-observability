# Honeypot defensivo: engodo para detectar e conter bots de abuso

> Parte da skill **schematize-observability**. Todo projeto com superfície pública adota. Gate:
> `scripts/check-honeypot.sh` (valida o `honeypots.yml`). Teste de acesso: `schematize-qa` (categoria
> "Matriz de acesso por rota"). Incidente confirmado: `schematize-incident`. Efeito externo:
> `schematize-engineering` -> `references/efeitos-externos.md`.

## 0. Decisão de desenho (registre em ADR no projeto)

**A captura é por COMPORTAMENTO, não por nacionalidade.** O pedido original era "pegar bots russos/árabes";
o desenho correto pega **quem toca a isca**, venha de onde vier. País/ASN de origem entra no máximo como
**sinal auxiliar de score** (peso pequeno), **nunca** como regra única de bloqueio e **nunca** como ban por
país. Por quê:

- bloqueio por país **pega usuário legítimo** (viajante, expatriado, cliente B2B, VPN corporativa);
- é **contornável** por proxy/VPN/botnet residencial — o atacante troca de país em segundos;
- tem **risco de discriminação** e de ilegalidade (LGPD: tratamento por origem nacional é dado sensível-adjacente;
  princípio da não discriminação, art. 6º IX);
- bot de abuso é global: o mesmo script roda de qualquer lugar. O que o denuncia é o **que ele faz**.

O gate reprova `country_block`/`block_by_country` no `honeypots.yml`.

## 1. Quando usar / quando NÃO

Usar: formulário público (cadastro, contato, login, newsletter), API aberta, qualquer rota que scanner,
scraper ou credential stuffing varra. É **camada de detecção + custo para o atacante** (queima tempo, revela
a cadeia de ataque, alimenta lista de bloqueio).

**Nunca no lugar de** authn, authz, rate limit, WAF, CAPTCHA/desafio ou validação de entrada. Honeypot que
substitui controle real é segurança de fachada. Também não usar: em rota que usuário legítimo toca; onde o
fake exigiria efeito colateral real; sem dono para tratar o alerta.

## 2. Tipos de isca

| Tipo (`tipo:`) | O que é | Detalhe |
|---|---|---|
| `campo-isca` | campo de formulário que humano não preenche | `hidden`/CSS-off (não só `display:none`; também fora da tela), nome tentador (`website`, `phone2`, `fax`), `autocomplete=off`, `tabindex=-1`, `aria-hidden`. **Time-trap:** token assinado com o instante de render; submit em menos de N ms (ex.: 2000) é bot. Campo preenchido OU submit rápido = toque |
| `rota-isca` | URL tentadora fora do mapa legítimo | `/wp-login.php`, `/.env`, `/admin/backup.sql`, `/api/v1/users/export`, `/xmlrpc.php`, `/.git/config`, `/phpmyadmin`. Nenhum link legítimo a referencia. Pode ser listada em `robots.txt` como `Disallow` — isca para scraper que ignora o arquivo (humano e crawler bem-comportado não vão lá) |
| `endpoint-isca` | endpoint de API que imita cadastro/pedido/pagamento | ex.: `POST /api/v1/register-legacy`. Responde **FAKE 201** (seção 3): o bot "achou que passou", segue o script e revela a cadeia seguinte |
| `credencial-canario` | conta/token-isca que ninguém usa legitimamente | em seed, `.env.example` de repositório isca, wiki, dump falso. **Qualquer uso = alerta crítico** (vazamento ou intrusão), não só bot |
| `arquivo-canario` | arquivo/link-isca (documento, URL única com token) | acesso = alguém leu o que não devia |
| `email-canario` | endereço-isca em página/base | **SOMENTE para sink** (domínio de teste em rota nula). **Nunca e-mail real**: respeita o piso de efeito externo |

Robots.txt: a linha `Disallow` de uma isca é pública por definição; a isca não pode proteger nada real.

## 3. Contrato do FAKE 201

Só vale em rota/campo **declarados** na allowlist versionada `honeypots.yml` (seção 8). Regras:

1. **Nunca em rota real.** O handler-isca é registrado só para rotas da allowlist; o teste prova que rota
   real nunca devolve o fake (seção 7).
2. **Corpo sintético sem relação com dado real:** `id` de faixa reservada reconhecível **só internamente**
   (ex.: prefixo/valor que a casa identifica no log, mas indistinguível para quem vê de fora), token
   aleatório que **não valida em lugar nenhum**, `Location` plausível apontando para rota-isca.
3. **ZERO efeito colateral real:** nada de gravar em tabela de produção, enviar e-mail/SMS/webhook, cobrar,
   criar usuário, publicar evento de domínio. Grava **apenas** no log de evidência (evento `honeypot.hit`) ou
   sink isolado. O provider injetado no handler-isca **é** o sink (não há caminho para o real).
4. **Latência com jitter realista**, tarpit leve **com teto** (ex.: 300-1500 ms; teto duro de 3 s): assíncrono,
   sem segurar thread/worker; limite global de conexões em tarpit e timeout, senão a isca vira vetor de DoS
   contra a própria casa.
5. **Indistinguível de sucesso real** em status, headers (`Content-Type`, `Location`, cabeçalhos de segurança
   iguais aos reais) e forma do JSON — mas **sem vazar nada** (versão de stack, caminho interno, id real).
6. Rota-isca de arquivo (`/.env`, `/.git/config`): conteúdo fabricado com credenciais-canário, nunca segredo real.

## 4. Sinais, pesos e ação

Score por comportamento. Pesos são ponto de partida (calibre com os falsos positivos observados).

| Sinal | Peso | Ação |
|---|---|---|
| Tocar rota/endpoint-isca declarado | alto (≥ limiar de bloqueio sozinho) | tarpit + fake 201 + bloquear com TTL + `honeypot.hit` |
| Usar credencial/arquivo-canário | crítico | alertar (page) + bloquear + incidente (`schematize-incident`) |
| Campo-isca preenchido | alto | descartar silenciosamente (fake 201 no cadastro), bloquear com TTL |
| Time-trap: submit abaixo de N ms | médio-alto | desafiar (prova de trabalho/CAPTCHA) ou descartar |
| Velocidade humano-impossível (req/s por sessão) | médio | desafiar, depois rate limit |
| Sem JS/cookie quando o fluxo exige | baixo-médio | observar, somar ao score |
| JA3/JA4 (TLS) inconsistente com o User-Agent declarado | médio | observar; desafiar se somado a outro sinal |
| Ordem anômala (POST sem GET prévio do formulário, token de CSRF/time-trap ausente) | médio | desafiar |
| Reuso do mesmo payload em muitos alvos/contas | médio-alto | tarpit, bloquear fingerprint |
| Sequência de enumeração de paths (dicionário de wordlist) | médio | observar; ao tocar isca, bloquear |
| Geo/ASN/datacenter | **baixo (peso pequeno, auxiliar)** | só soma ao score; **nunca** decide sozinho |

Ações em escala: **observar** (só registra) -> **desafiar** -> **tarpit** -> **bloquear com expiração** ->
**alertar**. Só bloqueia automático o que passa do limiar por sinal de alta confiança (toque em isca).

## 5. Contenção

- Toque de alta confiança: **IP + fingerprint** (JA4/UA/cookie da isca) entram em lista de bloqueio com
  **TTL** (ex.: 24 h na 1ª ocorrência; reincidência escalona 7 d -> 30 d). Sem TTL, lista vira dívida e
  bloqueia gente legítima para sempre.
- Propagar ao **WAF/edge/rate-limiter** (a decisão é do honeypot; a aplicação é do borda).
- **CGNAT/IP compartilhado:** nunca bloquear só por IP em faixa móvel/CGNAT/escritório; bloquear
  fingerprint + IP, TTL curto na 1ª vez, preferir desafio a bloqueio quando o IP é muito compartilhado.
- **Falso positivo tratável:** revisão do evento, remoção manual com motivo, **allowlist** de scanners
  autorizados da própria casa, do **pentest com RoE** (`schematize-pentest`) e de monitores de uptime.
  Tráfego da allowlist ainda gera evento (`allowlisted=true`), só não bloqueia.
- **NUNCA bloquear por país** (seção 0).

## 6. Observabilidade

- Evento estruturado `honeypot.hit` (log JSON; padrão em `references/logs.md`), atributos: `honeypot.id`,
  `honeypot.tipo`, `http.route`, `client.ip_hash` (ou IP truncado /24 e /48 conforme decisão LGPD),
  `user_agent.original`, `tls.ja4`, `honeypot.score`, `honeypot.acao`, `allowlisted`, `trace_id`.
- Métrica (cardinalidade controlada, `references/metricas.md`): `honeypot_hits_total{honeypot_id,acao}`;
  **IP, UA e path cru não são label**. Top ASNs e fingerprints vão por agregação de log/trace.
- Painel (`/obs-dashboard`): hits/hora por isca, top ASNs, tempo médio preso em tarpit, bloqueios ativos,
  **taxa de falso positivo** (bloqueios revertidos / bloqueios).
- Alerta com runbook (`references/slo-alertas.md`): **pico de hits** = campanha em curso (severity ticket ou
  page conforme volume, `for` definido, `runbook_url`); **credencial-canário usada = incidente** (page) ->
  `schematize-incident`.
- **LGPD:** IP é dado pessoal. Base legal: legítimo interesse (segurança e prevenção a fraude, art. 7º IX /
  art. 10), com LIA registrada. Minimização (hash/truncado), **retenção mínima definida** (ex.: 30-90 d; evento
  sem reincidência expira antes), acesso restrito, **sem repasse** a terceiros fora de obrigação legal.
  Citar no aviso de privacidade (`schematize-institutional`).

## 7. Limites éticos e legais

Defensivo, **não "hack back"**: não atacar, escanear nem invadir a origem do bot. **Sem payload malicioso
na resposta** (nada de zip-bomb, exploit ou script contra o cliente) a menos que exista decisão jurídica
explícita registrada em ADR. Sem coleta além do necessário (nada de fingerprint de dispositivo invasivo,
nada de cruzar com dado de pessoa identificada). Honeypot não induz ao crime a pessoa legítima: isca não
fica em fluxo de usuário.

## 8. Testes e `honeypots.yml`

A matriz de acesso por rota do `schematize-qa` **DEVE listar cada honeypot como entrada explícita** da
allowlist de públicas, com resultado esperado `fake 201` (ou o equivalente da isca). Testes, **vermelho
antes** (rode sem o handler-isca e veja falhar):

1. a isca **nunca toca banco, e-mail ou webhook real** (provider = sink; o teste injeta um provider
   que falha o teste se chamado);
2. **rota real nunca devolve o fake 201** (varrer o inventário de rotas reais);
3. o toque gera o evento `honeypot.hit` **e** o bloqueio **com TTL** (assert no TTL, não só no bloqueio);
4. **usuário legítimo passa:** campo-isca vazio + tempo humano -> cadastro real, sem bloqueio;
5. IP da allowlist (pentest/uptime) gera evento mas não bloqueia.

Exemplo `honeypots.yml` (versionado, revisado em PR):

```yaml
honeypots:
  - id: hp-register-legacy
    tipo: endpoint-isca            # campo-isca|rota-isca|endpoint-isca|credencial-canario|arquivo-canario|email-canario
    rota: POST /api/v1/register-legacy
    dono: time-seguranca
    justificativa: imita cadastro antigo; queima bot de cadastro em massa
    resposta: fake-201
    block_ttl: 24h                 # escalona 7d, 30d na reincidência
  - id: hp-env
    tipo: rota-isca
    rota: GET /.env
    dono: time-seguranca
    justificativa: scanner de segredo; conteudo fabricado com credencial-canario
    block_ttl: 24h
  - id: hp-signup-website
    tipo: campo-isca
    rota: POST /api/v1/signup
    campo: website
    time_trap_ms: 2000
    dono: time-produto
    justificativa: campo oculto + submit < 2s
    block_ttl: 6h
  - id: hp-canario-email
    tipo: email-canario
    dono: time-seguranca
    justificativa: detecta vazamento de base de contatos
    sink: sink.teste.invalid       # nunca e-mail real
    block_ttl: 24h
allowlist_scanners:                # evento sim, bloqueio não
  - { nome: pentest-RoE-2026-10, cidr: 203.0.113.0/28, expira: 2026-12-31 }
```

Esqueleto do handler-isca (agnóstico de linguagem):

```
registrar_rotas_isca(allowlist honeypots.yml)       # SÓ rotas da allowlist; nunca wildcard
handler_isca(req, isca):
  hit = {isca.id, rota, ip_hash(req), ua, ja4(req), trace_id}
  score = pontuar(hit, sinais(req))                 # geo/ASN com peso pequeno
  se ip_na_allowlist(req): evento(hit, allowlisted=true); retornar resposta_fake(isca)
  evento("honeypot.hit", hit, score)                # log/sink de evidência, nunca banco de produção
  se score >= limiar_bloqueio: bloqueio.adicionar(ip, fingerprint, ttl=isca.block_ttl)  # propaga ao edge
  dormir_assincrono(jitter(300ms..1500ms), teto=3s) # limite global de conexões em tarpit
  retornar 201 {id: sintetico(), token: aleatorio_invalido(), Location: isca_plausivel}
                                                    # mesmos headers da rota real; sem efeito colateral
```

## 9. Checklist de adoção (verificável)

- [ ] ADR registra a decisão "comportamento, não nacionalidade" e a base legal (LIA)
- [ ] `honeypots.yml` versionado; `bash scripts/check-honeypot.sh --routes <inventario> honeypots.yml` = 0
- [ ] nenhuma chave `country_block`/`block_by_country` no repo
- [ ] cada isca com dono, justificativa e `block_ttl`
- [ ] provider do handler-isca é sink; nenhum caminho para banco/e-mail/webhook real (teste vermelho antes)
- [ ] rota real nunca devolve fake 201 (teste)
- [ ] matriz de acesso (`schematize-qa`) lista cada isca como pública com `fake 201`
- [ ] tarpit com teto e limite de conexões; teste de carga curto sem esgotar workers
- [ ] evento `honeypot.hit` emitido, sem IP/UA/path cru como label de métrica
- [ ] bloqueio com TTL propagado ao edge/WAF; CGNAT tratado; allowlist de pentest/uptime
- [ ] painel (hits/hora, top ASNs, falso positivo) e alerta com `runbook_url`
- [ ] credencial-canário usada dispara page e liga a `schematize-incident`
- [ ] retenção definida e documentada; IP minimizado; sem repasse
- [ ] sem payload malicioso na resposta; sem hack back
