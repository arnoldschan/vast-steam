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

## Tailscale

Set `TS_AUTHKEY` on the Vast instance (reusable auth key). Do not bake it into the image.

If the host denies TUN, the container falls back to userspace Tailscale so the node can still join the tailnet. TCP pairing/UI can work on `100.x`; UDP video still needs a real TUN device.

Moonlight on the tailnet: add the node’s `100.x` address with **no custom port** (47989). Nintendo Switch cannot run Tailscale; use Moonlight on a phone/PC that is logged into the same tailnet.
