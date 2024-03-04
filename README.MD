# Program Concepts
This module is designed to work with the CAM Logic IT Department's goals and proceedures. 
The primary function of this module depends on the CIM (Common Information Model) Session Technology.
To learn more about CIM Sessions, click [here](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_cimsession?view=powershell-7.4)

## `Get-CLIComputerSurvey`
`Get-CLIComputerSurvey` is the primary driver for collecting information. 
This function relies on `CimSession` PowerShell objects in order to work.
As a user, you can pass only the `CimSession` objects that you would like to the `CimSession` parameter,
or you can have the program look through the Active Directory computer list and try to find as many computers as it can with the `-FindComputers` flag. 
The program returns a custom powershell object with predefined categories.
The `-Filter` parameter is only used with `-FindComputers`, and is the same as envoking a filter on `Get-ADComputer`.
For more information on `-Filter` syntax, visit [here](https://learn.microsoft.com/en-us/previous-versions/windows/server/hh531527(v=ws.10))

### Examples
```
New-CimSession -ComputerName $DesiredComputerName
$CimSess = Get-CimSession
Get-CLIComputerSurvey -CimSession $CimSess
```
```
New-CimSession -ComputerName $DesiredComputerName | Get-CLIComputerSurvey
```
```
Get-CLIComputerSurvey -FindComputers -Filter "*-L-*"
```

## `Export-CLIComputerSurvey`
`Export-CLIComputerSurvey` is a pre-configured version of `Export-CSV` that is designed to work with the custom objects that `Get-CLIComputerSurvey` generates.
Although a filename can be provided using the `-FileName` parameter, the function will attempt to make its own name based on the host computer's name.
This function is designed to work in tandem with `Get-CLIComputerSurvey`, but it will not envoke it. 
The output of `Get-CLIComputerSurvey` can be passed directly to `Export-CLIComputerSurvey` or it can be given by a saved variable. 

### Examples
```
Get-CimSession | Get-CLIComputerSurvey | Export-CLIComputerSurvey -FileName "December 2022 Hardware Survey.csv"
```