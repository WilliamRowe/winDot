function mstsc {
    [alias('start-rdp', 'rdp')]
    param ( $computer )
    # Override mstsc calls, use mstsc.exe to call direct.
    # Set the default resolution for Remote Desktop Connection
    if ($null -ne $computer) {
        mstsc.exe /v:$computer /h:1080 /w:1920 /remoteguard
    } else {
        mstsc.exe /h:1080 /w:1920 /remoteguard
    }
}
