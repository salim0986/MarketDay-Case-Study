-- MarketDay Database Schema (PostgreSQL via Supabase)
-- WARNING: This schema is for context only and is not meant to be run directly.
-- Tables, Types, and Constraints are designed for Next.js (Drizzle ORM) + FastAPI (asyncpg)

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ==============================================
-- Custom ENUM Types
-- ==============================================
CREATE TYPE member_role_enum AS ENUM ('admin', 'member');
CREATE TYPE job_type_enum AS ENUM ('discovery', 'che_generation', 'blog_generation');
CREATE TYPE job_status_enum AS ENUM ('pending', 'running', 'completed', 'failed');
CREATE TYPE cluster_page_type_enum AS ENUM ('pillar', 'cluster');
CREATE TYPE page_status_enum AS ENUM ('pending', 'generating', 'draft', 'linked', 'ready', 'scheduled', 'published');
CREATE TYPE opportunity_status_enum AS ENUM ('discovered', 'approved', 'generating', 'done', 'skipped');
CREATE TYPE publish_status_enum AS ENUM ('pending_review', 'scheduled', 'publishing', 'completed', 'failed');
CREATE TYPE cadence_enum AS ENUM ('1_per_day', '3_per_week', '5_per_week');

-- ==============================================
-- 1. Authentication & Organization
-- ==============================================

CREATE TABLE public.organizations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(255) UNIQUE NOT NULL,
    custom_domain VARCHAR(255) UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE
);

CREATE TABLE public.profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    display_name VARCHAR(255) NOT NULL,
    avatar_url TEXT,
    active_org_id UUID REFERENCES public.organizations(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE public.organization_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    role member_role_enum NOT NULL DEFAULT 'member',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(org_id, profile_id)
);

-- ==============================================
-- 2. Brand & Configuration
-- ==============================================

CREATE TABLE public.tenant_configs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    org_id UUID UNIQUE NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    encrypted_integrations TEXT, -- AES-256-GCM cipher string
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE public.brand_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    industry VARCHAR(255),
    voice VARCHAR(255),
    theme JSONB NOT NULL DEFAULT '{}'::jsonb,
    is_default BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE public.knowledge_documents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    filename VARCHAR(255) NOT NULL,
    storage_path TEXT NOT NULL,
    content_cache TEXT, -- Pre-extracted text to save LLM/OCR tokens
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ==============================================
-- 3. Job & Generation
-- ==============================================

CREATE TABLE public.jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    brand_profile_id UUID REFERENCES public.brand_profiles(id) ON DELETE SET NULL,
    type job_type_enum NOT NULL,
    status job_status_enum NOT NULL DEFAULT 'pending',
    request JSONB NOT NULL DEFAULT '{}'::jsonb,
    result JSONB,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE public.job_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id UUID NOT NULL REFERENCES public.jobs(id) ON DELETE CASCADE,
    phase VARCHAR(100) NOT NULL,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE public.generated_blogs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    brand_profile_id UUID REFERENCES public.brand_profiles(id) ON DELETE SET NULL,
    content_blocks JSONB NOT NULL DEFAULT '[]'::jsonb,
    seo_metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    published_platforms JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ==============================================
-- 4. Content Hub Engine (CHE)
-- ==============================================

CREATE TABLE public.clusters (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    brand_profile_id UUID REFERENCES public.brand_profiles(id) ON DELETE SET NULL,
    seed_keyword VARCHAR(255) NOT NULL,
    cluster_map JSONB NOT NULL DEFAULT '{}'::jsonb,
    publish_schedule JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE public.cluster_pages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cluster_id UUID NOT NULL REFERENCES public.clusters(id) ON DELETE CASCADE,
    page_type cluster_page_type_enum NOT NULL,
    target_keyword VARCHAR(255) NOT NULL,
    content_blocks JSONB NOT NULL DEFAULT '[]'::jsonb,
    seo_metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    quality_score INTEGER NOT NULL DEFAULT 0,
    status page_status_enum NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ==============================================
-- 5. Autopilot & Scheduling
-- ==============================================

CREATE TABLE public.opportunity_queue (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    topic VARCHAR(500) NOT NULL,
    discovery_meta JSONB NOT NULL DEFAULT '{}'::jsonb,
    roi_score NUMERIC(5,2) NOT NULL DEFAULT 0.00,
    status opportunity_status_enum NOT NULL DEFAULT 'discovered',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE public.autopilot_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    org_id UUID UNIQUE NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    cadence cadence_enum NOT NULL DEFAULT '3_per_week',
    review_mode BOOLEAN NOT NULL DEFAULT true,
    publish_time TIME NOT NULL DEFAULT '09:00:00',
    publish_timezone VARCHAR(100) NOT NULL DEFAULT 'UTC',
    onboarding_completed_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE public.publish_queue (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    cluster_page_id UUID REFERENCES public.cluster_pages(id) ON DELETE CASCADE,
    generated_blog_id UUID REFERENCES public.generated_blogs(id) ON DELETE CASCADE,
    scheduled_publish_at TIMESTAMP WITH TIME ZONE NOT NULL,
    target_platform VARCHAR(100) NOT NULL,
    status publish_status_enum NOT NULL DEFAULT 'pending_review',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_exclusive_publish_target CHECK (
        (cluster_page_id IS NOT NULL AND generated_blog_id IS NULL) OR 
        (cluster_page_id IS NULL AND generated_blog_id IS NOT NULL)
    )
);

CREATE TABLE public.growth_snapshots (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    snapshot_date DATE NOT NULL DEFAULT CURRENT_DATE,
    articles_published INTEGER NOT NULL DEFAULT 0,
    clusters_live INTEGER NOT NULL DEFAULT 0,
    avg_serp_rank NUMERIC(6,2),
    pages_in_top_3 INTEGER NOT NULL DEFAULT 0,
    pages_in_top_10 INTEGER NOT NULL DEFAULT 0,
    new_opportunities_found INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ==============================================
-- 6. Supporting Tables
-- ==============================================

CREATE TABLE public.content_suggestions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    idea_text TEXT NOT NULL,
    is_used BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE public.notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    read_by JSONB NOT NULL DEFAULT '[]'::jsonb, -- Array of profile UUIDs
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ==============================================
-- Performance & Multi-Tenancy Indexes
-- ==============================================

-- Multi-tenant isolation indices
CREATE INDEX idx_jobs_org_id ON public.jobs(org_id);
CREATE INDEX idx_generated_blogs_org_id ON public.generated_blogs(org_id);
CREATE INDEX idx_clusters_org_id ON public.clusters(org_id);
CREATE INDEX idx_growth_snapshots_org_id ON public.growth_snapshots(org_id);

-- Job processing & progress tracking
CREATE INDEX idx_job_events_job_id ON public.job_events(job_id);

-- Autopilot Queues & Scheduling
CREATE INDEX idx_publish_queue_status_time ON public.publish_queue(status, scheduled_publish_at);
CREATE INDEX idx_opportunity_queue_status_score ON public.opportunity_queue(org_id, status, roi_score DESC);

-- Fast join resolution
CREATE INDEX idx_cluster_pages_cluster_id ON public.cluster_pages(cluster_id);
