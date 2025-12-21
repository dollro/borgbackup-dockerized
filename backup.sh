#!/bin/bash

# Dockerized BorgBackup Script
# Adapted from baremetal backup script to work inside container
# The host filesystem is mounted at /mnt/target
# The S3 bucket is mounted at /mnt/backup

set -o pipefail

# Configuration
LOG_DIR="/target/backup/log"
LOG_FILE="${LOG_DIR}/backup-$(date +%Y%m%d-%H%M%S).log"
DUMP_BASE_DIR="/mnt/target/backup/dump"
DUMP_DIR="${DUMP_BASE_DIR}"

# Ensure log directory exists
mkdir -p "${LOG_DIR}"

# Logging functions
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[${timestamp}] [${level}] ${message}" | tee -a "${LOG_FILE}"
}

info() {
    log "INFO" "$@"
}

error() {
    log "ERROR" "$@"
}

success() {
    log "SUCCESS" "$@"
}

# Service-specific dump function for Mailcow
perform_dumps_mailcow() {
    if [ -f "/mnt/target/srv/mailcow/helper-scripts/backup_and_restore.sh" ]; then
        info "Found Mailcow installation, performing Mailcow backup..."
        MAILCOW_BACKUP_LOCATION="${DUMP_DIR}" /mnt/target/srv/mailcow/helper-scripts/backup_and_restore.sh backup all --delete-days 2
        if [ $? -eq 0 ]; then
            success "Mailcow backup completed successfully"
            return 0
        else
            error "Mailcow backup failed, but continuing with main backup"
            return 1
        fi
    else
        info "No Mailcow installation found, skipping Mailcow backup"
        return 0
    fi
}

# Add more service-specific dump functions here as needed
# Example:
# perform_dumps_mysql() {
#     # MySQL dump logic here
# }
# 
# perform_dumps_postgresql() {
#     # PostgreSQL dump logic here
# }

# Main function to orchestrate pre-backup dumps
perform_dumps() {
    info "Starting pre-backup dumps..."
    
    # Clean and create dump directory
    if [ -d "${DUMP_DIR}" ]; then
        info "Removing old dump directory..."
        rm -rf "${DUMP_DIR}"
    fi
    
    info "Creating dump directory: ${DUMP_DIR}"
    mkdir -p "${DUMP_DIR}"
    
    # Create timestamp file
    local timestamp=$(date +%F_%Hh%Mm)
    echo "${timestamp}" > "${DUMP_DIR}/timestamp"
    info "Created timestamp file: ${timestamp}"
    
    # Perform service-specific dumps
    perform_dumps_mailcow
    
    # Add more service dumps here as they are implemented
    # perform_dumps_mysql
    # perform_dumps_postgresql
    # perform_dumps_docker_volumes
    
    info "Pre-backup dumps completed"
}

# Main backup execution
main() {
    info "========================================="
    info "Starting Dockerized BorgBackup Process"
    info "========================================="
    info "Host root mounted at: /mnt/target"
    info "S3 bucket mounted at: /mnt/backup"
    info "Repository: ${BORG_REPO}"
    info "Log file: ${LOG_FILE}"
    echo ""
    
    # Check if S3 is mounted
    if ! mount | grep -q "/mnt/backup"; then
        error "S3 bucket is not mounted at /mnt/backup! Exiting."
        exit 1
    fi
    
    # Perform pre-backup dumps
    perform_dumps
    
    # Perform Borg backup
    info "========================================="
    info "Starting Borg backup..."
    info "========================================="
    
    # Change to /mnt/target so paths in archive are relative to host root
    cd /mnt/target
    
    borg create \
        --verbose \
        --stats \
        --show-rc \
        --exclude-caches \
        --compression lz4 \
        --one-file-system \
        --exclude 'backup/snapshots/*' \
        --exclude 'backup/log/*' \
        --exclude 'home/*/.cache/*' \
        --exclude 'var/cache/*' \
        --exclude 'var/tmp/*' \
        --exclude 'dev/*' \
        --exclude 'proc/*' \
        --exclude 'sys/*' \
        --exclude 'tmp/*' \
        --exclude 'run/*' \
        --exclude 'mnt/*' \
        --exclude 'media/*' \
        --exclude 'lost+found' \
        ::'{hostname}-{now}' \
        . 2>&1 | tee -a "${LOG_FILE}"
    
    backup_exit=${PIPESTATUS[0]}
    
    if [ ${backup_exit} -eq 0 ]; then
        success "Borg backup completed successfully"
    elif [ ${backup_exit} -eq 1 ]; then
        info "Borg backup finished with warnings"
    else
        error "Borg backup failed with exit code: ${backup_exit}"
    fi
    
    # Prune old backups
    info "========================================="
    info "Starting repository pruning..."
    info "========================================="
    
    borg prune \
        --list \
        --glob-archives '{hostname}-*' \
        --show-rc \
        --keep-daily 7 \
        --keep-weekly 4 \
        --keep-monthly 6 2>&1 | tee -a "${LOG_FILE}"
    
    prune_exit=${PIPESTATUS[0]}
    
    if [ ${prune_exit} -eq 0 ]; then
        success "Repository pruning completed successfully"
    elif [ ${prune_exit} -eq 1 ]; then
        info "Repository pruning finished with warnings"
    else
        error "Repository pruning failed with exit code: ${prune_exit}"
    fi
    
    # Calculate global exit code
    global_exit=$(( backup_exit > prune_exit ? backup_exit : prune_exit ))
    
    # Final status
    info "========================================="
    if [ ${global_exit} -eq 0 ]; then
        success "BACKUP PROCESS COMPLETED SUCCESSFULLY"
    elif [ ${global_exit} -eq 1 ]; then
        info "BACKUP PROCESS COMPLETED WITH WARNINGS"
    else
        error "BACKUP PROCESS FAILED"
    fi
    info "========================================="
    
    info "Full log available at: ${LOG_FILE}"
    
    exit ${global_exit}
}

# Run main function
main "$@"
