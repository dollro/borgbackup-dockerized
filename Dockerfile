FROM python:3.13.7-slim-trixie@sha256:5f55cdf0c5d9dc1a415637a5ccc4a9e18663ad203673173b8cda8f8dcacef689
ENV PYTHONUNBUFFERED=1
RUN --mount=type=cache,id=apt-cache,target=/var/cache/apt apt-get update \
  # dependencies for s3fs (latest version with cache management)
  && apt-get install -y s3fs=1.95-1 glib-networking curl gnupg gzip zip unzip \
  # dependencies for borgbackup
  && apt-get install -y python3-dev libacl1-dev libssl-dev liblz4-dev libzstd-dev libxxhash-dev build-essential pkg-config libfuse-dev fuse \
  # dependencies for USB storage backend (blkid, ntfs support)
  && apt-get install -y util-linux ntfs-3g e2fsprogs xfsprogs btrfs-progs dosfstools \
  # cleaning up unused files
  && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
  && rm -rf /var/lib/apt/lists/*
# Requirements are installed here to ensure they will be cached.
RUN python -m pip install --upgrade pip
RUN --mount=type=cache,id=pip-cache,target=/root/.cache/pip pip install borgbackup==1.4.1 llfuse

COPY ./entrypoint /entrypoint
RUN chmod +x /entrypoint
COPY ./start /start
RUN chmod +x /start

# Copy and setup backup script
COPY ./backup.sh /usr/sbin/backup.sh
RUN chmod +x /usr/sbin/backup.sh \
    && mkdir -p /var/log/borgbackup

# Health check: verify backup mount is accessible (only meaningful during backup runs)
HEALTHCHECK --interval=60s --timeout=5s --start-period=30s --retries=3 \
    CMD test -d /mnt/backup || exit 1

ENTRYPOINT ["/entrypoint"]
