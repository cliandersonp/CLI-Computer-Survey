function get-baseboard {
  param (
    [Parameter(ValueFromPipeline=$true)]$cimsession
  )

  Get-CimInstance Win32_BaseBoard -CimSession $cimsession
  
}

New-CimSession localhost | get-baseboard