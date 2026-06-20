# Smart Renewable Energy Monitoring Platform — Complete Technical Guide

> **Who is this for?**
> A .NET fresher who has written some C# code but is new to ASP.NET Core, cloud, Docker, and system design. Every concept is explained from first principles before diving into what this project actually does with it.

---

## Table of Contents

1. [What Is This Project?](#1-what-is-this-project)
2. [Why Microservices? (The Core Idea)](#2-why-microservices-the-core-idea)
3. [The Big Picture — All 7 Containers at a Glance](#3-the-big-picture--all-7-containers-at-a-glance)
4. [How Docker and Docker Compose Work](#4-how-docker-and-docker-compose-work)
5. [The End-to-End Data Flow](#5-the-end-to-end-data-flow)
6. [Service 1 — Asset Service (.NET 9)](#6-service-1--asset-service-net-9)
7. [Service 2 — Telemetry Service (Python)](#7-service-2--telemetry-service-python)
8. [Service 3 — Anomaly Detection Service (Python)](#8-service-3--anomaly-detection-service-python)
9. [Service 4 — Alert Service (Python)](#9-service-4--alert-service-python)
10. [Service 5 — Simulator (Python)](#10-service-5--simulator-python)
11. [Service 6 — Dashboard (nginx)](#11-service-6--dashboard-nginx)
12. [Infrastructure Services (LocalStack, PostgreSQL, Redis)](#12-infrastructure-services-localstack-postgresql-redis)
13. [Key Design Patterns Explained](#13-key-design-patterns-explained)
14. [The .NET Layered Architecture (Asset Service Deep Dive)](#14-the-net-layered-architecture-asset-service-deep-dive)
15. [AWS Concepts Used (Locally Simulated)](#15-aws-concepts-used-locally-simulated)
16. [CI/CD Pipeline Explained](#16-cicd-pipeline-explained)
17. [How to Run the Project Locally](#17-how-to-run-the-project-locally)
18. [Ports and Endpoints Quick Reference](#18-ports-and-endpoints-quick-reference)

---

## 1. What Is This Project?

Imagine a power company that runs 5 renewable energy assets: two wind turbines, a solar farm, a hydroelectric station, and a battery storage unit. Each asset has physical sensors attached to it that constantly measure things like temperature, vibration, power output, and wind speed.

This project is the **software backend** that:

1. **Keeps a record of all assets** (name, type, location, capacity)
2. **Ingests sensor readings** every 5 seconds from all 5 assets
3. **Automatically detects** if any reading is dangerous or unusual
4. **Raises an alert** when something is wrong, and logs what action to take
5. **Shows everything on a live web dashboard** so an operator can see the fleet at a glance

The "operator" is not physically present at each turbine — they sit in a control room and watch this dashboard.

---

## 2. Why Microservices? (The Core Idea)

### The old way — a Monolith

Imagine you built all this as one big program: one codebase, one database, one running process. This is called a **monolith**.

Problems with a monolith:
- If the anomaly detection crashes, the whole thing goes down — you can't save assets either
- You can't scale just the telemetry ingestion when traffic spikes; you have to scale everything
- Different teams can't work independently without stepping on each other's code

### The new way — Microservices

Break the system into **small, independent programs (services)** that each do one job and communicate over the network.

Each service:
- Runs in its own container (isolated environment)
- Has its own database
- Can be deployed, scaled, and restarted independently
- Communicates with other services via HTTP APIs or message queues

**Analogy:** Think of a restaurant kitchen. The grill station, salad station, and dessert station each operate independently. If the dessert station runs out of stock, the grilled food keeps going out. That's microservices.

This project has **5 microservices** + 1 simulator + 1 dashboard + 3 infrastructure services.

---

## 3. The Big Picture — All 7 Containers at a Glance

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                           Docker Network: renewable-energy-network            │
│                                                                              │
│  ┌──────────────┐   HTTP POST    ┌────────────────────┐                     │
│  │  Simulator   │ ─────────────► │  Telemetry Service │                     │
│  │  (Python)    │                │  (Python/FastAPI)  │                     │
│  │  port: none  │                │  port: 5002        │                     │
│  └──────────────┘                └────────┬───────────┘                     │
│                                           │                                  │
│                                    saves to DynamoDB                         │
│                                    publishes to SQS                          │
│                                           │                                  │
│                                           ▼                                  │
│                                  ┌────────────────────┐                     │
│                                  │  Anomaly Detection  │                     │
│                                  │  (Python/FastAPI)   │                     │
│                                  │  port: 5003         │◄─── SQS consumer   │
│                                  └────────┬────────────┘                     │
│                                           │                                  │
│                                    saves to DynamoDB                         │
│                                    publishes to SNS                          │
│                                           │                                  │
│                                           ▼                                  │
│                                  ┌────────────────────┐                     │
│                                  │   Alert Service    │                     │
│                                  │  (Python/FastAPI)  │                     │
│                                  │  port: 5004        │◄─── SQS consumer   │
│                                  └────────────────────┘                     │
│                                           │                                  │
│                                    saves to DynamoDB                         │
│                                                                              │
│  ┌──────────────┐    HTTP/REST   ┌────────────────────┐                     │
│  │  Dashboard   │ ◄──────────── │   Asset Service    │                     │
│  │  (nginx HTML)│ ──────────►   │  (.NET 9 / C#)     │                     │
│  │  port: 3000  │               │  port: 5001        │                     │
│  └──────────────┘               └────────────────────┘                     │
│                                           │                                  │
│                                    PostgreSQL (port 5432)                    │
│                                    Redis (port 6379)                         │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │  LocalStack (port 4566) — emulates AWS on your laptop                │   │
│  │  DynamoDB tables: Telemetry, Anomalies, Alerts                       │   │
│  │  SQS queues: telemetry-events, anomaly-events                        │   │
│  │  SNS topics: telemetry-topic, anomaly-topic, alert-topic             │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 4. How Docker and Docker Compose Work

### What is Docker?

Normally, to run a .NET app you install the .NET SDK, configure environment variables, set up PostgreSQL, etc. This means the app only works on your specific machine setup.

**Docker** packages an application + all its dependencies (runtime, config, libraries) into a single **image** — like a ZIP file of a complete environment. When you run that image, you get a **container** — an isolated, reproducible running instance.

Think of a Docker image as a recipe, and a container as the meal cooked from that recipe. You can cook the same meal on any stove (any machine).

### What is Docker Compose?

Running 7+ containers by hand (`docker run ...` for each) and wiring them together would be tedious. **Docker Compose** lets you declare all containers in one file (`docker-compose.yml`) and start/stop them all with one command.

### How this project's docker-compose.yml works

The file is at [infrastructure/docker-compose/docker-compose.yml](../infrastructure/docker-compose/docker-compose.yml).

**Startup order matters** — databases must be ready before apps try to connect. The file uses `depends_on` with `condition: service_healthy` to enforce this:

```
postgres (healthcheck pg_isready)
    ↓
redis (healthcheck redis-cli ping)
    ↓
localstack (healthcheck curl /_localstack/health)
    ↓
localstack-init (creates DynamoDB tables, SQS queues, SNS topics)
    ↓
asset-service, telemetry-service, anomaly-detection-service, alert-service
    ↓
simulator
    ↓
dashboard
```

Each service gets its configuration via **environment variables** — the connection string for Postgres, the SQS URL, etc. This is how the same Docker image works in dev (pointing at LocalStack) and in production (pointing at real AWS).

---

## 5. The End-to-End Data Flow

Here is the complete journey of one sensor reading — from the moment the simulator generates it to when it appears on the dashboard:

```
Step 1: Simulator wakes up every 5 seconds
        → picks asset "North Wind Farm Alpha" (WindTurbine)
        → generates: { wind_speed: 10.4, rotor_speed: 7.1, power_output: 32.0,
                        temperature: 48.2, vibration: 0.52 }
        → 5% chance it injects an anomaly (e.g. temperature = 88.5)

Step 2: Simulator HTTP POSTs to Telemetry Service
        POST http://telemetry-service:8000/api/v1/telemetry
        Body: { asset_id, timestamp, type, metrics, source: "simulator" }

Step 3: Telemetry Service saves record to DynamoDB (Table: Telemetry)
        Primary key: asset_id (partition key) + timestamp (sort key)
        → Also publishes a JSON message to SQS queue "telemetry-events"

Step 4: Anomaly Detection Service is listening to SQS queue "telemetry-events"
        → It reads the message (long-polling, checks every 5 seconds)
        → Fetches last 60 minutes of history for this asset from DynamoDB
        → Runs two checks:
            a) Threshold check: is temperature > 80? is vibration > 5?
            b) Rate-of-change check: did temperature jump > 10 degrees from last reading?
            c) ML check (if 15+ history points): does Isolation Forest flag this as unusual?
        → If anomaly found: saves to DynamoDB (Table: Anomalies)
        → Publishes anomaly event to SNS topic "anomaly-topic"

Step 5: SNS delivers the anomaly event to SQS queue "anomaly-events"
        (SNS → SQS fan-out: SNS can deliver the same message to multiple queues)

Step 6: Alert Service is listening to SQS queue "anomaly-events"
        → Reads the message
        → Creates a structured Alert record with severity (HIGH/CRITICAL/MEDIUM)
        → Logs simulated notifications:
            - All alerts: WEBHOOK channel logged
            - HIGH/CRITICAL: "Would post to Slack #ops"
            - CRITICAL: "Would page PagerDuty on-call"
        → Saves alert to DynamoDB (Table: Alerts) with status: NEW

Step 7: Dashboard (browser JavaScript) polls all services every 15 seconds
        GET http://localhost:5001/api/v1/assets           → asset list
        GET http://localhost:5002/api/v1/telemetry        → latest readings
        GET http://localhost:5003/api/v1/anomalies        → detected anomalies
        GET http://localhost:5004/api/v1/alerts           → active alerts
        → Updates the charts, tables, and status indicators live
```

---

## 6. Service 1 — Asset Service (.NET 9)

This is the most architecturally complex service in the project. It's written in C# with ASP.NET Core 9 and follows enterprise-grade design patterns.

### What it does

- Register new energy assets (wind turbines, solar farms, etc.)
- Look up an asset by ID
- List all assets with optional filtering by type or status
- Update an asset's status (Active / Maintenance / Offline / Decommissioned)
- Schedule maintenance on an asset
- Delete an asset

### Technology choices

| Technology | What it is | Why used here |
|---|---|---|
| ASP.NET Core 9 | Microsoft's web framework for C# | Host HTTP API endpoints |
| Entity Framework Core 9 | Object-Relational Mapper (ORM) | Talk to PostgreSQL without writing raw SQL |
| MediatR 12 | In-process messaging library | Implement CQRS (see below) |
| AutoMapper 13 | Object-to-object mapper | Convert between domain objects and API response shapes |
| FluentValidation 11 | Validation library | Validate incoming request bodies cleanly |
| Npgsql | PostgreSQL driver for .NET | EF Core uses this to connect to PostgreSQL |
| StackExchange.Redis | Redis client | Cache frequently-read asset lists |
| AWS SDK for .NET | Amazon's SDK | Publish events to SQS |

### The 4-Layer Architecture

The Asset Service splits code across 4 projects (C# project = `.csproj` file):

```
AssetService.API              ← HTTP layer: controllers, middleware, startup
    │
    ▼
AssetService.Application      ← Business logic: commands, queries, handlers
    │
    ▼
AssetService.Domain           ← Core concepts: entities, value objects, events
    │
    ▼
AssetService.Infrastructure   ← External concerns: database, cache, messaging
```

Each layer can only depend on the layer below it. The API never directly talks to the database — it goes through Application, which goes through Infrastructure. This is called **Clean Architecture** or **Onion Architecture**.

**Why?** Because if you later swap PostgreSQL for a different database, you only change the Infrastructure layer. The business logic in Application and Domain stays the same.

### What happens when you POST /api/v1/assets

Here is the complete execution path, line by line:

```
1. HTTP request arrives at AssetController.RegisterAsset()
   [File: services/asset-service/src/AssetService.API/Controllers/AssetController.cs:27]

2. ValidationFilter runs before the controller method
   → FluentValidation checks: Name not empty, Type is valid enum, Latitude in [-90,90], etc.
   [File: services/asset-service/src/AssetService.API/Filters/ValidationFilter.cs]

3. Controller calls: await _mediator.Send(command)
   → MediatR looks up which Handler is registered for RegisterAssetCommand
   → Finds RegisterAssetHandler

4. MediatR pipeline runs BEFORE calling the handler:
   a) LoggingBehavior: logs "Handling RegisterAssetCommand" with timer start
   b) ValidationBehavior: runs FluentValidation again (belt-and-suspenders)
   c) PerformanceBehavior: starts stopwatch to warn if handler takes > 500ms

5. RegisterAssetHandler.Handle() runs:
   a) Creates a Domain Entity: new Asset(id, name, type, location, capacity)
      → Asset constructor automatically raises AssetRegisteredEvent (domain event)
   b) Calls _assetRepository.AddAsync(asset) → EF Core tracks the entity
   c) Calls _assetRepository.SaveChangesAsync() → EF Core runs INSERT SQL
   d) Calls _eventPublisher.PublishAsync("AssetRegistered", asset) → sends to SQS
   e) Uses AutoMapper to convert Asset entity to AssetDto (the response shape)
   f) Returns RegisterAssetResponse { Id, Name, Type, Status, ... }

6. Controller returns: 201 Created with Location header pointing to GET /api/v1/assets/{id}

7. ExceptionHandlingMiddleware catches any unhandled exception:
   → Returns structured JSON error: { message, statusCode, traceId }
```

### How the Database is Initialized

On container startup, the Startup class runs `InitialiseDatabase()`:

```csharp
// This uses raw ADO.NET — bypasses EF Core entirely
// Sends SQL directly to PostgreSQL via the Npgsql driver
private static void InitialiseDatabase(ApplicationDbContext db)
{
    db.Database.OpenConnection();
    var conn = db.Database.GetDbConnection();
    
    // CREATE TABLE IF NOT EXISTS means: "create it if it doesn't exist, 
    // do nothing if it already exists" — safe to run on every restart
    Sql(conn, @"CREATE TABLE IF NOT EXISTS ""Assets"" ( ... )");
    Sql(conn, @"CREATE TABLE IF NOT EXISTS ""MaintenanceSchedules"" ( ... )");
    
    // INSERT with ON CONFLICT DO NOTHING = "insert seed data, 
    // but don't fail if those rows already exist"
    Sql(conn, @"INSERT INTO ""Assets"" ... ON CONFLICT (""Id"") DO NOTHING");
}
```

This seeds 5 pre-defined assets that match the 5 assets the simulator knows about.

---

## 7. Service 2 — Telemetry Service (Python)

### What it does

- Accept sensor readings from the simulator (or real sensors)
- Store each reading in DynamoDB
- Publish the reading as an event to SQS and SNS
- Let the dashboard query historical telemetry by asset and time range

### Technology choices

| Technology | What it is |
|---|---|
| Python 3.11 | Programming language |
| FastAPI | Web framework (like ASP.NET Core but for Python) |
| Pydantic | Data validation (like FluentValidation) |
| boto3 | AWS SDK for Python |
| uvicorn | ASGI server (like Kestrel in .NET) |

### Why Python instead of .NET?

Python excels at rapid prototyping of data-intensive services. The anomaly detection service needs NumPy, SciPy, and scikit-learn — libraries with no good .NET equivalents. Using Python for the data pipeline services is a deliberate polyglot design choice.

### Endpoints

```
POST /api/v1/telemetry         → ingest one reading
POST /api/v1/telemetry/batch   → ingest multiple readings at once
GET  /api/v1/telemetry/{id}    → get readings for one asset (time range)
GET  /api/v1/telemetry/{id}/latest → get the most recent reading
GET  /api/v1/telemetry         → scan all recent readings (demo)
GET  /health                   → health check
```

### How `POST /api/v1/telemetry` works

```python
# 1. FastAPI validates the request body using Pydantic model TelemetryDatapoint
#    (equivalent to FluentValidation in .NET)

# 2. _store_record() saves to DynamoDB:
table.put_item(Item={
    "asset_id": record.asset_id,    # partition key
    "timestamp": ts.isoformat(),     # sort key — enables range queries by time
    "record_id": str(uuid4()),
    "type": record.type,
    "metrics": {k: str(v) for k, v in record.metrics.items()},  # DynamoDB stores strings
    ...
})

# 3. BackgroundTasks.add_task(_publish, record)
#    → FastAPI returns 201 immediately
#    → _publish() runs in the background AFTER the response is sent
#    → sends to SQS and SNS (fire-and-forget, errors are logged not raised)
```

**Why background task?** The caller (simulator) should not wait for SQS/SNS round-trips. Return fast, publish asynchronously.

### Why DynamoDB instead of PostgreSQL?

- Telemetry is time-series data: write-heavy, high volume, rarely updated
- DynamoDB scales horizontally without configuration changes
- The `asset_id + timestamp` composite key makes time-range queries fast without indexes
- No schema migrations needed when we add new metric types

---

## 8. Service 3 — Anomaly Detection Service (Python)

### What it does

- Listen to SQS queue `telemetry-events` for new readings
- Detect anomalies using two methods:
  - **Threshold rules**: hard limits per metric (temperature > 80°C = HIGH anomaly)
  - **Machine learning**: scikit-learn Isolation Forest for statistical outliers
- Store detected anomalies in DynamoDB
- Publish anomaly events to SNS

### The Dual Detection Strategy

#### Method 1: Threshold Rules

```python
THRESHOLDS = {
    "temperature":  {"min": 20, "max": 80,  "rate_change": 10},
    "vibration":    {"min": 0,  "max": 5,   "rate_change": 0.5},
    "power_output": {"min": 0,  "max": 100, "rate_change": 20},
    ...
}
```

Two sub-checks:
- **Range check**: `value < min OR value > max` → severity HIGH
- **Rate-of-change check**: `abs(current - previous) > rate_change` → severity MEDIUM

This catches obvious physical faults (overheating, excessive vibration).

#### Method 2: Isolation Forest (ML)

```python
# Isolation Forest: an unsupervised ML algorithm
# Idea: "normal" data points are easy to isolate in a forest of random decision trees.
# Anomalies are isolated in fewer splits (they're different from the crowd).
# contamination=0.1 means "expect 10% of the training data to be outliers"

if len(history) >= 15:    # need enough data to train the model
    model = IsolationForest(contamination=0.1, random_state=42)
    model.fit(historical_values)           # train on past 60 minutes
    if model.predict([current_value]) == -1:  # -1 means "outlier"
        → raise MEDIUM anomaly: "Unusual pattern detected by ML model"
```

The model is trained fresh on every prediction using the last 60 minutes of history — no pre-training step needed. This means it automatically adapts to each asset's normal operating pattern.

### The SQS Consumer (Event-Driven Architecture)

```python
async def consume_telemetry_events():
    while True:
        # Long-polling: waits up to 5 seconds for messages before returning empty
        resp = sqs_client.receive_message(
            QueueUrl=SQS_QUEUE_URL,
            MaxNumberOfMessages=10,   # process up to 10 at once
            WaitTimeSeconds=5,        # long-poll to reduce API calls
        )
        for msg in resp.get("Messages", []):
            body = json.loads(msg["Body"])
            if body.get("EventType") == "TelemetryReceived":
                await detect_anomalies(...)
            # IMPORTANT: delete message after processing
            sqs_client.delete_message(QueueUrl=SQS_QUEUE_URL, ReceiptHandle=msg["ReceiptHandle"])
```

**Key concepts:**

- **Long polling** (`WaitTimeSeconds=5`): Instead of asking SQS "any messages?" constantly, the service waits up to 5 seconds for a message to arrive. This reduces unnecessary API calls and cost.
- **At-least-once delivery**: SQS guarantees a message is delivered at least once. The `delete_message` call tells SQS "I processed this, remove it." If the service crashes before deleting, SQS redelivers the message.
- **Event-driven**: The anomaly service doesn't know about the telemetry service. It only knows about messages. This decouples the services.

---

## 9. Service 4 — Alert Service (Python)

### What it does

- Listen to SQS queue `anomaly-events` for anomalies
- Create structured alerts with severity levels (CRITICAL / HIGH / MEDIUM / LOW)
- Simulate multi-channel notifications (Slack, PagerDuty, Email, SMS)
- Let operators acknowledge and resolve alerts via API

### Alert Lifecycle

```
NEW → ACKNOWLEDGED → RESOLVED
 ↓
IGNORED (skipped without action)
```

### Notification Logic

```python
def _notify(alert: Alert) -> List[str]:
    channels = []
    logger.info("[ALERT][%s] asset=%s metric=%s", severity, asset_id, metric_name)
    channels.append("WEBHOOK")            # always log

    if severity in (HIGH, CRITICAL):
        logger.warning("[SLACK] Would post to #ops")
        channels.append("SLACK")

    if severity == CRITICAL:
        logger.critical("[PAGERDUTY] Would page on-call")
        channels.append("PAGERDUTY")

    return channels   # stored on the alert record
```

In production this would call real APIs: Slack Webhooks, PagerDuty Events API, AWS SES for email, SNS for SMS. In this demo, the notification is logged and the channel list is recorded on the alert.

### Key Endpoints

```
POST /api/v1/alerts                      → manually create an alert
GET  /api/v1/alerts                      → list alerts (filter by asset/severity/status)
GET  /api/v1/alerts/{id}                 → get one alert
PUT  /api/v1/alerts/{id}/acknowledge     → operator acknowledges the alert
PUT  /api/v1/alerts/{id}/resolve         → operator marks it resolved
GET  /health
```

### How Acknowledge Works (DynamoDB UpdateItem)

```python
# Instead of loading the whole record, changing it, and saving it back,
# DynamoDB's update_item changes only the fields you specify, atomically.
resp = table.update_item(
    Key={"alert_id": alert_id},           # find the record
    UpdateExpression="SET #s = :s, acknowledged_at = :t",   # what to change
    ExpressionAttributeValues={
        ":s": "ACKNOWLEDGED",
        ":t": datetime.now(timezone.utc).isoformat()
    },
    ReturnValues="ALL_NEW",               # return the full updated record
)
```

---

## 10. Service 5 — Simulator (Python)

### What it does

The simulator pretends to be a fleet of IoT sensors. It runs forever, generating realistic sensor data for all 5 assets and posting it to the Telemetry Service every 5 seconds.

### Signal Generation — Making Data Look Real

Real sensors don't produce random noise — they follow physical patterns. The simulator uses math to model this:

```python
def _sin_wave(tick, period, amplitude, offset, noise=0.02):
    # sine wave = smoothly oscillating signal (like a day/night cycle)
    base = offset + amplitude * math.sin(2 * math.pi * tick / period)
    # gaussian noise = small random variation (like measurement error)
    return base + random.gauss(0, noise * amplitude)
```

**Wind turbine example:**
```python
wind_speed   = sine wave (period 288 ticks = 24 hours at 5s/tick, amplitude 6, offset 10)
               → smoothly oscillates between 4–16 m/s over the day
rotor_speed  = wind_speed × 0.7 + small noise
               → physically: rotor spins proportional to wind speed
power_output = rotor_speed × 4.5 + small noise
               → physically: power = rotational energy
temperature  = slower sine wave (period 576 = 2 days) + noise
vibration    = abs(gaussian noise around 0.5)
```

**Anomaly injection** (5% probability per reading):
```python
is_anomaly = random.random() < ANOMALY_RATE   # 0.05 = 5%
if is_anomaly:
    temperature = random.uniform(75, 95)   # simulate overheating
    vibration   = random.uniform(4.5, 8)   # simulate bearing failure
```

This is what triggers the detection pipeline — the anomaly service sees an out-of-range value and raises an alert.

---

## 11. Service 6 — Dashboard (nginx)

### What it is

A simple web server that serves static HTML/CSS/JavaScript files. There is no server-side rendering — all the logic runs in the browser.

Two pages:
- `index.html` — live monitoring dashboard (asset cards, telemetry charts, anomaly table, alert table)
- `control.html` — control panel (register assets, post manual telemetry, trigger simulated anomalies, manage maintenance, manage alerts)

### How the Dashboard Gets Data

The HTML files use the browser's built-in `fetch()` API to call the microservices directly:

```javascript
// Every 15 seconds, refresh all data
async function refreshAll() {
    const assets    = await fetch("http://localhost:5001/api/v1/assets");
    const telemetry = await fetch("http://localhost:5002/api/v1/telemetry");
    const anomalies = await fetch("http://localhost:5003/api/v1/anomalies");
    const alerts    = await fetch("http://localhost:5004/api/v1/alerts");
    // update DOM with the results
}
```

**No framework** (no React, Angular, Vue) — plain JavaScript. This keeps the dashboard light and zero-dependency. The services all have CORS enabled (`Allow-Origin: *`), so the browser can call them directly.

### nginx Configuration

```nginx
server {
    listen 80;
    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;   # serve files, fall back to index.html
        add_header Cache-Control "no-cache";  # always fetch fresh files
        add_header Access-Control-Allow-Origin *;
    }
}
```

---

## 12. Infrastructure Services (LocalStack, PostgreSQL, Redis)

### PostgreSQL

**What it is:** A full-featured open-source relational database.

**Used by:** Asset Service

**Tables:**
- `Assets` — one row per energy asset
- `MaintenanceSchedules` — maintenance records linked to assets via foreign key

**Why PostgreSQL for assets?**
- Assets have strict relational structure (FK from MaintenanceSchedule → Asset)
- We need ACID transactions (if the INSERT fails, don't leave partial data)
- EF Core has first-class PostgreSQL support via Npgsql

### Redis

**What it is:** An in-memory key-value store. Extremely fast (microsecond reads).

**Used by:** Asset Service (cache) and Alert Service (deduplication)

**Purpose in Asset Service:**
```csharp
// Before hitting PostgreSQL, check the cache
var cached = await _cache.GetAsync<AssetDto>($"asset:{id}");
if (cached != null) return cached;  // cache hit: no DB call needed

var asset = await _repo.GetByIdAsync(id);
await _cache.SetAsync($"asset:{id}", asset, TimeSpan.FromMinutes(5));  // cache for 5 min
return asset;
```

**Why cache?** The asset list doesn't change often, but the dashboard reads it every 15 seconds. Without caching, that's 4 PostgreSQL queries/minute per user. With Redis caching, it's a fast in-memory lookup.

### LocalStack

**What it is:** An open-source tool that runs real AWS services (DynamoDB, SQS, SNS, etc.) on your laptop inside Docker. No AWS account or internet needed.

**Port:** 4566 — all AWS services are accessed at `http://localhost:4566` (or `http://localstack:4566` from inside Docker).

**Services used:**

| AWS Service | Local Table/Queue/Topic Name | Purpose |
|---|---|---|
| DynamoDB | Telemetry | Store time-series sensor readings |
| DynamoDB | Anomalies | Store detected anomalies |
| DynamoDB | Alerts | Store alert records |
| SQS | telemetry-events | Telemetry → Anomaly Detection |
| SQS | anomaly-events | Anomaly Detection → Alert Service |
| SNS | telemetry-topic | Fan-out telemetry events |
| SNS | anomaly-topic | Fan-out anomaly events |
| SNS | alert-topic | Fan-out alert notifications |

**The init script** (`scripts/init-aws.sh`) runs once at startup to create all these resources using the AWS CLI. This is exactly what a Terraform or CloudFormation script does in production — declarative resource creation.

---

## 13. Key Design Patterns Explained

### CQRS (Command Query Responsibility Segregation)

**The idea:** Separate operations that *change data* (Commands) from operations that *read data* (Queries). They have different code paths and can even use different data stores.

**In the Asset Service:**
```
Commands (change state):              Queries (read state):
  RegisterAssetCommand                  GetAssetQuery
  UpdateAssetStatusCommand              ListAssetsQuery
  ScheduleMaintenanceCommand            GetAssetMaintenanceHistoryQuery
  DeleteAssetCommand                    GetAssetTelemetryQuery
```

Each command/query has a dedicated **Handler** class with a single `Handle()` method. This keeps each class small and focused — the Single Responsibility Principle.

**Why?** Reads are far more frequent than writes. With CQRS, you can optimize reads independently (add caching, read replicas) without touching write logic.

### MediatR (In-Process Mediator)

**The problem:** The controller needs to call business logic, but shouldn't directly reference handler classes (that creates tight coupling).

**The solution:** MediatR acts as a post office. You drop a "letter" (command/query object) into it, and it figures out who should handle it.

```csharp
// Controller sends a command — it has no idea what class handles it
var result = await _mediator.Send(new RegisterAssetCommand { Name = "Turbine 1", ... });

// MediatR finds RegisterAssetHandler because it implements IRequestHandler<RegisterAssetCommand>
// and calls Handle() on it
```

**Pipeline behaviors** are middleware that wrap every handler call:
```
incoming command
    → LoggingBehavior (log start, measure time)
    → ValidationBehavior (validate with FluentValidation)
    → PerformanceBehavior (warn if slow)
    → actual Handler.Handle()
    → PerformanceBehavior (log warning if > 500ms)
    → ValidationBehavior (nothing to do on way out)
    → LoggingBehavior (log completion)
outgoing result
```

### DDD (Domain-Driven Design)

**The idea:** Model your code to match how the business domain actually works. Use the same vocabulary that domain experts use.

**Key DDD concepts in this project:**

**Entity:** An object with a unique identity that persists over time. `Asset` is an entity — it has an `Id` (GUID) and its state changes (status updates, maintenance records).

**Value Object:** An object defined by its values, not its identity. `GeographicLocation(latitude, longitude)` is a value object — two locations with the same lat/lon are identical; they have no separate identity.

**Aggregate Root:** The "entry point" to a cluster of related objects. `Asset` is an aggregate root — you don't directly create `MaintenanceSchedule` objects; you call `asset.ScheduleMaintenance(...)`. The asset ensures its own consistency.

**Domain Event:** Something that happened in the domain that other parts of the system might care about. When an asset is registered, it raises `AssetRegisteredEvent`. The infrastructure layer then publishes this to SQS.

```csharp
// Asset entity raises events internally when state changes
public void UpdateStatus(AssetStatus newStatus)
{
    Status = newStatus;
    AddDomainEvent(new AssetStatusChangedEvent(Id, oldStatus, newStatus));
}
```

### Event-Driven Architecture

Instead of Service A directly calling Service B's API (tight coupling), Service A publishes an event to a message queue. Service B subscribes to that queue.

**Benefits:**
- Services don't need to know about each other
- If Service B is down, the message waits in the queue — no data lost
- You can add Service C later that also subscribes, without changing A or B

**SQS vs SNS:**
- **SQS (Simple Queue Service):** One subscriber pulls messages from the queue. Messages are deleted after processing. Point-to-point.
- **SNS (Simple Notification Service):** One publisher, many subscribers. SNS fans out one message to all subscribed SQS queues simultaneously. Pub/sub.

In this project:
- Telemetry Service → **SQS** `telemetry-events` → Anomaly Detection (one consumer)
- Anomaly Detection → **SNS** `anomaly-topic` → **SQS** `anomaly-events` → Alert Service
  (SNS allows adding more consumers — e.g., a future reporting service — without changing Anomaly Detection)

---

## 14. The .NET Layered Architecture (Asset Service Deep Dive)

### Directory Structure Explained

```
services/asset-service/src/
├── AssetService.API/              ← Layer 4 (outermost)
│   ├── Controllers/               ← HTTP endpoints (AssetController.cs)
│   ├── Middleware/                ← Request pipeline (logging, errors, correlation IDs)
│   ├── Filters/                   ← Pre/post action logic (validation, API key auth)
│   ├── Startup.cs                 ← Wires everything together; initializes DB
│   └── Program.cs                 ← Entry point: creates WebApplication and calls Startup
│
├── AssetService.Application/      ← Layer 3 (business logic)
│   ├── Commands/                  ← Write operations (change state)
│   ├── Queries/                   ← Read operations (return data)
│   ├── Behaviors/                 ← MediatR pipeline middleware
│   ├── DTOs/                      ← Data Transfer Objects (API response shapes)
│   ├── Interfaces/                ← Contracts (IAssetRepository, ICacheService, etc.)
│   └── Mappings/                  ← AutoMapper profiles (Entity → DTO)
│
├── AssetService.Domain/           ← Layer 2 (pure business rules, no dependencies)
│   ├── Entities/                  ← Asset.cs, MaintenanceSchedule.cs
│   ├── ValueObjects/              ← GeographicLocation.cs, Capacity.cs
│   ├── Events/                    ← AssetRegisteredEvent.cs, etc.
│   ├── Enums/                     ← AssetType.cs, AssetStatus.cs
│   └── Common/                    ← AggregateRoot.cs (base class)
│
└── AssetService.Infrastructure/   ← Layer 1 (implementations, DB, messaging)
    ├── Data/Context/              ← ApplicationDbContext.cs (EF Core DbContext)
    ├── Data/Configurations/       ← How EF Core maps C# classes to SQL tables
    ├── Repositories/              ← AssetRepository.cs (implements IAssetRepository)
    └── Services/                  ← SqsEventPublisher.cs, RedisCacheService.cs
```

### Dependency Injection — The Glue

ASP.NET Core has a built-in dependency injection (DI) container. Instead of classes creating their dependencies (`new SomeService()`), the container creates them and passes them in.

In `Startup.cs`:
```csharp
// "Register" services — tell the DI container what to create
services.AddScoped<IAssetRepository, AssetRepository>();
services.AddScoped<IEventPublisher, SqsEventPublisher>();
services.AddScoped<ICacheService, RedisCacheService>();
services.AddDbContext<ApplicationDbContext>(options =>
    options.UseNpgsql(connectionString));
```

In `AssetController.cs`:
```csharp
// Constructor injection — the DI container sees that AssetController needs
// IMediator and ILogger<>, and automatically provides them
public AssetController(IMediator mediator, ILogger<AssetController> logger)
{
    _mediator = mediator;
    _logger = logger;
}
```

**Why DI?** Makes testing easy — in unit tests you inject a fake `IAssetRepository` instead of the real one that needs a database. The controller code doesn't change.

### EF Core — Talking to PostgreSQL

Entity Framework Core is an ORM (Object-Relational Mapper). It lets you work with C# objects and it generates the SQL automatically.

```csharp
// ApplicationDbContext is the "session" with the database
public class ApplicationDbContext : DbContext
{
    public DbSet<Asset> Assets { get; set; }
    public DbSet<MaintenanceSchedule> MaintenanceSchedules { get; set; }
}

// Saving a new asset: EF Core generates "INSERT INTO "Assets" ..."
await db.Assets.AddAsync(asset);
await db.SaveChangesAsync();

// Querying: EF Core generates "SELECT ... FROM "Assets" WHERE "Status" = 'Active'"
var activeAssets = await db.Assets
    .Where(a => a.Status == AssetStatus.Active)
    .ToListAsync();
```

**Owned entities:** `GeographicLocation` and `Capacity` are value objects that EF Core stores as columns inside the `Assets` table (not as separate tables):
```
Assets table columns:
  Id, Name, Type, Status, Latitude, Longitude, Elevation,
  CapacityValue, CapacityUnit, InstallationDate, LastMaintenanceDate, Metadata
```

`Latitude`, `Longitude`, `Elevation` come from `GeographicLocation`. `CapacityValue`, `CapacityUnit` come from `Capacity`. This is configured in `AssetConfiguration.cs`.

### Middleware Pipeline

When an HTTP request comes in, it flows through middleware in order:

```
HTTP Request
    ↓
ExceptionHandlingMiddleware    ← wraps everything in try/catch, returns clean JSON errors
    ↓
CorrelationIdMiddleware        ← adds X-Correlation-ID header (for distributed tracing)
    ↓
RequestLoggingMiddleware       ← logs "GET /api/v1/assets → 200 OK in 12ms"
    ↓
CORS Middleware                ← adds Access-Control-Allow-Origin header
    ↓
ValidationFilter               ← runs FluentValidation on controller action parameters
    ↓
AssetController.ListAssets()   ← your actual code runs here
    ↓
HTTP Response (flows back up through the same middleware chain)
```

---

## 15. AWS Concepts Used (Locally Simulated)

### DynamoDB

DynamoDB is AWS's fully managed NoSQL database. No servers to manage, scales automatically.

**Key concepts:**
- **Table:** Like a SQL table but schemaless (each row can have different columns)
- **Partition key:** The primary lookup key. All rows with the same partition key go to the same storage node
- **Sort key:** Within a partition, rows are sorted by this key — enables range queries
- **GSI (Global Secondary Index):** Like a SQL index on non-primary-key columns

**In this project:**
```
Telemetry table:
  Partition key: asset_id      → "give me all readings for this asset"
  Sort key: timestamp          → "...between these two times"

Anomalies table:
  Partition key: anomaly_id    → unique composite key
  GSI on: asset_id             → query anomalies by asset

Alerts table:
  Partition key: alert_id      → unique alert ID
```

### SQS (Simple Queue Service)

A managed message queue. Producers put messages in; consumers pull them out.

**Key properties:**
- **Durability:** Messages are stored redundantly — survive failures
- **At-least-once delivery:** SQS may deliver a message more than once (handle duplicates!)
- **Visibility timeout:** When a consumer reads a message, it becomes invisible to others for N seconds. If the consumer crashes without deleting it, SQS re-delivers it.
- **Long polling:** Consumer waits up to 20s for a message rather than returning empty immediately

### SNS (Simple Notification Service)

A managed pub/sub service. One publisher, many subscribers.

**Subscription types:** SQS, Lambda, HTTP endpoint, Email, SMS

**Fan-out pattern used here:**
```
Anomaly Detection publishes to SNS "anomaly-topic"
    ↓
SNS delivers to:
    SQS "anomaly-events"  ← Alert Service subscribes
    (future) Lambda       ← Could trigger a real-time report
    (future) Email        ← Could email a manager directly
```

---

## 16. CI/CD Pipeline Explained

The `ci-cd/` directory contains automation that builds, tests, and deploys the project. In production on AWS, this replaces manual work.

### GitHub Actions (`.github/workflows/`)

Triggered automatically when you push code to GitHub.

**`ci.yml` — Continuous Integration (runs on every push/PR):**
```
1. Lint .NET code (dotnet format)
2. Lint Python code (flake8, black)
3. Run .NET unit tests (dotnet test)
4. Run Python tests (pytest)
5. Build Docker images for all 6 services (matrix job)
6. Security scan with Trivy (find known CVEs in dependencies)
```

**`cd.yml` — Continuous Deployment (runs only on push to main):**
```
1. Build all 6 Docker images
2. Push images to AWS ECR (Elastic Container Registry — like DockerHub but private)
3. Deploy to dev environment (ECS force-new-deployment)
4. Wait for human approval (GitHub Environment: staging)
5. Deploy to staging environment
6. Notify Slack webhook
```

**`security-scan.yml` — Weekly security scan:**
```
- Trivy: scan images for CVEs
- CodeQL: static analysis of C# and Python source code
- TruffleHog: scan git history for accidentally committed secrets
- safety + dotnet vulnerable: check package dependencies for known vulnerabilities
```

**`performance-test.yml` — Manual k6 load test:**
```
- You trigger it manually with: environment (dev/staging), duration (60s), virtual users (10)
- k6 runs against the target environment
- Fails if: p95 response time > 500ms OR error rate > 1%
```

### CodePipeline (AWS-native CI/CD)

CloudFormation templates in `ci-cd/codepipeline/` define AWS CodePipeline — the AWS-native CI/CD service that replaces GitHub Actions when deploying on AWS.

**`pipeline-prod.yml` stages:**
```
Source         → pull code from CodeCommit/GitHub
Build          → CodeBuild: docker build + push to ECR
Test           → CodeBuild: run tests
Security       → CodeBuild: Trivy + Bandit
ApprovalGate   → manual approval from a human
Deploy         → CodeDeploy: blue/green deployment to ECS Fargate
Monitoring     → wait 10 minutes, check CloudWatch alarms
(rollback Lambda runs automatically if alarms fire)
```

### Blue/Green Deployment (Zero-Downtime)

Old way (big bang): stop old version → start new version → downtime gap

Blue/Green:
```
Load Balancer ──► Blue (current live, 100% traffic)
                  Green (new version, 0% traffic — warming up)

After health checks pass:
Load Balancer ──► Green (new version, 100% traffic)
                  Blue (old version, kept for 30 min in case of rollback)
```

If the new version has problems, CodeDeploy flips traffic back to Blue in seconds.

---

## 17. How to Run the Project Locally

### Prerequisites

- Docker Desktop running
- At least 4 GB RAM allocated to Docker

### Steps

```bash
# From the repository root:
cd infrastructure/docker-compose

# Build all images and start all containers
# The first run takes 5-10 minutes to download base images and build
docker compose up --build

# You'll see output from all containers interleaved:
# rep_postgres: database system is ready
# rep_localstack: LocalStack started
# rep_localstack_init: Creating DynamoDB tables, SQS queues, SNS topics...
# rep_asset_service: Application started. Press Ctrl+C to shut down.
# rep_telemetry_service: Starting Telemetry Service
# rep_anomaly_service: Starting anomaly SQS consumer
# rep_alert_service: Starting Alert Service
# rep_simulator: Telemetry Simulator starting
# rep_simulator: North Wind Farm Alpha → {wind_speed: 10.40, ...}
```

### Verify Everything is Running

Open a browser and check:
- Dashboard: http://localhost:3000
- Control Panel: http://localhost:3000/control.html
- Asset Service Swagger UI: http://localhost:5001 (interactive API docs)
- Telemetry Service docs: http://localhost:5002/docs
- Anomaly Service docs: http://localhost:5003/docs
- Alert Service docs: http://localhost:5004/docs

### Trigger a Manual Anomaly

```bash
curl -X POST http://localhost:5002/api/v1/telemetry \
  -H "Content-Type: application/json" \
  -d '{
    "asset_id": "11111111-0000-0000-0000-000000000001",
    "type": "WindTurbine",
    "metrics": { "temperature": 95.0, "vibration": 7.5 },
    "source": "manual-test"
  }'
```

Then call the Anomaly Detection service directly:

```bash
curl -X POST http://localhost:5003/api/v1/detect \
  -H "Content-Type: application/json" \
  -d '{
    "telemetry_data": {
      "asset_id": "11111111-0000-0000-0000-000000000001",
      "timestamp": "2024-01-01T12:00:00Z",
      "type": "WindTurbine",
      "metrics": { "temperature": 95.0, "vibration": 7.5 }
    }
  }'
```

You should see anomalies returned, and within seconds an alert in http://localhost:5004/api/v1/alerts.

### Shut Down

```bash
docker compose down          # stop containers, keep volumes (data survives)
docker compose down -v       # stop containers AND delete volumes (fresh start)
```

---

## 18. Ports and Endpoints Quick Reference

| Container | External Port | Internal Port | URL |
|---|---|---|---|
| Dashboard (nginx) | 3000 | 80 | http://localhost:3000 |
| Asset Service (.NET) | 5001 | 8080 | http://localhost:5001 |
| Telemetry Service (Python) | 5002 | 8000 | http://localhost:5002 |
| Anomaly Detection (Python) | 5003 | 8000 | http://localhost:5003 |
| Alert Service (Python) | 5004 | 8000 | http://localhost:5004 |
| PostgreSQL | 5432 | 5432 | localhost:5432 (assetdb / repuser / reppass) |
| Redis | 6379 | 6379 | localhost:6379 |
| LocalStack (all AWS) | 4566 | 4566 | http://localhost:4566 |

### Key API Endpoints

**Asset Service (http://localhost:5001)**
```
GET    /api/v1/assets              → list all assets
POST   /api/v1/assets              → register new asset
GET    /api/v1/assets/{id}         → get asset details
PUT    /api/v1/assets/{id}/status  → update status
DELETE /api/v1/assets/{id}         → delete asset
GET    /health                     → health check
```

**Telemetry Service (http://localhost:5002)**
```
POST /api/v1/telemetry             → ingest one reading
POST /api/v1/telemetry/batch       → ingest batch
GET  /api/v1/telemetry             → list recent readings
GET  /api/v1/telemetry/{asset_id}  → readings for one asset
GET  /health
```

**Anomaly Detection (http://localhost:5003)**
```
POST /api/v1/detect                → detect anomalies in a reading
GET  /api/v1/anomalies             → list all anomalies
GET  /api/v1/anomalies/{asset_id}  → anomalies for one asset
GET  /health
```

**Alert Service (http://localhost:5004)**
```
POST /api/v1/alerts                      → create alert manually
GET  /api/v1/alerts                      → list alerts
GET  /api/v1/alerts/{id}                 → get one alert
PUT  /api/v1/alerts/{id}/acknowledge     → acknowledge
PUT  /api/v1/alerts/{id}/resolve         → resolve
GET  /health
```

---

*This document covers every running component, every data flow, and every major design decision in the platform. For the full source code, see the `services/` directory.*
