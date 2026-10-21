#!/bin/bash
# Request one URL per route through the distribution at $API_ROOT and check
# each answers 200. A path that reaches the wrong origin gets a 403 from API
# Gateway ("Missing Authentication Token"). Responses may come from the
# CloudFront cache, which is fine: only the routing is under test.
set -uo pipefail

paths=(
    /nj/counties
    /nj/counties/34001
    /nj/municipalities
    /nj/municipalities/2020
    /nj/municipalities/2020/3400100100
    /nj/municipality_xrefs/2000/2001
    /nj/use_of_force/agencies
    /nj/use_of_force/attributes
    "/nj/use_of_force/counts/incidents?by=year"
)

failed=0
for path in "${paths[@]}"; do
    status=$(curl -s -o /dev/null -w '%{http_code}' --max-time 30 "$API_ROOT$path")
    echo "$status $path"
    [[ $status == 200 ]] || failed=1
done
exit $failed
