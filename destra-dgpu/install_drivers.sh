#!/bin/bash

# Utility functions
status() {
    echo "STATUS: $1"
}

warning() {
    echo "WARNING: $1" >&2
}

error() {
    echo "ERROR: $1" >&2
    exit 1
}

install_success() {
    echo "INSTALLATION SUCCESSFUL"
}

available() {
    command -v "$1" >/dev/null 2>&1
}

# Check for available tools and GPU presence
if ! available lspci && ! available lshw; then
    warning "Unable to detect NVIDIA GPU. Install lspci or lshw to automatically detect and install GPU drivers."
    exit 0
fi

check_gpu() {
    case $1 in
        lspci) 
            case $2 in
                nvidia) available lspci && lspci -d '10de:' | grep -q 'NVIDIA' || return 1 ;;
                amdgpu) available lspci && lspci -d '1002:' | grep -q 'AMD' || return 1 ;;
            esac ;;
        lshw) 
            case $2 in
                nvidia) available lshw && sudo lshw -c display -numeric | grep -q 'vendor: .* \[10DE\]' || return 1 ;;
                amdgpu) available lshw && sudo lshw -c display -numeric | grep -q 'vendor: .* \[1002\]' || return 1 ;;
            esac ;;
        nvidia-smi) available nvidia-smi || return 1 ;;
    esac
}

if check_gpu nvidia-smi; then
    status "NVIDIA GPU detected and drivers are already installed."
    exit 0
fi

if ! check_gpu lspci && ! check_gpu lshw; then
    warning "No NVIDIA or AMD GPU detected. Destra-DGPU will run in CPU-only mode."
    exit 0
fi

# AMD GPU Check
if check_gpu lspci amdgpu || check_gpu lshw amdgpu; then
    # Look for pre-existing ROCm v6 before downloading the dependencies
    for search in "${HIP_PATH:-''}" "${ROCM_PATH:-''}" "/opt/rocm"; do
        if [ -n "${search}" ] && [ -e "${search}/lib/libhipblas.so.2" ]; then
            status "Compatible AMD GPU ROCm library detected at ${search}"
            install_success
            exit 0
        fi
    done

    status "Downloading AMD GPU dependencies..."
    curl --fail --show-error --location --progress-bar -o /tmp/ "https://example.com/path/to/rocm-dependencies.tgz" \
        | sudo tar zx -C /tmp/rocm .

    status "Installing AMD GPU dependencies to /opt/rocm..."
    sudo install -o0 -g0 -m755 -d /opt/rocm
    sudo cp -r /tmp/rocm/* /opt/rocm/

    install_success
    status "AMD GPU dependencies installed."
    exit 0
fi

# CUDA Driver Installation for RHEL/CentOS/Fedora
install_cuda_driver_yum() {
    status 'Installing NVIDIA repository...'
    case $PACKAGE_MANAGER in
        yum)
            sudo $PACKAGE_MANAGER -y install yum-utils
            sudo $PACKAGE_MANAGER-config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/$1$2/$(uname -m)/cuda-$1$2.repo
            ;;
        dnf)
            sudo $PACKAGE_MANAGER config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/$1$2/$(uname -m)/cuda-$1$2.repo
            ;;
    esac

    case $1 in
        rhel)
            status 'Installing EPEL repository...'
            sudo $PACKAGE_MANAGER -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-$2.noarch.rpm || true
            ;;
    esac

    status 'Installing CUDA driver...'

    if [ "$1" = 'centos' ] || [ "$1$2" = 'rhel7' ]; then
        sudo $PACKAGE_MANAGER -y install nvidia-driver-latest-dkms
    fi

    sudo $PACKAGE_MANAGER -y install cuda-drivers
}

# CUDA Driver Installation for Debian/Ubuntu
install_cuda_driver_apt() {
    status 'Installing NVIDIA repository...'
    curl -fsSL -o /tmp/cuda-keyring.deb https://developer.download.nvidia.com/compute/cuda/repos/$1$2/$(uname -m)/cuda-keyring_1.1-1_all.deb

    case $1 in
        debian)
            status 'Enabling contrib sources...'
            sudo sed 's/main/contrib/' < /etc/apt/sources.list | sudo tee /etc/apt/sources.list.d/contrib.list > /dev/null
            if [ -f "/etc/apt/sources.list.d/debian.sources" ]; then
                sudo sed 's/main/contrib/' < /etc/apt/sources.list.d/debian.sources | sudo tee /etc/apt/sources.list.d/contrib.sources > /dev/null
            fi
            ;;
    esac

    status 'Installing CUDA driver...'
    sudo dpkg -i /tmp/cuda-keyring.deb
    sudo apt-get update

    sudo apt-get -y install cuda-drivers -q
}

if [ ! -f "/etc/os-release" ]; then
    error "Unknown distribution. Skipping CUDA installation."
fi

. /etc/os-release

OS_NAME=$ID
OS_VERSION=$VERSION_ID

PACKAGE_MANAGER=
for PACKAGE_MANAGER in dnf yum apt-get; do
    if available $PACKAGE_MANAGER; then
        break
    fi
done

if [ -z "$PACKAGE_MANAGER" ]; then
    error "Unknown package manager. Skipping CUDA installation."
fi

if ! check_gpu nvidia-smi || [ -z "$(nvidia-smi | grep -o "CUDA Version: [0-9]*\.[0-9]*")" ]; then
    case $OS_NAME in
        centos|rhel) install_cuda_driver_yum 'rhel' $(echo $OS_VERSION | cut -d '.' -f 1) ;;
        rocky) install_cuda_driver_yum 'rhel' $(echo $OS_VERSION | cut -c1) ;;
        fedora) [ $OS_VERSION -lt '37' ] && install_cuda_driver_yum $OS_NAME $OS_VERSION || install_cuda_driver_yum $OS_NAME '37';;
        amzn) install_cuda_driver_yum 'fedora' '37' ;;
        debian) install_cuda_driver_apt $OS_NAME $OS_VERSION ;;
        ubuntu) install_cuda_driver_apt $OS_NAME $(echo $OS_VERSION | sed 's/\.//') ;;
        *) exit ;;
    esac
fi

if ! lsmod | grep -q nvidia; then
    KERNEL_RELEASE="$(uname -r)"
    case $OS_NAME in
        rocky) sudo $PACKAGE_MANAGER -y install kernel-devel kernel-headers ;;
        centos|rhel|amzn) sudo $PACKAGE_MANAGER -y install kernel-devel-$KERNEL_RELEASE kernel-headers-$KERNEL_RELEASE ;;
        fedora) sudo $PACKAGE_MANAGER -y install kernel-devel-$KERNEL_RELEASE ;;
        debian|ubuntu) sudo apt-get -y install linux-headers-$KERNEL_RELEASE ;;
        *) exit ;;
    esac

    NVIDIA_CUDA_VERSION=$(sudo dkms status | awk -F: '/added/ { print $1 }')
    if [ -n "$NVIDIA_CUDA_VERSION" ]; then
        sudo dkms install $NVIDIA_CUDA_VERSION
    fi

    if lsmod | grep -q nouveau; then
        status 'Reboot to complete NVIDIA CUDA driver install.'
        exit 0
    fi

    sudo modprobe nvidia
fi

status "NVIDIA CUDA drivers installed."
