#!/bin/bash

# Configuration
DB_HOST="dpg-d5jkq924d50c73d2mh10-a.frankfurt-postgres.render.com"
DB_PORT="5432"
DB_USER="gostar"
DATABASE_NAME="gostar_03zx"

BACKUP_DIR="/home/ubuntu/backup"
S3_BUCKET="gostar-db-backup"
AWS_REGION="eu-central-1"

# Generated Variables
TIMESTAMP=$(date -u -Iseconds)
BACKUP_FILENAME="data.$TIMESTAMP.tar.gz"
GZIPPED_FILE="$BACKUP_DIR/$BACKUP_FILENAME"

echo "Starting PostgreSQL database backup at $TIMESTAMP..."

if [ -z "$PGPASSWORD" ]; then
    echo "Error: PGPASSWORD environment variable is not set."
    exit 1
fi

mkdir -p "$BACKUP_DIR" || { echo "Error: Could not create backup directory $BACKUP_DIR. Exiting."; exit 1; }

pg_dump \
    --host="$DB_HOST" \
    --port="$DB_PORT" \
    --username="$DB_USER" \
    --column-inserts \
    --data-only \
    "$DATABASE_NAME" \
| gzip \
> "$GZIPPED_FILE"

if [ $? -ne 0 ]; then
    echo "Error: Database backup failed. No file created at $GZIPPED_FILE. Exiting."
    exit 1
fi

echo "Backup created: $GZIPPED_FILE"

echo "Uploading $BACKUP_FILENAME to s3://$S3_BUCKET/..."
aws s3 cp "$GZIPPED_FILE" "s3://$S3_BUCKET/$BACKUP_FILENAME" --region "$AWS_REGION"

if [ $? -ne 0 ]; then
    echo "Error: S3 upload failed for $GZIPPED_FILE. The local file has NOT been deleted."
    exit 1
fi

echo "Successfully uploaded $BACKUP_FILENAME to S3."

echo "Deleting local backup file: $GZIPPED_FILE"
rm "$GZIPPED_FILE"

if [ $? -ne 0 ]; then
    echo "Warning: Failed to delete local backup file $GZIPPED_FILE."
    exit 0
fi

echo "Local backup file deleted successfully."
echo "Backup process completed."
