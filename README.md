[![GitHub Release](https://img.shields.io/github/v/release/claudiospizzi/ansiblectl?label=Release&logo=GitHub&sort=semver)](https://github.com/claudiospizzi/ansiblectl/releases)
[![GitHub CI Build](https://img.shields.io/github/actions/workflow/status/claudiospizzi/ansiblectl/pwsh-ci.yml?label=CI%20Build&logo=GitHub)](https://github.com/claudiospizzi/ansiblectl/actions/workflows/pwsh-ci.yml)
[![PowerShell Gallery Version](https://img.shields.io/powershellgallery/v/AnsibleCtl?label=PowerShell%20Gallery&logo=PowerShell)](https://www.powershellgallery.com/packages/AnsibleCtl)
[![Gallery Downloads](https://img.shields.io/powershellgallery/dt/AnsibleCtl?label=Downloads&logo=PowerShell)](https://www.powershellgallery.com/packages/AnsibleCtl)

# Ansible Control (ansiblectl)

The Ansible Control (ansiblectl) provides a **lightweight containerized** environment to run **Ansible** on **Windows**. It consists of two main components which together allows you to run Ansible.

- **Container Image**  
  The ansiblectl container image is based on Ubuntu and includes Ansible along with commonly used dependencies. It's available on the GitHub Container Registry as [`ghcr.io/claudiospizzi/ansiblectl`](https://github.com/claudiospizzi/ansiblectl).

- **PowerShell Module**  
  The PowerShell module provides a simple way to interactively start the Ansible Control container image. It's solves the task of manage and inject SSH keys into the container, Ansible repository volume mounting, bash history, etc. It's available on the PowerShell Gallery as [`AnsibleCtl`](https://www.powershellgallery.com/packages/AnsibleCtl).

## Prerequisites

To use ansiblectl, you need to have the following prerequisites installed on your Windows machine:

- Docker Desktop  
  This provides the runtime environment for the container. For more details on the Docker Desktop setup, licensing term, etc. please refer to the official [Docker Desktop documentation](https://docs.docker.com/desktop/).

- AnsibleCtl PowerShell Module  
  This module simplifies the interaction with the ansiblectl container.

- Ansible Repository  
  This is your Ansible project directory containing playbooks, inventory files, roles, etc. It will be mounted as a volume into the container. Normally it also requires some SSH keys to access remote hosts.

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

# Using the full cmdlet name with custom parameters for the Ansible repository
# path, the Ansible version and the 1Password SSH key item name.
Start-AnsibleCtl -RepositoryPath 'D:\Workspace\AnsibleRepo' -AnsibleVersion '11.10.0' -OnePasswordSshKeys 'Work'
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

The latest PowerShell version is also installed in the container.
