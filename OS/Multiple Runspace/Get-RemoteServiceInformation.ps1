function Get-RemoteServiceInformation {
    <#
    .SYNOPSIS
       Gather remote service information.
    .DESCRIPTION
       Gather remote service information. Uses multiple runspaces and, if required, alternate credentials.
    .PARAMETER ComputerName
       Specifies the target computer for data query.
    .PARAMETER ServiceName
       Specific service name to query.
    .PARAMETER IncludeDriverServices
       Include driver level services.
    .PARAMETER ThrottleLimit
       Specifies the maximum number of systems to inventory simultaneously.
    .PARAMETER Timeout
       Specifies the maximum time in second command can run in background before terminating this thread.
    .PARAMETER ShowProgress
       Show progress bar information.
    .EXAMPLE
       PS > Get-RemoteServiceInformation

       <output>
       
       Description
       -----------
       <Placeholder>
    .NOTES
       Author: Zachary Loeber
       Site: http://www.the-little-things.net/
       Requires: Powershell 2.0

       Version History
       1.0.0 - 08/31/2013
        - Initial release
    #>
    [CmdletBinding()]
    param (
        [Parameter(HelpMessage="Computer or computers to gather information from",ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true, Position=0)]
        [ValidateNotNullOrEmpty()]
        [Alias('DNSHostName','PSComputerName')]
        [string[]]$ComputerName=$env:computername,
        
        [Parameter( ValueFromPipelineByPropertyName=$true, ValueFromPipeline=$true, HelpMessage="The service name to return." )]
        [Alias('Name')]
        [string[]]$ServiceName,
        
        [parameter( HelpMessage="Include the normally hidden driver services. Only applicable when not supplying a specific service name." )]
        [switch]$IncludeDriverServices,
        
        [parameter( HelpMessage="Optional WMI filter")]
        [string]$Filter,
        
        [Parameter(HelpMessage="Maximum number of concurrent threads")]
        [ValidateRange(1,65535)]
        [int32]$ThrottleLimit = 32,
 
        [Parameter(HelpMessage="Timeout before a thread stops trying to gather the information")]
        [ValidateRange(1,65535)]
        [int32]$Timeout = 120,
 
        [Parameter(HelpMessage="Display progress of function")]
        [switch]$ShowProgress,
        
        [Parameter(HelpMessage="Set this if you want the function to prompt for alternate credentials")]
        [switch]$PromptForCredential,
        
        [Parameter(HelpMessage="Set this if you want to provide your own alternate credentials")]
        [System.Management.Automation.PSCredential]$Credential = [System.Management.Automation.PSCredential]::Empty
    )
    begin {
        # Gather possible local host names and IPs to prevent credential utilization in some cases
        Write-Verbose -Message 'Remote Service Information: Creating local hostname list'
        $IPAddresses = [net.dns]::GetHostAddresses($env:COMPUTERNAME) | Select-Object -ExpandProperty IpAddressToString
        $HostNames = $IPAddresses | ForEach-Object {
            try {
                [net.dns]::GetHostByAddress($_)
            }
            catch {}
        } | Select-Object -ExpandProperty HostName -Unique
        $LocalHost = @('', '.', 'localhost', $env:COMPUTERNAME, '::1', '127.0.0.1') + $IPAddresses + $HostNames
 
        Write-Verbose -Message 'Remote Service Information: Creating initial variables'
        $runspacetimers       = [HashTable]::Synchronized(@{})
        $runspaces            = New-Object -TypeName System.Collections.ArrayList
        $bgRunspaceCounter    = 0

        Write-Verbose -Message 'Remote Service Information: Creating Initial Session State'
        $iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
        foreach ($ExternalVariable in ('runspacetimers', 'Credential', 'LocalHost'))
        {
            Write-Verbose -Message "Remote Service Information: Adding variable $ExternalVariable to initial session state"
            $iss.Variables.Add((New-Object -TypeName System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList $ExternalVariable, (Get-Variable -Name $ExternalVariable -ValueOnly), ''))
        }
        
        Write-Verbose -Message 'Remote Service Information: Creating runspace pool'
        $rp = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(1, $ThrottleLimit, $iss, $Host)
        $rp.ApartmentState = 'STA'
        $rp.Open()
 
        # This is the actual code called for each computer
        Write-Verbose -Message 'Remote Service Information: Defining background runspaces scriptblock'
        $ScriptBlock = {
            [CmdletBinding()]
            param (
                [Parameter()]
                [string]$ComputerName,
                [Parameter()]                
                [string[]]$ServiceName,
                [parameter()]
                [switch]$IncludeDriverServices,
                [parameter()]
                [string]$Filter,
                [Parameter()]
                [int]$bgRunspaceID
            )
            $runspacetimers.$bgRunspaceID = Get-Date
            
            try {
                Write-Verbose -Message ('Remote Service Information: Runspace {0}: Start' -f $ComputerName)
                $WMIHast = @{
                    ComputerName = $ComputerName
                    ErrorAction = 'Stop'
                }
                if ($ServiceName -ne $null)
                {
                    $WMIHast.Filter = "Name LIKE '$ServiceName'"
                }
                elseif ($Filter -ne $null)
                {
                    $WMIHast.Filter = $Filter
                }
                if (($LocalHost -notcontains $ComputerName) -and ($Credential -ne [System.Management.Automation.PSCredential]::Empty))
                {
                    $WMIHast.Credential = $Credential
                }

                # General variables
                $ResultSet = @()
                $PSDateTime = Get-Date
                
                #region Services
                Write-Verbose -Message ('Remote Service Information: Runspace {0}: Service information' -f $ComputerName)

                # Modify this variable to change your default set of display properties
                $defaultProperties    = @('ComputerName','Services')                                          
                                         
                $Services = @()
                $wmi_data = Get-WmiObject @WMIHast -Class Win32_Service
                foreach ($service in $wmi_data)
                {
                    $ServiceProperty = @{
                        'Name' = $service.Name
                        'DisplayName' = $service.DisplayName
                        'PathName' = $service.PathName
                        'Started' = $service.Started
                        'StartMode' = $service.StartMode
                        'State' = $service.State
                        'ServiceType' = $service.ServiceType
                        'StartName' = $service.StartName
                    }
                    $Services += New-Object PSObject -Property $ServiceProperty
                }
                if ($IncludeDriverServices)
                {
                    $wmi_data = Get-WmiObject @WMIHast -Class 'Win32_SystemDriver'
                    foreach ($service in $wmi_data)
                    {
                        $ServiceProperty = @{
                            'Name' = $service.Name
                            'DisplayName' = $service.DisplayName
                            'PathName' = $service.PathName
                            'Started' = $service.Started
                            'StartMode' = $service.StartMode
                            'State' = $service.State
                            'ServiceType' = $service.ServiceType
                            'StartName' = $service.StartName
                        }
                        $Services += New-Object PSObject -Property $ServiceProperty
                    }
                }
                $ResultProperty = @{
                    'PSComputerName' = $ComputerName
                    'PSDateTime' = $PSDateTime
                    'ComputerName' = $ComputerName
                    'Services' = $Services
                }
                
                $ResultObject = New-Object -TypeName PSObject -Property $ResultProperty
                    
                # Setup the default properties for output
                $ResultObject.PSObject.TypeNames.Insert(0,'My.Services.Info')
                $defaultDisplayPropertySet = New-Object System.Management.Automation.PSPropertySet('DefaultDisplayPropertySet',[string[]]$defaultProperties)
                $PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)
                $ResultObject | Add-Member MemberSet PSStandardMembers $PSStandardMembers
                
                $ResultSet += $ResultObject
            
                #endregion Services

                Write-Output -InputObject $ResultSet
            }
            catch {
                Write-Warning -Message ('Remote Service Information: {0}: {1}' -f $ComputerName, $_.Exception.Message)
            }
            Write-Verbose -Message ('Remote Service Information: Runspace {0}: End' -f $ComputerName)
        }
 
        function Get-Result {
            [CmdletBinding()]
            param (
                [switch]$Wait
            )
            do {
                $More = $false
                foreach ($runspace in $runspaces)
                {
                    $StartTime = $runspacetimers[$runspace.ID]
                    if ($runspace.Handle.isCompleted)
                    {
                        Write-Verbose -Message ('Remote Service Information: Thread done for {0}' -f $runspace.IObject)
                        $runspace.PowerShell.EndInvoke($runspace.Handle)
                        $runspace.PowerShell.Dispose()
                        $runspace.PowerShell = $null
                        $runspace.Handle = $null
                    }
                    elseif ($runspace.Handle -ne $null)
                    {
                        $More = $true
                    }
                    if ($Timeout -and $StartTime)
                    {
                        if ((New-TimeSpan -Start $StartTime).TotalSeconds -ge $Timeout -and $runspace.PowerShell)
                        {
                            Write-Warning -Message ('Timeout {0}' -f $runspace.IObject)
                            $runspace.PowerShell.Dispose()
                            $runspace.PowerShell = $null
                            $runspace.Handle = $null
                        }
                    }
                }
                if ($More -and $PSBoundParameters['Wait'])
                {
                    Start-Sleep -Milliseconds 100
                }
                foreach ($threat in $runspaces.Clone())
                {
                    if ( -not $threat.handle)
                    {
                        Write-Verbose -Message ('Remote Service Information: Removing {0} from runspaces' -f $threat.IObject)
                        $runspaces.Remove($threat)
                    }
                }
                if ($ShowProgress)
                {
                    $ProgressSplatting = @{
                        Activity = 'Remote Service Information: Getting info'
                        Status = 'Remote Service Information: {0} of {1} total threads done' -f ($bgRunspaceCounter - $runspaces.Count), $bgRunspaceCounter
                        PercentComplete = ($bgRunspaceCounter - $runspaces.Count) / $bgRunspaceCounter * 100
                    }
                    Write-Progress @ProgressSplatting
                }
            }
            while ($More -and $PSBoundParameters['Wait'])
        }
    }
    process {
        foreach ($Computer in $ComputerName)
        {
            $bgRunspaceCounter++
            $psCMD = [System.Management.Automation.PowerShell]::Create().AddScript($ScriptBlock)
            $null = $psCMD.AddParameter('bgRunspaceID',$bgRunspaceCounter)
            $null = $psCMD.AddParameter('ComputerName',$Computer)
            $null = $psCMD.AddParameter('ServiceName',$ServiceName)
            $null = $psCMD.AddParameter('IncludeDriverServices',$IncludeDriverServices)
            $null = $psCMD.AddParameter('Filter',$Filter)
            $null = $psCMD.AddParameter('Verbose',$VerbosePreference)
            $psCMD.RunspacePool = $rp
 
            Write-Verbose -Message ('Remote Service Information: Starting {0}' -f $Computer)
            [void]$runspaces.Add(@{
                Handle = $psCMD.BeginInvoke()
                PowerShell = $psCMD
                IObject = $Computer
                ID = $bgRunspaceCounter
           })
           Get-Result
        }
    }
    end {
        Get-Result -Wait
        if ($ShowProgress)
        {
            Write-Progress -Activity 'Remote Service Information: Getting service information' -Status 'Done' -Completed
        }
        Write-Verbose -Message "Remote Service Information: Closing runspace pool"
        $rp.Close()
        $rp.Dispose()
    }
}