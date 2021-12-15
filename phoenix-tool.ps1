$InstallPath = "C:\Files\Toolback"
$LocalPath = "C:\Files\Toolback\Origem"
$Destino = "C:\Files\Toolback\Destino"
$LogPath = $InstallPath + "\phoenixtool" + (Get-Date -Format "ddMMyyyyHHmm") + ".log"
$LogFile = $LogPath
$AllFiles = "*.bak"
$FullFiles = "*.full.bak"
$DiffFiles = "*.diff.bak"

Write-Host "`n*************************************************************" 
Write-Host "*                PHOENIX TOOL BACKUP v1.0                   *"
Write-Host "*************************************************************`n"

#Mantem apenas 2 backups "Full" na pasta, o que for mais antigo que isso é excluido.
function Invoke-DelFullOld {
        write-host "Selecionando backups (full) antigos..."
        Start-Sleep -s 4
        $DateOldFileFull = (Get-Childitem $LocalPath -Include $FullFiles -Recurse | Sort-Object CreationTime | Select-Object -Last 2)[0].CreationTime
        if (!$DateOldFileFull){
                Write-Warning "Nao foi possivel encontrar nenhum backup full. Verifique e tente novamente. `n"
                Exit
        }
        $OldFilesFull = Get-Childitem $LocalPath -Include $FullFiles -Recurse | Where-Object {$_.CreationTime -lt "$DateOldFileFull"}
        if (!$OldFilesFull){
                Write-Warning "Nenhum backup (full) canditado para exclusao. `n"
        }
        else {
                write-host "Excluindo backups (full) antigos..."
                Start-Sleep -s 4
                Remove-Item $OldFilesFull.FullName | out-null
                Write-Host "Backups (full) antigos excluidos. `n"
                Start-Sleep -s 2
        }
}

#Exclui todos os backups "Diff" que forem mais antigos que o penultimo backup "Full"
function Invoke-DelDiffOld {
        write-host "Selecionando backups (diff) antigos..."
        Start-Sleep -s 4
        $NumberFullFiles = Get-Childitem $LocalPath -Include $FullFiles -Recurse | Measure-Object | Select-Object -expand Count
        if ($NumberFullFiles -lt 2){
                Write-Warning "Preciso de pelo menos 2 arquivos de backup (full) para completar a analise. Verifique e tente novamente. `n"
                Exit
        }
        $DatePenFileFull = (Get-Childitem $LocalPath -Include $FullFiles -Recurse | Sort-Object CreationTime | Select-Object -Last 2)[0].CreationTime
        $OldFilesDiff = Get-Childitem $LocalPath -Include $DiffFiles -Recurse | Where-Object {$_.CreationTime -lt "$DatePenFileFull"}
        if (!$OldFilesDiff){
                Write-Warning "Nenhum backup (diff) canditado para exclusao. `n"
        }
        else {   
                write-host "Excluindo backups (diff) antigos..."
                Start-Sleep -s 4
                Remove-Item $OldFilesDiff.FullName | out-null
                write-host "Backups (diff) antigos excluidos. `n"
                Start-Sleep -s 2
        }
}

#Deleta todos arquivos do destino antes de iniciar o processo de backup
function Invoke-DelAllDestOld {
        write-host "Selecionando backups antigos..."
        Start-Sleep -s 4
        $AllFilesOldDest = (Get-Childitem $Destino -Include $AllFiles -Recurse | Sort-Object CreationTime)
        if (!$AllFilesOldDest){
                Write-Warning "Nenhum arquivo foi encontrado no local de destino. `n"
        }
        else {
                Write-host "Excluindo backups antigos..."
                Start-Sleep -s 4
                Remove-Item $AllFilesOldDest.FullName | out-null
                Write-Host "Todos arquivos de backup do destino foram excluidos. `n"
                Start-Sleep -s 2
        }
}

#Seleciona os backups mais recentes e faz a copia para a pasta de destino
function Invoke-CopyNewFiles {
        write-host "Selecionando arquivos para backup..."
        Start-Sleep -s 4
        $NumberFullFiles = Get-Childitem $LocalPath -Include $FullFiles -Recurse | Measure-Object | Select-Object -expand Count
        if ($NumberFullFiles -lt 2){
                Write-Warning "Preciso de pelo menos 2 arquivos de backup (.full) para completar a analise e seguir com backup. Verifique e tente novamente."
                Exit
        }
        $DatePenFileFull = (Get-Childitem $LocalPath -Include $FullFiles -Recurse | Sort-Object CreationTime | Select-Object -Last 2)[0].CreationTime
        $OldFileOrigem = Get-Childitem $LocalPath -Include $AllFiles -Recurse | Where-Object {$_.CreationTime -le $DatePenFileFull}
        Write-host "Iniciando processo de copia dos arquivos..."
        Start-Sleep -s 5
        robocopy /W:10 /R:2 /ETA /V /TEE /LOG:$LogFile $LocalPath $Destino /xf $OldFileOrigem
        Get-Content $LogFile -Tail 9 | Out-File -FilePath "$InstallPath\Report.txt"
        Start-Sleep -s 3
        Write-Host "`nProcesso de backup conluido com sucesso. `nMais detalhes em: ($LogFile) `n"
}

#Envia email notificando a conclusão do backup
function Invoke-SendEmail {
        Write-Host "Enviando alerta por e-mail..."
        Start-Sleep -s 4
        $hostname = [System.Net.Dns]::GetHostName()
        $From = "noc@aditusbr.com"
        $To = "infra@aditusbr.com"

            $report1 = (Get-Content $LogFile -Tail 9)[0]
            $report2 = (Get-Content $LogFile -Tail 9)[2]
            $report3 = (Get-Content $LogFile -Tail 9)[3]
            $report4 = (Get-Content $LogFile -Tail 9)[4]
            $report5 = (Get-Content $LogFile -Tail 9)[5]
            $report6 = (Get-Content $LogFile -Tail 9)[6]
            $report7 = (Get-Content $LogFile -Tail 9)[7]
            $report8 = "------------------------------------------------------------------------------"
            $report9 = "Mais detalhes em: " + "$LogFile"

        $Subject = "($hostname) Backup completo!"
        $Body = "$report1`n$report2`n$report3`n$report4`n$report5`n$report6`n$report7`n$report8`n$report9"
        $SMTPServer = "smtp.gmail.com"
        $SMTPPort = "587"
        $PassBase64 = [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String("e2FkaXR1c11HbWFpbHsxMkFETX0="))
        $secpasswd = ConvertTo-SecureString "$PassBase64" -AsPlainText -Force
        $mycreds = New-Object System.Management.Automation.PSCredential($From, $secpasswd)
        Send-MailMessage -From $From -to $To -Subject $Subject -Body $Body -SmtpServer $SMTPServer -port $SMTPPort -UseSsl -Credential $mycreds
        Write-Host "Alerta enviado. `n"
}

#Envia notificação para slack informando conclusão do backup
function Invoke-SendSlack {
        $webhook = "https://hooks.slack.com/services/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"
        $hostname = [System.Net.Dns]::GetHostName()

            $report1 = (Get-Content $LogFile -Tail 9)[0]
            $report2 = (Get-Content $LogFile -Tail 9)[2]
            $report3 = (Get-Content $LogFile -Tail 9)[3]
            $report4 = (Get-Content $LogFile -Tail 9)[4]
            $report5 = (Get-Content $LogFile -Tail 9)[5]
            $report6 = (Get-Content $LogFile -Tail 9)[6]
            $report7 = (Get-Content $LogFile -Tail 9)[7]
            $report8 = "------------------------------------------------------------------------------"
            #$report9 = "Mais detalhes em: $LogFile"

        $data = Get-Date -Format "dddd dd/MM/yyyy HH:mm"
        $body = @"
        {
                "attachments": [
                {
                        "fallback": "Phoenix Tool Notifications.",
                        "pretext": "Phoenix Tool Notifications",
                        "color": "#FF4500",
                        "title": "($hostname) Backup Completo!\n",
                        "text": "$data \n$report1\n$report2\n$report3\n$report4\n$report5\n$report6\n$report7\n$report8",
                        "footer": "by Oliba"
                }
            ]
        }
"@
        Invoke-RestMethod -uri $webhook -Method Post -body $body -ContentType 'application/json'
}

Invoke-DelFullOld
Invoke-DelDiffOld
Invoke-DelAllDestOld
Invoke-CopyNewFiles
Invoke-SendEmail