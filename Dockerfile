FROM ubuntu:24.04


##
## PowerShell Setup
## https://learn.microsoft.com/en-us/powershell/scripting/install/install-ubuntu
##

# Install prerequisites
RUN apt update && apt install -y \
    wget \
    apt-transport-https \
    software-properties-common

# Register the Microsoft repository
RUN . /etc/os-release && \
    wget -q https://packages.microsoft.com/config/ubuntu/$VERSION_ID/packages-microsoft-prod.deb && \
    dpkg -i packages-microsoft-prod.deb && \
    rm packages-microsoft-prod.deb

# Finally install PowerShell
RUN apt update && apt install -y \
    powershell


##
## SSH Setup
##

# Add the dos2unix (convert Windows line endings to linux line endings for the
# ssh key files)
RUN apt update && apt install -y \
    dos2unix

# Volume for the SSH key mount, will be copied to ~/.ssh by the entrypoint
# script, because the permissions must be fixed if mounted on a Windows hosts.
RUN mkdir /tmp/.ssh
VOLUME [ "/tmp/.ssh" ]


##
## Ansible Setup
##


# The Ansible version to install, must be specified for the build. Currently
# supported and tested versions as of September 2025 are:
# - 11.10.0-1ppa~noble
#   https://github.com/ansible-community/ansible-build-data/blob/main/11/CHANGELOG-v11.md
ARG ANSIBLE_VERSION

# Install prerequisites
RUN apt update && apt install -y \
    software-properties-common

# Add the Ansible PPA repository with the desired major version
RUN ANSIBLE_VERSION_MAJOR=${ANSIBLE_VERSION%%.*} && \
    add-apt-repository --yes ppa:ansible/ansible-${ANSIBLE_VERSION_MAJOR}

# Install Ansible
RUN apt update && apt install -y \
    ansible=${ANSIBLE_VERSION}-1ppa~noble

# Ansible working directory to be mounted on runtime
RUN mkdir /ansible
WORKDIR /ansible
VOLUME [ "/ansible" ]

# This workaround prevents the warning, that Ansible is running in a world
# writable folder. This is because of the Windows mount behavior into the Linux
# container cannot be set with permissions Ansible requires.
ENV ANSIBLE_CONFIG=/ansible/ansible.cfg


##
## Startup
##

COPY entrypoint.sh /bin/entrypoint.sh

ENTRYPOINT [ "/bin/entrypoint.sh", "bash" ]
