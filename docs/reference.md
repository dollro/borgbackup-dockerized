# Technical Reference

## Software Versions

| Component | Version |
|-----------|---------|
| Base Image | python:3.13.7-slim-trixie |
| BorgBackup | 1.4.1 |
| s3fs | 1.95-1 |

## Container Capabilities

The container requires the following capabilities for proper operation:

- `privileged`: Required for FUSE mounts (S3), block device mounts (USB), and mounting over Docker bind mounts
- `SYS_ADMIN`: Required for FUSE mounts (S3, USB)

## Volume Mounts

| Container Path | Purpose |
|---------------|---------|
| `/mnt/backup` | Backup storage mount point |
| `/mnt/target` | Host filesystem |
| `/dev` | Device access for FUSE (S3) and block devices (USB) |

## Supported USB Filesystems

| Filesystem | Mount Options |
|------------|---------------|
| ext4, ext3, ext2 | `rw` |
| xfs, btrfs | `rw` |
| ntfs | `rw,uid=0,gid=0` |
| vfat | `rw,uid=0,gid=0,umask=002` |

## Resources

- [BorgBackup Documentation](https://borgbackup.readthedocs.io/)
- [AWS S3 Documentation](https://docs.aws.amazon.com/s3/)
- [Docker Documentation](https://docs.docker.com/)
- [s3fs-fuse Project](https://github.com/s3fs-fuse/s3fs-fuse)
