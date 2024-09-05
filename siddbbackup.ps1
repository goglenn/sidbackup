$mypath = $MyInvocation.MyCommand.Path
$scriptPath=Split-Path $mypath
$configPath="$scriptPath\config.conf"

Foreach ($i in $(Get-Content -path $configPath)){
    Set-Variable -Name $i.split("=")[0] -Value $i.split("=",2)[1]
}

Add-Type -AssemblyName PresentationFramework

$var_backupDir="$scriptPath\$var_BACKUPDIRPARAM"
$var_dbstatusFile="$scriptPath\$var_DBSTATUSFILEPARAM"
$var_folderListFile="$scriptPath\$var_FOLDERLISTFILEPARAM"
$xamlFile="$scriptPath\$var_XMLFILEPARAM"

$inputXAML = Get-Content -Path $xamlFile -Raw
$inputXAML = $inputXAML -replace 'mc:Ignorable="d"','' -replace "x:n","N" -replace '^<Win.*','<Window'
[XML]$XAML=$inputXAML
If (!(test-path $var_backupDir))
{
    md $var_backupDir
}

if($var_LOGGING -eq "1") {
    Write-Output "Path of the script : $scriptPath"
    Write-Output "Path of the config file : $configPath"
    Get-Variable var_*
    Get-Variable xamlFile
}



function Backup-SIDDbFolders{
    [CmdLetBinding()]
    Param(
        [Parameter(Mandatory=$true,HelpMessage="Enter the destination path")]
        [string]$destinationPath,

        [Parameter(Mandatory=$true,HelpMessage="Enter the backup name")]
        [string]$backupName,

        [Parameter(Mandatory=$true,HelpMessage="Enter the folder to archive",ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [string]$folder,

        [Parameter(Mandatory=$true,HelpMessage="Enter the name of archive",ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [string]$archiveName
    )
    
    BEGIN{
        $var_txtOutputBox.Clear()
        Add-OutputBoxLine -Message "starting backup $backname"
    }
    PROCESS{
        $backupFileName = -join($backupName,"_",$archiveName)

        $destinationFile = -join($destinationPath,"\",$backupFileName,".zip")

        Add-OutputBoxLine -Message "folder to archive $folder to $destinationFile"
        Add-OutputBoxLine -Message "use Windows compress"
        [boolean]$okToCompressFolder = Test-Path "$folder"
        if($okToCompressFolder) {
            Compress-Archive -Path $folder $destinationFile
        } else {
            Add-OutputBoxLine -Message "$folder does not exist. Skipping compress"
        }


    }
    END{
        
    }
    
}

Function Restore-SIDDbFolders{
[CmdLetBinding()]
    Param(
        [Parameter(Mandatory=$true,HelpMessage="Enter the destination path")]
        [string]$destinationPath,

        [Parameter(Mandatory=$true,HelpMessage="Enter the backup name")]
        [string]$backupName,

        [Parameter(Mandatory=$true,HelpMessage="Enter the folder to archive",ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [string]$folder,

        [Parameter(Mandatory=$true,HelpMessage="Enter the name of archive",ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [string]$archiveName
    )
    
    BEGIN{}
    PROCESS{
        $backupIndexFile = -join($destinationPath,"\",$backupName,".txt")   
        [boolean]$okToContinue = Test-Path "$backupIndexFile"
        if($okToContinue) {
        
            $backupFileName = -join($backupName,"_",$archiveName)

            $zipFile = -join($destinationPath,"\",$backupFileName,".zip")

            Add-OutputBoxLine -Message "Restore-SIDDbFolders restore $folder from $zipFile"
            [boolean]$okToExpandArchive = Test-Path "$archiveName"
            if($okToExpandArchive) {
                Drop-SIDdb -folder $folder -archiveName $archiveName
                Expand-Archive -Path $archiveName $folder
            } else {
                 Add-OutputBoxLine -Message "$archiveName does not exist. Skipping expand"
            }
                    
            
         } else {
            Add-OutputBoxLine -Message "cannot restore. invalid backup"
         }

    }
    END{}
}

function Delete-SIDBackup{
    [CmdLetBinding()]
    Param(
        [Parameter(Mandatory=$true,HelpMessage="Enter the destination path")]
        [string]$destinationPath,

        [Parameter(Mandatory=$true,HelpMessage="Enter the backup name")]
        [string]$backupName,

        [Parameter(Mandatory=$true,HelpMessage="Enter the folder to archive",ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [string]$folder,

        [Parameter(Mandatory=$true,HelpMessage="Enter the name of archive",ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [string]$archiveName
    )

    BEGIN{}
    PROCESS{
        $backupFileName = -join($backupName,"_",$archiveName)

        $destinationFile = -join($destinationPath,"\",$backupFileName,".zip")

        Add-OutputBoxLine -Message "deleting $destinationFile"
        
        Remove-Item $destinationFile -ErrorAction SilentlyContinue
        
    }
    END{
        $var_dg_backupList.Rem
        $backupIndexFile = -join($destinationPath,"\",$backupName,".txt")
        Remove-Item $backupIndexFile -ErrorAction SilentlyContinue
    }
}
function Drop-SIDdb {
    [CmdLetBinding()]
    Param(
        [Parameter(Mandatory=$true,HelpMessage="Enter the folder to archive",ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [string]$folder,

        [Parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [string]$archiveName

    )

    BEGIN{}
    PROCESS{
        $folderPath = $folder.Replace("\*","")
        
        Add-OutputBoxLine -Message "Drop-SIDdb folder to delete:  $folderPath"
        Remove-Item $folderPath -Force  -Recurse -ErrorAction SilentlyContinue
        $var_lblCurrentBackup.Content="Db Dropped"

    }
    END{}
}






$reader = New-Object System.Xml.XmlNodeReader $XAML
try {
    $psform=[Windows.Markup.XamlReader]::Load($reader)
} catch{
    Write-Host $_.Exception
    throw
}

$psform.Add_Closing({ 
    $backupName=$var_lblCurrentBackup.Content
    if($var_LOGGING -eq "1") {
        Write-Host "closing.. current db is $backupName "
    }
    
    Set-Content -Path $var_dbstatusFile -Value $var_lblCurrentBackup.Content
})

$XAML.SelectNodes("//*[@Name]") | ForEach-Object {
    try{
        Set-Variable -Name "$($_.Name)" -Value $psform.FindName($_.Name) -ErrorAction Stop
    }catch{
        throw
    }
}
$var_txtOutputBox.IsReadOnly=$true
$var_txtOutputBox.VerticalScrollBarVisibility="Visible"

function saveDBStatus {
   
    Set-Content -Path $var_dbstatusFile -Value $var_lblCurrentBackup.Content
    $backupIndexFile = -join($var_backupDir,"\",$var_txtNewBackupName.Text,".txt")

    Add-Content -Path $backupIndexFile "Created on:"
    $a = Get-Date
    Add-Content -Path $backupIndexFile "$a"

}

function RefreshData{
    $backups=Get-ChildItem $var_backupDir\*.txt

    $Columns=@(
        'Name'
        'LastWriteTime'   
    )

    $BackupDataTable=New-Object System.Data.DataTable
    [void]$BackupDataTable.Columns.AddRange($Columns)

    foreach($backup in $backups) {
        $dbname=$backup.Name.Replace(".txt","")
        [void]$BackupDataTable.Rows.Add(@($dbname,$backup.LastWriteTime))
    }

    $var_dg_backupList.ItemsSource=$BackupDataTable.DefaultView
    $var_dg_backupList.IsReadOnly=$true
    $var_dg_backupList.GridLinesVisibility="None"

}

function Add-OutputBoxLine {
    Param ($Message)
    $var_txtOutputBox.AppendText("`r`n$Message")
    $var_txtOutputBox.ScrollToEnd()
}

if(!(test-path $var_dbstatusFile)) {
    $var_lblCurrentBackup.Content="None"
    Set-Content -Path $var_dbstatusFile -Value $var_lblCurrentBackup.Content
} else {
    $var_lblCurrentBackup.Content = Get-Content -path $var_dbstatusFile
}


RefreshData


##set delete db file button event
$var_btnDeleteDBFiles.Add_Click({
    Import-Csv $var_folderListFile | Drop-SIDdb -Verbose
})

##set create new backup button event
$var_btnCreateNewBackup.Add_Click({
    Import-Csv $var_folderListFile | Backup-SIDDbFolders -destinationPath $var_backupDir -backupName $var_txtNewBackupName.Text -Verbose
    $var_lblCurrentBackup.Content=$var_txtNewBackupName.Text
    RefreshData
})

##set restore backup button event
$var_btnRestoreBackup.Add_Click({
    $var_lblCurrentBackup.Content=$var_dg_backupList.SelectedItem.Name
    Import-Csv $var_folderListFile | Restore-SIDDbFolders -destinationPath $var_backupDir -backupName $var_dg_backupList.SelectedItem.Name -Verbose
})

##set update backup button event
$var_btnUpdateBackup.Add_Click({
    Import-Csv $var_folderListFile | Delete-SIDBackup -destinationPath $var_backupDir -backupName $var_dg_backupList.SelectedItem.Name -Verbose
    Import-Csv $var_folderListFile | Backup-SIDDbFolders -destinationPath $var_backupDir -backupName $var_txtNewBackupName.Text -Verbose
    RefreshData
})

##set delete backup button event
$var_btnDeleteBackup.Add_Click({
    Import-Csv $var_folderListFile | Delete-SIDBackup -destinationPath $var_backupDir -backupName $var_dg_backupList.SelectedItem.Name -Verbose
    RefreshData
})

$psform.ShowDialog()
