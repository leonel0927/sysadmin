FROM alpine:3.19
LABEL description="Apache personalizado - Practica 10"
RUN apk update && apk add --no-cache apache2 apache2-utils curl iputils-ping \
    && rm -rf /var/cache/apk/* \
    && echo "ServerTokens Prod"   >> /etc/apache2/httpd.conf \
    && echo "ServerSignature Off" >> /etc/apache2/httpd.conf \
    && echo "TraceEnable Off"     >> /etc/apache2/httpd.conf \
    && addgroup -S webgroup \
    && adduser  -S webuser -G webgroup \
    && mkdir -p /var/www/html/uploads /var/log/apache2 /var/run/apache2
COPY html/ /var/www/html/
RUN printf '<Directory "/var/www/html/uploads">\n  Options +Indexes\n  Require all granted\n</Directory>\n' \
        >> /etc/apache2/conf.d/uploads.conf \
    && chown -R webuser:webgroup /var/www/html /var/log/apache2
EXPOSE 80
USER webuser
CMD ["httpd","-D","FOREGROUND","-f","/etc/apache2/httpd.conf"]
