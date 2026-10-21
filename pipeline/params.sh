#!/bin/bash
# Print the stack parameters in pipeline/env/<env>.params, one Key=Value per
# line, without comments or blank lines.
set -euo pipefail
grep -hv -e '^[[:space:]]*#' -e '^[[:space:]]*$' "pipeline/env/$1.params"
