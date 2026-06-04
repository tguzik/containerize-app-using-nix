{
  pkgs ? import <nixpkgs> { },
  pkgsLinux64 ? import <nixpkgs> { system = "x86_64-linux"; },

  # These variables are set on the command line
  appVersion,
  appBinary,
  appConfigFile,
  appImageName,
}:
let
  # The derivation defined in the other file. We could inline the configuration into this file (yay for Nix being a
  # pure functional language), but to lower the cognitive complexity we'll just import it from the other file.
  derivationWithApplication = import ./fake-app-package.nix {
    inherit appVersion;
    inherit appBinary;
    inherit appConfigFile;
  };
  # pkgs.callPackage ./fake-app-package.nix {};
in
# Docs: https://nixos.org/manual/nixpkgs/stable/#ssec-pkgs-dockerTools-buildImage
# Docs: https://nixos.org/manual/nixpkgs/stable/#ssec-pkgs-dockerTools-buildLayeredImage
#
# Note that `pkgs.dockerTools.buildImage` uses kvm/qemu under the hood, but `pkgs.dockerTools.buildLayeredImage` does
# not. Public GitHub Actions runners do not support kvm.
pkgs.dockerTools.buildLayeredImage {
  # The resulting image will contain the tag/version, which is controllable through this attribute.
  name = appImageName;

  # The resulting image will contain the tag/version, which is controllable through this attribute. If we did not
  # set it explicitly like we do in the next line, Nix would set it to the hash of the derivation -- this is fine
  # on its own, but the scripting in this repo is significantly simpler if we just set it to a pre-defined value.
  tag = appVersion;

  # Mark which architecture this image is for. This variable has defaults, we're just being explicit.
  architecture = "amd64";

  # Section describing the contents of the image. Directories and things that coerce to directories (e.g. derivations)
  # are allowed here, but prefer to sticking to just derivations.
  contents = [
    # The container image will start from a blank slate (`FROM scratch`), so let's add some basic packages to make
    # it possible to shell into the container
    pkgsLinux64.bash
    pkgsLinux64.coreutils-full
    pkgsLinux64.iana-etc
    pkgsLinux64.cacert

    # Include our derivation in the container image, the star of the show, including all of its dependencies
    derivationWithApplication

    # Include additional packages in the image. You can pick your own - these are just to improve the user experience
    # in case somebody wanted to shell into the container:
    pkgsLinux64.procps
  ];

  # Commands to run when building the image. These are mostly up to the specific application.
  # In this case we're just being fancy and create a specific, predictable directory (/app) with symlinks to the
  # app (the actual app, not the wrapper script) and its config -- the users of this container image may then use
  # bind mount to swap the configuration file.
  enableFakechroot = true;
  fakeRootCommands = ''
    mkdir -p  /app
    ln -s  "${derivationWithApplication}/libexec/${appBinary}"      "/app/${appBinary}"
    ln -s  "${derivationWithApplication}/libexec/${appConfigFile}"  "/app/${appConfigFile}"
  '';

  # Default runtime configuration embedded in the container
  config = {
    WorkingDir = "/app";
    Cmd = [ "/app/${appBinary}" ];
  };
}
