function ConvertFrom-Excel {
    param( 
        [alias('ExcelFile')]
        $Path
    )
    try {
        # Establish Excel COM object
        $excel = New-Object -ComObject Excel.Application
    } catch {
        # Check that Excel is installed on system
        throw "Failed to create Excel COM object! $_"
    }
    # do not display window, interact in background.
    $excel.Visible = $false

    # open as readonly
    $workbook = $excel.Workbooks.Open(
        $Path, # FileName
        $null, # UpdateLinks
        $true # ReadOnly
        # $null, # Format
        # $null, # Password
        # $null, # WriteResPassword
        # $true, # IgnoreReadOnlyRecommended
        # $null, # Origin,
        # $null, # Delimiter
        # $null, # Editable
        # $null, # Notify
        # $null, # Converter
        # $null, # AddToMru
        # $null, # Local
        # $null  # CorruptLoad
    )
    $sheet = $workbook.Sheets.Item(1)
    $usedRange = $sheet.UsedRange
    
    $headers = @()
    for ($col = 1; $col -le $usedRange.Columns.Count; $col++) {
        $headers += $usedRange.Cells.Item(1, $col).Text.trim()
    }
    
    $rows = @()
    $totalRows = $usedRange.Rows.Count
    for ($row = 2; $row -le $totalRows; $row++){
        $percentComplete = [int](($row-1)/($totalRows-1)*100)
        Write-Progress -Activity "Processing Excel Rows" -Status "$percentComplete % - Row $row of $totalRows." -PercentComplete $percentComplete
        $obj = [PSCustomObject]@{}
        for ($col = 1; $col -le $usedRange.Columns.Count; $col++){
            $header = $headers[$col-1]
            $value = $usedRange.Cells.Item($row, $col).Text.trim()
            $obj | Add-Member -NotePropertyName $header -NotePropertyValue $value
        }
        $rows += $obj
    }
    $rows

    # Clean up
    $workbook.Close($false)
    $excel.Quit()
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel)
}
