# ARC runner with libatomic1 and gzip

`ghcr.io/xpadev-net/arc-runner:latest` extends GitHub's official `ghcr.io/actions/actions-runner:latest` with `libatomic1`, for standalone pnpm and other binaries that need `libatomic.so.1`, and `gzip`, for compression and extraction.
The runner user, entry points, Docker tooling and externals remain inherited from the official image.

## Use with ARC

```yaml
template:
  spec:
    containers:
      - name: runner
        image: ghcr.io/xpadev-net/arc-runner:latest
        imagePullPolicy: Always
        command: ["/home/runner/run.sh"]
```

If a DinD configuration copies `/home/runner/externals` from an init container, use this image and `Always` there as well.
`Always` resolves the tag when a container starts; publishing an image does not replace existing warm runner Pods.
Since `latest` is mutable, separately starting init and runner containers can resolve different releases during publication.

## Updates and validation

GitHub Actions builds daily at 03:23 UTC, on pushes to `main`, and through **Run workflow**.
GitHub-hosted amd64 and arm64 runners build from the same resolved upstream digest without cached apt layers.
Each architecture must run the runner executable, verify `libatomic1`, `gzip` and the default `runner` user, check a gzip compression/decompression round trip, and download, integrity-check and execute the platform binary selected by the latest `@pnpm/exe` package.
The smoke-test pnpm binary is temporary and is not installed in the published image.

Only after both smoke tests pass does the workflow publish the multi-architecture `latest` tag.
Failed builds leave the previous `latest` in place.
When retrying a failed matrix run, choose **Re-run all jobs** so both architecture tags use the same run attempt.
Each publication also has an unreused `build-<run-id>-<attempt>` tag for recovery, with architecture-specific tags ending in `-amd64` and `-arm64`.
Workflow summaries and image labels record the upstream digest and source commit.
Dependabot proposes weekly updates for workflow action pins.

The GHCR package must be public so ARC can pull without registry credentials; public source repository visibility does not automatically guarantee package visibility.
After the first publication, open the package’s **Package settings → Change visibility → Public** before switching ARC to this image.
Scheduled workflows depend on GitHub Actions availability and may be delayed or disabled under GitHub's inactivity policy; review workflow failures and schedule status.

## Build and recover

```sh
docker build --pull --no-cache -t arc-runner:local .
docker run --rm -i arc-runner:local bash -s < scripts/smoke-test.sh
```

To recover from a bad upstream release, change the GitOps manifest's image to a known-good `build-<run-id>-<attempt>` tag or its digest.
The image adds a library on the runner filesystem; it does not add that library to independently selected job-container images.
