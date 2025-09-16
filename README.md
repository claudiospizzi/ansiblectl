# Ansible Control (ansiblectl)

The Ansible Control (ansiblectl) provides a **lightweight containerized** environment to run **Ansible** on **Windows**. It consists of two main components which together allows you to run Ansible

- Container Image  
  The container image is based on Ubuntu and includes Ansible along with commonly used dependencies. It's available on Docker Hub as [`claudiospizzi/ansiblectl`](https://hub.docker.com/u/claudiospizzi/ansiblectl) and on GitHub Container Registry as [`ghcr.io/claudiospizzi/ansiblectl`](https://github.com/claudiospizzi/ansiblectl).

- PowerShell Module  
  The PowerShell module provides a simple way to interactively start the Ansible Control container image and manage SSH keys, Ansible repositories, etc. It's available on the PowerShell Gallery as [`AnsibleCtl`](https://www.powershellgallery.com/packages/AnsibleCtl).

## Prerequisites

To use ansiblectl, you need to have the following prerequisites installed on
your Windows machine:

- Docker Desktop  
  This provides the runtime environment for the container.

- AnsibleCtl PowerShell Module  
  This module simplifies the interaction with the ansiblectl container.

## Getting Started

Assuming, Docker Desktop is installed and ready, use the following command to install the AnsibleCtl PowerShell module from the PowerShell Gallery and start the ansiblectl container:

```powershell
# Install the PowerShell module
Install-Module -Name 'AnsibleCtl' -Scope 'CurrentUser'

# Start the Ansible Control with only default values. Use SSH Keys from $HOME,
# the current path as Ansible repository and the latest Ansible Control
# container image version. The command `ansiblectl` is an Alias for the full
# cmdlet name `Start-AnsibleCtl`.
ansiblectl
```

## Features

### Ansible Repository

ToDo.

### SSH Key Handling

ToDo.

### Customer Container Image

ToDo.

### Bash History

ToDo.

### PowerShell

If required, the latest PowerShell version is also installed in the container.
