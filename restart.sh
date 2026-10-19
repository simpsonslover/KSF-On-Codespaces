#!/bin/bash
# Restarts the KSF On Codespaces container, e.g. after the Codespace was stopped.
# Works no matter which directory it is run from.
cd "$(dirname "$(readlink -f "$0")")" || exit 1

echo "=== Waiting for Docker ==="
# Right after a Codespace resumes, the Docker daemon can take a moment to come up
for _ in $(seq 1 30); do
    docker info >/dev/null 2>&1 && break
    sleep 2
done
if ! docker info >/dev/null 2>&1; then
    echo "Docker is not running. Wait a minute and run this script again."
    exit 1
fi

# Rebuild the image if it is gone (e.g. the Codespace was rebuilt)
if ! docker image inspect ksf-on-codespaces >/dev/null 2>&1; then
    echo "=== Image not found, rebuilding ==="
    if [ ! -f options.json ]; then
        python3 installer.py
    fi
    docker build -t ksf-on-codespaces . || exit 1
fi

mkdir -p Save
if [ -z "$(ls -A Save)" ]; then
    cp -r root/config/* Save
fi

# The Codespace may come back on a machine without KVM, and passing a missing
# device makes docker run fail
KVM_ARGS=()
if [ -e /dev/kvm ]; then
    KVM_ARGS=(--device=/dev/kvm)
fi

echo "=== Starting container ==="
docker rm -f KSFOnCodespaces >/dev/null 2>&1
docker run -d --name=KSFOnCodespaces -e PUID=1000 -e PGID=1000 "${KVM_ARGS[@]}" --security-opt seccomp=unconfined -e TZ=Etc/UTC -e SUBFOLDER=/ -e TITLE="KSF On Codespaces" -p 3000:3000 --shm-size="2gb" -v "$(pwd)/Save:/config" --restart unless-stopped ksf-on-codespaces || exit 1

echo "KSF ON CODESPACES WAS RESTARTED SUCCESSFULLY! Check Port Tab"
