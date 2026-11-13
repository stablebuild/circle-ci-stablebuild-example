# StableBuild + CircleCI example

[![CircleCI](https://dl.circleci.com/status-badge/img/gh/stablebuild/circle-ci-stablebuild-example/tree/main.svg?style=svg)](https://dl.circleci.com/status-badge/redirect/gh/stablebuild/circle-ci-stablebuild-example/tree/main)

A small Flask app whose CircleCI pipeline downloads every dependency through [StableBuild](https://www.stablebuild.com/).
A pipeline that runs today and one that runs next year install exactly the same base image, Debian packages, Python packages and files,
even if they change or disappear upstream.

## What gets pinned

| Dependency | Used in | Pinned with |
|---|---|---|
| `python:3.14.10-slim-trixie` base image | `Dockerfile` | [Docker mirror](https://docs.stablebuild.com/mirrors-and-caches/docker-mirror) |
| `curl` and its dependencies from Debian | `Dockerfile` | [OS package mirror](https://docs.stablebuild.com/mirrors-and-caches/os-package-registry-ubuntu-debian-alpine), `sb-apt.sh` and `APT_PIN_DATE` |
| Flask, Gunicorn, pytest and everything they depend on | `Dockerfile`, `test` job | [PyPI mirror](https://docs.stablebuild.com/mirrors-and-caches/pypi-mirror) and `PYPI_PIN_DATE` |
| [tini](https://github.com/krallin/tini) binary from GitHub releases | `Dockerfile` | [File mirror](https://docs.stablebuild.com/mirrors-and-caches/file-mirror) |

`requirements.txt` only pins Flask and Gunicorn. Their own dependencies (Werkzeug, Jinja2, click, ...) are pinned by `PYPI_PIN_DATE`:
pip resolves them against PyPI as it was on that day. The app's `/versions` endpoint lists what got installed.

## The pipeline

- **`test`** runs on the `cimg/python` image without Docker. It installs the requirements from the PyPI mirror and runs pytest.
- **`build-image`** builds the `Dockerfile` with remote Docker, starts the container, and calls `/health` and `/versions`.

## Run it on your own CircleCI account

1. Fork this repository and [set it up as a project](https://circleci.com/docs/guides/getting-started/create-project/) in CircleCI.
2. Copy your API key from **Keys** in the [StableBuild dashboard](https://dashboard.stablebuild.com). The Community plan is free.
3. In CircleCI, open **Project Settings > Environment Variables** and add `SB_API_KEY` with your key.
4. Run the pipeline.

The first run fetches the base image and the tini binary from upstream and stores them in your StableBuild account.
Every later run gets the same bytes back. The dashboard lists everything that has been cached.

To share one key between several projects, put `SB_API_KEY` in a [context](https://circleci.com/docs/guides/security/contexts/) instead,
and add `context: <context name>` to both jobs under `workflows`.

## Build it locally

```sh
docker build --build-arg SB_API_KEY="$SB_API_KEY" -t circleci-stablebuild-example .
docker run --rm -p 8000:8000 circleci-stablebuild-example
curl http://localhost:8000/versions
```

## Moving to newer dependencies

- **Debian and Python packages:** change `APT_PIN_DATE` and `PYPI_PIN_DATE` in the `Dockerfile`, and `PYPI_PIN_DATE` in
  `.circleci/config.yml`. Keep both PyPI dates the same, so the tests run against the packages that end up in the image.
  The newest snapshot is listed at http://debmirror.stablebuild.com/.
- **Base image:** change the tag in `FROM`, and the `cimg/python` tag in `.circleci/config.yml` to the same Python version.
- **tini:** change `TINI_VERSION`.

## Your key ends up in the image

The key is in the image's build history and in `/etc/apt/sources.list`. That's fine for images you keep internal. Before you push an
image to a public registry, see [Protecting your keys in public Docker containers](https://docs.stablebuild.com/tutorials/protecting-your-keys-in-public-docker-containers).
