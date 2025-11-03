#!/bin/bash

set -euo pipefail

GRADLEW="./gradlew"
if [ ! -x "${GRADLEW}" ]; then
    if command -v gradle >/dev/null 2>&1; then
        GRADLEW="gradle"
    else
        echo "Unable to find ./gradlew or gradle on PATH. Please generate the Gradle wrapper before running this script." >&2
        exit 1
    fi
fi

TASK="assembleDebug"

case "${1:-debug}" in
    install)
        ${GRADLEW} installDebug
        exit 0
        ;;
    clean)
        ${GRADLEW} clean
        exit 0
        ;;
    release)
        TASK="assembleRelease"
        ;;
    debug)
        TASK="assembleDebug"
        ;;
    *)
        echo "Unknown target '${1}'. Expected one of: debug, release, install, clean." >&2
        exit 1
        ;;
esac

${GRADLEW} ${TASK}
