# Security Considerations

## Credential Management

- Never commit `.env` to version control
- Restrict `.env` file permissions: `chmod 600 .env`
- Use strong, unique `BORG_PASSPHRASE` (store securely)
- Rotate AWS access keys regularly
- For USB: Consider filesystem encryption (LUKS)

## Container Hardening

- The container runs in privileged mode (required for FUSE mounts and mounting over bind mounts)
- Memory is capped at 4GB by default (adjustable in `docker-compose.yml`)
- A health check monitors `/mnt/backup` accessibility

## Borg Encryption

- Always use encryption when initializing repositories
- Store repository key in multiple secure locations
- Test restore procedures regularly
