# vast-steam

Steam + Sunshine image based on [Games on Whales](https://github.com/games-on-whales/gow), intended for GPU game streaming (Palworld mapped to Proton Experimental).

## Image

Published by GitHub Actions on pushes to `main`:

```bash
docker pull arnoldschan/vast-steam:latest
docker pull ghcr.io/arnoldschan/vast-steam:latest
```

## Build locally

```bash
docker build -t vast-steam .
```

## Ports

Sunshine UI and streaming: TCP/UDP `47984-47990`, TCP `48010`.

Web UI (HTTPS) uses the browser’s HTTP Basic login, not the Welcome form.

Default: username `sunshine`, password `sunshine` (override with `SUNSHINE_USERNAME` / `SUNSHINE_PASSWORD`).
