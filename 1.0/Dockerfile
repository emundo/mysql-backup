# This is forked from https://github.com/deitch/mysql-backup
# Mysql backup image
FROM alpine:3.5
MAINTAINER Georgi Potzkov <georgi.potzkov@e-mundo.de>

# Timezone for backup timestamp
ENV TIMEZONE=Europe/Vienna

# Install the necessary client
RUN apk add --update mysql-client bash apk-cron && \
    rm -rf /var/cache/apk/*

# Set timezone
RUN apk add --virtual tz --no-cache tzdata && \
    cp /usr/share/zoneinfo/$TIMEZONE /etc/localtime && echo $TIMEZONE > /etc/timezone && \
    apk del tz && rm -rf /var/cache/apk/*

ENV CRON_TIME="0 0 * * *"

ADD run.sh /run.sh
RUN chmod +x /run.sh
VOLUME ["/backup"]

CMD ["/run.sh"]
