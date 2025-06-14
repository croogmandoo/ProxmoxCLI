# ProxmoxVE PowerShell Module
# Main module file

$Global:PVERealSession = $null

# Function to connect to Proxmox VE (Live API version)
function Connect-PVEReal {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Server,

        [Parameter(Mandatory=$true)]
        [string]$User,

        [Parameter(Mandatory=$true)]
        [System.Security.SecureString]$Password,

        [string]$Realm = "pam",

        [Parameter()]
        [switch]$SkipCertificateCheck
    )

    Write-Verbose "Attempting to connect to Proxmox VE server: $Server as user: $User@$Realm" # This should be $User, not $User@$Realm if $User is just 'root'

    # Use -f format operator for $apiUrl construction
    $apiUrl = "https://{0}:8006/api2/json/access/ticket" -f $Server
    Write-Verbose "Constructed API URL: $apiUrl" # Added for debugging

    $plainPassword = ConvertFrom-SecureString -SecureString $Password -AsPlainText
    
    $body = @{
        username = $User # Assuming $User is 'root' not 'root@pam'
        password = $plainPassword
        realm = $Realm
    }

    # Clear password from memory as soon as possible
    Clear-Variable plainPassword

    $irmParameters = @{
        Uri = $apiUrl
        Method = 'POST'
        Body = $body
        ContentType = 'application/x-www-form-urlencoded'
        ErrorAction = 'Stop'
    }

    if ($SkipCertificateCheck) {
        Write-Warning "Skipping SSL/TLS certificate validation. This is insecure and should only be used for trusted environments with self-signed certificates."
        $irmParameters.SkipCertificateCheck = $true
    }

    try {
        Write-Verbose "Executing Invoke-RestMethod to $apiUrl" # This will now use the debugged $apiUrl
        $response = Invoke-RestMethod @irmParameters
        
        if ($response.data -and $response.data.ticket -and $response.data.CSRFPreventionToken) {
            $Global:PVERealSession = @{
                Server = $Server
                Ticket = $response.data.ticket
                CSRFToken = $response.data.CSRFPreventionToken
                User = $response.data.username # This is usually user@realm from PVE
                ConnectTime = Get-Date
                SkipCertCheck = $PSBoundParameters['SkipCertificateCheck'].IsPresent
            }
            Write-Host "Successfully connected to Proxmox VE: $Server as $($Global:PVERealSession.User)"
            return $Global:PVERealSession
        } else {
            Write-Error "Authentication failed or unexpected response from server. Response: $($response | ConvertTo-Json -Depth 3)"
            return $null
        }
    } catch {
        Write-Error "Error connecting to Proxmox VE: $($_.Exception.Message)"
        if ($_.Exception.Response) {
            Write-Error "Server Response: $($_.Exception.Response | Out-String)"
        }
        return $null
    }
}

# Minimal Disconnect function for testing
function Disconnect-PVEReal {
    [CmdletBinding()]
    param()
    Write-Host "Disconnect-PVEReal was called."
    $Global:PVERealSession = $null
}

# Function to get Proxmox VE VMs
function Get-PVEVM {
    [CmdletBinding()]
    param(
        [string]$Node
    )

    if ($null -eq $Global:PVERealSession) {
        Write-Error "Not connected to any Proxmox VE server. Please use Connect-PVEReal first."
        return
    }

    Write-Verbose "Getting VMs from server: $($Global:PVERealSession.Server)"

    $apiUrl = ""
    if ($PSBoundParameters.ContainsKey('Node') -and -not ([string]::IsNullOrWhiteSpace($Node))) {
        Write-Verbose "Targeting specific node: $Node for VMs"
        $apiUrl = "https://$($Global:PVERealSession.Server):8006/api2/json/nodes/$Node/qemu"
    } else {
        Write-Verbose "Getting VMs from all resources (cluster view)"
        $apiUrl = "https://$($Global:PVERealSession.Server):8006/api2/json/cluster/resources?type=vm"
    }

    $headers = @{
        "CSRFPreventionToken" = $Global:PVERealSession.CSRFToken
        "Cookie" = "PVEAuthCookie=$($Global:PVERealSession.Ticket)"
    }

    $irmParameters = @{
        Uri = $apiUrl
        Method = 'Get'
        Headers = $headers
        ErrorAction = 'Stop'
    }

    # Honor SkipCertificateCheck from the session
    if ($Global:PVERealSession.SkipCertCheck -eq $true) {
        Write-Verbose "Honoring SkipCertificateCheck for this Get-PVEVM call."
        $irmParameters.SkipCertificateCheck = $true
    }

    try {
        Write-Verbose "Executing Invoke-RestMethod GET to $apiUrl"
        $response = Invoke-RestMethod @irmParameters # Using splatting
        
        # Proxmox API often returns data directly if successful and data exists
        # For /cluster/resources, it's directly an array in 'data'
        # For /nodes/{node}/qemu, it's also directly an array in 'data'
        if ($response.data) {
            # Ensure we always output a collection, even if single item from API
            if ($response.data -is [System.Management.Automation.PSCustomObject]) {
                 return @([PSCustomObject]$response.data)
            } else {
                 return $response.data | ForEach-Object { [PSCustomObject]$_ }
            }
        } else {
            Write-Warning "No VMs found or unexpected API response from server (response.data is null or empty)."
            return @() # Return an empty array if no data
        }
    } catch {
        Write-Error "Error getting VMs from Proxmox VE: $($_.Exception.Message)"
        if ($_.Exception.Response) {
            Write-Error "Server Response: $($_.Exception.Response | Out-String)"
        }
        return @() # Return an empty array on error
    }
}

# Function to get Proxmox VE LXC Containers
function Get-PVELXC {
    [CmdletBinding()]
    param(
        [string]$Node
    )

    if ($null -eq $Global:PVERealSession) {
        Write-Error "Not connected to any Proxmox VE server. Please use Connect-PVEReal first."
        return
    }

    Write-Verbose "Getting LXC containers from server: $($Global:PVERealSession.Server)"

    $apiUrl = ""
    if ($PSBoundParameters.ContainsKey('Node') -and -not ([string]::IsNullOrWhiteSpace($Node))) {
        Write-Verbose "Targeting specific node: $Node for LXCs"
        $apiUrl = "https://$($Global:PVERealSession.Server):8006/api2/json/nodes/$Node/lxc"
    } else {
        Write-Verbose "Getting LXCs from all resources (cluster view)"
        # 'ct' is the type for LXC containers in /cluster/resources
        $apiUrl = "https://$($Global:PVERealSession.Server):8006/api2/json/cluster/resources?type=ct" 
    }
    
    $headers = @{
        "CSRFPreventionToken" = $Global:PVERealSession.CSRFToken
        "Cookie" = "PVEAuthCookie=$($Global:PVERealSession.Ticket)"
    }

    $irmParameters = @{
        Uri = $apiUrl
        Method = 'Get'
        Headers = $headers
        ErrorAction = 'Stop'
    }

    # Honor SkipCertificateCheck from the session
    if ($Global:PVERealSession.SkipCertCheck -eq $true) {
        Write-Verbose "Honoring SkipCertificateCheck for this Get-PVELXC call."
        $irmParameters.SkipCertificateCheck = $true
    }

    try {
        Write-Verbose "Executing Invoke-RestMethod GET to $apiUrl"
        $response = Invoke-RestMethod @irmParameters # Using splatting
        
        if ($response.data) {
            # Ensure we always output a collection
            if ($response.data -is [System.Management.Automation.PSCustomObject]) {
                 return @([PSCustomObject]$response.data)
            } else {
                 return $response.data | ForEach-Object { [PSCustomObject]$_ }
            }
        } else {
            Write-Warning "No LXC containers found or unexpected API response from server (response.data is null or empty)."
            return @() # Return an empty array if no data
        }
    } catch {
        Write-Error "Error getting LXC containers from Proxmox VE: $($_.Exception.Message)"
        if ($_.Exception.Response) {
            Write-Error "Server Response: $($_.Exception.Response | Out-String)"
        }
        return @() # Return an empty array on error
    }
}
