ARG SB_API_KEY
FROM ${SB_API_KEY}.dockermirror.stablebuild.com/python:3.14.10-slim-trixie

ARG SB_API_KEY
ARG APT_PIN_DATE=2026-11-12T16:37:01Z
ARG PYPI_PIN_DATE=2026-11-12
ARG TINI_VERSION=v0.19.0

COPY ./sb-apt.sh /opt/sb-apt.sh
RUN bash /opt/sb-apt.sh load-apt-sources debian

RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

RUN curl -fsSL -o /usr/local/bin/tini \
        "https://${SB_API_KEY}.httpcache.stablebuild.com/circleci-stablebuild-example/https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-$(dpkg --print-architecture)" && \
    chmod +x /usr/local/bin/tini

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir \
        -i "https://${SB_API_KEY}.pypimirror.stablebuild.com/${PYPI_PIN_DATE}/" \
        -r requirements.txt

COPY app.py .

EXPOSE 8000
HEALTHCHECK CMD curl -fsS http://localhost:8000/health || exit 1
ENTRYPOINT ["tini", "--"]
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "app:app"]
