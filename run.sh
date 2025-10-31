#!/bin/bash

RESTORE_ID=${RESTORE_ID:-"latest"}

rm -f /backup.sh
cat <<EOF >> /backup.sh
#!/bin/bash

cd /volume

TIMESTAMP=\`/usr/bin/env date +"%Y%m%dT%H%M%S"\`
BACKUP_NAME=\${TIMESTAMP}.tar.gz

echo -n "[\${TIMESTAMP}] Compressing backup..."
tar -czf ../\${BACKUP_NAME} ./
echo " Done"

echo -n "[\${TIMESTAMP}] Uploading to S3..."
if s3cmd \
    --quiet \
    --access_key=$AWS_ACCESS_KEY_ID \
    --secret_key=$AWS_SECRET_ACCESS_KEY \
    --region=$AWS_REGION \
    --acl-private \
    put \
    ../\${BACKUP_NAME} \
    s3://${AWS_S3_BUCKET}/${AWS_S3_PATH} ; then

    echo " Done"

    echo -n "[\${TIMESTAMP}] Linking latest on S3..."
    if s3cmd \
        --quiet \
        --access_key=$AWS_ACCESS_KEY_ID \
        --secret_key=$AWS_SECRET_ACCESS_KEY \
        --region=$AWS_REGION \
        --acl-private \
        cp \
        s3://${AWS_S3_BUCKET}/${AWS_S3_PATH}\${BACKUP_NAME} \
        s3://${AWS_S3_BUCKET}/${AWS_S3_PATH}latest.tar.gz ; then

        echo " Done"
    else
        echo " Failed"
        exit 1
    fi
else
    echo " Failed"
    exit 1
fi

rm ../\${BACKUP_NAME}
EOF
chmod +x /backup.sh

rm -f /restore.sh
cat <<EOF >> /restore.sh
#!/bin/bash

cd /volume

rm -rf ./*

RESTORE_NAME=${RESTORE_ID}.tar.gz

echo -n "[${RESTORE_ID}] Downloading from S3..."
if s3cmd \
    --quiet \
    --access_key=$AWS_ACCESS_KEY_ID \
    --secret_key=$AWS_SECRET_ACCESS_KEY \
    --region=$AWS_REGION \
    get \
    s3://${AWS_S3_BUCKET}/${AWS_S3_PATH}\${RESTORE_NAME} \
    ../\${RESTORE_NAME} ; then
    echo " Done"

    echo -n "[\${RESTORE_ID}] Extracting backup..."
    tar -xzf ../\${RESTORE_NAME}
    echo " Done"

    rm ../\${RESTORE_NAME}
else
    echo " Failed"
    exit 1
fi
EOF
chmod +x /restore.sh

rm -f /list.sh
cat <<EOF >> /list.sh
#!/bin/bash
s3cmd \
    --access_key=$AWS_ACCESS_KEY_ID \
    --secret_key=$AWS_SECRET_ACCESS_KEY \
    --region=$AWS_REGION \
    ls \
    s3://${AWS_S3_BUCKET}/${AWS_S3_PATH} \
    | awk '{print $3}' \
    | sed 's/.*\///'
EOF
chmod +x /list.sh

ln -sf /list.sh /usr/bin/list-backups

if [[ "$ACTION" == "BACKUP" ]]; then
    /backup.sh
fi

if [[ "$ACTION" == "BACKUP_AND_SCHEDULE" || "$ACTION" == "SCHEDULE" ]]; then
    if [[ "$ACTION" == "BACKUP_AND_SCHEDULE" ]]; then
        /backup.sh
    fi

    touch /cron.log
    echo "${CRON_SCHEDULE} /backup.sh >> /cron.log 2>&1" > /crontab.conf
    crontab /crontab.conf
    crontab -l
    cron && tail -f /cron.log
fi

if [[ "$ACTION" == "RESTORE" ]]; then
    /restore.sh
fi

if [[ "$ACTION" == "LIST" ]]; then
    /list.sh
fi
