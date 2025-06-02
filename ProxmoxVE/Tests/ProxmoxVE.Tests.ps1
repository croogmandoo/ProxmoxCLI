# ProxmoxVE.Tests.ps1
# Pester tests for the ProxmoxVE module

# Import the module being tested.
# Assuming the ProxmoxVE.psd1 is in the parent directory of this Tests directory.
Import-Module ..\ProxmoxVE.psd1 -Force # Use -Force to ensure latest version is loaded

Describe "ProxmoxVE Module" {
    Context "Module Manifest and Exported Functions" {
        $module = Get-Module ProxmoxVE
        It "Module should be loaded" {
            $module | Should -Not -BeNullOrEmpty
        }

        $expectedFunctions = @(
            'Connect-PVEReal',
            'Disconnect-PVEReal',
            'Get-PVEVM',
            'Get-PVELXC',
            'Start-PVEVM',
            'Stop-PVEVM',
            'Start-PVELXC',
            'Stop-PVELXC',
            'New-PVEVM',
            'New-PVELXC',
            'Get-PVERoot' # The initial placeholder
        )
        # Sort both arrays to ensure order doesn't cause test failure
        $exportedFunctions = ($module.ExportedCommands.Keys | Where-Object { $module.ExportedCommands[$_].CommandType -eq 'Function' } | Sort-Object)
        $expectedFunctionsSorted = $expectedFunctions | Sort-Object

        It "Should export the correct functions" {
            $exportedFunctions | Should -Be $expectedFunctionsSorted
        }
    }

    Context "Connect-PVEReal" {
        # Mock Invoke-RestMethod if we were doing real calls
        # For now, we test the simulation
        It "Should simulate connection and return session object" {
            # Note: This requires manual input for SecureString if run interactively without defaults
            # For automated tests, consider how to handle SecureString or use PSCredential
            $password = ConvertTo-SecureString "testpassword" -AsPlainText -Force
            $session = Connect-PVEReal -Server "simhost" -User "simuser" -Password $password -WarningAction Silently
            $session | Should -Not -BeNull
            $session.Server | Should -Be "simhost"
            $session.Ticket | Should -Be "SIMULATED_TICKET"
            # Clean up global session for other tests
            $Global:PVERealSession = $null
        }

        It "Should set Global:PVERealSession on successful connection" {
            $password = ConvertTo-SecureString "testpassword" -AsPlainText -Force
            Connect-PVEReal -Server "simhost2" -User "simuser2" -Password $password -WarningAction Silently | Out-Null
            $Global:PVERealSession | Should -Not -BeNull
            $Global:PVERealSession.Server | Should -Be "simhost2"
            $Global:PVERealSession = $null # Teardown
        }
    }

    Context "Disconnect-PVEReal" {
        It "Should clear Global:PVERealSession" {
            # Setup a dummy session
            $Global:PVERealSession = @{ Server = "simhost"; User = "simuser"; Ticket = "SIM_TICKET_DISCONNECT" }
            Disconnect-PVEReal -WarningAction Silently
            $Global:PVERealSession | Should -BeNull
        }

        It "Should output a message if no active session" {
            $Global:PVERealSession = $null # Ensure no session
            Disconnect-PVEReal -WarningAction Silently | Should -Write "No active Proxmox VE session to disconnect."
        }
    }

    Context "Get-PVEVM / Get-PVELXC (Simulated)" {
        # Setup a dummy session for these tests
        BeforeAll {
            $Global:PVERealSession = @{
                Server = "simtesthost"
                Ticket = "SIMULATED_TICKET_GET"
                CSRFToken = "SIMULATED_CSRF_GET"
                User = "simtestuser@pam"
            }
        }
        AfterAll {
            $Global:PVERealSession = $null # Teardown
        }

        It "Get-PVEVM should return simulated VM data" {
            $vms = Get-PVEVM -WarningAction Silently
            $vms | Should -Not -BeNullOrEmpty
            ($vms[0]).vmid | Should -Be 100
        }

        It "Get-PVELXC should return simulated LXC data" {
            $lxcs = Get-PVELXC -WarningAction Silently
            $lxcs | Should -Not -BeNullOrEmpty
            ($lxcs[0]).vmid | Should -Be 102
        }

        It "Get-PVEVM should require connection" {
            $currentSession = $Global:PVERealSession
            $Global:PVERealSession = $null
            { Get-PVEVM -WarningAction Silently } | Should -Throw "Not connected to any Proxmox VE server. Please use Connect-PVEReal first."
            $Global:PVERealSession = $currentSession # Restore
        }
    }

    Context "Start-PVEVM / Stop-PVEVM (Simulated with ShouldProcess)" {
        BeforeAll {
            $Global:PVERealSession = @{
                Server = "simtesthost"
                Ticket = "SIMULATED_TICKET_ACTION"
                CSRFToken = "SIMULATED_CSRF_ACTION"
                User = "simtestuser@pam"
            }
        }
        AfterAll {
            $Global:PVERealSession = $null # Teardown
        }

        It "Start-PVEVM should return simulated task ID" {
            Start-PVEVM -Node "pve1" -VMID 100 -Confirm:$false -WarningAction Silently | Should -Match "SIMULATED_TASK_ID"
        }

        It "Start-PVEVM should support -WhatIf" {
            { Start-PVEVM -Node "pve1" -VMID 101 -WhatIf -WarningAction Silently } | Should -Write "What if: Performing the operation "Start" on target "VM 101 on node pve1"."
        }

        It "Stop-PVEVM should return simulated task ID" {
            Stop-PVEVM -Node "pve1" -VMID 100 -Confirm:$false -WarningAction Silently | Should -Match "SIMULATED_TASK_ID"
        }
    }

    Context "New-PVEVM (Simulated with ShouldProcess)" {
        BeforeAll {
            $Global:PVERealSession = @{
                Server = "simtesthost"
                Ticket = "SIMULATED_TICKET_NEW"
                CSRFToken = "SIMULATED_CSRF_NEW"
                User = "simtestuser@pam"
            }
        }
        AfterAll {
            $Global:PVERealSession = $null # Teardown
        }

        It "New-PVEVM should return simulated task ID" {
            New-PVEVM -Node "pve1" -VMID 900 -ISO "local:iso/test.iso" -Storage "local-lvm" -Confirm:$false -WarningAction Silently -Verbose:$false | Should -Match "SIMULATED_TASK_ID"
        }

        It "New-PVEVM should show -WhatIf with name" {
            { New-PVEVM -Node "pve1" -VMID 901 -Name "TestVM901" -ISO "local:iso/test.iso" -Storage "local-lvm" -WhatIf -WarningAction Silently -Verbose:$false } | Should -Write "What if: Performing the operation "Create" on target "VM 901 (TestVM901) on node pve1"."
        }
         It "New-PVEVM should show -WhatIf without name" {
            { New-PVEVM -Node "pve1" -VMID 902 -ISO "local:iso/test.iso" -Storage "local-lvm" -WhatIf -WarningAction Silently -Verbose:$false } | Should -Write "What if: Performing the operation "Create" on target "VM 902 (No Name) on node pve1"."
        }
    }

    # Add similar Context blocks for Start-PVELXC, Stop-PVELXC, New-PVELXC
    # For brevity, these are omitted here but would follow the same pattern.
}
