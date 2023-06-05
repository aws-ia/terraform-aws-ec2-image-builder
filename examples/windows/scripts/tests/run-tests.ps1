Write-Output "Importing Pester module.."
Import-Module Pester -Force # added force

Write-Output "Invoking tests with Pester.."
$result = Invoke-Pester -Path "C:/temp/tests/"  -PassThru
Write-Output $result