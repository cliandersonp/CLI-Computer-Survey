<#
  .SYNOPSIS
  Provides customized hardware data report.

  .DESCRIPTION
  Accepts CIMSessions to collect specific hardware data, such as UsedBy, AssetTag, Make, Model, SerialNumber, FirstLogon, CPU, GPU, TotalStorage, OperatingSystemBuild, IncludedCamera, and availble MemorySlots for the usage of CLI hardware data collection. 

  .PARAMETER CimSession
  Accepts Microsoft.Management.Infrastructure.CimSession objects, or collection ob objects. Accepts Pipeline

  .PARAMETER FindComputers
  For ease of use, the user doesn't need to provide their own cimsessions. The FindComputers switch will attempt to use Get-ADComputers to get a list of computernames that it will try and make CIMSessions for. If a CIMSession cannot be created, the function will silently continue and work only with what CIMSessions it can establish. 

  .PARAMETER Filter
  Filter passes to Get-ADComputer only if FindComputer flag is enabled and is ignored otherwise. For additional information about Active Directory filters, visit https://learn.microsoft.com/en-us/previous-versions/windows/server/hh531527(v=ws.10) 

  .EXAMPLE
  # Starts working for all devices accessible on the network
  Get-CLIComputerSurvey -FindComputers

  .EXAMPLE
  # Creates a new CIMSession in-line to collect data for single computer
  Get-CLIComputerSurvey -CimSession (New-CimSession <ComputerName>)

  .EXAMPLE
  # Pipe in CIMSessions from Get-CimSession
  Get-CimSession | Get-CLIComputerSurvey

#>
function Get-CLIComputerSurvey {
  # Define parameters.
  param(
    # [Microsoft.Management.Infrastructure.CimSession]$cimsession
    [Parameter(ValueFromPipeline=$true)]$CimSession,
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
      $computerName | ForEach-Object {New-CimSession $_ -ErrorAction SilentlyContinue}
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

  return $OutputArray
}


function Export-CLIHardwareSurvey {
  param (
    [Parameter(ValueFromPipeline=$true)][System.Object]$InputObject,
    $FileName = "$((HOSTNAME.EXE).tostring())-trk-comp.csv"
  )
  
  # Data Validation.
  # Checks that the provided filename is legal
  if (-not ($FileName -match "^[\w,\s-]+\.[A-Za-z]{3}$")){
    Write-Error -Category InvalidArgument -Message "Illegal Filename"
    return
  }

  # To Check if $InputObject is valid, it should possess all the appropriate parameters. 
  $InputParameters = @(
  "UsedBy"
  "AssetTag"
  "Make"
  "Model"
  "SerialNumber"
  "FirstLogon"
  "CPU"
  "GPU"
  "TotalStorage"
  "TotalMemory"
  "OperatingSystemBuild"
  "IncludesCamera"
  "MemorySlots"
  )

  $InputParameters | ForEach-Object {
    if (-not ($InputObject.PSObject.Properties.name -match $_)){
      Write-Error -Category InvalidData -Message "Required parameter $_ not found in input object."
      return
    }
  }

  # process input opbject.
  $InputObject | ForEach-Object -Begin {
    $trkCompFieldHeadings = @(
      "x_used_by"
      "x_trk_comp_asset"
      "x_studio_field_0Zdfz"
      "x_name"
      "x_trk_comp_serial"
      "x_trj_comp_issue" #This is a typo in Odoo, not here
      "x_trk_comp_cpu"
      "x_trk_comp_gpu"
      "x_trk_comp_storage"
      "x_trk_comp_mem_total"
      "x_trk_comp_os"
      "x_trk_comp_includes_camera"
      "x_trk_memory_slots"
      "x_trk_modern_data"
      )

      $trkCompHeader = ""

      $trkCompFieldHeadings | ForEach-Object {if (-not $trkCompHeader) {
        $trkCompHeader += $_
      } else {
        $trkCompHeader += ",$_"
      }}
    
      $trkCompHeader | Out-File -FilePath .\$FileName
  } -Process{
    "$($InputObject.UsedBy),$($InputObject.AssetTag),$($InputObject.Make),$($InputObject.Model),$($InputObject.SerialNumber),$($InputObject.FirstLogon),$($InputObject.CPU),$($InputObject.GPU),$($InputObject.TotalStorage),$($InputObject.TotalMemory),$($InputObject.OperatingSystemBuild),$($InputObject.IncludesCamera),$($InputObject.MemorySlots),$True" | Out-File -FilePath .\$FileName
  }
}

Export-ModuleMember -Function Get-CLIComputerSurvey,
                              Export-CLIHardwareSurvey