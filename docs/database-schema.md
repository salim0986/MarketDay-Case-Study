# Database Schema Diagram

## Core Entity Relationships

```mermaid
erDiagram
    ORGANIZATIONS ||--o{ PROFILES : contains
    ORGANIZATIONS ||--o{ ORGANIZATION_MEMBERS : defines
    ORGANIZATIONS ||--o{ BRAND_PROFILES : owns
    ORGANIZATIONS ||--|| TENANT_CONFIGS : configures
    ORGANIZATIONS ||--o{ KNOWLEDGE_DOCUMENTS : owns
    ORGANIZATIONS ||--o{ GROWTH_SNAPSHOTS : tracks
    
    PROFILES ||--o{ ORGANIZATION_MEMBERS : "belongs to"
    
    ORGANIZATIONS {
        uuid id PK
        varchar name
        varchar slug UK
        varchar custom_domain UK
        timestamp created_at
    }
    
    PROFILES {
        uuid id PK
        varchar display_name
        text avatar_url
        uuid active_org_id FK
    }
    
    ORGANIZATION_MEMBERS {
        uuid id PK
        uuid org_id FK
        uuid profile_id FK
        enum role "admin | member"
    }
    
    TENANT_CONFIGS {
        uuid id PK
        uuid org_id FK
        text encrypted_integrations "AES-256-GCM"
    }
    
    BRAND_PROFILES {
        uuid id PK
        uuid org_id FK
        varchar name
        varchar industry
        varchar voice
        jsonb theme
        boolean is_default
    }
    
    KNOWLEDGE_DOCUMENTS {
        uuid id PK
        uuid org_id FK
        varchar filename
        text storage_path
        text content_cache
    }
```

## Generation & Job Schema

```mermaid
erDiagram
    ORGANIZATIONS ||--o{ JOBS : dispatches
    BRAND_PROFILES ||--o{ JOBS : contextualizes
    JOBS ||--o{ JOB_EVENTS : emits
    ORGANIZATIONS ||--o{ GENERATED_BLOGS : owns
    BRAND_PROFILES ||--o{ GENERATED_BLOGS : contextualizes
    
    JOBS {
        uuid id PK
        uuid org_id FK
        uuid brand_profile_id FK
        enum type
        enum status
        jsonb request
        jsonb result
    }
    
    JOB_EVENTS {
        uuid id PK
        uuid job_id FK
        varchar phase
        jsonb metadata
        timestamp created_at
    }
    
    GENERATED_BLOGS {
        uuid id PK
        uuid org_id FK
        uuid brand_profile_id FK
        jsonb content_blocks
        jsonb seo_metadata
        jsonb published_platforms
    }
```

## Content Hub Engine (CHE) Schema

```mermaid
erDiagram
    ORGANIZATIONS ||--o{ CLUSTERS : owns
    BRAND_PROFILES ||--o{ CLUSTERS : contextualizes
    CLUSTERS ||--o{ CLUSTER_PAGES : contains
    
    CLUSTERS {
        uuid id PK
        uuid org_id FK
        uuid brand_profile_id FK
        varchar seed_keyword
        jsonb cluster_map
        jsonb publish_schedule
    }
    
    CLUSTER_PAGES {
        uuid id PK
        uuid cluster_id FK
        enum page_type "pillar | cluster"
        varchar target_keyword
        jsonb content_blocks
        jsonb seo_metadata
        int quality_score
        enum status "pending | generating | ready | scheduled | published"
    }
```

## Autopilot & Publishing Schema

```mermaid
erDiagram
    ORGANIZATIONS ||--o{ OPPORTUNITY_QUEUE : discovers
    ORGANIZATIONS ||--|| AUTOPILOT_SETTINGS : configures
    ORGANIZATIONS ||--o{ PUBLISH_QUEUE : schedules
    CLUSTER_PAGES |o--o| PUBLISH_QUEUE : "published via"
    GENERATED_BLOGS |o--o| PUBLISH_QUEUE : "published via"
    
    OPPORTUNITY_QUEUE {
        uuid id PK
        uuid org_id FK
        varchar topic
        jsonb discovery_meta
        numeric roi_score
        enum status "discovered | approved | generating | done | skipped"
    }
    
    AUTOPILOT_SETTINGS {
        uuid id PK
        uuid org_id FK
        enum cadence
        boolean review_mode
        time publish_time
        varchar publish_timezone
    }
    
    PUBLISH_QUEUE {
        uuid id PK
        uuid org_id FK
        uuid cluster_page_id FK
        uuid generated_blog_id FK
        timestamp scheduled_publish_at
        varchar target_platform
        enum status "pending_review | scheduled | publishing | completed"
    }
    
    GROWTH_SNAPSHOTS {
        uuid id PK
        uuid org_id FK
        date snapshot_date
        int articles_published
        int clusters_live
        numeric avg_serp_rank
    }
```

## Core Entity Details

### Organization Entity (Root)
```
organizations
├─ id (PK, UUID, DEFAULT uuid_generate_v4())
├─ name (VARCHAR NOT NULL)
├─ slug (VARCHAR UNIQUE NOT NULL)
├─ custom_domain (VARCHAR UNIQUE)
├─ created_at (TIMESTAMP WITH TIME ZONE)
└─ updated_at (TIMESTAMP WITH TIME ZONE)
```

### Brand Profiles (Configuration)
```
brand_profiles
├─ id (PK, UUID)
├─ org_id (FK → organizations ON DELETE CASCADE)
├─ name (VARCHAR NOT NULL)
├─ industry (VARCHAR)
├─ voice (VARCHAR)
├─ theme (JSONB DEFAULT '{}')
├─ is_default (BOOLEAN DEFAULT false)
└─ created_at (TIMESTAMP)
```

### Clusters (Content Hub Engine)
```
clusters
├─ id (PK, UUID)
├─ org_id (FK → organizations)
├─ brand_profile_id (FK → brand_profiles ON DELETE SET NULL)
├─ seed_keyword (VARCHAR)
├─ cluster_map (JSONB)
└─ publish_schedule (JSONB)

cluster_pages
├─ id (PK, UUID)
├─ cluster_id (FK → clusters ON DELETE CASCADE)
├─ page_type (ENUM: pillar, cluster)
├─ target_keyword (VARCHAR)
├─ content_blocks (JSONB) - typed array of components
├─ seo_metadata (JSONB)
├─ quality_score (INTEGER)
└─ status (ENUM)
```

### Autopilot & Queues
```
opportunity_queue
├─ id (PK, UUID)
├─ org_id (FK → organizations)
├─ topic (VARCHAR)
├─ discovery_meta (JSONB)
├─ roi_score (NUMERIC(5,2))
└─ status (ENUM: discovered, approved, generating, done, skipped)

publish_queue
├─ id (PK, UUID)
├─ org_id (FK → organizations)
├─ cluster_page_id (FK → cluster_pages, nullable)
├─ generated_blog_id (FK → generated_blogs, nullable)
├─ scheduled_publish_at (TIMESTAMP)
├─ target_platform (VARCHAR)
└─ status (ENUM: pending_review, scheduled, publishing, completed, failed)
```

## Relationship Types

- **One-to-Many**: Organization → Brand Profiles, Organization → Clusters, Cluster → Cluster Pages
- **One-to-One**: Organization → Tenant Configs, Organization → Autopilot Settings
- **Polymorphic / Optional FKs**: Publish Queue maps to *either* a `cluster_page_id` *or* a `generated_blog_id`.

## Key Indexes

- `organizations.slug` and `organizations.custom_domain` (UNIQUE, critical for middleware routing)
- `publish_queue.status` + `publish_queue.scheduled_publish_at` (Compound index for the Cron worker polling)
- `opportunity_queue.org_id` + `opportunity_queue.status` + `opportunity_queue.roi_score DESC` (For Autopilot queue pop)
- `jobs.org_id` and `job_events.job_id` (For fast UI event streaming)

## Design Notes

1. **JSONB Content Blocks**: Rather than raw HTML, articles are stored as JSON arrays (`{ type: "heading", text: "..."}`). This structure is extremely robust for updating specific sections without regex, and writing cross-platform adapters (e.g., transforming JSON into WordPress Gutenberg blocks vs Shopify HTML).
2. **Encrypted Integrations**: `tenant_configs.encrypted_integrations` is stored as an AES-256-GCM cipher string. The DB never stores raw CMS API keys or OAuth tokens.
3. **Multi-Tenancy Enforcement**: With the exception of `organizations`, every table includes `org_id` to ensure isolated RLS/service-layer querying.
4. **Append-Only Job Events**: Progress streaming relies on inserting into `job_events` rather than mutating a `jobs.progress` field, providing full history for diagnostics and smooth UX steppers.
