# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A **single-file HTML deployment** for the "Coordenação de Planejamento e Gestão · Igreja Athos" page. The repo's sole purpose is to ship `CPG Athos.html` as a static site behind nginx, hosted on a home Ubuntu server via EasyPanel and exposed through a Cloudflared tunnel.

`CPG Athos.html` is an artifact-style document with an in-page bundler (`<script type="__bundler/manifest">`, `<script type="__bundler/template">`, inline `text/babel` JSX). It is self-contained — there is no separate build step, no `node_modules`, no source tree to compile. **Do not try to "convert" it into a normal React/Vite project** unless explicitly asked; the bundler lives inside the file itself.

## Deployment architecture

- **Host:** home Ubuntu server (separate from the dev machine — this repo is edited on `pop-os` and pushed to GitHub; EasyPanel pulls from there).
- **Platform:** EasyPanel (Docker Swarm under the hood). Service name on the server: `igreja_cpg-athos`. Project: `igreja`. Server build path: `/etc/easypanel/projects/igreja/cpg-athos/code/`.
- **Source:** EasyPanel builds from `https://github.com/Ludsonfrancisco/cpg_athos.git`, branch `main`, Dockerfile at repo root.
- **Port:** the EasyPanel published-ports config uses `8010 → 8010` (host → container) and the container port **cannot be edited in this template**. That is why the Dockerfile patches the default nginx config to listen on `8010` instead of `80`. If you change `EXPOSE` or the `sed` line, the port mapping breaks silently (nginx ends up listening on a port nothing is forwarded to).
- **External access:** Cloudflared tunnel on the same host, ingress rule pointing to `http://localhost:8010` (or `http://cpg-athos:8010` if Cloudflared runs inside the EasyPanel network).
- **Sibling services on the same EasyPanel for reference:** `apps_dmais` (Django/gunicorn on 8001, publishes `8001→8001`), `apps_robo_totvs` (Python worker, no published port). The cpg-athos service is the only one that needs nginx.

## File layout

- `CPG Athos.html` — the artifact. Note the space in the filename: the Dockerfile uses JSON-array `COPY` syntax to handle it (`COPY ["CPG Athos.html", "/usr/share/nginx/html/index.html"]`). nginx serves it as `index.html`.
- `Dockerfile` — `nginx:alpine`, copies the HTML to `index.html`, `sed`-patches `/etc/nginx/conf.d/default.conf` to listen on `8010`, `EXPOSE 8010`.
- `.dockerignore` — excludes `.git`, the Dockerfile itself, and docs from the build context.

## Common commands

```bash
# Local smoke test (build + run, then curl)
docker build -t cpg-athos .
docker run --rm -p 8010:8010 cpg-athos
curl -I http://localhost:8010    # expect 200 OK, Server: nginx/...

# Deploy: push to main, then click Deploy/Rebuild in EasyPanel
git push origin main

# On the production server: verify what's actually listening
sudo docker ps | grep cpg-athos                  # want: 0.0.0.0:8010->8010/tcp
sudo ss -tlnp 'sport = :8010'
sudo docker inspect <container> --format '{{.Config.Cmd}}'   # want: [nginx -g daemon off;]
```

## Gotchas

- **EasyPanel typo trap:** the build path field defaults to `Dockerfile`. If anyone retypes it as `Dockerflie` (or any typo), the build fails with `failed to read dockerfile`. Leave it blank or exactly `Dockerfile`.
- **Container vs host port mismatch:** if you see `0.0.0.0:8010->80/tcp` in `docker ps`, someone changed the Dockerfile back to port 80 — that does not work with this EasyPanel template because the container target port is locked to 8010. Keep nginx listening on 8010.
- **The dev machine (`pop-os`) is not the deploy target.** `/etc/easypanel/...` and the running containers only exist on the home server. Diagnosing the deploy by running `docker ps` locally will always show nothing — ask the user to run checks on the server.
