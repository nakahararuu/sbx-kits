This sandbox is set up for developing Docker Sandboxes kits written in kit-spec v3
(`<kit>/<kit>.yaml` whose first line is `# syntax=docker/sandbox-kit:3`).

`sbx kit validate` does not accept v3 source kits, and the `sbx` CLI is not installed
here. After editing a kit, validate it by building it with the kit frontend through the
sandbox's own Docker Engine:

    docker buildx build <kit-dir> -f <kit-dir>/<kit>.yaml --output type=cacheonly

Strict decoding rejects unknown or misplaced fields (for example a leftover v2 `name:`
or `permissions:`), naming the offending field and line. The build pulls the frontend
image `docker/sandbox-kit:3` from Docker Hub, which this sandbox's network policy allows.
If a kit's `<kit>.dockerfile` downloads from other hosts in `RUN` steps, those hosts are
not allowed here and the build may fail to reach them; that is a limit of this sandbox,
not necessarily a bug in the kit.

A successful build only proves the descriptor is well-formed. Network grants and hook
behaviour can only be checked by creating a sandbox with the kit on the host, which this
sandbox cannot do, so ask the user to run that (e.g. `sbx run
docker.io/docker/sbx-kit-claude:<tag> --kit ./<kit> .`).
