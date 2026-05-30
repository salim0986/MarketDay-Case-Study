# MarketDay API Reference

## Overview

The MarketDay platform operates on a split architecture: a Next.js frontend/API layer for state management and user interaction, and a Python FastAPI microservice for AI workloads. They communicate securely over HTTP and share a Supabase PostgreSQL database.

**Base URL (Client API)**: `https://app.marketday.com/api`
**Base URL (Internal Worker API)**: `http://worker:8000/internal`

**Authentication**:
- **Client-facing Endpoints**: Secured via Clerk JWTs. All queries implicitly include an `orgId` predicate derived from the session.
- **Internal Service Endpoints**: Secured via an `X-Internal-Secret` header matching the environment `INTERNAL_API_SECRET`.

---

## 1. Authentication & Organizations (Next.js API)

### GET /api/orgs/current
Retrieves the current authenticated organization details and its verified domain status.

**Response**:
```json
{
  "id": "org_2X9abc...",
  "name": "Acme SaaS",
  "slug": "acme",
  "customDomain": "hub.acme.com",
  "isDomainVerified": true
}
```

---

## 2. Brand & Knowledge Base (Next.js API)

### GET /api/brands
List all brand profiles for the organization.

### POST /api/brands
Create a new brand profile including voice, industry, and target audience parameters.

### POST /api/knowledge/upload
Upload a new knowledge base document. Returns a Supabase Storage reference and triggers a background extraction job to populate `contentCache`.

---

## 3. Autopilot Engine (Next.js API)

### GET /api/autopilot/settings
Get the current autopilot cadence and configuration.

### PATCH /api/autopilot/settings
Update autopilot configuration.

**Request**:
```json
{
  "isEnabled": true,
  "cadence": "3_per_week",
  "reviewMode": true,
  "publishTime": "09:00",
  "publishTimezone": "America/New_York",
  "targetDays": ["mon", "wed", "fri"]
}
```

---

## 4. Opportunity Discovery (Next.js API)

### POST /api/discovery/trigger
Triggers the multi-agent discovery pipeline for the organization. Dispatches a fire-and-forget job to the Python worker.

### GET /api/opportunities
Returns the prioritized opportunity queue.

**Query Parameters**:
- `status` (discovered | approved | generating | done | skipped)
- `page`, `pageSize`

---

## 5. Job Orchestration (Internal Python API)

*Note: These endpoints are only accessible from the Next.js API layer via the `X-Internal-Secret` header.*

### POST /internal/jobs/che-generate
Dispatches a Content Hub Engine (CHE) generation job. The Python worker begins the 5-stage LangGraph pipeline for cluster generation.

**Request**:
```json
{
  "jobId": "uuid",
  "orgId": "string",
  "opportunityId": "uuid",
  "brandProfileId": "uuid"
}
```

### POST /internal/jobs/blog-generate
Dispatches a single-article generation job (7-stage pipeline).

---

## 6. Job State & Event Streaming (Next.js API)

### GET /api/jobs/:jobId
Check the status of a specific job.

**Response**:
```json
{
  "id": "uuid",
  "status": "running",
  "progress": 45,
  "startedAt": "2024-03-01T12:00:00Z"
}
```

### GET /api/jobs/:jobId/events
Retrieve the append-only event log for a job. The frontend uses this to render the real-time progress stepper.

**Response**:
```json
{
  "events": [
    {
      "phase": "world_model_complete",
      "timestamp": "2024-03-01T12:01:00Z",
      "metadata": { "sourcesFound": 12 }
    },
    {
      "phase": "narrative_complete",
      "timestamp": "2024-03-01T12:01:45Z",
      "metadata": { "sectionsPlanned": 8 }
    }
  ]
}
```

---

## 7. Content Hub & Publishing (Next.js API)

### GET /api/clusters
List generated clusters and their component pages.

### GET /api/publish-queue
List items scheduled for publishing.

**Query Parameters**:
- `status` (pending_review | scheduled | publishing | completed | failed)

### POST /api/publish-queue/:id/approve
Approve an item in `pending_review` status and transition it to `scheduled`.

### POST /api/publish/cron
Triggered every 10 minutes by Vercel Cron. Scans the `publishQueue` for items where `scheduledPublishAt <= NOW()` and pushes them to the configured CMS adapters (WordPress, Shopify, Ghost, etc.).
