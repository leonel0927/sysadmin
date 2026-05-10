FROM alpine:3.19
RUN apk add --no-cache python3
WORKDIR /app
COPY index.html .
EXPOSE 3000
CMD ["python3", "-m", "http.server", "3000"]
