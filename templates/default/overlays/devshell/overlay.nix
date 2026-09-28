# Vendored devShell interface from nixpkgs PR #509697 (lisanna-dettwyler, "devShell interface").
# https://github.com/NixOS/nixpkgs/pull/509697
# 待 nixpkgs 合入后迁移到原生实现（见 flake.nix 顶部注释）。
#
# 与 PR 的差异：PR 在 stdenv 内部用"原始 drvAttrs"（derivation 调用前的属性集，全是
# env-coercible 值）调用 devShell，并把 devShell 作为直接 attr 挂在结果上（与
# passthru/meta 并列，故 .#pkg.devShell 可直达）。本 overlay 面向"已构建的 derivation"
# （其属性集含 passthru/meta/outPath 等非 coercible 属性），故 sanitize 过滤掉这些；
# 同样把 devShell 作为直接 attr 挂在 drv 上。
#
# withDevShell drv { extraPackages ? [] }：
#   额外开发工具包（如 ripgrep、LSP、watcher）追加到 devShell 的 nativeBuildInputs，
#   经 get-env.sh source stdenv setup 重建 PATH 时进入 devShell 环境。
final: prev:
let
  lib = final.lib;
  shell = final.lib.getExe final.bashInteractive;

  isEnvCoercible =
    v:
    let t = builtins.typeOf v; in
    if t == "string" || t == "path" || t == "int" || t == "float" || t == "bool" then
      true
    else if t == "list" then
      builtins.all isEnvCoercible v
    else if t == "set" then
      v ? outPath
    else
      false;

  mkDevShell =
    { drvAttrs, extraPackages ? [ ], extraBuildInputs ? [ ] }:
    assert lib.asserts.assertMsg
      ((baseNameOf (drvAttrs.builder or "bash")) == "bash")
      "devShell 仅支持 builder 为 bash 的 derivation";
    let
      sanitize =
        d:
        lib.filterAttrs (_: v: isEnvCoercible v) (
          removeAttrs d [
            "outPath"
            "drvPath"
            "type"
            "passthru"
            "meta"
            "outputChecks"
            "allowedReferences"
            "allowedRequisites"
            "disallowedReferences"
            "disallowedRequisites"
          ]
        );
      s = sanitize drvAttrs;
    in
    (derivation (
      s
      // {
        name = "${drvAttrs.name or "drv"}-env";
        args = [
          ./get-env.sh
          shell
        ];
        nativeBuildInputs = (s.nativeBuildInputs or [ ]) ++ extraPackages;
        buildInputs = (s.buildInputs or [ ]) ++ extraBuildInputs;
      }
    ))
    // {
      meta = {
        mainProgram = "run-shell";
      };
      __isDevShell = true;
    };
in
{
  s1rtDevShellGetEnv = ./get-env.sh;

  s1rtDevShell = mkDevShell;

  # helper：为任意 derivation 直接追加 .devShell（与 passthru/meta 并列，故 .#pkg.devShell 直达）。
  # 第二参数（可选）extraPackages / extraBuildInputs：追加进 devShell 的开发工具包。
  withDevShell =
    drv:
    { extraPackages ? [ ], extraBuildInputs ? [ ] }:
    drv
    // {
      devShell = mkDevShell {
        drvAttrs = drv;
        inherit extraPackages extraBuildInputs;
      };
    };
}
