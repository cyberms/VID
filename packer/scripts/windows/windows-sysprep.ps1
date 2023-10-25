# Stop the Tiledatamodelsvc service
Stop-Service -Name "Tiledatamodelsvc"

# Check if a:\unattend.xml exists
if (Test-Path -Path "a:\unattend.xml") {
    # Run Sysprep with unattend.xml from a:\
    Start-Process -FilePath "c:\windows\system32\sysprep\sysprep.exe" -ArgumentList "/generalize /oobe /shutdown /unattend:a:\unattend.xml" -Wait
} else {
    # Delete existing unattend.xml if it exists
    Remove-Item -Path "c:\Windows\System32\Sysprep\unattend.xml" -Force -ErrorAction SilentlyContinue

    # Run Sysprep without unattend.xml
    Start-Process -FilePath "c:\windows\system32\sysprep\sysprep.exe" -ArgumentList "/generalize /oobe /shutdown /quiet" -Wait
}
