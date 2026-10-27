# syntax=docker/dockerfile:1
#
# LinuxServer.io Docker Mod: conch for code-server.
#
# ⚠️ THE FINAL IMAGE MUST HAVE EXACTLY ONE LAYER.
# The mod installer (/docker-mods in LSIO images) resolves the manifest and then
# fetches `.layers[0].digest` — the FIRST layer only. A second COPY in the final
# stage would create a second layer that is silently never applied. So the whole
# tree is assembled under /rootfs in the build stage and lands in a single
# `COPY --from`.
#
# The installer extracts that layer and does `cp -R /tmp/mod/* /`, so paths here
# are absolute paths in the target container — there is no /root-layer/ wrapper.

# Must satisfy conch's go.mod (v1.0.19 requires go >= 1.26.5). The official golang
# images set GOTOOLCHAIN=local, so a too-old base fails the build outright rather
# than quietly downloading a newer toolchain — keep this at or above what go.mod
# asks for instead of relaxing GOTOOLCHAIN, which would make builds non-reproducible.
FROM golang:1.26-alpine AS build

# Pin the conch release. Bump deliberately; this is a shell-execution server.
ARG CONCH_VERSION=v1.0.23

RUN apk add --no-cache git

# CGO off so the binary is static and does not care about the target image's libc
# (LSIO images are Ubuntu-based; this builds on Alpine).
#
# The ldflags mirror upstream's Makefile so a mod-built binary reports the same
# /version payload as an official release build — without them conch serves
# {"version":"dev","revision":"unknown"} and there is no way to tell from outside
# which build is deployed. BuildTime is derived from the pinned tag rather than the
# wall clock so rebuilding the same CONCH_VERSION is reproducible.
#
# The clone prints `warning: refs/tags/vX.Y.Z ... is not a commit!` — conch's release
# tags are annotated tag objects; git resolves them to the underlying commit and the
# warning is cosmetic.
RUN git clone --depth 1 --branch "${CONCH_VERSION}" https://github.com/newo-ether/conch /src \
 && cd /src \
 && REVISION="$(git rev-parse --short HEAD)" \
 && BUILD_TIME="$(git log -1 --format=%cI)" \
 && CGO_ENABLED=0 go build -trimpath -buildvcs=false \
      -ldflags="-s -w \
        -X github.com/newo-ether/conch/buildinfo.Version=${CONCH_VERSION} \
        -X github.com/newo-ether/conch/buildinfo.Revision=${REVISION} \
        -X github.com/newo-ether/conch/buildinfo.BuildTime=${BUILD_TIME}" \
      -o /rootfs/usr/local/bin/conch .

COPY root/ /rootfs/

# Set modes here rather than relying on git's executable bit surviving the
# checkout — s6 will not run a service whose `run` is not executable.
RUN chmod 0755 /rootfs/usr/local/bin/conch \
 && chmod 0755 /rootfs/etc/s6-overlay/s6-rc.d/svc-conch/run

FROM scratch
COPY --from=build /rootfs/ /
