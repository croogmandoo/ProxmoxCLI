# ProxmoxVE PowerShell Module

This PowerShell module provides cmdlets to interact with the Proxmox Virtual Environment (PVE) API. It allows for automation of various Proxmox VE management tasks.

**Note:** This is an initial version and currently uses simulated API calls. Functionality will be expanded and integrated with the live Proxmox VE API in future updates.

## Features (Simulated)

*   Connect to and disconnect from a Proxmox VE server.
*   Retrieve lists of Virtual Machines (VMs) and LXC Containers.
*   Start and stop VMs and LXC Containers.
*   Create new VMs and LXC Containers with basic options.

## Installation

1.  **Download:** Obtain the `ProxmoxVE` module directory.
2.  **Module Path:** Place the `ProxmoxVE` directory into one of your PowerShell module paths. Common paths include:
    *   Current User: `$HOME\Documents\WindowsPowerShell\Modules` or `$HOME\.config\powershell\Modules` (PowerShell 6+)
    *   All Users: `C:\Program Files\WindowsPowerShell\Modules` or `/usr/local/share/powershell/Modules` (PowerShell 6+)
3.  **Import:**
    ```powershell
    Import-Module ProxmoxVE
    ```

## Basic Usage Examples

```powershell
# Import the module
Import-Module ProxmoxVE

# Connect to your Proxmox VE server (replace with your details)
$Password = Read-Host -AsSecureString "Enter your Proxmox VE password"
Connect-PVEReal -Server "your-proxmox-ip-or-hostname" -User "root@pam" -Password $Password

# Get all VMs
Get-PVEVM

# Get all LXC Containers on a specific node
Get-PVELXC -Node "pve1"

# Start a VM
Start-PVEVM -Node "pve1" -VMID 100

# Stop an LXC Container
Stop-PVELXC -Node "pve1" -ContainerID 102

# Create a new VM (parameters are examples, adjust as needed)
# Ensure your Proxmox storage and ISO paths are correct
New-PVEVM -Node "pve1" -VMID 700 -Name "my-new-vm" -ISO "local:iso/ubuntu-server.iso" -Storage "local-lvm" -Memory 2048 -Cores 2 -Network "virtio,bridge=vmbr0" -StartOnCreate

# Create a new LXC Container
# Ensure your Proxmox storage and template paths are correct
$LxcPassword = Read-Host -AsSecureString "Enter password for LXC root"
New-PVELXC -Node "pve1" -VMID 701 -Hostname "my-new-lxc" -Template "local:vztmpl/alpine-base.tar.gz" -Storage "local-lvm" -Password $LxcPassword -Memory 512 -Network "name=eth0,bridge=vmbr0,ip=dhcp" -StartOnCreate

# Disconnect the session
Disconnect-PVEReal
```

## Available Cmdlets

*   `Connect-PVEReal`
*   `Disconnect-PVEReal`
*   `Get-PVEVM`
*   `Get-PVELXC`
*   `New-PVEVM`
*   `New-PVELXC`
*   `Start-PVEVM`
*   `Start-PVELXC`
*   `Stop-PVEVM`
*   `Stop-PVELXC`
*   `Get-PVERoot` (initial placeholder)

## Contributing

Contributions are welcome! Please refer to the project repository for guidelines. (Link to be added if this becomes a public project).

## License

This module is licensed under the MIT License. See the LICENSE file for details.
