# PowerShell script for Windows
# Manual database backup script

# Configuration
$BACKUP_DIR = ".\backups"
$DAYS_TO_KEEP = 30
$TIMESTAMP = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

Write-Host "---------------------------------------------------" -ForegroundColor Cyan
Write-Host "🚀 Starting manual database backup..." -ForegroundColor Cyan
Write-Host "---------------------------------------------------" -ForegroundColor Cyan

# 1. Execute backup by calling the container
# The container's internal script generates the file in /backups (mapped to your local ./backups)
docker exec postgres_backup /backup.sh

# Check if the previous command (docker exec) was successful
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Backup completed successfully!" -ForegroundColor Green
    
    # 2. Cleanup old files to save space on Windows
    Write-Host "🧹 Removing local backups older than $DAYS_TO_KEEP days..." -ForegroundColor Yellow
    
    if (Test-Path $BACKUP_DIR) {
        $cutoffDate = (Get-Date).AddDays(-$DAYS_TO_KEEP)
        Get-ChildItem -Path $BACKUP_DIR -Filter "*.sql.gz" | Where-Object {
            $_.LastWriteTime -lt $cutoffDate
        } | Remove-Item -Force
        
        Write-Host "📂 Check the $BACKUP_DIR folder in your project." -ForegroundColor Cyan
        Write-Host "📄 File generated and logged in the container." -ForegroundColor Cyan
    }
    
    # 3. Update Swagger/API Cache (Optional, but useful if tables changed)
    Write-Host "🔄 Updating API cache..." -ForegroundColor Yellow
    docker kill -s SIGUSR1 postgrest_api
    
    Write-Host "✅ All done! Backup saved and API updated." -ForegroundColor Green
} else {
    Write-Host "❌ Error attempting to perform backup. Check if containers are running." -ForegroundColor Red
}

Write-Host "---------------------------------------------------" -ForegroundColor Cyan
Write-Host "✨ Process finished at: $TIMESTAMP" -ForegroundColor Cyan

