#!/bin/bash

# Linux/Mac bash script
# Manual database backup script

# Configuration
BACKUP_DIR="./backups"
DAYS_TO_KEEP=30
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

echo "---------------------------------------------------"
echo "🚀 Starting manual database backup..."
echo "---------------------------------------------------"

# 1. Execute backup by calling the container
# The container's internal script generates the file in /backups (mapped to your local ./backups)
docker exec postgres_backup /backup.sh

# Check if the previous command (docker exec) was successful
if [ $? -eq 0 ]; then
    echo "✅ Backup completed successfully!"
    
    # 2. Cleanup old files to save space
    echo "🧹 Removing local backups older than $DAYS_TO_KEEP days..."
    find "$BACKUP_DIR" -name "*.sql.gz" -mtime +$DAYS_TO_KEEP -exec rm {} \;
    
    echo "📂 Check the $BACKUP_DIR folder in your project."
    echo "📄 File generated and logged in the container."
    
    # 3. Update Swagger/API Cache (Optional, but useful if tables changed)
    echo "🔄 Updating API cache..."
    docker kill -s SIGUSR1 postgrest_api
    
    echo "✅ All done! Backup saved and API updated."
else
    echo "❌ Error attempting to perform backup. Check if containers are running."
fi

echo "---------------------------------------------------"
echo "✨ Process finished at: $TIMESTAMP"

