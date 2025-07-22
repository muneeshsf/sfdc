# === CONFIG ===
$AppName = "AppMon"
$MetadataDir = "C:\Muneesh\SFDXSetup\MBMeta\force-app\main\default\permissionsets"
$OutputFile = "AppAccess_Report.csv"


# === INIT CSV ===
"PermissionSet,GrantsAccessToApp" | Out-File -Encoding UTF8 $OutputFile

# === XML Namespace ===
$nsManager = New-Object System.Xml.XmlNamespaceManager ([System.Xml.NameTable]::new())
$nsManager.AddNamespace("sf", "http://soap.sforce.com/2006/04/metadata")

# === LOOP THROUGH FILES ===
Get-ChildItem -Recurse -Path $MetadataDir -Filter *.permissionset-meta.xml | ForEach-Object {
    $file = $_.FullName
    try {
        $reader = [System.IO.StreamReader]::new($file, [System.Text.Encoding]::UTF8)
        $xmlContent = $reader.ReadToEnd()
        $reader.Close()

        $xmlDoc = New-Object System.Xml.XmlDocument
        $xmlDoc.LoadXml($xmlContent)

        $permissionSetName = $_.BaseName -replace "\.permissionset$", ""

        $nodes = $xmlDoc.SelectNodes("//sf:applicationVisibilities", $nsManager)
        foreach ($node in $nodes) {
            $app = $node.SelectSingleNode("sf:application", $nsManager)
            $visible = $node.SelectSingleNode("sf:visible", $nsManager)
            if ($app -and $visible -and $app.InnerText -eq $AppName -and $visible.InnerText -eq "true") {
                "$permissionSetName,Yes" | Out-File -Append -Encoding UTF8 $OutputFile
                break
            }
        }
    } catch {
        Write-Host "❌ Failed to parse $file"
        continue
    }
}

Write-Host "`n✅ Done! Only matching permission sets saved to $OutputFile"
