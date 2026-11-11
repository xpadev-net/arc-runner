#!/usr/bin/env bash
set -euo pipefail

# Run inside the candidate image as its default user, without changing the image.
test "$(id -un)" = runner
test "$(dpkg-query -W -f='${Status}' libatomic1)" = 'install ok installed'
test "$(dpkg-query -W -f='${Status}' gzip)" = 'install ok installed'
test "$(printf 'gzip smoke test' | gzip -c | gzip -dc)" = 'gzip smoke test'
test -x /home/runner/bin/Runner.Listener
/home/runner/bin/Runner.Listener --version
test -d /home/runner/externals

case "$(uname -m)" in
  x86_64) platform=linux-x64 ;;
  aarch64) platform=linux-arm64 ;;
  *) echo 'Unsupported smoke-test architecture' >&2; exit 1 ;;
esac

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
cd "$tmp_dir"
curl --fail --silent --show-error --location --retry 3 \
  https://registry.npmjs.org/@pnpm/exe/latest -o exe.json
package="@pnpm/exe.$platform"
version=$(jq -er --arg package "$package" '.optionalDependencies[$package]' exe.json)
curl --fail --silent --show-error --location --retry 3 \
  "https://registry.npmjs.org/$package/$version" -o binary.json
url=$(jq -er '.dist.tarball' binary.json)
integrity=$(jq -er '.dist.integrity | select(startswith("sha512-"))' binary.json)
curl --fail --silent --show-error --location --retry 3 "$url" -o pnpm.tgz
expected=$(printf '%s' "${integrity#sha512-}" | base64 --decode | od -An -v -tx1 | tr -d ' \n')
printf '%s  pnpm.tgz\n' "$expected" | sha512sum --check
tar -xzf pnpm.tgz
test -x package/pnpm
actual=$(./package/pnpm --version)
test "$actual" = "$version"
printf 'Smoke test passed: user=runner, libatomic1 and gzip installed, gzip round trip passed, runner executable, %s=%s\n' "$package" "$actual"
