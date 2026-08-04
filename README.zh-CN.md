# flake-by-folder

[English](README.md) | 简体中文

面向 [`flake-parts`](https://github.com/hercules-ci/flake-parts) 项目、基于目录约定自动发现
输出的模块。

`flake-by-folder` 会递归查找采用约定文件名的包、开发环境和 bundler，并把项目内的
overlay 应用到每个 system 的包集。这样，每个输出都与其实现保持在一起，不再需要一个
集中式文件手工导入所有条目。

本仓库是 flake 模块库，而不是应用程序。根 flake 向使用方导出 `flakeModule`，并通过
`templates.default` 提供项目脚手架。

## 功能特性

- 递归发现 `package.nix`、`devshell.nix`、`bundler.nix` 和 `overlay.nix`。
- 使用包、开发环境和 bundler 文件的直接父目录名称作为其导出属性名。
- 包之间可以通过普通函数参数引用其他自动发现的包。
- 自动向开发环境和 bundler 注入已发现的包。
- 可选地使用 `pkgs.pkgsStatic` 和 `pkgs.pkgsCross` 中的包集重新求值所有包。
- 内置可运行模板，包含普通包、包装包、开发环境、bundler、overlay 和
  `nix2container` 镜像示例。

## 快速开始

需要已启用 `nix-command` 和 `flakes` 特性的 Nix。

```bash
mkdir my-flake
cd my-flake
nix flake init -t github:RazYang/flake-by-folder
nix flake show
```

第一次求值会解析模板 inputs，并在使用方项目中创建 `flake.lock`；应将该 lock 文件与
项目一起提交。

该模板是一个演示项目，启用了 `x86_64-linux` 和 `aarch64-linux`，生成以下结构：

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

模板中的可运行输出仅为上述两个 Linux system 定义。在其他平台上运行前，需要先把对应
system 加入 `flake.nix`，并确认各个包支持该平台。

可以在已配置的 Linux system 上直接运行模板示例：

```bash
nix run .#hello
nix run .#hello-wrapper
nix develop .#default
nix build .#hello-image
nix bundle --bundler .#default .#hello
```

`nix build .#hello-image` 生成的是 `nix2container` 镜像 manifest，而不是 Docker
归档文件。可以分别通过 `nix run .#hello-image.copyToDockerDaemon` 或
`nix run .#hello-image.copyToPodman` 加载到 Docker 或 Podman 的本地镜像存储中。

需要复制到任意 Skopeo 支持的可写目标时，可以使用通用的 `copyTo` 入口：

```bash
# 使用目标引用指定要推送的仓库和标签。
nix run .#hello-image.copyTo -- \
  docker://registry.example.com/team/hello:latest

# 使用 Skopeo 的目录 transport 导出。
nix run .#hello-image.copyTo -- "dir:$PWD/hello-image"
```

`--` 用来结束由 `nix run` 解析的选项。`copyTo` 会把源固定为 Nix 构建的镜像，并将
此后的所有参数原样传给 `skopeo copy`；至少需要提供一个包含 transport 前缀的目标。
其他 Skopeo copy 参数也应放在 `--` 之后。内置 Skopeo 支持的其他可写 transport，
例如 `oci:` 和 `docker-archive:`，使用方式相同。写入远端 `docker://` 目标前，需要让
Skopeo 能够读取 registry 凭据，例如通过其认证文件。

当前包装器会使用 `--insecure-policy` 调用 Skopeo。该选项会禁用容器镜像签名 policy
检查，但**不会**关闭 registry TLS 校验；认证和 TLS 行为仍由 Skopeo 配置及 copy 参数
控制。

最后一条命令用于演示 bundler 的工作方式。该模板会生成
`./bundle-hello/bin/bundle-hello`；结果仍然依赖 Nix store，仅用于演示连接方式，
不应视为可移植的独立 bundle。

## 接入现有 flake

下面是与仓库内模板一致的最小集成方式。请按项目需要调整 `nixpkgs` 和 `systems`。

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

        # 仅在所有自动发现的包都支持时启用。
        pkgsCross.enable = false;
        pkgsStatic.enable = false;
      };
    };
}
```

`flake-by-folder` 本身不会选择 system；它只会为使用方 `flake-parts` 项目配置的
system 创建 per-system 输出。

当 `devshells.enable` 为 `true` 且存在 `devshells/` 目录时，使用方还必须像上例一样
导入 `inputs.devshell.flakeModule`。本模块不会代替使用方隐式导入 `devshell`。

## 目录约定

发现过程会在 `flake-by-folder.root` 下递归进行：

| 源文件 | 生成结果 | 常用命令 |
| --- | --- | --- |
| `packages/**/package.nix` | `packages.<system>.<直接父目录>` | `nix build .#<名称>` |
| `devshells/**/devshell.nix` | `devShells.<system>.<直接父目录>` | `nix develop .#<名称>` |
| `bundlers/**/bundler.nix` | `bundlers.<system>.<直接父目录>` | `nix bundle --bundler .#<名称> .#<包>` |
| `overlays/**/overlay.nix` | 应用到 per-system `pkgs` | 不单独导出 flake 属性 |

文件名严格匹配并区分大小写。例如，`packages/hello/package.nix` 和
`packages/tools/hello/package.nix` 生成的名称都是 `hello`。同一类别内应保证直接父目录
名称唯一；更深层的目录名称不会转换为属性路径。重复名称不会触发错误，只会保留其中一个
匹配项。

如果 flake 位于 Git 工作区中，新建文件后需要先加入 Git 索引，再进行求值：

```bash
git add packages/my-package/package.nix
nix flake show
```

本模块不会自动发现 `apps`、`checks` 或其他 flake-parts 输出；需要时应通过普通的
flake-parts 模块定义。

## 编写条目

### 包

将 `packages/<名称>/package.nix` 编写为通过 `lib.callPackageWith` 求值并返回
derivation 的函数：

```nix
{ writeShellApplication }:

writeShellApplication {
  name = "hello";
  text = ''
    echo "hello from flake-by-folder"
  '';
}
```

所有自动发现的包位于同一个扁平不动点作用域中，因此一个包可以直接通过名称请求另一个
包：

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

除了 `pkgs` 中的普通属性，包函数还可以请求 `inputs`、`self'`、`inputs'` 和
`system`。应避免在自动发现的包之间形成循环依赖。可以通过
`nix build .#hello-wrapper` 构建该示例。在这个作用域中，自动发现的包会覆盖同名
Nixpkgs 属性。

### 开发环境

将 `devshells/<名称>/devshell.nix` 编写为
[`numtide/devshell`](https://github.com/numtide/devshell) 模块。已发现的包同样可以
作为函数参数使用：

```nix
{ hello, ... }:

{
  devshell = {
    name = "default";
    packages = [ hello ];
  };
}
```

包装层会提供空的默认 MOTD，并使用一份自动生成的空配置为交互式 Bash 初始化
Starship。默认 MOTD 可以正常覆盖；如果要完全替换注入的 Starship 初始化，需要使用
更高优先级的模块定义，例如 `lib.mkForce`。
开发环境函数还可以请求普通的 `pkgs` 属性、`inputs`、`self'`、`inputs'` 和
`system`。可以通过 `nix develop .#default` 进入该示例环境。

### Overlay

使用标准 Nixpkgs overlay 接口编写 `overlays/<名称>/overlay.nix`：

```nix
final: prev: {
  my-tool = prev.callPackage ./package.nix { };
}
```

存在 `overlays/` 目录时，模块会针对每个已配置 system 重新导入
`inputs.nixpkgs`，设置 `allowUnfree = true`，通过 `prev.inputs` 暴露 flake inputs，
应用所有发现的 overlay，并把结果作为 per-system 的 `pkgs` 模块参数。

因此，启用 overlay 发现时，使用方必须提供名称严格为 `nixpkgs` 的 input。

这是一种项目内部的包集定制方式。发现的 overlay **不会**导出为
`flake.overlays`。由于模块会重新实例化 `pkgs`，如果使用方已经在其他位置配置了
Nixpkgs 选项或 overlay，应审查这里的组合行为。既有的 Nixpkgs 配置、overlay 和自定义
`_module.args.pkgs` 不会自动合并到这个新实例中。

### Bundler

`bundlers/<名称>/bundler.nix` 的外层函数可以请求普通的 `pkgs` 属性、`inputs`、
`self'`、`inputs'`、`system`、已发现的包和其他自动发现的 bundler。它必须返回一个
从 `nix bundle` 所选值到 derivation 的函数。内置示例假定该值是 derivation，并访问
它的 `name` 和 `out` 属性：

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

生成的函数位于 `bundlers.<system>.<名称>`，可以通过
`nix bundle --bundler .#<名称>` 选择。如果包和 bundler 使用相同名称，bundler 参数
作用域在解析该名称时会优先选择包。

## 配置选项

| 选项 | 类型 | 默认值 | 含义 |
| --- | --- | --- | --- |
| `flake-by-folder.root` | path 或绝对路径字符串 | 必填 | 包含约定目录的根路径 |
| `flake-by-folder.devshells.enable` | boolean | `true` | 发现 `devshell.nix` |
| `flake-by-folder.bundlers.enable` | boolean | `true` | 发现 `bundler.nix` |
| `flake-by-folder.pkgsCross.enable` | boolean | `true` | 在 `packages.<system>.pkgsCross` 下增加交叉包集 |
| `flake-by-folder.pkgsStatic.enable` | boolean | `true` | 在 `packages.<system>.pkgsStatic` 下增加静态包集 |

包和 overlay 发现目前没有单独的启用开关；对应目录存在时就会启用。

默认模板显式关闭了 `pkgsCross` 和 `pkgsStatic`，因为并非所有包及其依赖都能使用
这些包集完成求值。

## 交叉与静态变体

启用后，每个自动发现的 `package.nix` 都会使用对应包集再次求值，结果路径为：

```text
packages.<宿主-system>.pkgsStatic.<包名>
packages.<宿主-system>.pkgsCross.<目标平台>.<包名>
```

可以直接使用 Nix CLI 的简写形式：

```bash
nix build .#pkgsStatic.hello
nix build .#pkgsCross.aarch64-multiplatform.hello
```

交叉编译目标名称来自模块的 `lib.systems.examples`，并用于查询
`pkgs.pkgsCross`。目标出现在该集合中，并不代表每个包都支持它；遇到不兼容包导致的
求值或构建失败属于关闭相应输出的合理情况。

启用对应功能时，`pkgsStatic` 和 `pkgsCross` 是保留包名：自动生成的根节点会覆盖使用
这些名称的自动发现包。

这里有一个重要的依赖边界：普通 Nixpkgs 参数会切换到静态或目标包集，但对其他自动发现
包的依赖仍会解析到原生 `packages.<宿主-system>.<名称>` 不动点。将带其他自动发现包
依赖的静态/交叉变体视为目标平台纯净输出之前，应先审查它们的实际依赖。

`pkgsStatic` 和 `pkgsCross` 本身是带有嵌套属性集属性的 derivation，因此
`nix flake show` 只会把根节点显示为 package，不会展开其中的包树。

## 实现结构

| 路径 | 职责 |
| --- | --- |
| `flake.nix` | 导出公共 flake 模块和默认模板 |
| `flake-by-folder.nix` | 声明选项并导入各发现模块 |
| `by-folder/packages.nix` | 构造包不动点以及可选的交叉/静态包集 |
| `by-folder/devshells.nix` | 把发现的文件适配为 `devshell` 模块 |
| `by-folder/bundlers.nix` | 定义并填充转置后的 `bundlers` 输出 |
| `by-folder/overlays.nix` | 使用本地 overlay 构造每个 system 的 Nixpkgs 实例 |
| `templates/default/` | 端到端使用方示例 |

## 开发与验证

检查模块库自身：

```bash
nix flake show path:$PWD --all-systems
nix flake check path:$PWD --all-systems --no-build
```

根 flake 检查可以验证模板声明，但无法单独执行任意 flake 模块。要使用**本地工作区**
而不是 GitHub input 对内置使用方模板求值，需要覆盖 input：

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

如果不使用 `--override-input`，`templates/default/flake.nix` 会解析其中声明的
GitHub input，因而可能无法验证尚未提交的本地模块修改。
