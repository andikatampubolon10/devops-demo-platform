# DevOps Demo Platform

This project includes a simple Node.js app, a worker, and RabbitMQ.

## Run locally with Docker Compose

From the project root:

```bash
docker compose up --build
```

Then open:

- App: http://localhost:3000
- RabbitMQ Management: http://localhost:15672

## Stop services

```bash
docker compose down
```

## Useful commands

```bash
docker compose logs -f app

docker compose logs -f worker

docker compose ps
```
