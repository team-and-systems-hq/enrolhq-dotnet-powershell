#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }
#Requires -Version 7.0

BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot '../../src/EnrolHQ.PowerShell/EnrolHQ.PowerShell.psd1'
    Import-Module $ModulePath -Force
}

AfterAll {
    Remove-Module EnrolHQ.PowerShell -Force -ErrorAction SilentlyContinue
}

Describe 'EnrolHQStatus' {

    It 'Maps <Name> to the API status code <Code>' -ForEach @(
        @{ Name = 'RegisterInterest'; Code = -1 }
        @{ Name = 'EnquiryOnline';    Code = 0 }
        @{ Name = 'EnquiryEvent';     Code = 1 }
        @{ Name = 'Eoi';              Code = 2 }
        @{ Name = 'Enrolment';        Code = 3 }
        @{ Name = 'Orientation';      Code = 4 }
        @{ Name = 'Community';        Code = 5 }
        @{ Name = 'Alumni';           Code = 6 }
        @{ Name = 'Trashed';          Code = 7 }
        @{ Name = 'Declined';         Code = 8 }
        @{ Name = 'Waitlist';         Code = 9 }
        @{ Name = 'ReservedOffer';    Code = 10 }
        @{ Name = 'NotProceeding';    Code = 11 }
        @{ Name = 'EnrolmentOffer';   Code = 12 }
        @{ Name = 'Interview';        Code = 13 }
        @{ Name = 'Pending';          Code = 14 }
        @{ Name = 'Custom1';          Code = 15 }
        @{ Name = 'Custom8';          Code = 22 }
        @{ Name = 'Custom9';          Code = 23 }
        @{ Name = 'Custom16';         Code = 30 }
    ) {
        $actual = InModuleScope EnrolHQ.PowerShell -Parameters @{ Name = $Name } {
            param($Name)
            [EnrolHQStatus]::$Name
        }
        $actual | Should -Be $Code
    }

    It 'Defines every code from -1 to 30 exactly once' {
        $codes = InModuleScope EnrolHQ.PowerShell {
            [EnrolHQStatus].GetProperties([System.Reflection.BindingFlags]'Static,Public') |
                ForEach-Object { $_.GetValue($null) }
        }
        ($codes | Sort-Object) | Should -Be (-1..30)
    }
}
