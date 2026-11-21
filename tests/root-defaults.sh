#!/usr/bin/env bash
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fixture=$(cd "$tmp" && pwd -P)
project="$fixture/project"
mkdir "$project"

cat > "$fixture/flake.nix" <<EOF
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";
  inputs.flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
  inputs.devshell.url = "github:numtide/devshell";
  inputs.devshell.inputs.nixpkgs.follows = "nixpkgs";
  inputs.flake-by-folder.url = "path:$repo";

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } {
    imports = [ inputs.flake-by-folder.flakeModule inputs.devshell.flakeModule ];
    systems = [ "x86_64-linux" ];
    flake-by-folder.root = ./project;
    flake-by-folder.devshells.enable = !(builtins.pathExists ./disable-devshells);
  };
}
EOF

# Resolve inputs once; optional arguments allow local input overrides.
nix flake lock "$@" --output-lock-file "$fixture/flake.lock" "path:$fixture"

packages=packages.x86_64-linux
shells=devShells.x86_64-linux
expect() {
  local actual
  actual=$(nix eval --raw "path:$fixture#$1" --apply "$2")
  if [[ $actual != "$3" ]]; then
    printf '%s: expected %s, got %s\n' "$1" "$3" "$actual" >&2
    exit 1
  fi
}

touch "$project/Package.nix"
mkdir "$project/devshell.nix"
expect "$packages" builtins.toJSON '{}'
expect "$shells" builtins.toJSON '{}'
rm "$project/Package.nix"
rmdir "$project/devshell.nix"

echo '{ default ? null }: { devshell.name = if default == null then "standalone" else default.name; }' > "$project/devshell.nix"
expect "$shells.default.name" 'x: x' standalone
echo '{ writeText }: writeText "root-package" ""' > "$project/package.nix"
expect "$packages" 'p: "${p.default.name},${p.pkgsStatic.default.name},${p.pkgsCross.aarch64-multiplatform.default.name}"' 'root-package,root-package,root-package'
expect "$shells.default.name" 'x: x' root-package

mkdir -p "$project/packages/default" "$project/packages/tools/named" "$project/devshells/default" "$project/devshells/tools/named"
echo '{ writeText }: writeText "folder-package" ""' > "$project/packages/default/package.nix"
echo '{ default }: default' > "$project/packages/tools/named/package.nix"
echo '{}: { devshell.name = "folder-shell"; }' > "$project/devshells/default/devshell.nix"
echo '{}: { devshell.name = "named-shell"; }' > "$project/devshells/tools/named/devshell.nix"
expect "$packages" 'p: "${p.default.name},${p.named.name}"' 'root-package,root-package'
expect "$shells" 's: "${s.default.name},${s.named.name}"' 'root-package,named-shell'

touch "$fixture/disable-devshells"
expect "$shells" builtins.toJSON '{}'
rm "$fixture/disable-devshells" "$project/package.nix" "$project/devshell.nix"
expect "$packages" 'p: "${p.default.name},${p.named.name}"' 'folder-package,folder-package'
expect "$shells" 's: "${s.default.name},${s.named.name}"' 'folder-shell,named-shell'
