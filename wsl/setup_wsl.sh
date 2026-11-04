#!/bin/bash
set -e

# User and repository paths
USER_NAME="$(id -un)"

REPO_DIR="$HOME/agibot_x2_examples"
WSL_DIR="$REPO_DIR/wsl"

# Request sudo credentials at the beginning
sudo -v

export PATH="$HOME/.local/bin:$PATH"

# Installing ROS
cd "$WSL_DIR"

sudo apt update
sudo apt install -y git

# ROS installation scripts must use sudo only for system operations.
# They must not be executed as root if they modify user files.
bash ros2_humble_install.bash
bash ros2-tools.bash

# System dependencies
sudo apt update
sudo apt install -y \
    iputils-ping \
    net-tools \
    nano \
    gedit \
    x11-apps \
    mlocate \
    python3-pip \
    curl \
    wget \
    sudo \
    ffmpeg \
    git-lfs \
    htop \
    unzip

pip install -U pip

# Additional ROS packages
sudo apt update
sudo apt install -y \
    ros-humble-rviz2 \
    ros-humble-rqt-common-plugins \
    ros-humble-rqt-tf-tree \
    ros-humble-rqt-image-view \
    ros-humble-tf-transformations \
    ros-humble-diagnostic-updater \
    ros-humble-image-transport-plugins \
    ros-humble-angles \
    ros-humble-rmw-fastrtps-cpp

# Transformers
python3 -m pip install --user --ignore-installed \
    datasets \
    torchcodec \
    'transformers[torch]'==4.56.1 \
    bitsandbytes==0.47 \
    accelerate \
    'huggingface_hub[cli]'

# Python utilities
pip install pyOpenssl

# Audio libraries
sudo apt update
sudo apt install -y \
    portaudio19-dev \
    alsa-base \
    alsa-utils

python3 -m pip install --user \
    sounddevice \
    soundfile \
    librosa \
    pyaudio

# ReSpeaker
python3 -m pip install --user \
    pyusb==1.0.2 \
    'click>=8.1.3' \
    pixel-ring==0.1.0

python3 -m pip install --user -U --ignore-installed transforms3d

# YOLO
python3 -m pip install --user --no-deps ultralytics==8.3.220

python3 -m pip install --user \
    torchvision==0.23 \
    'ultralytics-thop>=2.0.0' \
    polars

# Python utilities
python3 -m pip install --user -U \
    httpx \
    pyOpenSSL \
    scipy==1.15.3

# NO MOVE!
pip install numpy==1.26.3 'setuptools<80,>=30.3.0'

# Cleanup
sudo apt-get clean
sudo rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* 
sudo rm -rf /root/.cache

# ROS environment variables
source /opt/ros/humble/setup.bash

# AimDK installation
# Run as the normal user to avoid root-owned files in the workspace.
cd "$REPO_DIR"
bash "$WSL_DIR/install_aimdk.sh"

cat <<'EOF' >> ~/.bashrc

# ROS 2 environment
export REPO_DIR="$HOME/agibot_x2_examples"
export PATH="$HOME/.local/bin:$PATH"

export ROS_LOCALHOST_ONLY=0
export ROS_DOMAIN_ID=0
export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
export FASTRTPS_DEFAULT_PROFILES_FILE="$HOME/agibot_x2_examples/wsl/agi_dds.xml"

ros2 daemon start

EOF

export ROS_LOCALHOST_ONLY=0
export ROS_DOMAIN_ID=0
export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
export FASTRTPS_DEFAULT_PROFILES_FILE="$HOME/agibot_x2_examples/wsl/agi_dds.xml"

# Add user to dialout group
sudo usermod -aG dialout "$USER_NAME"

echo "Installation completed."
echo "Restart the WSL terminal to load the new environment."
