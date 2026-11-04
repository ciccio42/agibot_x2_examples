
#!/bin/bash
set -e

# ============================================================
# AIMDK dependencies
# ============================================================

#AIMDK dependencies
sudo apt update && sudo apt install -y \
    libopencv-dev \
    python3-opencv \
    ros-humble-ruckig \
    libncurses-dev \
    libcurl4-openssl-dev \
    ros-humble-cv-bridge

mkdir agibot_ws
cd agibot_ws

wget https://x2-aimdk.agibot.com/downloads/aimdk-sdk-v1_1_0-aimdk-aarch64-faf4c945-artifacts.zip && \
    unzip aimdk-sdk-v1_1_0-aimdk-aarch64-faf4c945-artifacts.zip && \
    rm -rf aimdk-sdk-v1_1_0-aimdk-aarch64-faf4c945-artifacts.zip && \
    mv aimdk-aarch64-faf4c945-artifacts aimdk

source /opt/ros/humble/setup.bash && colcon build --symlink-install
source install/setup.bash

# ============================================================
#Cleanup
# ============================================================

sudo apt-get clean
sudo rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

echo "AIMDK dependencies installation completed."

# ============================================================
# Configure .bashrc
# ============================================================

AIMDK_SETUP="source $HOME/agibot_x2_examples/agibot_ws/install/setup.bash"

if ! grep -Fxq "$AIMDK_SETUP" ~/.bashrc; then
    echo "$AIMDK_SETUP" >> ~/.bashrc
fi