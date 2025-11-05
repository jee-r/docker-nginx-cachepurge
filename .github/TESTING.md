# Testing if pkg-oss patch is applied

The `prebuild` script is a temporary workaround for [nginx/pkg-oss#70](https://github.com/nginx/pkg-oss/pull/70) which fixes the `libpcre3-dev` → `libpcre2-dev` issue for Debian Trixie.

## How to test if the patch is no longer needed

Once PR #70 is merged and released in pkg-oss, we can remove the `prebuild` script.

### Manual test

1. **Temporarily disable the prebuild script:**
   ```bash
   mv cachepurge/prebuild cachepurge/prebuild.bak
   ```

2. **Try building:**
   ```bash
   make build
   ```

3. **If it succeeds:**
   - ✅ The patch has been applied upstream!
   - You can safely delete `cachepurge/prebuild`
   - Update the README to remove references to the patch

4. **If it fails with `libpcre3-dev` error:**
   - ❌ The patch is not yet applied
   - Restore the prebuild script:
     ```bash
     mv cachepurge/prebuild.bak cachepurge/prebuild
     ```

### Automated check (GitHub Actions)

You can add a monthly workflow to test without the patch:

```yaml
name: Test upstream patch

on:
  schedule:
    # Run monthly on the 1st
    - cron: '0 0 1 * *'
  workflow_dispatch:

jobs:
  test-without-patch:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Fetch Dockerfile
        run: curl -fsSL -o Dockerfile https://raw.githubusercontent.com/nginx/docker-nginx/master/modules/Dockerfile

      - name: Disable prebuild script
        run: rm -f cachepurge/prebuild

      - name: Try building without patch
        id: build
        continue-on-error: true
        uses: docker/build-push-action@v5
        with:
          context: .
          file: ./Dockerfile
          build-args: |
            NGINX_FROM_IMAGE=nginx:mainline
            ENABLED_MODULES=cachepurge

      - name: Create issue if patch is applied
        if: steps.build.outcome == 'success'
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: '🎉 pkg-oss patch has been applied upstream!',
              body: 'The libpcre2-dev patch from https://github.com/nginx/pkg-oss/pull/70 appears to be applied.\n\nYou can now:\n- Remove `cachepurge/prebuild`\n- Update README to remove patch references\n- This issue was automatically created by the test workflow.'
            })
```

## Monitoring pkg-oss releases

- Watch https://github.com/nginx/pkg-oss/releases
- Check the PR: https://github.com/nginx/pkg-oss/pull/70
- The patch should be in a branch like `nginx-<version>-<release>`

## When the patch is applied

1. Delete `cachepurge/prebuild`
2. Update [README.md](../README.md) to remove:
   - References to the prebuild script
   - Mentions of the libpcre2-dev patch
3. Update the "How It Works" section
4. Test the build to confirm it works
5. Commit with message: `chore: remove prebuild patch (applied upstream in pkg-oss)`
