#!/usr/bin/env bash
scriptDir=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")
exec "$scriptDir/share/xyz.nokarin.aqloss/Aqloss" "$@"