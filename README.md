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
