# Destra-DGPU - Alpha 

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)


Destra-DGPU is a Python package for starting and managing a GPU Worker Node in the Destra GPU Network. 

This library is designed to handle all things related to Destra GPU Worker Node, including installing the NVidia drivers for the available GPUs, installing all the required dependency libraries, starting the GPU Worker Node, registering with the Destra GPU Registry, and stopping the GPU Worker Node.

## Smart Contract
- Destra GPU Registry:   0x9B1B198C5C671F8B5a67721cC4Fff5E9F020D505 ([deployed on testnet](https://sepolia.etherscan.io/address/0x9B1B198C5C671F8B5a67721cC4Fff5E9F020D505))

## Prerequisites

- Ubuntu system
- NVidia GPU
- Stable internet connection
- Sepolia RPC
- Wallet with 0.2 Sepolia ETH


## Setup Instructions

### 1. Clone the GitHub Repository

First, clone the GitHub repository to your local machine.

```sh
git clone https://github.com/DestraNetwork/destra-dgpu.git
cd destra-dgpu
```

### 2. Run the `install_drivers.sh` Script

This script installs the necessary drivers for your GPU. Ensure you have the necessary permissions to execute the script.

```sh
cd destra-dgpu
chmod +x install_drivers.sh
sudo ./install_drivers.sh
```

### 3. Install Python 3.9.6

Ensure you have Python 3.9.6 installed. You can either install from source or use `pyenv` to manage your Python versions.

#### Install from Source (Recommended)

1. **Install Required Build Tools**:

    ```sh
    sudo apt-get update
    sudo apt-get install build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev curl libbz2-dev
    ```

2. **Download and Extract Python Source Code**:

    ```sh
    cd /usr/src
    sudo wget https://www.python.org/ftp/python/3.9.6/Python-3.9.6.tgz
    sudo tar xzf Python-3.9.6.tgz
    ```

3. **Build and Install Python**:

    ```sh
    cd Python-3.9.6
    sudo ./configure --enable-optimizations
    sudo make altinstall
    ```

#### Or Using `pyenv`

1. **Install `pyenv`**:

    ```sh
    curl https://pyenv.run | bash
    ```

    Add the following lines to your shell configuration file (e.g., `~/.bashrc`, `~/.zshrc`):

    ```sh
    export PATH="$HOME/.pyenv/bin:$PATH"
    eval "$(pyenv init --path)"
    eval "$(pyenv init -)"
    eval "$(pyenv virtualenv-init -)"
    ```

    Restart your shell or source the configuration file:

    ```sh
    source ~/.bashrc
    source ~/.zshrc
    ```

2. **Install Python 3.9.6**:

    ```sh
    pyenv install 3.9.6
    pyenv global 3.9.6
    ```

### 4. Set Up a Virtual Environment

Create and activate a virtual environment for your project.

```sh
python3.9 -m venv dgpu-env
source dgpu-env/bin/activate
```

### 5. Install the Destra-DGPU Package

Install the `destra-dgpu` package from the provided wheel file.

```sh
cd ~/destra-dgpu
pip install destra-dgpu/destra_dgpu-0.1.0-cp39-cp39-linux_x86_64.whl
```

### 6. Set Environment Variables

Set the environment variable `NODE_OPERATOR_PRIVATE_KEY` with your private key. Replace `YourPrivateKeyHere` with your actual private key (without the `0x` prefix). Ensure atleast 0.2 Sepolia ETH.

```sh
export NODE_OPERATOR_PRIVATE_KEY=YourPrivateKeyHere
```

### 7. Start the GPU Worker Node

It is recommended to use `tmux` to manage the session and keep the GPU worker node running in the background.

1. **Install `tmux`**:

    ```sh
    sudo apt-get install tmux
    ```

2. **Start a new `tmux` session**:

    ```sh
    tmux new -s destra-gpu
    ```

3. **Start the GPU worker node**. Replace `<destra_gpu_registry_contract_address>` and `<rpc_url>` with the appropriate values.

    ```sh
    destra-gpu-start-worker <destra_gpu_registry_contract_address> <rpc_url>
    ```

    Example:

    ```sh
    destra-gpu-start-worker 0x9B1B198C5C671F8B5a67721cC4Fff5E9F020D505 https://sepolia.infura.io/v3/<YOUR_INFURA_KEY>
    ```

4. **Detach from the `tmux` session** by pressing `Ctrl+b`, then `d`. This will keep the session running in the background.

    To reattach to the session later, use:

    ```sh
    tmux attach -t destra-gpu
    ```
### 8. Stop the GPU Worker Node

To stop the GPU worker node, run the following command from anywhere:

```sh
destra-gpu-stop-worker
```

## Troubleshooting

If you encounter any issues, ensure that:

- The environment variables are set correctly.
- The necessary dependencies are installed.
- The correct Python version is being used.
- You have a NVidia GPU
- The `install_drivers.sh` script was executed successfully.
- If you run a node with incompatible GPU or w/o GPU, no tasks will be assigned.

If you still face any issues, contact us on our telegram channel.