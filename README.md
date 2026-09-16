# docker-mods

LinuxServer.io-compatible [Docker Mods](https://github.com/linuxserver/docker-mods).
One mod per branch; each publishes to `ghcr.io/vichzp/docker-mods:<branch>`.

| Mod | Base image | Adds |
|---|---|---|
| [`code-server-conch`](../../tree/code-server-conch) | `linuxserver/code-server` | [conch](https://github.com/newo-ether/conch) remote shell/exec server as a supervised s6 service |

## Using a mod

Append it to the container's `DOCKER_MODS` (pipe-separated):

```
-e DOCKER_MODS=linuxserver/mods:universal-docker|ghcr.io/vichzp/docker-mods:code-server-conch
```

## Writing one — things the docs do not tell you

Both of these were derived by reading `/docker-mods` inside a live LSIO image.

**The mod image must be exactly one layer.** The installer fetches
`.layers[0].digest` and extracts only that. A second `COPY` in the final stage
produces a second layer which is silently ignored — the mod appears to install
and half of it is missing. Stage everything in a build stage and finish with a
single `COPY --from=build /rootfs/ /` into `scratch`.

**Paths are absolute, with no `/root-layer/` wrapper.** The installer does
`cp -R /tmp/mod/* /`, so the layer's own tree *is* the overlay.

**v2 layout is dead.** Current images explicitly `rm -rf` `etc/cont-init.d` and
`etc/services.d` from the extracted mod. Long-running processes must be real
s6-rc services: a `svc-*` directory with `type` = `longrun` and a `run`, plus an
empty marker file in `user/contents.d/` to register it.

**Mods run before s6-rc compiles its database** (`S6_STAGE2_HOOK=/docker-mods`),
which is why a mod can add a service that starts on the very first boot — and why
the same thing written into `/custom-cont-init.d` cannot.

**Multi-arch works**, selected by `.platform.architecture` against the container's
`dpkg --print-architecture`. It matters only for mods shipping a compiled binary.
Build with `provenance: false` / `sbom: false`.
