# mysql-backup

This is forked from https://github.com/jmcarbo/docker-postgres-backup and adapted for MySQL
This image runs mysqldump to backup data using cronjob to folder `/backup`

## Usage:

    docker run -d \
        --env MYSQL_HOST=mysql.host \
        --env MYSQL_USER=admin \
        --env MYSQL_PASSWORD=password \
        --volume host.folder:/backup
        emundo/mysql-backup

Remember that you can also Link the containers to set the mysql.host `--link mysql-container:mysql.host`

## Parameters

    MYSQL_HOST      the host/ip of your mysql database
    MYSQL_PORT      the port number of your postgres database (Default: 3306)
    MYSQL_USER      the username of your postgres database
    MYSQL_PASSWORD      the password of your postgres database
    MYSQL_DB        the database name to dump. Default: `--all-databases`
    CRON_TIME       the interval of cron job to run mysqldump. `0 0 * * *` by default, which is every day at 00:00
    MAX_BACKUPS     the number of backups to keep. When reaching the limit, the old backup will be discarded. No limit by default
    INIT_BACKUP     if set, create a backup when the container starts
    INIT_RESTORE_LATEST if set, restores latest backup

## Restore from a backup

See the list of backups, you can run:

    docker exec mysql-backup ls /backup

To restore database from a certain backup, simply run:

    docker exec mysql-backup /restore.sh /backup/<DB>/<backup.sql>

