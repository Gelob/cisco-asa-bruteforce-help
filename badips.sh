#!/bin/bash

# Get the current year, month, and day
YEAR=$(date +%Y)
MONTH=$(date +%m)
DAY=$(date +%d)
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# Set the path to your vpn device log files
DIR_PATH="/opt/syslog/myvpn.test.lab/${YEAR}/${MONTH}/${DAY}"

# Change to the directory
cd "$DIR_PATH" || { echo "$DATE - Error: Directory $DIR_PATH does not exist."; exit 1; }

# Optionally print the current directory to confirm
echo "$DATE - INFO: Current directory: $(pwd)"

# Set running directory and filename
DIRECTORY="/opt/syslog/myvpn.test.lab/badips"
FILENAME="$(date '+%Y-%m-%d_%H-%M-%S')_badips.txt"
WEB_DIR="/usr/share/nginx/html/badips"

#Create badips.txt if it doesn't exist
[ ! -e $WEB_DIR/badips.txt ] && touch $WEB_DIR/badips.txt

#Find bad IPs who failed 20 or more times and write to a file with their total amount to save for later investigation if needed
grep -rP 'ASA-6-(113005|113015): AAA user authentication Rejected.*user IP = \d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}' syslog.txt | grep -oP '(?<=user IP = )\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}'| awk '{print $1 "/32"}' | sort | uniq -c | awk '$1 > 20 {print $1 " " $2}' | sort -nr > /"${DIRECTORY}"/"${FILENAME}" || { echo "$DATE - Error: Failed to find bad ips and write file."; exit 1; }

#Count the number of IPs in the file
LINES=$(wc -l < $DIRECTORY/$FILENAME) || { echo "$DATE - Error: Failed to count lines"; exit 1; }

#Note for logging
echo "$DATE - INFO: Wrote ${FILENAME} with ${LINES} bad IPs"

# Find bad IPs who failed 20 or more times and write to temp file to be included in main badips.txt file
grep -rP 'ASA-6-(113005|113015): AAA user authentication Rejected.*user IP = \d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}' syslog.txt | grep -oP '(?<=user IP = )\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}'| awk '{print $1 "/32"}' | sort | uniq -c | awk '$1 > 20 {print $2}' | sort -nr > $WEB_DIR/badipstemp.txt || { echo "$DATE - Failed to write badipstemp.txt"; exit 1; }

#Backup badips file incase something goes wrong
cp "$WEB_DIR/badips.txt" "$WEB_DIR/badips.txt.bak" || { echo "$DATE - Error: Failed to backup badips.txt."; exit 1; }

#Copy existing bad IPs file to temp file so we can combine the old with new bad IPs
cp "$WEB_DIR/badips.txt" "$WEB_DIR/badipstemp2.txt" || { echo "$DATE - Error: Failed to copy badips.txt to temp file"; exit 1; }

#Do the combination of old IPs and new IPs
cat "$WEB_DIR/badipstemp.txt" "$WEB_DIR/badipstemp2.txt" | sort | uniq > "$WEB_DIR/badips.txt" || { echo "$DATE - Error: Failed to combine old and new bad IPs file."; exit 1; }

#Remove the old files
rm -rf "$WEB_DIR/badipstemp2.txt"
rm -rf "$WEB_DIR/badipstemp.txt"

#Delete investigation files older than 30 days
FILES=$(find $DIRECTORY -type f -name '*_badips.txt' -mtime +30 | paste -sd, -)
if [ -z "$FILES" ]; then
  echo "$DATE - INFO: Found no files to delete over 30 days"
else
  find $DIRECTORY -type f -name '*_badips.txt' -mtime +30 -delete
  echo "$DATE - INFO: Deleted $FILES"
fi

FLINES=$(wc -l < $WEB_DIR/badips.txt) || { echo "$DATE - Error: Failed to count lines in badips.txt"; exit 1; }
echo "$DATE - INFO: Wrote new badips.txt with total lines of $FLINES"
