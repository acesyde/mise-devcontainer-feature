#!/bin/bash
set -e

# Clean up
rm -rf /var/lib/apt/lists/*

MISE_VERSION=${VERSION:-"latest"}
MISE_GPG_KEYS_URI="https://mise.jdx.dev/gpg-key.pub"
MISE_REPO_URI="https://mise.jdx.dev/deb"

if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

echo "Installing mise version: $MISE_VERSION"

# Bring in ID, ID_LIKE, VERSION_ID, VERSION_CODENAME
. /etc/os-release
ARCHITECTURE="$(dpkg --print-architecture)"
# Get an adjusted ID independent of distro variants
if [ "${ID}" = "debian" ] || [ "${ID_LIKE}" = "debian" ]; then
    ADJUSTED_ID="debian"
elif [ "${ID}" = "alpine" ]; then
    ADJUSTED_ID="alpine"
else
    echo "Linux distro ${ID} not supported."
    exit 1
fi

if type apt-get > /dev/null 2>&1; then
    INSTALL_CMD=apt-get
elif type apk > /dev/null 2>&1; then
    INSTALL_CMD=apk
else
    echo "(Error) Unable to find a supported package manager."
    exit 1
fi

# Clean up
clean_up() {
    case $ADJUSTED_ID in
        debian)
            rm -rf /var/lib/apt/lists/*
            ;;
        alpine)
            rm -rf /var/cache/apk/*
            ;;
    esac
}
clean_up

# Check if mise is already installed
if type mise > /dev/null 2>&1; then
        echo "Detected existing system install: $(mise -v)"
        # Clean up
        clean_up
        exit 0
fi

# Add the Mise GPG key and repository
if [ "$INSTALL_CMD" = "apt-get" ]; then
    apt-get update
    apt-get install -y gpg curl
    curl -sSL ${MISE_GPG_KEYS_URI} | gpg --dearmor > /usr/share/keyrings/mise-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/mise-archive-keyring.gpg arch=${ARCHITECTURE}] ${MISE_REPO_URI} stable main" > /etc/apt/sources.list.d/mise.list
    apt-get update -y
fi

# Install mise
if [ "$INSTALL_CMD" = "apt-get" ]; then
    echo "Installing mise from OS apt repository"
    if [ "$MISE_VERSION" = "latest" ]; then
        apt-get install -y mise
    else
        apt-get install -y mise=$MISE_VERSION
    fi
elif [ "$INSTALL_CMD" = "apk" ]; then
    echo "Installing mise from OS apk repository"
    
    if [ "$MISE_VERSION" = "latest" ]; then
        apk add mise
    else
        apk add mise=$MISE_VERSION
    fi
fi


# Clean up
clean_up
exit 0