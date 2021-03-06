(Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -recurse | 
    Get-ItemProperty -name Version -ea 0 | 
    Where { $_.PSChildName -match '^(?!S)\p{L}'} | 
    Select @{n='version';e={[decimal](($_.Version).Substring(0,3))}} -Unique |
    Sort-Object -Descending | select -First 1).Version