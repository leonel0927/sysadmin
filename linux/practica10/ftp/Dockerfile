FROM alpine:3.19
LABEL description="vsftpd FTP - Practica 10"
RUN apk update && apk add --no-cache vsftpd && rm -rf /var/cache/apk/* \
    && addgroup -S ftpgroup \
    && adduser  -S ftpuser -G ftpgroup -h /ftp -s /bin/false \
    && mkdir -p /var/run/vsftpd/empty /ftp/uploads \
    && chown -R ftpuser:ftpgroup /ftp
COPY vsftpd.conf   /etc/vsftpd/vsftpd.conf
COPY ftp-entry.sh  /usr/local/bin/ftp-entry.sh
RUN chmod +x /usr/local/bin/ftp-entry.sh
EXPOSE 21 21100-21110
ENTRYPOINT ["/usr/local/bin/ftp-entry.sh"]
