Import-Module (Join-Path $PSScriptRoot "..\..\scripts\WinNetlab.Foundation.psm1") -Force

Describe "Convert-WindowsPathToWsl" {
    It "converts a drive path into a WSL path" {
        $result = Convert-WindowsPathToWsl -WindowsPath "C:\Users\lab\repo"
        $result | Should Be "/mnt/c/Users/lab/repo"
    }
}

Describe "Get-OverallStatus" {
    It "returns fail when a required check fails" {
        $checks = @(
            [pscustomobject]@{ Required = $true; Status = "pass" },
            [pscustomobject]@{ Required = $true; Status = "fail" }
        )

        Get-OverallStatus -Checks $checks | Should Be "fail"
    }

    It "returns pass-with-warnings for optional warnings" {
        $checks = @(
            [pscustomobject]@{ Required = $true; Status = "pass" },
            [pscustomobject]@{ Required = $false; Status = "warn" }
        )

        Get-OverallStatus -Checks $checks | Should Be "pass-with-warnings"
    }
}

Describe "Initialize-LabScaffold" {
    It "creates local files from templates without overwriting existing local files" {
        $root = Join-Path $TestDrive "repo"
        New-Item -ItemType Directory -Force -Path $root | Out-Null
        New-Item -ItemType Directory -Force -Path (Join-Path $root "configs") | Out-Null
        Set-Content -Path (Join-Path $root ".env.example") -Value "LAB_NAME=test"
        Set-Content -Path (Join-Path $root "configs\lab.config.example.json") -Value '{"lab_name":"test","operator":"lab-operator","environment":"local-training","documentation_ranges":["192.0.2.0/24"],"devices":[]}'

        $firstRun = Initialize-LabScaffold -RootPath $root
        Test-Path (Join-Path $root ".env.local") | Should Be $true
        Test-Path (Join-Path $root "configs\lab.config.json") | Should Be $true
        $firstRun.Operations.Count | Should BeGreaterThan 0

        Set-Content -Path (Join-Path $root ".env.local") -Value "LAB_NAME=custom"
        $null = Initialize-LabScaffold -RootPath $root
        Get-Content (Join-Path $root ".env.local") | Should Be "LAB_NAME=custom"
    }
}
