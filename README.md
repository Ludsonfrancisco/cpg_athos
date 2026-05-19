# CPG Athos — Página da Coordenação de Planejamento e Gestão

Página estática (HTML single-file) da **Coordenação de Planejamento e Gestão da Igreja Athos**, hospedada em servidor caseiro Ubuntu via **EasyPanel** e exposta na internet através de **Cloudflare Tunnel**.

---

## Ideia do projeto

O conteúdo da página é um único arquivo `CPG Athos.html` — um artefato auto-contido com bundler embutido (scripts `__bundler/manifest`, `__bundler/template` e blocos `text/babel`). Não há build step externo, nem `node_modules`, nem código-fonte separado: o arquivo HTML já carrega e renderiza tudo por conta própria no navegador.

O repositório existe apenas para **empacotar esse HTML dentro de uma imagem Docker (nginx) e publicar via EasyPanel**, com acesso público pelo túnel da Cloudflare. Ou seja: o que está versionado aqui é o *deploy*, não a aplicação em si.

---

## Arquitetura

```
                           Internet
                              │
                              ▼
                ┌─────────────────────────────┐
                │   Cloudflare Tunnel         │
                │   (hostname público)        │
                └──────────────┬──────────────┘
                               │  HTTPS
                               ▼
        ┌──────────────────────────────────────────┐
        │  Servidor Ubuntu caseiro                 │
        │  ┌────────────────────────────────────┐  │
        │  │  cloudflared (daemon)              │  │
        │  └──────────────┬─────────────────────┘  │
        │                 │ http://localhost:8010   │
        │                 ▼                         │
        │  ┌────────────────────────────────────┐  │
        │  │  EasyPanel (Docker Swarm)          │  │
        │  │                                    │  │
        │  │  projeto: igreja                   │  │
        │  │  service: cpg-athos                │  │
        │  │  container: igreja_cpg-athos.1.…   │  │
        │  │  imagem:  nginx:alpine             │  │
        │  │  porta:   8010 (host) → 8010 (ct)  │  │
        │  └────────────────────────────────────┘  │
        └──────────────────────────────────────────┘
                               ▲
                               │ pull on Deploy
                               │
                ┌──────────────┴──────────────┐
                │  GitHub                     │
                │  Ludsonfrancisco/cpg_athos  │
                │  branch: main               │
                └─────────────────────────────┘
```

### Componentes

| Camada | O que é | Onde mora |
|---|---|---|
| Conteúdo | `CPG Athos.html` (artefato auto-contido) | repo |
| Empacotamento | `Dockerfile` (nginx:alpine + sed pra escutar na 8010) | repo |
| Build & runtime | EasyPanel buildando direto do GitHub | servidor caseiro |
| Exposição externa | Cloudflare Tunnel apontando pra `localhost:8010` | servidor caseiro |

---

## Estrutura do repositório

```
cpg_athos/
├── CPG Athos.html      # o artefato (nome com espaço, atenção)
├── Dockerfile          # nginx:alpine, COPY do HTML como index.html, listen 8010
├── .dockerignore       # exclui .git, Dockerfile, docs do build context
├── CLAUDE.md           # contexto pra futuras sessões do Claude Code
└── README.md           # este arquivo
```

### Sobre o Dockerfile

```dockerfile
FROM nginx:alpine

COPY ["CPG Athos.html", "/usr/share/nginx/html/index.html"]

RUN sed -i 's/listen\s*80;/listen 8010;/g; s/listen\s*\[::\]:80;/listen [::]:8010;/g' /etc/nginx/conf.d/default.conf

EXPOSE 8010

CMD ["nginx", "-g", "daemon off;"]
```

Pontos a destacar:

- **`COPY` em forma JSON** — necessário porque o nome do arquivo tem espaço (`CPG Athos.html`).
- **`sed` patchando o `default.conf`** — o template do EasyPanel desta instância **trava a porta interna do container em 8010** (não dá pra editar pela UI). Como o nginx por padrão escuta na 80, precisamos fazê-lo escutar na 8010 dentro do container pra bater com o mapeamento `8010 → 8010` que o EasyPanel gera.
- **`EXPOSE 8010`** — apenas documental; o que faz a porta ser publicada é o "Published Ports" do EasyPanel.

---

## Histórico do que foi feito

Resumo da configuração realizada, em ordem:

1. **Repositório inicial** com apenas o `CPG Athos.html`.
2. **Criado `Dockerfile` (nginx:alpine)** servindo o HTML como `/usr/share/nginx/html/index.html`, junto com `.dockerignore`.
3. **Push pro GitHub** (`https://github.com/Ludsonfrancisco/cpg_athos.git`, branch `main`).
4. **Service criado no EasyPanel** (projeto `igreja`, serviço `cpg-athos`) com **Source = Git** apontando pro repo.
5. **Primeiro build falhou** com `failed to read dockerfile: open Dockerflie: no such file or directory` — o campo de path no EasyPanel estava com typo (`Dockerflie`). Corrigido pra `Dockerfile` (ou deixar em branco, que é o default).
6. **Build subiu**, container rodou nginx 1.31.0 com workers. Logs mostraram `Configuration complete; ready for start up`.
7. **Container subiu, mas a porta 8010 não respondia.** Diagnóstico:
   - `docker ps` mostrava `igreja_cpg-athos … 80/tcp, 0.0.0.0:8010->8010/tcp`
   - Ou seja, o EasyPanel mapeou `host 8010 → container 8010`, mas o nginx, por default, escutava na **80**. Tráfego caía em 8010 do container, onde **nada** estava ouvindo.
8. **Tentativa A descartada** — mudar "container port" no EasyPanel pra 80 não era possível (template trava o campo).
9. **Tentativa B aplicada** — alterado o Dockerfile pra fazer nginx escutar na 8010 (linha do `sed`). Commit `746bf91`, push, Rebuild no EasyPanel.
10. **Cloudflare Tunnel** apontando pra `http://localhost:8010` no host (config feita pelo usuário).

### Para referência (outros serviços no mesmo EasyPanel)

| Serviço | App | Porta publicada | Observação |
|---|---|---|---|
| `apps_dmais` | Django + gunicorn | `8001 → 8001` | App escuta nativamente na 8001 |
| `apps_robo_totvs` | `python worker.py` | nenhuma | Worker sem HTTP, acessado pela rede interna |
| `igreja_cpg-athos` | nginx servindo HTML | `8010 → 8010` | Único que precisou de nginx + patch de porta |

---

## Como atualizar a página

1. Editar `CPG Athos.html` localmente.
2. Commit + `git push origin main`.
3. No EasyPanel → projeto `igreja` → service `cpg-athos` → **Deploy** (ou **Rebuild**).
4. Verificar no servidor:
   ```bash
   sudo docker ps | grep cpg-athos        # deve mostrar 0.0.0.0:8010->8010/tcp
   curl -I http://localhost:8010          # esperado: 200 OK, Server: nginx/...
   ```

Se o HTML mudar de nome, lembrar de atualizar o `COPY` do Dockerfile.

---

## Cloudflare Tunnel — exemplo de ingress

No `config.yml` do `cloudflared` (geralmente em `~/.cloudflared/config.yml` ou `/etc/cloudflared/config.yml`), uma regra do tipo:

```yaml
tunnel: <UUID-do-tunnel>
credentials-file: /root/.cloudflared/<UUID>.json

ingress:
  - hostname: cpg.seudominio.com
    service: http://localhost:8010
  # ... outras regras ...
  - service: http_status:404
```

Após editar:

```bash
cloudflared tunnel ingress validate
cloudflared tunnel route dns <NOME-DO-TUNNEL> cpg.seudominio.com   # uma vez só
sudo systemctl restart cloudflared
```

> Se o `cloudflared` rodar como container dentro da mesma rede do EasyPanel, dá pra apontar pra `http://cpg-athos:8010` em vez de `localhost:8010` e dispensar a publicação da porta no host.

---

## Troubleshooting (lições aprendidas)

### "Build falha com `failed to read dockerfile`"
Typo no campo de path do Dockerfile no EasyPanel. Deixe em branco ou exatamente `Dockerfile`.

### "Container subiu mas `curl localhost:8010` não responde"
Confirme com `docker ps` que aparece `0.0.0.0:8010->8010/tcp`. Se aparecer `…->80/tcp`, alguém reverteu o Dockerfile pra escutar na 80 — não funciona com este template (container port travado em 8010).

### "Container nem aparece no `docker ps`"
Se você está rodando o comando na máquina de dev (não no servidor), nunca vai aparecer — o EasyPanel só existe no servidor caseiro. Faça SSH antes.

### "Quero servir múltiplos arquivos / pasta"
Trocar o `COPY` pontual por `COPY . /usr/share/nginx/html/` e ajustar `.dockerignore`. Adicionar um `index.html` real ou ajustar `try_files` no nginx.

---

## Stack resumida

- **nginx:alpine** servindo HTML estático
- **Docker** (imagem buildada pelo EasyPanel)
- **EasyPanel** (orquestrador self-hosted sobre Docker Swarm)
- **GitHub** como fonte do build
- **Cloudflare Tunnel** pra expor sem abrir porta no roteador
