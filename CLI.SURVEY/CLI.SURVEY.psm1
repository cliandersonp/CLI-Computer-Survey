function Get-CLIComputerSurvey {
  # Define parameters.
  param(
    # [Microsoft.Management.Infrastructure.CimSession]$cimsession
    [Parameter(ValueFromPipeline=$true)]$cimsession,
    [switch]$FindComputers,
    $Filter = "*"
  )

  # Checks that either $Cimsession or $Findcomputers is defined. 
  if (-not ($cimsession -or $FindComputers)){
    Write-Error -Category NotSpecified -Message "Function requires either imported CIM Sessions or Find Computer parameters to be defined"
    return
  }
  
  if (-not $FindComputers) {
    # Data Validation Checking. Script should only work if a cimsession is provided
    if (-not $cimsession){
      Write-Error -Category NotSpecified -Message "CimSession Not Given"
      return
    }
  
    $cimsession | ForEach-Object {
      if ($_.GetType().Name -ne "CimSession") {
        Write-Error -Category InvalidData -Message "Not All Values given are CimSession"
        return
      }
    }
  }else {
    # Check if get-computer is available
    if (Get-Command Get-ADComputer) {
      $computerName = (Get-ADComputer -Filter $Filter).Name
      $computerName | ForEach-Object {New-CimSession $_}
      $cimsession = Get-CimSession
    }else {
      Write-Error -Category NotInstalled -Message "Get-ADComputer ActiveDirectory Module is not present. Please install or import ActiveDirectory before performing this operation"
    }
  }


  # Output Array holds the custom system objects until all cimsessions are complete and the result may be posted
  $OutputArray = @()

  $cimsession | ForEach-Object -Process {
    $cimSes = $_

     # Targeted fields
    $usedBy = $null
    $assetTag = $null
    $make = $null
    $model = $null
    $serialNumber = $null
    $firstLogon = $null
    $cpu = $null
    $gpu = $null
    $totalStorage = $null
    $totalMemory = $null
    $operatingSystemBuild = $null
    $includesCamera = $null
    $memorySlots = $null

    # Field Definition
    get-ciminstance -CimSession $cimSes -ClassName Win32_ComputerSystem  -Property UserName,Manufacturer,Model,TotalPhysicalMemory | ForEach-Object {
      $usedBy,$make,$model,$totalMemory = $_.UserName, $_.Manufacturer, $_.Model, ($_.TotalPhysicalMemory/1GB)
    }

    Get-CimInstance -CimSession $cimSes -ClassName Win32_SystemEnclosure -Property SMBIOSAssetTag,SerialNumber | ForEach-Object {
      $assetTag, $serialNumber = $_.SMBIOSAssetTag, $_.SerialNumber
    }
    Get-CimInstance -CimSession $cimSes -ClassName Win32_OperatingSystem -Property Caption,BuildNumber,InstallDate | ForEach-Object {
      $operatingSystemBuild, $firstLogon = "$($_.Caption) $($_.BuildNumber)" , $_.InstallDate
    }

    $cpu = Get-CimInstance -CimSession $cimSes -ClassName Win32_Processor -Property Name | Select-Object -ExpandProperty Name

    $gpu = Get-CimInstance -CimSession $cimSes -ClassName Win32_VideoController -Property Caption | Where-Object {
      $_.Caption -match "nvidia"
    } | select-object -ExpandProperty Caption

    $storageDevices = Get-CimInstance -CimSession $cimSes Win32_DiskDrive -Property model,size,SystemName,InterfaceType | Where-Object {
      $_.InterfaceType -eq "SCSI"
    }

    $storageDevices | ForEach-Object {$totalStorage += $_.Size}; $totalStorage = $totalStorage / 1GB

    $includesCamera = (Get-CimInstance -CimSession $cimSes Win32_PnPEntity | Where-Object {
      $_.Caption -match "camera" -or $_.Caption -match "webcam"
      }).length -gt 0

    $memorySlots = Get-CimInstance -CimSession $cimsession Win32_PhysicalMemoryArray -Property MemoryDevices | Select-Object -ExpandProperty MemoryDevices
    
    # Secondary Definitions
    if (-not $assetTag){
      $hostname = (HOSTNAME.EXE).tostring()
      if ($hostname -match "\w\w\w-[dlw]-\d\d\d\d") {
        $assetTag = $hostname -replace "[^0-9]", ""
      }
    }

    # Adding Object to $outputArray
    $OutputArray += [PSCustomObject]@{
      UsedBy = $usedBy
      AssetTag = $assetTag
      Make = $make
      Model = $model
      SerialNumber = $serialNumber
      FirstLogon = $firstLogon
      CPU = $cpu
      GPU = $gpu
      TotalStorage = $totalStorage
      TotalMemory = $totalMemory
      OperatingSystemBuild = $operatingSystemBuild
      IncludesCamera = $includesCamera
      MemorySlots = $memorySlots
    }
  } # End Foreach-Object

  $OutputArray
}


Export-ModuleMember -Function Get-CLIComputerSurvey