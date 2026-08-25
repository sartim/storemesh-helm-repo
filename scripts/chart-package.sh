#!/bin/sh

set -eu

repository_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
distribution_directory="$repository_root/dist"

"$repository_root/scripts/helm-validate.sh"
mkdir -p "$distribution_directory"
find "$distribution_directory" -maxdepth 1 -type f -name 'storemesh-user-service-*.tgz' -delete
chart_version="${CHART_VERSION:-$(cat "$repository_root/VERSION")}"
helm package "$repository_root/storemesh-user-service" \
    --destination "$distribution_directory" \
    --version "$chart_version" \
    --app-version "$chart_version"

package="$distribution_directory/storemesh-user-service-${chart_version}.tgz"
test -f "$package"
helm show chart "$package" >/dev/null
echo "Packaged $package"
