FROM ubuntu:24.04

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl gnupg openssl unzip \
    && install -d /usr/share/postgresql-common/pgdg \
    && curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.gpg \
    && echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.gpg] http://apt.postgresql.org/pub/repos/apt noble-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends nodejs npm postgresql-client-18 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
RUN unzip awscliv2.zip && ./aws/install

COPY backup-new.sh /app
RUN chmod +x /app/backup-new.sh

RUN cat > server.js <<'EOF'
const http = require('http');
const fs = require('fs');

const port = process.env.PORT ? Number(process.env.PORT) : 3000;

const server = http.createServer((req, res) => {
  if (req.method === 'GET' && req.url === '/backup.log') {
    fs.readFile('/app/backup.log', 'utf8', (err, data) => {
      if (err) {
        res.statusCode = err.code === 'ENOENT' ? 404 : 500;
        res.setHeader('Content-Type', 'text/plain; charset=utf-8');
        res.end('backup.log not available');
        return;
      }

      res.statusCode = 200;
      res.setHeader('Content-Type', 'text/plain; charset=utf-8');
      res.end(data);
    });
    return;
  }

  res.statusCode = 200;
  res.setHeader('Content-Type', 'application/json');
  res.end(JSON.stringify({ ok: true }));
});

server.listen(port, '0.0.0.0');
EOF

EXPOSE 3000

CMD ["/bin/bash", "-c", "/app/backup-new.sh > /app/backup.log 2>&1 && exec node /app/server.js"]
