#!/bin/bash
file_env() {
	local var="$1"
	local fileVar="${var}_FILE"
	local def="${2:-}"
	if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
		echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
		exit 1
	fi
	local val="$def"
	if [ "${!var:-}" ]; then
		val="${!var}"
	elif [ "${!fileVar:-}" ]; then
		val="$(< "${!fileVar}")"
	fi
	export "$var"="$val"
	unset "$fileVar"
}


file_env 'MYSQL_PASSWORD'
if [ "$MYSQL_PASSWORD" ]; then
	echo >&1 "...MYSQL_PASSWORD was successfully set."
else
	# The - option suppresses leading tabs but *not* spaces. :)
		cat >&2 <<-'EOWARN'
				****************************************************
				WARNING: No password has been set for the database.
				This will very likely result in JIRA not starting up
				correctly. Please provide a password.

				Use "-e MYSQL_PASSWORD=password" to set
				it in "docker run".

				Note: You can also use docker secrets with the 
				"_FILE" ending. Use 
				"-e MYSQL_PASSWORD_FILE=/run/secrets/mysecret" to 
				set it in "docker run" 
				****************************************************
		EOWARN
fi

MYSQL_PASSWORD=${MYSQL_PASSWORD:-${MYSQL_ENV_MYSQL_PASSWORD}}

[ -z "${MYSQL_HOST}" ] && { echo "=> MYSQL_HOST cannot be empty" && exit 1; }
[ -z "${MYSQL_USER}" ] && { echo "=> MYSQL_USER cannot be empty" && exit 1; }
[ -z "${MYSQL_PASSWORD}" ] && { echo "=> MYSQL_PASSWORD cannot be empty" && exit 1; }
[ -z "${MYSQL_DB}" ] && { echo "=> MYSQL_DB cannot be empty" && exit 1; }
[ -z "${MYSQL_PORT}" ] && { export MYSQL_PORT=3306; }
export MYSQLPASSWORD="${MYSQL_PASSWORD}"

BACKUP_CMD="mysqldump -A -h ${MYSQL_HOST} -P${MYSQL_PORT} -u${MYSQL_USER} -p${MYSQL_PASSWORD} > /backup/\${MYSQL_DB}/\${BACKUP_NAME}"

mkdir /backup/${MYSQL_DB}

echo "=> Creating backup script"
rm -f /backup.sh
cat <<EOF >> /backup.sh
#!/bin/bash

MAX_BACKUPS=${MAX_BACKUPS}

BACKUP_NAME=\${MYSQL_DB}\$(date +\%Y.\%m.\%d.\%H\%M\%S).sql

export MYSQLPASSWORD="${MYSQL_PASSWORD}"

echo "=> Backup started: \${BACKUP_NAME}"
if ${BACKUP_CMD} ;then
		echo "   Backup succeeded"
else
		echo "   Backup failed"
		rm -rf /backup/\${MYSQL_DB}/\${BACKUP_NAME}
fi

if [ -n "\${MAX_BACKUPS}" ]; then
		while [ \$(ls /backup/\${MYSQL_DB} -w1 | wc -l) -gt \${MAX_BACKUPS} ];
		do
				BACKUP_TO_BE_DELETED=\$(ls /backup/\${MYSQL_DB} -w1 | sort | head -n 1)
				echo "   Backup \${BACKUP_TO_BE_DELETED} is deleted"
				rm -rf /backup/\${MYSQL_DB}/\${BACKUP_TO_BE_DELETED}
		done
fi
echo "=> Backup done"
EOF
chmod +x /backup.sh

echo "=> Creating restore script"
rm -f /restore.sh
cat <<EOF >> /restore.sh
#!/bin/bash

export MYSQLPASSWORD="${MYSQL_PASSWORD}"

echo "=> Restore database from \$1"
if mysql -h${MYSQL_HOST} -P${MYSQL_PORT} -u${MYSQL_USER} -p${MYSQL_PASSWORD}< \$1 ;then
		echo "   Restore succeeded"
else
		echo "   Restore failed"
fi
echo "=> Done"
EOF
chmod +x /restore.sh

touch /mysql_backup.log
tail -F /mysql_backup.log &

if [ -n "${INIT_BACKUP}" ]; then
		echo "=> Create a backup on the startup"
		/backup.sh
elif [ -n "${INIT_RESTORE_LATEST}" ]; then
		echo "=> Restore latest backup"
		until nc -z $MYSQL_HOST
		do
				echo "waiting database container..."
				sleep 1
		done
		ls -d -1 /backup/${MYSQL_DB}/* | tail -1 | xargs /restore.sh
fi

echo "${CRON_TIME} export MAX_BACKUPS=${MAX_BACKUPS}; export MYSQL_DB=${MYSQL_DB}; /backup.sh >> /mysql_backup.log 2>&1" > /crontab.conf
crontab  /crontab.conf
echo "=> Running cron job"
crond -f -l 8
