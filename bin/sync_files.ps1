# https://github.com/WhyAskWhy/mysql2sqlite
# https://github.com/WhyAskWhy/mysql2sqlite-dev

# Purpose: Sync files over from host to test VM

$target_vm = "Ubuntu-16.04"

$base_dir = 'T:\whyaskwhy.org\projects\mysql2sqlite-dev'

$return_path = $pwd

$sql_import_files = @{

    # Content kept locally for testing purposes, but excluded from VCS.
    # Referenced here for direct injection into test VM.
    "$base_dir\sample_data" = '/home/ubuntu/Desktop/'

}

$bootstrap_script = "setup_dev_environment.sh"

# http://stackoverflow.com/questions/9015138/powershell-looping-through-a-hash-or-using-an-array
foreach ($d in $sql_import_files.GetEnumerator()) {

    Set-Location $d.Name
    Write-Output "`nCopying files from $($base_dir) to VM $($target_vm):"
    Get-ChildItem | Where-Object { $_.PSIsContainer -eq $false } | ForEach-Object {
        $file_source_path = "$($pwd)\$($_.Name)"
        $file_destination_path = $d.Value
        Write-Output "* $($_.Name)"
        Copy-VMFile $target_vm `
            -SourcePath $file_source_path `
            -DestinationPath $file_destination_path `
            -CreateFullPath `
            -FileSource Host `
            -Force
    }
}


# Just copy over the main bootstrap script, it will take care of the rest
Write-Output "* $bootstrap_script"
Copy-VMFile $target_vm `
    -SourcePath "$($base_dir)\bin\$($bootstrap_script)" `
    -DestinationPath $file_destination_path `
    -CreateFullPath `
    -FileSource Host `
    -Force


Set-Location $return_path
