# Recipe: Containerize native app using tooling from nixpkgs

This repository contains a recipe that is an example on how to package a native application into a container. This
application can be virtually anything:

* Your own app that you would like to run on:
  * operating systems that are not NixOS,
  * in a Dockerswarm,
  * in a Kubernetes cluster, or
* Open-Source application that you would like to run in its own sandbox[^1][^2], or
* Application that requires secrets that need to be swapped at runtime or that vary in different environments[^3].
* Proprietary application that cannot be shared with public due to license and/or other agreements.

[^1]: Containers more of a convenience mechanism than a security one. Malicious application can break out of a
container - if you are looking for a secure containment you might want to run the code in a lightweight Virtual Machine
like Firecracker.
[^2]: Depending on the exact need, this may be also achieved using Nix flakes and by running the application using a
separate, dedicated user account (there are cons to this solution too, like more difficult CPU/RAM quota management).
Containers are not the only way - make sure you pick the right solution for _your_ problem.
[^3]: In this solution you could just mount the file with the secret, but if you wanted to avoid containers and
use "plain" NixOS you might want to look into solutions like [sops-nix](https://github.com/mic92/sops-nix)
or [SecretSpec](https://devenv.sh/blog/2025/07/21/announcing-secretspec-declarative-secrets-management/).

Additionally, this recipe assumes following complications:

* The application is not present in upstream nixpkgs and never will be:
  * _This complication simulates private and/or proprietary applications. If the application in question was already
    in nixpkgs then this recipe would be considerably shorter (if it would exist at all)._
  * _This recipe adds additional friction by marking the application as unfree._
* The application's compilation process is decoupled from the Nix derivation building the container image:
  * _At this point this is more of a preference to keep the original build process separate from the functionality in
    this recipe._
  * _We can look at this complication as the application already having build pipeline(s), where we want to add this
    one feature of building a container, without rewriting the whole CI._
* The application is compiled down to native code:
  * _If the application was compiled to an intermediate format (e.g. Java) or just needed a runtime (e.g. JavaScript,
    Python), we could just use a distroless base image with the runtime instead. Similarily, if the application was
    compiled statically (e.g. Go, Rust\*), we could just use a scratch base image instead._
  * _This recipe uses a placeholder hello-world-level C application to satisfy this complication._
* The application needs to be able to dynamically load commonly available shared libraries from a known set:
  * Additionally, let's assume that the libraries cannot be compiled in statically, no matter whether that's due to
    technical or legal reasons (incompatible licenses etc.).
  * _The placeholder C application uses `dlopen()` to load and execute functions from `libaio` (LGPL) to satisfy this
    complication._
* The application has assets and/or configuration files that need to be available in the same working directory:
  * _This complication is satisfied by including the `fake-config-file.conf` file that the placeholder application
    will try to read._
* The result container needs to expose the application binary and the assets at a well-known location:
  * This well-known location will be used to swap the configuration file via container volume\*.
  * _We don't want to search for the application in `/nix/store/` each time, so this recipe will create the `/app`
    directory with symlinks to the application binary and its assets._
* The result container needs to contain a basic shell for debugging, besides the application and its dependencies:
  * _The shell is something extra we need to add, which is why this is rolled into base assumptions - if you are okay
    with distroless-like containers without a shell then just remove it from the derivation._
* The result container will be running on a generic Linux x64 system, without Nix:
  * _It needs to be a regular OCI container image that makes as little assumptions about the actual runtime environment
    as possible. The container may be started as standalone (`podman run ..`), as part of a docker compose or in a
    Kubernetes cluster._
  * _Snaps, AppImages, Flatpacks and other similar solutions are not in scope._

I've encountered this problem several times when working with both niche applications & proprietary stuff.
I'm sure I'm not the only one to do so - this recipe was created to save myself and others time when packaging given
application for the first time.

## What's required

The function to build the container image based off a Nix derivation is built-in into the nixpkgs library, so **to
build the container itself** we just need Nix and your favourite snapshot of nixpkgs.

The recipe in this repository uses a bunch of other tools ([go-task](https://taskfile.dev/), gcc etc.) that are
acquired via [DevEnv shell](https://devenv.sh/) - see the file `devenv.nix` for details.

## How this works

> [!NOTE]
> The pipeline is in the `Taskfile.yaml`

Assuming the application is already compiled and linked into an executable, this recipe will build the container image
will be built in two stages:

1. The first stage is building the derivation with the application itself, its dependencies (including shared
   libraries) and metadata to mark the application as unfree:
   * In this derivation, the simulated application is treated as just another package in `/nix/store`, without any
     special treatment (out-of-store links, secrets management etc.).
   * The derivation built in this stage would be sufficient to run this application on Nix-enabled Linux systems,
     however since we want to build a container image for greater portability...
2. The second stage is a _separate_ derivation that builds a container image using the _first_ derivation and then
   adding utilities like a shell:
   * This stage builds a `.tar.gz` file containing the layers of the container image. Once loaded via `podman load` they
     can be run using ordinary `podman run ..` command or pushed using ordinary `podman push ..`.
   * In addition to basic container setup, this stage also creates directory `/app` in the container with symlinks
     to the main application binary in `/nix/store` (the actual binary, not the wrapper script) and the simulated
     configuration file. Having these at a predictable well-known location allows users of the container image to, for
     example, mount a volume in its place to replace the configuration with whatever is appropriate in given environment.

The rest of the pipeline is mostly just plumbing and printing of extra debugging information, both of which can be
adjusted or removed depending on specific needs.

This repository contains a GitHub Actions workflow that executes all steps from the pipeline, including said debug
information. Reviewing the log from the latest build on the main branch is highly encouraged - it will get you up
to speed with what is actually going on.

Obviously this isn't the only way to do it. For starters both derivations could be squeezed into a single file/nix
lambda, however I felt that the recipe would be easier to understand when they aren't.

<!-- TODO: Expand this section, i guess? -->

## Running produced container image

The produced container image can be run in the usual way:

```shell
[$] podman run -it --rm  container-with-our-super-secret-application:${version}
```

The container has `bash` shell at a predictable path, so you can shell into the container by running:

```shell
[$] podman run -it --rm --entrypoint=/bin/bash  container-with-our-super-secret-application:${version}
```

## Compatibility with public GitHub Actions runners

This method is compatible with (runs under) public GitHub Actions runners, however there are some caveats:

* The [`pkgs.dockerTools.buildImage`](https://nixos.org/manual/nixpkgs/stable/#ssec-pkgs-dockerTools-buildImage) Nix
  function uses kvm device under the hood, which is not available on public GitHub Action runners:
  * Instead, this recipe uses the
    [`pkgs.dockerTools.buildLayeredImage`](https://nixos.org/manual/nixpkgs/stable/#ssec-pkgs-dockerTools-buildLayeredImage)
    function which does not have that requirement.
* Copies of the [`podman`](https://github.com/containers/podman) package obtained through Nix seem to be able to load
  the container image (`$ podman load`), but are blocked by runner's security profile from running any containers,
  even in rootless mode:
  * Considering the current security landscape around GitHub Actions security this is unfortunate, but understandable.
  * At the time of writing (2026-05-31) the `podman` binary shipped with the `ubuntu-latest` runner image does not have
    that limitation, so it is used in the CI workflow instead.

Using this recipe on self-hosted GitHub Actions runners is very likely to run into the same limitations as outlined
above, however with self-hosted runners you will have more tools in the toolbox to work around them.

## Running the workflow locally

This workflow can be run locally within a [DevEnv](https://devenv.sh/) shell:

```shell
[$] devenv shell --profile local
[devenv$] task all
```

The `local` profile includes [`podman`](https://github.com/containers/podman) obtained through Nix. If your system
already has `podman` set up, you can skip that profile and use the default shell instead.

## License

This repository is available under MIT license. See the `LICENSE` file for details.
