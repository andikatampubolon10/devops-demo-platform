# DevOps Demo Platform

This project includes a simple Node.js app, a worker, and RabbitMQ.

## Run with Docker Compose

### 1. Development (with Hot Reload)

Runs the stack with volume mounts, hot reload (`node --watch`), and exposed RabbitMQ management UI:

```bash
docker compose -f docker-compose.dev.yml up --build
```

Then open:
- App: http://localhost:3000
- RabbitMQ Management: http://localhost:15672 (User/Pass: `guest`/`guest`)

To stop:
```bash
docker compose -f docker-compose.dev.yml down
```

### 2. Production (Production-shaped Stack)

Runs the production stack with secure internal networking, resource limits, and persistent data:

```bash
docker compose up --build
# or
docker compose -f docker-compose.yml up -d
```

Then open:
- App: http://localhost:3000

To stop:
```bash
docker compose down
```

### 3. Jenkins (CI/CD Pipeline)

Runs the custom Jenkins container (equipped with Docker CLI, Terraform, and kubectl):

```bash
docker compose -f docker-compose.jenkins.yml up -d --build
```

Then open:
- Jenkins UI: http://localhost:8080

Get initial admin password:
```bash
docker exec -it devops-jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

To stop:
```bash
docker compose -f docker-compose.jenkins.yml down
```

## Useful Commands

```bash
# View logs
docker compose logs -f app
docker compose logs -f worker

# Or in development:
docker compose -f docker-compose.dev.yml logs -f app

# Check status
docker compose ps
```
