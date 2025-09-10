FROM ubuntu:24.04

ENV ANSIBLE_VERSION=11.10.0-1ppa~noble

RUN apt update

RUN apt install -y software-properties-common

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
## SSH Setup
##

# Add the dos2unix (convert Windows line endings to linux line endings for the
# ssh key files)
RUN apt install -y dos2unix

# Volume for the SSH key mount, will be copied to ~/.ssh by the entrypoint
# script, because the permissions must be fixed if mounted on a Windows hosts.
RUN mkdir /ansible/.ssh
VOLUME [ "/tmp/.ssh" ]


COPY entrypoint.sh /bin/entrypoint.sh


ENTRYPOINT [ "/bin/entrypoint.sh", "bash" ]
