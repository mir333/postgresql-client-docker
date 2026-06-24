#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <path-to-tar.gz>"
    echo "Example: $0 /tmp/data.2026-04-08T12:00:00+00:00.tar.gz"
    exit 1
fi

GZIPPED_FILE="$1"
EXTRACT_DIR="/tmp/restore_$$"

if [ ! -f "$GZIPPED_FILE" ]; then
    echo "Error: File $GZIPPED_FILE not found."
    exit 1
fi

echo "Starting PostgreSQL database restore from $GZIPPED_FILE..."

mkdir -p "$EXTRACT_DIR"

tar -xzf "$GZIPPED_FILE" -C "$EXTRACT_DIR"

if [ $? -ne 0 ]; then
    echo "Error: Extraction failed. Exiting."
    rm -rf "$EXTRACT_DIR"
    exit 1
fi

DUMP_DIR=$(find "$EXTRACT_DIR" -maxdepth 1 -type d -name "dump_*" | head -1)

if [ -z "$DUMP_DIR" ]; then
    echo "Error: No dump directory found in archive."
    rm -rf "$EXTRACT_DIR"
    exit 1
fi

echo "Restoring database from $DUMP_DIR..."

pg_restore \
    --host=localhost \
    --port=5432 \
    --username=postgres \
    --format=directory \
    --jobs=2 \
    --data-only \
    --disable-triggers \
    --dbname=postgres \
    "$DUMP_DIR"

if [ $? -ne 0 ]; then
    echo "Error: Database restore failed."
    rm -rf "$EXTRACT_DIR"
    exit 1
fi

echo "Cleaning up..."
rm -rf "$EXTRACT_DIR"

echo "Restore completed successfully."
