This sandbox has the `sbx` CLI installed for developing Docker Sandboxes kits.

The kits in this monorepo use kit-spec v3 (`<kit>/<kit>.yaml` starting with
`# syntax=docker/sandbox-kit:3`). `sbx kit validate` does not accept v3 source kits,
so after editing a kit validate it by building it with the kit frontend:

    docker buildx build <kit-dir> -f <kit-dir>/<kit>.yaml --output type=cacheonly

Strict decoding rejects unknown or misplaced fields (for example a leftover v2 `name:`
or `permissions:`), naming the offending field and line.
