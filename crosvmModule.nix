{
  config,
  lib,
  pkgs,
  ...
}: let
  closureInfo = pkgs.closureInfo {
    rootPaths = [config.system.build.toplevel];
  };
  root = pkgs.stdenvNoCC.mkDerivation {
    binPath = with pkgs;
      lib.makeBinPath (
        [
          config.system.build.nixos-install
          config.system.build.nixos-enter
          nix
          pkgs.squashfsTools
        ]
        ++ stdenv.initialPath
      );
    name = "rootFS";

    nativeBuildInputs = [pkgs.squashfsTools];

    unpackPhase = "true";
    dontFixup = true;
    installPhase = ''
      export PATH=$binPath

      root="$PWD/root"
      mkdir -p $root

      # Provide a Nix database so that nixos-install can copy closures.
      export NIX_STATE_DIR=$TMPDIR/state
      nix-store --load-db < ${closureInfo}/registration

      chmod 755 "$TMPDIR"
      echo "running nixos-install..."
      nixos-install --root $root --no-bootloader --no-root-passwd \
        --system ${config.system.build.toplevel} \
        "--no-channel-copy" \
        --substituters ""

      # Build it into a squashfs image
      mksquashfs $root/nix/* $out \
        -no-hardlinks -keep-as-directory -all-root -b 1048576 -comp xz -Xdict-size 100% \
        -processors $NIX_BUILD_CORES
    '';
  };
in {
  config = {
    system.build.crosvmImage = pkgs.stdenvNoCC.mkDerivation {
      name = "crosvmImage";

      unpackPhase = "true";
      installPhase = ''
        mkdir -p $out
          cp '${config.system.build.toplevel}/kernel' $out/bzImage
          cp '${config.system.build.toplevel}/initrd' $out/initrd
          echo '${config.system.build.toplevel}/init' > $out/init
          cp '${config.system.build.toplevel}/kernel-params' $out/kernel-params
          cp '${root}' $out/root.squashfs
      '';
    };
  };
}
