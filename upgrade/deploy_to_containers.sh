#!/bin/bash
# XLoud Nova - Docker Container Deployment Script
# This script deploys XLoud Nova changes to a Docker-based Nova installation

set -e

# Configuration - Update these for your environment
TARGET_HOST="${TARGET_HOST:-103.240.25.209}"
CONTAINER_NAME="${CONTAINER_NAME:-nova_api}"
NOVA_SITE_PACKAGES="${NOVA_SITE_PACKAGES:-/usr/local/lib/python3.10/site-packages/nova}"
SOURCE_REPO="${SOURCE_REPO:-/root/xloud-nova}"
BACKUP_DIR="${BACKUP_DIR:-./backups}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to deploy a single file
deploy_file() {
    local src=$1
    local dst=$2
    local filename=$(basename "$src")
    
    print_info "Deploying: $src -> $dst"
    
    # Copy to target host /tmp
    if ! rsync -avz --progress "$src" root@${TARGET_HOST}:/tmp/ 2>/dev/null; then
        print_error "Failed to rsync $src to target host"
        return 1
    fi
    
    # Copy into container
    if ! ssh root@${TARGET_HOST} "docker cp /tmp/$filename ${CONTAINER_NAME}:$dst" 2>/dev/null; then
        print_error "Failed to copy $filename into container"
        return 1
    fi
    
    # Cleanup
    ssh root@${TARGET_HOST} "rm /tmp/$filename" 2>/dev/null || true
    
    return 0
}

# Function to verify deployment
verify_file() {
    local path=$1
    local check_content=$2
    
    if ssh root@${TARGET_HOST} "docker exec ${CONTAINER_NAME} test -f $path" 2>/dev/null; then
        if [ -n "$check_content" ]; then
            if ssh root@${TARGET_HOST} "docker exec ${CONTAINER_NAME} grep -q '$check_content' $path" 2>/dev/null; then
                echo "✓"
                return 0
            else
                echo "✗ (file exists but missing content)"
                return 1
            fi
        else
            echo "✓"
            return 0
        fi
    else
        echo "✗ (file not found)"
        return 1
    fi
}

# Main deployment function
main() {
    print_info "========================================="
    print_info "XLoud Nova Container Deployment"
    print_info "========================================="
    print_info "Target Host: $TARGET_HOST"
    print_info "Container: $CONTAINER_NAME"
    print_info "Nova Path: $NOVA_SITE_PACKAGES"
    print_info "Source: $SOURCE_REPO"
    echo

    # Check if source repo exists
    if [ ! -d "$SOURCE_REPO" ]; then
        print_error "Source repository not found: $SOURCE_REPO"
        exit 1
    fi

    cd "$SOURCE_REPO" || exit 1

    # Test connectivity
    print_info "Testing connectivity to target host..."
    if ! ssh root@${TARGET_HOST} "echo ok" >/dev/null 2>&1; then
        print_error "Cannot connect to $TARGET_HOST"
        print_error "Please ensure SSH access is configured"
        exit 1
    fi

    # Test Docker container
    print_info "Testing Docker container access..."
    if ! ssh root@${TARGET_HOST} "docker exec ${CONTAINER_NAME} echo ok" >/dev/null 2>&1; then
        print_error "Cannot access container $CONTAINER_NAME"
        exit 1
    fi

    print_info "Connectivity tests passed!"
    echo

    # Create backup
    print_info "Creating backup..."
    mkdir -p "$BACKUP_DIR"
    BACKUP_FILE="nova-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    
    ssh root@${TARGET_HOST} "docker exec ${CONTAINER_NAME} bash -c 'cd ${NOVA_SITE_PACKAGES} && \
        tar czf /tmp/$BACKUP_FILE \
        api/openstack/compute/routes.py \
        compute/manager.py \
        compute/rpcapi.py \
        virt/libvirt/driver.py \
        objects/request_spec.py \
        scheduler/utils.py 2>/dev/null || true'" 2>/dev/null
    
    if scp root@${TARGET_HOST}:/tmp/$BACKUP_FILE "$BACKUP_DIR/" 2>/dev/null; then
        print_info "Backup saved to: $BACKUP_DIR/$BACKUP_FILE"
    else
        print_warn "Could not create backup (files may not exist yet)"
    fi
    echo

    # Deploy new files
    print_info "========================================="
    print_info "Deploying New Files (5 files)"
    print_info "========================================="
    
    NEW_FILES=(
        "nova/api/openstack/compute/xloud_adjust.py:${NOVA_SITE_PACKAGES}/api/openstack/compute/xloud_adjust.py"
        "nova/api/validation/extra_specs/minimum.py:${NOVA_SITE_PACKAGES}/api/validation/extra_specs/minimum.py"
        "nova/policies/xloud_adjust.py:${NOVA_SITE_PACKAGES}/policies/xloud_adjust.py"
        "nova/tests/functional/libvirt/test_vcpu_current.py:${NOVA_SITE_PACKAGES}/tests/functional/libvirt/test_vcpu_current.py"
    )

    for entry in "${NEW_FILES[@]}"; do
        src="${entry%%:*}"
        dst="${entry##*:}"
        deploy_file "$src" "$dst" || exit 1
    done
    echo

    # Deploy modified files
    print_info "========================================="
    print_info "Deploying Modified Files (13 core files)"
    print_info "========================================="
    
    MODIFIED_FILES=(
        "nova/api/openstack/compute/routes.py:${NOVA_SITE_PACKAGES}/api/openstack/compute/routes.py"
        "nova/compute/api.py:${NOVA_SITE_PACKAGES}/compute/api.py"
        "nova/compute/instance_actions.py:${NOVA_SITE_PACKAGES}/compute/instance_actions.py"
        "nova/compute/manager.py:${NOVA_SITE_PACKAGES}/compute/manager.py"
        "nova/compute/rpcapi.py:${NOVA_SITE_PACKAGES}/compute/rpcapi.py"
        "nova/objects/request_spec.py:${NOVA_SITE_PACKAGES}/objects/request_spec.py"
        "nova/scheduler/utils.py:${NOVA_SITE_PACKAGES}/scheduler/utils.py"
        "nova/policies/__init__.py:${NOVA_SITE_PACKAGES}/policies/__init__.py"
        "nova/virt/driver.py:${NOVA_SITE_PACKAGES}/virt/driver.py"
        "nova/virt/libvirt/config.py:${NOVA_SITE_PACKAGES}/virt/libvirt/config.py"
        "nova/virt/libvirt/driver.py:${NOVA_SITE_PACKAGES}/virt/libvirt/driver.py"
        "nova/virt/libvirt/guest.py:${NOVA_SITE_PACKAGES}/virt/libvirt/guest.py"
    )

    for entry in "${MODIFIED_FILES[@]}"; do
        src="${entry%%:*}"
        dst="${entry##*:}"
        deploy_file "$src" "$dst" || exit 1
    done
    echo

    # Verify deployment
    print_info "========================================="
    print_info "Verifying Deployment"
    print_info "========================================="
    
    print_info "Checking new files..."
    printf "  xloud_adjust.py (API): "
    verify_file "${NOVA_SITE_PACKAGES}/api/openstack/compute/xloud_adjust.py"
    
    printf "  minimum.py (validator): "
    verify_file "${NOVA_SITE_PACKAGES}/api/validation/extra_specs/minimum.py"
    
    printf "  xloud_adjust.py (policy): "
    verify_file "${NOVA_SITE_PACKAGES}/policies/xloud_adjust.py"
    
    echo
    print_info "Checking xloud code markers in modified files..."
    
    printf "  routes.py: "
    verify_file "${NOVA_SITE_PACKAGES}/api/openstack/compute/routes.py" "xloud"
    
    printf "  compute/manager.py: "
    verify_file "${NOVA_SITE_PACKAGES}/compute/manager.py" "xloud_adjust"
    
    printf "  virt/libvirt/driver.py: "
    verify_file "${NOVA_SITE_PACKAGES}/virt/libvirt/driver.py" "xloud_adjust"
    
    echo
    print_info "Testing Python imports..."
    
    if ssh root@${TARGET_HOST} "docker exec ${CONTAINER_NAME} python3 -c 'from nova.api.openstack.compute import xloud_adjust'" 2>/dev/null; then
        print_info "✓ xloud_adjust import successful"
    else
        print_error "✗ xloud_adjust import failed"
    fi
    
    if ssh root@${TARGET_HOST} "docker exec ${CONTAINER_NAME} python3 -c 'from nova.api.validation.extra_specs import minimum'" 2>/dev/null; then
        print_info "✓ minimum validator import successful"
    else
        print_error "✗ minimum validator import failed"
    fi
    
    echo
    print_info "========================================="
    print_info "Deployment Complete!"
    print_info "========================================="
    echo
    print_warn "IMPORTANT: Next Steps:"
    echo "  1. Update setup.cfg to register minimum validator"
    echo "  2. Restart Nova services:"
    echo "     ssh root@${TARGET_HOST} 'docker restart nova_api nova_conductor nova_scheduler'"
    echo "  3. Test the deployment with a test flavor"
    echo "  4. Check Nova logs for any errors"
    echo
    print_info "Backup location: $BACKUP_DIR/$BACKUP_FILE"
    echo
}

# Run main function
main "$@"