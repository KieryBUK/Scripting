#!/bin/sh

if podman container exists multicastrelay; then
  podman start multicastrelay
else
  podman container create --name multicastrelay -d --restart=always --network=host -e OPTS="--noMDNS" -e INTERFACES="br0 br202" docker.io/scyto/multicast-relay
  podman start multicastrelay
fi
