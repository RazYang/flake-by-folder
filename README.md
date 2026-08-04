# flake-by-folder

English | [简体中文](README.zh-CN.md)

Convention-based output discovery for
[`flake-parts`](https://github.com/hercules-ci/flake-parts) projects.

`flake-by-folder` recursively finds packages, development shells, and bundlers
from well-known filenames, then applies project-local overlays to the
per-system package set. It keeps each output next to its implementation and
removes the need for a central file that manually imports every entry.

This repository is a flake module library, not an application. Its root flake
exports `flakeModule` for consumers and `templates.default` for bootstrapping a
project.

## Features

- Discovers `package.nix`, `devshell.nix`, `bundler.nix`, and `overlay.nix`
  files recursively.
- Uses each package, development-shell, and bundler file's immediate parent
  directory as its exported attribute name.
- Lets packages depend on other discovered packages through ordinary function
  arguments.
- Makes discovered packages available to development shells and bundlers.
- Optionally evaluates every package with `pkgs.pkgsStatic` and the package
  sets in `pkgs.pkgsCross`.
- Includes a runnable template with package, wrapper, development shell,
  bundler, overlay, and `nix2container` image examples.

## Quick start

You need Nix with the `nix-command` and `flakes` features enabled.

```bash
mkdir my-flake
cd my-flake
nix flake init -t github:RazYang/flake-by-folder
nix flake show
```

The first evaluation resolves the template inputs and creates the consuming
project's `flake.lock`; commit that lock file with the project.

The template is a demonstration project. It enables `x86_64-linux` and
`aarch64-linux`, and includes the following layout:

```text
.
├── flake.nix
├── bundlers/
│   └── default/bundler.nix
├── devshells/
│   └── default/devshell.nix
├── overlays/
│   └── nix2container/overlay.nix
└── packages/
    ├── hello/package.nix
    ├── hello-image/package.nix
    └── hello-wrapper/package.nix
```

The generated runnable outputs are defined only for the two configured Linux
systems. On another platform, add its system to `flake.nix` and ensure the
individual packages support it before running these examples.

Try the generated examples on a configured Linux system:

```bash
nix run .#hello
nix run .#hello-wrapper
nix develop .#default
nix build .#hello-image
nix bundle --bundler .#default .#hello
```

`nix build .#hello-image` produces a `nix2container` image manifest, not a
Docker archive. Load it into Docker or Podman's local image storage with
`nix run .#hello-image.copyToDockerDaemon` or
`nix run .#hello-image.copyToPodman`, respectively.

Use the generic `copyTo` runner for any writable destination supported by
Skopeo:

```bash
# Push with the repository and tag selected by the destination reference.
nix run .#hello-image.copyTo -- \
  docker://registry.example.com/team/hello:latest

# Export with Skopeo's directory transport.
nix run .#hello-image.copyTo -- "dir:$PWD/hello-image"
```

The `--` separator ends the options parsed by `nix run`. `copyTo` fixes the
source to the image built by Nix and forwards every following argument to
`skopeo copy`; at minimum, provide a destination with its transport prefix.
Additional Skopeo copy flags can also follow `--`. Other writable transports
supported by the bundled Skopeo, such as `oci:` and `docker-archive:`, work the
same way. Before writing to a remote `docker://` destination, make registry
credentials available to Skopeo, for example through its auth file.

The current wrapper invokes Skopeo with `--insecure-policy`. This disables
container-image signature-policy enforcement; it does **not** disable registry
TLS verification. Authentication and TLS behavior remain controlled by Skopeo
configuration and copy flags.

The last command exercises the bundler wiring. With the template it creates
`./bundle-hello/bin/bundle-hello`. The result is backed by the Nix store; it is
not intended to be a portable standalone executable.

## Add it to an existing flake

The minimal integration below follows the bundled template. Adjust `nixpkgs`
and `systems` for your project.

```nix
{
  description = "A flake-by-folder project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-by-folder.url = "github:RazYang/flake-by-folder";

    devshell.url = "github:numtide/devshell";
    devshell.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.devshell.flakeModule
        inputs.flake-by-folder.flakeModule
      ];

      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      flake-by-folder = {
        root = ./.;

        # Enable these only when every discovered package supports them.
        pkgsCross.enable = false;
        pkgsStatic.enable = false;
      };
    };
}
```

`flake-by-folder` does not choose systems. It creates per-system outputs only
for the systems configured by the consuming `flake-parts` project.

When `devshells.enable` is true and a `devshells/` directory exists, the
consumer must also import `inputs.devshell.flakeModule`, as shown above. The
module deliberately does not import `devshell` on the consumer's behalf.

## Directory conventions

Discovery is recursive below `flake-by-folder.root`:

| Source file | Result | Typical command |
| --- | --- | --- |
| `packages/**/package.nix` | `packages.<system>.<parent-directory>` | `nix build .#<name>` |
| `devshells/**/devshell.nix` | `devShells.<system>.<parent-directory>` | `nix develop .#<name>` |
| `bundlers/**/bundler.nix` | `bundlers.<system>.<parent-directory>` | `nix bundle --bundler .#<name> .#<package>` |
| `overlays/**/overlay.nix` | Applied to the per-system `pkgs` | No separate flake output |

Filenames are matched exactly and are case-sensitive. For example, both
`packages/hello/package.nix` and
`packages/tools/hello/package.nix` produce the name `hello`. Keep immediate
parent directory names unique within each category; deeper directory names do
not become an attribute path. Duplicate names are not reported as an error;
only one matching entry is retained.

If the flake is backed by a Git worktree, remember to stage newly created files
before evaluating it:

```bash
git add packages/my-package/package.nix
nix flake show
```

This module does not auto-discover `apps`, `checks`, or other flake-parts
outputs. Define those through normal flake-parts modules when needed.

## Writing entries

### Packages

Create `packages/<name>/package.nix` as a function evaluated with
`lib.callPackageWith`; it should return a derivation:

```nix
{ writeShellApplication }:

writeShellApplication {
  name = "hello";
  text = ''
    echo "hello from flake-by-folder"
  '';
}
```

All discovered packages are part of the same flat fixed-point scope, so one
package can request another by name:

```nix
{ hello, writeShellApplication }:

writeShellApplication {
  name = "hello-wrapper";
  text = ''
    echo "hello from wrapper"
    ${hello}/bin/hello
  '';
}
```

In addition to normal attributes from `pkgs`, package functions can request
`inputs`, `self'`, `inputs'`, and `system`. Avoid dependency cycles between
discovered packages. A discovered package shadows a same-named Nixpkgs
attribute in this scope. Build the example with `nix build .#hello-wrapper`.

### Development shells

Create `devshells/<name>/devshell.nix` as a module for
[`numtide/devshell`](https://github.com/numtide/devshell). Discovered packages
are available as function arguments:

```nix
{ hello, ... }:

{
  devshell = {
    name = "default";
    packages = [ hello ];
  };
}
```

The wrapper supplies an empty default MOTD and initializes Starship with an
empty generated configuration for interactive Bash shells. The default MOTD
can be overridden normally. Replacing the injected Starship initialization
entirely requires a higher-priority module definition, such as `lib.mkForce`.
Development-shell functions can also request normal `pkgs` attributes,
`inputs`, `self'`, `inputs'`, and `system`.
Enter the example with `nix develop .#default`.

### Overlays

Create `overlays/<name>/overlay.nix` with the normal Nixpkgs overlay interface:

```nix
final: prev: {
  my-tool = prev.callPackage ./package.nix { };
}
```

When an `overlays/` directory exists, the module re-imports `inputs.nixpkgs`
for each configured system, sets `allowUnfree = true`, exposes the flake inputs
as `prev.inputs`, applies every discovered overlay, and uses the resulting set
as the per-system `pkgs` module argument.

Consequently, overlay discovery requires the consumer to provide an input
named exactly `nixpkgs`.

This is local package-set customization. Discovered overlays are **not**
exported as `flake.overlays`. Because `pkgs` is re-instantiated, review this
behavior if the consuming flake already supplies custom Nixpkgs configuration
or overlays elsewhere. Existing Nixpkgs configuration, overlays, and a custom
`_module.args.pkgs` are not automatically merged into this new instance.

### Bundlers

Create `bundlers/<name>/bundler.nix` with an outer function that can request
normal `pkgs` attributes, `inputs`, `self'`, `inputs'`, `system`, discovered
packages, and other discovered bundlers. It must return a function from the
value selected by `nix bundle` to a derivation. The bundled example assumes
that value is a derivation and accesses its `name` and `out` attributes:

```nix
{ hello, writeShellApplication, ... }:

drv:
writeShellApplication {
  name = "bundle-${drv.name or "drv"}";
  text = ''
    ${hello}/bin/hello
    echo ${drv.out}
  '';
}
```

The resulting function is exposed under `bundlers.<system>.<name>` and can be
selected with `nix bundle --bundler .#<name>`. If a package and a bundler use
the same name, the package wins when resolving that name in a bundler's
argument scope.

## Options

| Option | Type | Default | Meaning |
| --- | --- | --- | --- |
| `flake-by-folder.root` | path or absolute path string | Required | Root containing the convention directories |
| `flake-by-folder.devshells.enable` | boolean | `true` | Discover `devshell.nix` files |
| `flake-by-folder.bundlers.enable` | boolean | `true` | Discover `bundler.nix` files |
| `flake-by-folder.pkgsCross.enable` | boolean | `true` | Add cross-package sets below `packages.<system>.pkgsCross` |
| `flake-by-folder.pkgsStatic.enable` | boolean | `true` | Add a static package set below `packages.<system>.pkgsStatic` |

Package and overlay discovery do not currently have separate enable switches;
they are activated when their directories exist.

The default template explicitly disables `pkgsCross` and `pkgsStatic` because
not every package or dependency can be evaluated with those package sets.

## Cross and static variants

When enabled, every discovered `package.nix` is evaluated again with the
corresponding package set. The resulting paths are:

```text
packages.<host-system>.pkgsStatic.<package>
packages.<host-system>.pkgsCross.<target>.<package>
```

Nix CLI shorthand can select them directly:

```bash
nix build .#pkgsStatic.hello
nix build .#pkgsCross.aarch64-multiplatform.hello
```

Cross target names come from the module's `lib.systems.examples` set and are
looked up in `pkgs.pkgsCross`. A target being present does not imply that every
package supports it; evaluation or build failures from incompatible packages
are expected reasons to disable one of these outputs.

When the corresponding features are enabled, `pkgsStatic` and `pkgsCross` are
reserved package names: the generated roots replace discovered packages with
those names.

There is one important dependency boundary: normal Nixpkgs arguments switch to
the static or target package set, but dependencies on other auto-discovered
packages still resolve to the native `packages.<host-system>.<name>` fixed
point. Audit packages with dependencies on other discovered packages before
treating their static or cross variants as target-pure outputs.

`pkgsStatic` and `pkgsCross` are derivations with the nested sets attached as
attributes. `nix flake show` therefore displays their root nodes as packages
and does not expand the nested package tree.

## Implementation layout

| Path | Responsibility |
| --- | --- |
| `flake.nix` | Exports the public flake module and default template |
| `flake-by-folder.nix` | Declares options and imports the discovery modules |
| `by-folder/packages.nix` | Builds the package fixed point and optional cross/static sets |
| `by-folder/devshells.nix` | Adapts discovered files to `devshell` modules |
| `by-folder/bundlers.nix` | Defines and populates the transposed `bundlers` output |
| `by-folder/overlays.nix` | Constructs the per-system Nixpkgs instance with local overlays |
| `templates/default/` | End-to-end consumer example |

## Development and verification

Check the library flake itself:

```bash
nix flake show path:$PWD --all-systems
nix flake check path:$PWD --all-systems --no-build
```

The root check validates the template declaration, but it cannot exercise an
arbitrary flake module by itself. To evaluate the bundled consumer template
against the **local checkout** instead of the GitHub input, override the input:

```bash
nix flake check --all-systems --no-build \
  --no-write-lock-file \
  --override-input flake-by-folder path:$PWD \
  path:$PWD/templates/default

nix run \
  --no-write-lock-file \
  --override-input flake-by-folder path:$PWD \
  path:$PWD/templates/default#hello
```

Without `--override-input`, `templates/default/flake.nix` resolves its declared
GitHub input and may not test uncommitted local module changes.
