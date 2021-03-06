function Convert-ToNumberRange {
    <#
    # Gather 20 random numbers between 0 and 40
    $test = @()
    1..20 | Foreach {$test += (Get-Random -Minimum 0 -Maximum 40)}

    # Show the contiguous number ranges in a nice table
    $test | Convert-ToNumberRange | ft -AutoSize

    # Convert to PowerShell range operator format
    $test | Convert-ToNumberRange | Foreach { "$($_.Begin)..$($_.End)" }
    #>
    [CmdletBinding()] 
    param (
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, HelpMessage='Range of numbers in array.')]
        $series
    )
    begin {
        $numberseries = @()
        filter isNumeric() {
            return $_ -is [byte]  -or $_ -is [int16]  -or $_ -is [int32]  -or $_ -is [int64]  `
               -or $_ -is [sbyte] -or $_ -is [uint16] -or $_ -is [uint32] -or $_ -is [uint64] `
               -or $_ -is [float] -or $_ -is [double] -or $_ -is [decimal]
        }
    }
    
    process {
        if (isNumeric $series) {
            $numberseries += $series
        }
        else {
            if ([bool]($series -as [int64] -is [int64])) {
                $numberseries += [int64]$series
            }
        }
    }
    end {
        $numberseries = @($numberseries | Sort | Select -Unique)
        $index = 1
        $initmode = $true
        
        # Start at the begining
        $start = $numberseries[0]
        
        # If we only have a single number in the series then go ahead and return it
        if ($numberseries.Count -eq 1) {
            return New-Object psobject -Property @{
                'Begin' = $numberseries[0]
                'End' = $numberseries[0]
            }
        }
        do {
            if ($initmode) {
                $initmode = $false
            }
            else {
                # if the current number minus the last number is not exactly 1 then the range has split 
                # (so we have a non-contiguous series of numbers like 1,2,3,12,13,14....)
                if (($numberseries[$index] - $numberseries[$index - 1]) -ne 1) {
                    New-Object psobject -Property @{
                        'Begin' = $start
                        'End' = $numberseries[$index-1]
                    }
                    # Reset our starting point and begin again
                    $start = $numberseries[$index]
                    $initmode = $true
                }
            }
            $index++
        } until ($index -eq ($numberseries.length))
        
        # We should always end up with a result at the end for the last digits
        New-Object psobject -Property @{
            'Begin' = $start
            'End' = $numberseries[$index - 1]
        }
    }
}