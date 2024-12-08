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
          nix
          pkgs.squashfsTools
        ]
        ++ stdenv.initialPath
      );
    name = "root.squashfs";

    nativeBuildInputs = [pkgs.squashfsTools];

    unpackPhase = "true";
    dontFixup = true;
    installPhase = ''
      export PATH=$binPath

      root="$PWD/root"
      mkdir -p $root

      # Provide a Nix database
      export NIX_STATE_DIR=$TMPDIR/state
      nix-store --load-db < ${closureInfo}/registration

      nix-env --store "$PWD/root" --substituters "" \
        --extra-substituters "auto?trusted=1" \
        -p "$PWD"/root/nix/var/nix/profiles/system --set ${config.system.build.toplevel}
      # nix --extra-experimental-features "nix-command flakes" \
      #   copy --to "$root" ${config.system.build.toplevel}
      # nix-copy-closure --to "$root" ${config.system.build.toplevel}
      file_args="$root/nix/*"

      # Pass the file paths directly to mksquashfs
      # Doesn't work as the resulting paths have /nix in the front
      # e.g. we want the paths inside the image to be /store/whatever instead of /nix/store/whatever
      # This causes issues as we can't mount the squashfs to the root without creating a bunch of mounts for /var,/etc etc
      # Note: we may be able to get squashfs to output the right files by using a chroot or file namespace
      # mapfile -t <${pkgs.writeClosure [config.system.build.toplevel]}
      # file_args="''${MAPFILE[@]}"

      # Build it into a squashfs image
      mksquashfs $file_args $out \
        -no-hardlinks -keep-as-directory -all-root -b 1048576 -comp xz -Xdict-size 100% \
        -processors $NIX_BUILD_CORES
        # -no-strip
    '';
  };
in {
  config = {
    system.build.crosvmImage = pkgs.stdenvNoCC.mkDerivation {
      name = "crosvmImage";

      unpackPhase = "true";
      dontFixup = true;
      installPhase = ''
        mkdir -p $out
        ln -s '${config.system.build.toplevel}/kernel' $out/bzImage
        ln -s '${config.system.build.toplevel}/initrd' $out/initrd
        echo '${config.system.build.toplevel}/init' > $out/init
        ln -s '${config.system.build.toplevel}/kernel-params' $out/kernel-params
        ln -s '${root}' $out/root.squashfs
      '';
    };
  };
}
