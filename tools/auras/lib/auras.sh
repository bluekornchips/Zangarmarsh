#!/usr/bin/env bash
#
# Shared Auras library: constants plus path, desktop, buff, and debuff helpers
#

AURAS_DESKTOP_VERSION="1"
AURAS_MANAGED_KEY="X-Auras-Managed=true"
AURAS_VERSION_KEY="X-Auras-Version=${AURAS_DESKTOP_VERSION}"

_AURAS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_AURAS_LIB_DIR}/paths.sh" || return 1
source "${_AURAS_LIB_DIR}/desktop.sh" || return 1
source "${_AURAS_LIB_DIR}/buff.sh" || return 1
source "${_AURAS_LIB_DIR}/debuff.sh" || return 1
