Describe "Test-HelloWorldScript" {
    It "Outputs 'Hello, World!'" {
        # Replace the path with the path to your PowerShell script
        $output = & 'C:\temp\HelloWorld.ps1'
        $output.Trim() | Should Be 'Hello, World!'
    }
}