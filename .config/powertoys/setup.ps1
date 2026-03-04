# Configure current path to be used for PowerToys Settings Backup and Restore
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\PowerToys' -Name 'SettingsBackupAndRestoreDir' -Value $PSScriptRoot
