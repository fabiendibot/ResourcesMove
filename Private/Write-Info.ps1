Function Write-Info {
    param (
        [String]$type,
        [string]$msg
    )

    Switch ($type) {
        "Info" { $color = "Yellow" }
        "Success" { $color = "Green" }
        "Error" { $color = "Red" }
        "Warning" { $color = "Cyan" }
    }

    Write-Host "[" -NoNewline
    Write-Host "$type" -ForegroundColor $color -NoNewline
    Write-Host "] - $msg "

}