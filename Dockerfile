FROM ubuntu:24.04


##
## Ansible Setup
##

ENV ANSIBLE_VERSION=11.10.0-1ppa~noble

# Install prerequisites
RUN apt update
RUN apt install -y software-properties-common

# Add the Ansible PPA repository and install ansible
RUN add-apt-repository --yes --update ppa:ansible/ansible
RUN apt install -y ansible=${ANSIBLE_VERSION}

# Ansible working directory.
RUN mkdir /ansible
WORKDIR /ansible
VOLUME [ "/ansible" ]

# This workaround prevents the warning, that Ansible is running in a world
# writable folder. This is because of the Windows mount behavior into the Linux
# container.
ENV ANSIBLE_CONFIG=/ansible/ansible.cfg


##
## PowerShell Setup
##

ENV POWERSHELL_OS_VER=24.04

# Update the list of packages
RUN apt update
RUN apt install -y wget apt-transport-https software-properties-common

# Register the Microsoft repository
RUN wget -q https://packages.microsoft.com/config/ubuntu/${POWERSHELL_OS_VER}/packages-microsoft-prod.deb
RUN dpkg -i packages-microsoft-prod.deb
RUN rm packages-microsoft-prod.deb

# Finally install PowerShell
RUN apt update
RUN apt install -y powershell


##
## SSH Setup
##

# Add the dos2unix (convert Windows line endings to linux line endings for the
# ssh key files)
RUN apt install -y dos2unix

# Volume for the SSH key mount, will be copied to ~/.ssh by the entrypoint
# script, because the permissions must be fixed if mounted on a Windows hosts.
RUN mkdir /ansible/.ssh
VOLUME [ "/tmp/.ssh" ]


##
## Startup
##

COPY entrypoint.sh /bin/entrypoint.sh

ENTRYPOINT [ "/bin/entrypoint.sh", "bash" ]
