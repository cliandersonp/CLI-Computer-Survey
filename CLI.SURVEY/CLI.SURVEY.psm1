function Get-CLIComputerSurvey {
  # Define parameters.
  param(
    [Microsoft.Management.Infrastructure.CimSession]$cimsession
  )

  # Data Validation Checking. Script should only work if a cimsession is provided
  if (-not $cimsession){
    Write-Error -Category NotSpecified -Message "CimSession Not Given"
    return
  }

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
  }
}


Export-ModuleMember -Function Get-CLIComputerSurvey