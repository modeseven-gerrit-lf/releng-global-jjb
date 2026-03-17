#!/bin/bash
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2016 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################

# Detect OS using /etc/os-release (works on all modern distros)
# Falls back to facter for legacy images that still have it installed
if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    OS=$(echo "$ID" | tr '[:upper:]' '[:lower:]')
    OS_RELEASE="$VERSION_ID"
elif command -v facter > /dev/null 2>&1; then
    OS=$(facter operatingsystem | tr '[:upper:]' '[:lower:]')
    OS_RELEASE=$(facter lsbdistrelease | tr '[:upper:]' '[:lower:]')
else
    echo "ERROR: Unable to detect OS: /etc/os-release not found and facter not installed"
    exit 1
fi

if [[ "$OS_RELEASE" == "18.04" && "$OS" == 'ubuntu' ]]; then
    # We do not want var expansion here as profile script expands at runtime.
    # shellcheck disable=SC2016
    echo 'export PATH=$HOME/.local/bin:$PATH' >> /etc/profile
fi

useradd -m -s /bin/bash jenkins

if grep -q docker /etc/group; then
    usermod -a -G docker jenkins
fi

# Used for building RPMs
if grep -q mock /etc/group; then
    usermod -a -G mock jenkins
fi

mkdir /home/jenkins/.ssh
# Find the default cloud user's authorized_keys to copy to jenkins user
if [ -f "/home/${OS}/.ssh/authorized_keys" ]; then
    cp "/home/${OS}/.ssh/authorized_keys" /home/jenkins/.ssh/authorized_keys
elif [ -f "/home/ubuntu/.ssh/authorized_keys" ]; then
    cp /home/ubuntu/.ssh/authorized_keys /home/jenkins/.ssh/authorized_keys
elif [ -f "/home/centos/.ssh/authorized_keys" ]; then
    cp /home/centos/.ssh/authorized_keys /home/jenkins/.ssh/authorized_keys
else
    echo "ERROR: Unable to find authorized_keys for default cloud user"
    exit 1
fi
chmod 0600 /home/jenkins/.ssh/authorized_keys

# Generate ssh key for use by Robot jobs
echo -e 'y\n' | ssh-keygen -N "" -f /home/jenkins/.ssh/id_rsa -t rsa
chown -R jenkins:jenkins /home/jenkins/.ssh
chmod 0700 /home/jenkins/.ssh

# The '/w' volume may already be part of image
[[ ! -d '/w' ]] && mkdir /w
chown -R jenkins:jenkins /w
