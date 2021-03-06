function Test-PsRemoting {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory = $true,HelpMessage='Computer to test PsRemoting against.')]
        [String]
        $computername
    )
   
    try {
        $errorActionPreference = "Stop"
        $result = Invoke-Command -ComputerName $computername { 1 }
    }
    catch {
        Write-Verbose 'Test-PsRemoting: PsRemoting was unable to connect to $computername'
		return $false
    }

    if($result -ne 1) {
        Write-Verbose "Test-PsRemoting: Remoting to $computerName returned an unexpected result."
        return $false
    }
    Write-Verbose 'Test-PsRemoting: PsRemoting was able to connect to $computername'
    return $true
} 