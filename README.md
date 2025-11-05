# Nginx with Cache Purge Module

[![Docker Build](https://github.com/jee-r/docker-nginx-cachepurge/actions/workflows/docker-build.yml/badge.svg)](https://github.com/jee-r/docker-nginx-cachepurge/actions/workflows/docker-build.yml)
[![GitHub Container Registry](https://img.shields.io/badge/ghcr-image-blue)](https://github.com/jee-r/docker-nginx-cachepurge/pkgs/container/nginx-cachepurge)

Nginx mainline image with the [ngx_cache_purge](https://github.com/nginx-modules/ngx_cache_purge) module pre-compiled and ready to use.

This repository uses the [official nginx dynamic modules build system](https://github.com/nginx/docker-nginx/tree/master/modules) to compile the module.

## Features

- Based on official `nginx:mainline` image
- ngx_cache_purge module compiled as dynamic module
- Multi-architecture support (amd64, arm64, arm/v7)
- Automatic updates via Renovate when new nginx mainline versions are released
- Published to GitHub Container Registry
- Minimal repository footprint (nginx official Dockerfile + module definition only)

## Quick Start

```bash
docker run -d -p 80:80 ghcr.io/jee-r/nginx-cachepurge:latest
```

## Usage

The ngx_cache_purge module is automatically loaded. You can use it in your nginx configuration:

### Example Configuration

```nginx
http {
    proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=my_cache:10m max_size=1g inactive=60m;

    server {
        listen 80;
        server_name example.com;

        location / {
            proxy_cache my_cache;
            proxy_pass http://backend:8080;
            proxy_cache_key $scheme$host$request_uri;
            proxy_cache_valid 200 60m;

            # Enable cache purge
            proxy_cache_purge PURGE from 127.0.0.1;
        }

        # Dedicated purge location
        location ~ /purge(/.*) {
            allow 127.0.0.1;
            deny all;
            proxy_cache_purge my_cache $scheme$host$1;
        }
    }
}
```

### Purging Cache

Using the same-location syntax:
```bash
curl -X PURGE http://localhost/path/to/cached/content
```

Using the separate-location syntax:
```bash
curl http://localhost/purge/path/to/cached/content
```

## Building Locally

This project uses the official nginx modules build system. The Dockerfile is automatically fetched from the nginx repository using the Makefile.

### Using Makefile (Recommended)

```bash
# Clone this repository
git clone https://github.com/jee-r/docker-nginx-cachepurge.git
cd docker-nginx-cachepurge

# Show available commands
make help

# Build the image (automatically fetches Dockerfile)
make build

# Build and run tests
make test

# Build and run nginx
make run

# View logs
make logs

# Stop and clean up
make clean
```

### Manual Build

```bash
# Fetch the official Dockerfile
make fetch

# Or manually:
curl -o Dockerfile https://raw.githubusercontent.com/nginx/docker-nginx/master/modules/Dockerfile

# Build the image
docker build --network host \
  --build-arg NGINX_FROM_IMAGE=nginx:mainline \
  --build-arg ENABLED_MODULES=cachepurge \
  -t nginx-cachepurge .
```

### Remote Build

You can also build directly from the GitHub repository:

```bash
docker build --network host \
  --build-arg NGINX_FROM_IMAGE=nginx:mainline \
  --build-arg ENABLED_MODULES=cachepurge \
  -t nginx-cachepurge \
  'https://github.com/jee-r/docker-nginx-cachepurge.git#main'

# Or using Makefile
make remote-build
```

### Build with Docker Compose

Use the pre-built image:

```yaml
services:
  nginx:
    image: ghcr.io/jee-r/nginx-cachepurge:latest
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
```

## Available Tags

- `latest`, `mainline`: Latest nginx mainline with cache purge module
- `sha-<commit>`: Specific commit builds

## Architecture Support

This image supports the following architectures:

- `linux/amd64`
- `linux/arm64`
- `linux/arm/v7`

## Automated Updates

This repository uses:

- **Renovate**: Automatically creates PRs when new nginx mainline versions are available
- **GitHub Actions**: Automatically builds and publishes images on:
  - Push to main branch
  - Weekly schedule (to catch nginx updates)
  - Manual workflow dispatch

## Module Information

The [ngx_cache_purge](https://github.com/nginx-modules/ngx_cache_purge) module enables purging of cached content from:
- FastCGI cache
- Proxy cache
- SCGI cache
- uWSGI cache

### Configuration Directives

- `proxy_cache_purge`
- `fastcgi_cache_purge`
- `scgi_cache_purge`
- `uwsgi_cache_purge`

See the [module documentation](https://github.com/nginx-modules/ngx_cache_purge) for detailed usage.

## Repository Structure

```
.
├── .github/
│   └── workflows/
│       └── docker-build.yml     # GitHub Actions build workflow
├── cachepurge/
│   ├── source                   # URL to module source code
│   ├── build-deps               # Build dependencies (empty - no special deps)
│   └── prebuild                 # Temporary: patch libpcre3-dev → libpcre2-dev (until pkg-oss#70 is merged)
├── Makefile                     # Build automation and testing
├── renovate.json                # Renovate configuration
├── README.md
└── LICENSE
```

**Note:** The `Dockerfile` is not in the repository. It's automatically fetched from the [nginx/docker-nginx](https://github.com/nginx/docker-nginx/tree/master/modules) repository by the Makefile or GitHub Actions to ensure we always use the latest official version.

## How It Works

1. The repository contains the module definition in [cachepurge/](cachepurge/)
2. The Dockerfile is fetched from the official [nginx/docker-nginx](https://github.com/nginx/docker-nginx/tree/master/modules) repository
3. The build process:
   - Fetches the official nginx modules Dockerfile
   - Pulls the nginx:mainline base image (Debian Trixie)
   - Downloads nginx source matching the base image version
   - Downloads the module source from the URL in [cachepurge/source](cachepurge/source)
   - Runs [cachepurge/prebuild](cachepurge/prebuild) to patch `build_module.sh` (replaces `libpcre3-dev` with `libpcre2-dev` for Debian Trixie compatibility)
   - Compiles the module as a dynamic module (.deb package)
   - Installs the module in the final image

This approach ensures:
- Always uses the latest official nginx build system
- Compatibility with nginx mainline (Debian Trixie)
- Follows official nginx build practices
- Minimal maintenance burden
- Automatic compatibility with new nginx versions

## Temporary Workaround

**Note:** The `prebuild` script is a temporary workaround for [nginx/pkg-oss#70](https://github.com/nginx/pkg-oss/pull/70).

Once this PR is merged and released in pkg-oss, the `prebuild` script can be removed. See [.github/TESTING.md](.github/TESTING.md) for instructions on how to test if the upstream patch has been applied.

## License

This project is licensed under the MIT License.

The nginx software is licensed under the [2-clause BSD license](https://nginx.org/LICENSE).

The ngx_cache_purge module is licensed under the [2-clause BSD license](https://github.com/nginx-modules/ngx_cache_purge/blob/master/LICENSE).

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Acknowledgments

- [Nginx](https://nginx.org/)
- [ngx_cache_purge module](https://github.com/nginx-modules/ngx_cache_purge)
- [Nginx Docker Official Images](https://github.com/nginxinc/docker-nginx)
- [Nginx Dynamic Modules Build System](https://github.com/nginx/docker-nginx/tree/master/modules)
