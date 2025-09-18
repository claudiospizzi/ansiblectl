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
Start-AnsibleCtl -RepositoryPath 'D:\Workspace\AnsibleRepo' -AnsibleVersion '11.10.0' -SshKeys1Password 'Work'
```

## Prerequisites

To use ansiblectl, you need to have the following prerequisites installed on your Windows machine:

- Docker Desktop  
  This provides the runtime environment for the container. For more details on the Docker Desktop setup, licensing term, etc. please refer to the official [Docker Desktop documentation](https://docs.docker.com/desktop/).

- AnsibleCtl PowerShell Module  
  This module simplifies the interaction with the ansiblectl container.

- Ansible Repository  
  This is your Ansible project directory containing playbooks, inventory files, roles, etc. It will be mounted as a volume into the container. Normally it also requires some SSH keys to access remote hosts.

## Versions

These are the currently maintained versions of Ansible in ansiblectl, as described in the [Ansible Releases](https://docs.ansible.com/ansible/latest/reference_appendices/release_and_maintenance.html#ansible-community-changelogs) documentation:

- `12.0.0` (latest)  
  Ansible 12.x with core 2.19 is the current latest stable release.

- `11.10.0`  
  Ansible 11.x with core 2.18 is in extended maintenance.

- `10.7.0`  
  Ansible 10.x with core 2.17 even unmaintained (end of life) is still available in ansiblectl.

## Features

### Ansible Repository

The Ansible repository is mounted as a volume into the container. By default, the current working directory is used as the repository path. You can change this by specifying the `-RepositoryPath` parameter of the `Start-AnsibleCtl` cmdlet. This allows running multiple Ansible Control sessions on the same machine.

### SSH Key Handling

Most of the time, Ansible uses SSH to connect to remote hosts. The AnsibleCtl PowerShell module provides different ways to inject SSH keys into the container. The keys are mounted from the ansiblectl cache into the container at `/tmp/.ssh` and copied to the root's SSH directory (`/root/.ssh`) with the correct permissions when the container starts. The keys in the ansiblectl cache will be deleted automatically after the operation.

At the moment, there is no known way to use forwarding of SSH agents like the Windows built-in or 1Password into the Docker Desktop container on Windows. For improvements or suggestions, please open an issue.

The following options are available:

- **File System**  
  By default, the SSH keys from the user's home directory (`$HOME/.ssh`) are mounted into the container. This is the simplest way to provide SSH keys. This can be changed by specifying the `-SshKeysFilePath` parameter of the `Start-AnsibleCtl` cmdlet.

- **1Password**  
  If you use 1Password to manage your SSH keys, you can specify the 1Password item name or id using the `-SshKeys1Password` parameter of the `Start-AnsibleCtl` cmdlet. This allows the module to retrieve the SSH keys from 1Password and inject them into the container.

- **No SSH Keys**  
  If your Ansible repository does not require any SSH keys, you can specify the `-NoSshKeys` switch parameter of the `Start-AnsibleCtl` cmdlet. This will start the container without any SSH keys.

### Customer Container Image

If you need to customize the container image, you can build your own image using a custom Dockerfile. It's recommended to start from a baseline `ansiblectl` image and add your dependencies. The AnsibleCtl PowerShell module provides the `-DockerfilePath` parameter of the `Start-AnsibleCtl` cmdlet to specify the path to your Dockerfile. The command will build the container image from the specified Dockerfile and use it to start the container.

### Bash History

The bash history is persisted between container sessions. The history file is stored in the Ansible repository path as `.ansiblectl_bash_history`. This allows you to have a consistent bash history across multiple sessions.

### PowerShell

The latest PowerShell version is installed in the container.

### Container Image Versions

The AnsibleCtl PowerShell module allows you to specify the Ansible version to use with the parameter `-AnsibleVersion` using the `Start-AnsibleCtl` cmdlet. The version corresponds to the tag of the container image. The following list shows the generated tags.

- `latest`  
  This is set to the latest stable Ansible and AnsibleCtl version.
- `<AnsibleVersion>`  
  This tag corresponds to the specified Ansible community package release version. It's always used as a three-digit version number. Verify the official [Releases and maintenance - Ansible community changelogs](https://docs.ansible.com/ansible/latest/reference_appendices/release_and_maintenance.html#ansible-community-changelogs) for available versions.
- `<AnsibleVersion>-<AnsibleCtlVersion>`  
  This tag combines the Ansible version with the AnsibleCtl version. This is useful to ensure that you are using a specific AnsibleCtl version along with a specific Ansible version is used.
- `<AnsibleVersion>-ci`  
  This tag is generated for the preview releases of every CI build and always points to the latest CI build for the specified Ansible version.
- `<AnsibleVersion>-<GitCommitId>-ci`  
  This tag is generated for preview releases of every CI build and combines the Ansible version with the Git commit ID of the current build.

The following placeholders are used in the tags:

- `<AnsibleVersion>`  
  The version of Ansible (e.g. `11.10.0`, `12.0.0`, etc.).
- `<AnsibleCtlVersion>`  
  The version of the AnsibleCtl itself, always semantic versioning (e.g. `1.0.0`, etc.).
- `<GitCommitId>`  
  The short Git commit ID of the current build (e.g. `a1b2c3d`, etc.).  
