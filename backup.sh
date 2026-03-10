#!/bin/bash

# Dockerized BorgBackup Script
# Adapted from baremetal backup script to work inside container
# The host filesystem is mounted at /mnt/target
# The backup storage is mounted at /mnt/backup (S3, USB, or local)

set -e
set -o pipefail

# Configuration
BACKUP_STORAGE_TYPE="${BACKUP_STORAGE_TYPE:-s3}"
SHOW_PROGRESS="${SHOW_PROGRESS:-false}"
BORG_AUTO_BREAK_LOCK="${BORG_AUTO_BREAK_LOCK:-false}"
LOG_DIR="/mnt/target/backup/log"
LOG_FILE="${LOG_DIR}/backup-$(date +%Y%m%d-%H%M%S).log"
DUMP_BASE_DIR="/mnt/target/backup/dump"
DUMP_DIR="${DUMP_BASE_DIR}"

# Cleanup handler for interruptions and failures
cleanup_on_exit() {
    local exit_code=$?
    if [ -d "${DUMP_DIR}" ] && [ "${DUMP_DIR}" != "/" ] && [ "${DUMP_DIR}" != "/mnt/target" ]; then
        info "Cleaning up dump directory: ${DUMP_DIR}" 2>/dev/null || true
        rm -rf "${DUMP_DIR}"
    fi
    exit ${exit_code}
}
trap cleanup_on_exit EXIT

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

    # Validate DUMP_DIR for safety
    if [ -z "${DUMP_DIR}" ] || [ "${DUMP_DIR}" = "/" ] || [ "${DUMP_DIR}" = "/mnt/target" ]; then
        error "Invalid or dangerous DUMP_DIR value: '${DUMP_DIR}'"
        error "DUMP_DIR must be a subdirectory path, not empty or root"
        exit 1
    fi

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

# Verify storage backend is accessible
verify_storage_backend() {
    info "Verifying storage backend (${BACKUP_STORAGE_TYPE})..."
    
    case "$BACKUP_STORAGE_TYPE" in
        s3)
            # For S3, check if s3fs mount is present
            # Use mountpoint command for reliable detection (avoids Docker overlay false matches)
            if ! mountpoint -q /mnt/backup; then
                error "S3 bucket is not mounted at /mnt/backup! Exiting."
                return 1
            fi
            ;;
        usb)
            # For USB, check if device is mounted
            # Use mountpoint command for reliable detection (avoids Docker overlay false matches)
            if ! mountpoint -q /mnt/backup; then
                error "USB device is not mounted at /mnt/backup! Exiting."
                return 1
            fi
            ;;
        local)
            # For local, check if directory exists and is writable
            if [ ! -d "/mnt/backup" ]; then
                error "Local backup path /mnt/backup does not exist! Exiting."
                return 1
            fi
            ;;
        *)
            error "Unknown storage backend: ${BACKUP_STORAGE_TYPE}"
            return 1
            ;;
    esac
    
    # Common check: verify write access
    if ! touch /mnt/backup/.backup_test 2>/dev/null; then
        error "Cannot write to /mnt/backup! Check permissions."
        return 1
    fi
    rm -f /mnt/backup/.backup_test

    # Check available disk space (warn if less than 5GB available)
    local available_space
    available_space=$(df -BG /mnt/backup 2>/dev/null | tail -1 | awk '{print $4}' | sed 's/G//')

    if [ -z "${available_space}" ] || ! [[ "${available_space}" =~ ^[0-9]+$ ]]; then
        info "Could not determine available space on backup storage (common with s3fs)"
    else
        info "Available space on backup storage: ${available_space}GB"
        if [ "${available_space}" -lt 5 ]; then
            error "WARNING: Less than 5GB available on backup storage!"
            error "Available: ${available_space}GB - Consider freeing up space or pruning old backups"
        fi
    fi

    success "Storage backend '${BACKUP_STORAGE_TYPE}' is accessible"
    return 0
}

# Get storage type description for logging
get_storage_description() {
    case "$BACKUP_STORAGE_TYPE" in
        s3)    echo "S3 bucket" ;;
        usb)   echo "USB device" ;;
        local) echo "Local path" ;;
        *)     echo "Unknown storage" ;;
    esac
}

# Handle Borg lock errors
# Returns: 0 = lock broken and should retry, 1 = do not retry
handle_borg_lock() {
    local operation="$1"  # "backup" or "prune"
    
    error "Repository lock detected (previous backup may have been interrupted)"
    
    case "$BORG_AUTO_BREAK_LOCK" in
        false)
            error "BORG_AUTO_BREAK_LOCK=false: Not breaking lock automatically"
            error "To resolve manually, run: borg break-lock ${BORG_REPO}"
            return 1  # Do not retry
            ;;
        manual)
            info "BORG_AUTO_BREAK_LOCK=manual: Requesting user confirmation"
            echo ""
            echo "═══════════════════════════════════════════════════════════"
            echo "  REPOSITORY LOCK DETECTED"
            echo "═══════════════════════════════════════════════════════════"
            echo "The repository is locked, likely from an interrupted backup."
            echo ""
            echo -n "Do you want to break the lock and retry? (y/n): "
            read -r response
            echo ""
            
            if [[ "$response" =~ ^[Yy]$ ]]; then
                info "User confirmed: Breaking lock..."
                borg break-lock "${BORG_REPO}" 2>&1 | tee -a "${LOG_FILE}"
                if [ ${PIPESTATUS[0]} -eq 0 ]; then
                    success "Lock broken successfully"

                    # Verify repository integrity after breaking lock
                    info "Verifying repository integrity..."
                    if borg check --repository-only "${BORG_REPO}" 2>&1 | tee -a "${LOG_FILE}"; then
                        success "Repository integrity verified, retrying ${operation}..."
                        return 0  # Retry
                    else
                        error "Repository integrity check failed after breaking lock!"
                        error "Manual intervention required. Run: borg check ${BORG_REPO}"
                        return 1  # Do not retry
                    fi
                else
                    error "Failed to break lock"
                    return 1  # Do not retry
                fi
            else
                info "User declined: Not breaking lock"
                return 1  # Do not retry
            fi
            ;;
        auto)
            info "BORG_AUTO_BREAK_LOCK=auto: Waiting 60 seconds before auto-breaking lock..."
            echo ""
            echo "═══════════════════════════════════════════════════════════"
            echo "  REPOSITORY LOCK DETECTED - AUTO MODE"
            echo "═══════════════════════════════════════════════════════════"
            echo "The lock will be automatically broken in 60 seconds..."
            echo "Press Ctrl+C to abort."
            echo ""
            
            # Countdown timer
            for i in {60..1}; do
                printf "\r  Waiting: %2d seconds remaining..." "$i"
                sleep 1
            done
            echo ""
            echo ""
            
            info "Timeout reached: Breaking lock automatically..."
            borg break-lock "${BORG_REPO}" 2>&1 | tee -a "${LOG_FILE}"
            if [ ${PIPESTATUS[0]} -eq 0 ]; then
                success "Lock broken successfully"

                # Verify repository integrity after breaking lock
                info "Verifying repository integrity..."
                if borg check --repository-only "${BORG_REPO}" 2>&1 | tee -a "${LOG_FILE}"; then
                    success "Repository integrity verified, retrying ${operation}..."
                    return 0  # Retry
                else
                    error "Repository integrity check failed after breaking lock!"
                    error "Manual intervention required. Run: borg check ${BORG_REPO}"
                    return 1  # Do not retry
                fi
            else
                error "Failed to break lock"
                return 1  # Do not retry
            fi
            ;;
        *)
            error "Invalid BORG_AUTO_BREAK_LOCK value: ${BORG_AUTO_BREAK_LOCK}"
            return 1  # Do not retry
            ;;
    esac
}

# Main backup execution
main() {
    local storage_desc=$(get_storage_description)

    # Validate required environment variables
    if [ -z "${BORG_REPO}" ]; then
        error "BORG_REPO is not set (should be exported by entrypoint)"
        exit 1
    fi
    if [ -z "${BORG_PASSPHRASE}" ]; then
        error "BORG_PASSPHRASE is not set"
        exit 1
    fi

    info "========================================="
    info "Starting Dockerized BorgBackup Process"
    info "========================================="
    info "Storage Backend: ${BACKUP_STORAGE_TYPE} (${storage_desc})"
    info "Host root mounted at: /mnt/target"
    info "Backup storage at: /mnt/backup"
    info "Repository: ${BORG_REPO}"
    info "Log file: ${LOG_FILE}"
    echo ""
    
    # Verify storage backend is accessible
    if ! verify_storage_backend; then
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
    
    # Build progress option
    PROGRESS_OPT=""
    if [ "${SHOW_PROGRESS}" = "true" ]; then
        PROGRESS_OPT="--progress"
        info "Progress display enabled"
    fi

    # Build dynamic exclusion for local backup path (prevent recursive backups)
    LOCAL_PATH_EXCLUDE=()
    if [ "${BACKUP_STORAGE_TYPE}" = "local" ] && [ -n "${LOCAL_BACKUP_PATH}" ]; then
        # Convert absolute path to relative (strip leading slash)
        LOCAL_PATH_RELATIVE="${LOCAL_BACKUP_PATH#/}"
        LOCAL_PATH_EXCLUDE=(--exclude "${LOCAL_PATH_RELATIVE}" --exclude "${LOCAL_PATH_RELATIVE}/*")
        info "Excluding local backup path from backup: ${LOCAL_PATH_RELATIVE}"
    fi
    
    # Attempt backup (with lock handling)
    local backup_attempts=0
    local max_attempts=2
    backup_exit=2  # Initialize with lock error code
    
    while [ ${backup_attempts} -lt ${max_attempts} ] && [ ${backup_exit} -eq 2 ]; do
        if [ ${backup_attempts} -gt 0 ]; then
            info "Retrying backup after lock resolution..."
        fi
        
        borg create \
            --verbose \
            ${PROGRESS_OPT} \
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
            "${LOCAL_PATH_EXCLUDE[@]}" \
            ::'{hostname}-{now}' \
            . 2>&1 | tee -a "${LOG_FILE}"
        
        backup_exit=${PIPESTATUS[0]}
        backup_attempts=$((backup_attempts + 1))
        
        # If lock error and not on last attempt, try to handle it
        if [ ${backup_exit} -eq 2 ] && [ ${backup_attempts} -lt ${max_attempts} ]; then
            if ! handle_borg_lock "backup"; then
                # User declined or error breaking lock, don't retry
                break
            fi
        fi
    done
    
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
    
    # Attempt prune (with lock handling)
    local prune_attempts=0
    local max_prune_attempts=2
    prune_exit=2  # Initialize with lock error code
    
    while [ ${prune_attempts} -lt ${max_prune_attempts} ] && [ ${prune_exit} -eq 2 ]; do
        if [ ${prune_attempts} -gt 0 ]; then
            info "Retrying prune after lock resolution..."
        fi
        
        borg prune \
            ${PROGRESS_OPT} \
            --list \
            --glob-archives '{hostname}-*' \
            --show-rc \
            --keep-daily 7 \
            --keep-weekly 4 \
            --keep-monthly 6 2>&1 | tee -a "${LOG_FILE}"
        
        prune_exit=${PIPESTATUS[0]}
        prune_attempts=$((prune_attempts + 1))
        
        # If lock error and not on last attempt, try to handle it
        if [ ${prune_exit} -eq 2 ] && [ ${prune_attempts} -lt ${max_prune_attempts} ]; then
            if ! handle_borg_lock "prune"; then
                # User declined or error breaking lock, don't retry
                break
            fi
        fi
    done
    
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
