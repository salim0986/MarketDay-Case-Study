# MarketDay — AI-Powered SEO Content Platform

A full-stack, multi-tenant SaaS platform that autonomously discovers content opportunities, generates SEO-optimized articles through a multi-agent AI pipeline, and publishes them across every major CMS — without human intervention.

[![Watch the video](https://github.com/salim0986/MarketDay-Case-Study/blob/caaa5839a8527f84fd07519b8c3bb12c165f9e3d/assets/marketday-thumbnail.png)](https://github.com/salim0986/MarketDay-Case-Study/blob/d01de4b10b70d790840dda2d977e67febecd316d/assets/marketday-demo.mp4)



## Project Overview

MarketDay is an autonomous growth engine I built for businesses that want to scale their organic search presence without scaling their content team. The platform handles the entire content lifecycle: discovering high-ROI content opportunities from competitor gaps and audience pain points, generating pillar-and-cluster topic structures, writing and internally linking every article through a multi-stage LangGraph agent pipeline, and drip-publishing the output to WordPress, Shopify, Ghost, Framer, Webflow, or Wix on a configurable weekly cadence.

The platform is multi-tenant by design. Each organization gets its own isolated data, brand profiles, custom content hub domain, and autopilot configuration. A public-facing content hub serves each org's published articles at either a custom domain or a MarketDay-hosted subdomain, with per-org sitemaps, robots.txt, and an llms.txt file for AI model discoverability.

The application follows a service-oriented structure with a Next.js frontend + API layer and a separate Python FastAPI microservice handling all AI workloads. The two services communicate over HTTP with a shared secret, while both read and write to the same Supabase PostgreSQL database.

## Problem Statement

Content marketing at scale presents compounding challenges for growing businesses:

- **Content discovery is guesswork** — teams publish what they think will rank rather than what the data shows has low competition and high traffic value
- **Production bottlenecks** — quality SEO content takes hours per article; most teams can publish a handful per month
- **Isolated articles perform poorly** — standalone posts lack the topical authority that search engines reward; pillar-and-cluster architecture is known to outperform but is difficult to execute at scale
- **Multi-platform publishing is repetitive** — manually reformatting the same article for WordPress, Shopify, and Ghost is pure overhead
- **Content goes stale** — published articles degrade in ranking as SERP landscapes shift; most teams lack the bandwidth to refresh
- **No feedback loop** — without Google Search Console data integrated into the workflow, teams can't see which keywords they almost rank for and push over the threshold

MarketDay addresses every one of these challenges through an autonomous pipeline that runs continuously in the background, requiring the user to only review and approve content before it goes live.

## Core Features

### 1. Multi-Tenant Organization Management

Every resource in the system is scoped to a Clerk organization. A single MarketDay deployment serves unlimited organizations with complete data isolation enforced at the service layer — every database query carries an explicit `orgId` predicate.

Each organization maintains its own:

- Brand profiles (multiple brands per org, each with voice, color, logo, audience)
- Knowledge base documents (PDFs, DOCX, TXT, Markdown) injected into AI context
- Custom content hub domain or MarketDay-hosted subdomain
- Autopilot configuration (cadence, review mode, publish schedule)
- Encrypted CMS credentials for each connected platform
- Opportunity queue, content clusters, and publish calendar

### 2. AI-Powered Opportunity Discovery

The discovery pipeline runs at onboarding and then monthly, building a prioritized queue of content opportunities specific to the organization's niche and competitors.

**Context-First Approach — five sequential agents:**

**Business Context Builder** — Synthesizes the brand profile, knowledge base documents, and website information into a structured "Business DNA" representation: product positioning, differentiators, target personas, and the problems the business solves.

**Competitor Finder Agent** — Uses Serper API to identify real product competitors, not just topically adjacent sites. Queries are derived from the Business DNA so the agent finds companies competing for the same customers rather than the same keywords.

**Keyword Universe Builder** — Generates audience pain-point seed keywords from the Business DNA and competitor landscape. Seeds are expanded through Serper's related-keyword data. Falls back to Gemini-driven expansion when Serper data is sparse.

**Cluster Formation Agent** — Groups the raw keyword universe into thematic content clusters, each anchored by a pillar keyword and surrounded by related long-tail cluster keywords. Deduplicates across clusters to avoid topical overlap.

**ROI Scorer Agent** — Scores each discovered cluster using a blended metric: 60% estimated monthly traffic value (from Serper SERP data) and 40% product-fit score (how well the topic connects to the organization's offering). Clusters are ranked and stored in the opportunity queue.

### 3. Content Hub Engine (CHE) — Pillar + Cluster Generation

The Content Hub Engine generates a full topic cluster in a single pipeline run: one pillar page and up to twelve cluster pages, all internally linked, SEO-optimized, and staggered for publication.

**Five-stage LangGraph pipeline:**

**Cluster Architect Node** — Maps the full cluster from a single seed keyword. Defines the pillar page angle, identifies supporting cluster page topics, assigns target keywords and search intent (informational / commercial / navigational) to each page, and plans the internal linking structure.

**CHE Research Node** — Runs parallel SERP and competitor research for every page in the cluster. Each page receives a `research_bundle` containing top-ranking URLs, competitor angles, keyword difficulty, and related questions. This grounds the generated content in actual search reality rather than model priors.

**CHE Writer Node** — Generates full article drafts for every page using the research bundles. Each article goes through the same recursive section loop used in single-blog generation: a ComponentWriter drafts each section, three critic agents score it on clarity, coherence, and SEO, and a RevisionCritic decides whether to accept or request a rewrite.

**Link Weaver Node** — Injects internal links between all pages in the cluster. The agent reads every draft simultaneously, identifies natural anchor opportunities, and rewrites the relevant content blocks to include contextual cross-references. This is what creates the topical authority signal that isolated articles lack.

**Schema Quality Gate** — Validates JSON-LD schema for each page, checks keyword relevance scores against targets, runs readability analysis, and marks the cluster ready or failed. Quality notes and a 0-100 quality score are persisted alongside each article.

**Staggered publishing** mirrors human-like content cadence to avoid search engine content-farm penalties: the pillar page and two cluster pages publish immediately, three more publish after seven days, and the remainder after fourteen days.

### 4. Single-Article Blog Generation

For on-demand article generation, a separate seven-stage LangGraph pipeline handles individual blog posts with a heavier focus on narrative structure and image generation.

**Seven-stage pipeline:**

**World Model Node** — Researches the topic through Serper, extracts structured facts, statistics, and competitor angles, and retrieves relevant content from the organization's knowledge base. Outputs a grounded `world_model` TypedDict that all downstream nodes consume.

**Narrative Architecture Node** — Generates the emotional blueprint for the article: a central metaphor, emotional arc, hook strategy, tone profile calibrated to the brand voice, and section-by-section briefs. This is what separates content that reads like AI from content that reads like a human wrote it with a point of view.

**Section Loop Node** — Generates and quality-gates each section independently through a recursive inner loop: draft → three-critic score → RevisionCritic decision → accept or revise up to N times. The loop continues until every section passes or the maximum iteration count is reached.

**Coherence Node** — Reads all sections simultaneously and checks global article coherence: intro-conclusion alignment, section flow, CTA placement, and narrative consistency with the spine. Applies surgical rewrites to sections that break the overall arc.

**Images Node** — Generates images for each major section using Gemini's image generation API, applies brand logo overlays, and matches color tone to the brand's primary color palette.

**SEO & Publish Node** — Generates the meta title, meta description, focus keywords, and FAQ section. Validates keyword density and readability score. Formats the final content blocks array.

**DB Publish Node** — Persists the completed article to `generated_blogs` with all content blocks, SEO metadata, images, and FAQs. Updates job status and emits a completion notification.

### 5. Autopilot Growth Engine

The Autopilot engine is the fully autonomous operating mode. Once enabled, it runs continuously without user intervention.

**How it operates:**

An hourly cron job polls the opportunity queue for the highest-ROI approved opportunity. It checks the current content backlog (items already scheduled but not yet published) and skips generation if the backlog exceeds the configured cadence limit — typically two weeks of content. This prevents the engine from flooding the publish calendar.

When the backlog has room, the cron dispatches a CHE generation job for the top opportunity to the Python worker. The opportunity row moves to `generating` status. A recovery routine resets any opportunities that have been stuck in `generating` for more than two hours back to `approved`, protecting the queue from worker crashes.

A separate cron runs every ten minutes to check the publish queue for items whose `scheduledPublishAt` timestamp has passed and pushes them live to the configured CMS or to the MarketDay content hub.

**Configuration options:**

- Enabled / paused toggle
- Publishing cadence: 1 per day, 3 per week, 5 per week, or custom articles-per-week
- Review mode: require manual approval before scheduling (default on)
- Publish time and timezone (content publishes at the configured local time)
- Publish days (specific weekdays only)
- Weekly growth report emails

### 6. Public Content Hub

Each organization's published cluster pages are served through a public-facing content hub, fully indexed by search engines.

**Two routing modes:**

- **Custom domain**: `https://hub.yourbrand.com/article-slug` — traffic routes through the organization's own domain
- **MarketDay subdomain**: `https://yourbrand.marketday.com/article-slug` — works immediately with no DNS configuration

The hub is implemented as a Next.js route at `/hub/[domainOrSlug]/` with middleware-based domain interception. When an incoming request's `Host` header matches a custom domain stored in the database, the middleware rewrites the request path internally — no redirect, no separate server. The public URL stays on the custom domain while Next.js serves the hub route.

**Hub features:**

- Brand theming (logo, primary color, preferred layout: minimal / corporate / startup)
- Per-org dynamic sitemap.xml for search engine crawling
- Per-org robots.txt
- llms.txt route exposing article metadata for AI model discovery
- Incremental Static Regeneration with a 5-minute revalidation window — hub pages feel static-fast but update within minutes of a new publish

### 7. CMS Multi-Platform Publishing

Articles generated by MarketDay can be pushed to any supported platform through a per-platform adapter that handles the formatting differences and API authentication requirements.

**Supported platforms:**

**WordPress** — Publishes via the WordPress REST API. Content blocks are converted to Gutenberg block syntax before submission. Yoast SEO metadata (meta title, meta description, focus keyword) is written to the post's SEO fields. Supports draft, publish, and pending-review status.

**Shopify** — Publishes to a Shopify blog via the Admin GraphQL API. Supports blog selection, tag assignment, and collection linking.

**Ghost** — Publishes via the Ghost Admin API. Supports member visibility tiers and scheduled publishing.

**Framer** — Creates CMS records via the Framer native API. Assets uploaded to Framer's storage.

**Wix** — Publishes blog posts via the Wix REST API with category assignment support.

**Webflow** — Creates CMS collection items via the Webflow API.

**Medium** — Publishes stories via the Medium integration API with license and distribution configuration.

All CMS credentials are stored AES-256-GCM encrypted in a single JSON column in the database. The encryption key lives in the environment and never touches the database. Credentials passed in the request body take precedence over stored credentials, enabling per-request overrides.

### 8. Google Search Console Integration

Connecting a Google Search Console property surfaces a GSC opportunity widget on the dashboard: keywords where the org's pages are ranking in positions 4–20 (impressions but low clicks) — the "almost ranking" zone where targeted content updates have the highest chance of pushing a page to the top three.

OAuth flow runs as a popup window to avoid disrupting the current application state. On completion, the popup posts a message to the parent window, which refreshes the tenant configuration and shows the connected state without a full page reload.

Tokens (access + refresh) are stored encrypted in the `tenantConfigs.integrations` column alongside CMS credentials.

### 9. Knowledge Base

Organizations can upload internal documents (PDF, DOCX, TXT, Markdown) that are injected into the AI context during content generation. This grounds the output in company-specific facts: proprietary research, case studies, product documentation, and brand guidelines.

Files are stored in Supabase Storage. Content is extracted on upload and cached in the `knowledgeDocuments` table — the World Model node retrieves the cached extraction rather than re-processing the file on every generation run.

### 10. Evergreen Content Refresh

The refresh pipeline re-evaluates published cluster pages against current SERP data. A SERP delta checker identifies pages whose ranking keywords have shifted, then a Surgical Editor node rewrites only the stale sections rather than regenerating the whole article. Structure and internal links are preserved; outdated information is replaced.

### 11. Analytics & Growth Tracking

Weekly snapshots capture KPI trends across the organization's content operation: total articles published, clusters live, average SERP rank, pages in top 3, pages in top 10, new opportunities found, and competitor gaps identified. These snapshots power growth trajectory charts on the dashboard.

The Autopilot page surfaces four live KPI cards — Pages Live, Scheduled, Pending Review, and Opportunities — all backed by TanStack Query with optimistic updates so approving a review card instantly reflects across all counters without a page reload.

### 12. Onboarding Flow

A multi-step onboarding collects everything the Autopilot engine needs to operate:

1. **Brand Basics** — Brand name, website, industry, target audience, product description. Creates the first brand profile.
2. **Domain Setup** — Optional custom domain with CNAME verification against Vercel's DNS.
3. **Connect Data** — Google Search Console OAuth connection.
4. **Opportunity Discovery** — Launches the discovery pipeline. A progress screen streams real-time updates through job events while the five-stage discovery agents run.
5. **Autopilot Setup** — Publishing cadence, review mode, publish time and timezone, target days.

## Technical Architecture

### System Design

The platform splits into two independently deployed services communicating over HTTP:

**Frontend + API Layer (Next.js)**: Handles authentication via Clerk, serves the application UI, exposes REST API routes for the frontend, persists job records to PostgreSQL via Drizzle ORM, dispatches generation jobs fire-and-forget to the Python backend, and serves the public content hub. All long-polling and state management happens in this layer.

**AI Microservice (Python FastAPI + LangGraph)**: Receives generation jobs from the Next.js layer (authenticated via a shared `X-Internal-Secret` header), runs LangGraph agent pipelines, writes results directly to the shared Supabase database, and updates job status. Also runs as a Redis-backed queue worker for decoupled async processing.

**Database (Supabase PostgreSQL)**: Single shared database written to by both services. JSON fields store flexible schemas (content blocks, SEO metadata, opportunity discovery data) as serialized text. Sensitive data (CMS credentials, OAuth tokens) is stored AES-256-GCM encrypted.

**Job Communication Pattern**: The Next.js layer creates a job row and returns immediately. The Python worker processes the job and writes results back. The frontend polls job status from the database, rendering real-time phase updates from the `job_events` table. No WebSockets or long-running HTTP connections are required.

### Technology Stack

**Frontend & API Layer:**
- Next.js 16 with App Router and React Server Components
- React 19 with concurrent features
- TypeScript 5 across the entire frontend
- Tailwind CSS 4 for utility-first styling
- shadcn/ui components built on Radix UI primitives
- TanStack Query 5 for server state management, caching, and optimistic updates
- TanStack Table 8 for interactive data tables
- Drizzle ORM for type-safe PostgreSQL access
- Clerk for multi-tenant authentication and organization management
- Supabase JS client for storage and additional DB access
- Zod 4 for runtime schema validation
- Tiptap 3 (ProseMirror-based rich text editor) for content editing
- Recharts for analytics visualization
- Sonner for toast notifications
- Date-fns for date handling
- Lucide React for iconography
- Vitest + React Testing Library for unit and integration tests

**Python AI Microservice:**
- FastAPI with Uvicorn for the HTTP API layer
- LangGraph 0.4+ for multi-agent workflow orchestration
- LangChain Core for agent primitives and tool abstractions
- Google Generative AI SDK (Gemini 2.0) for all language model calls
- Redis for the async job queue
- Supabase Python client for database operations
- AsyncPG for high-performance async PostgreSQL access
- Serper API for real-time search result data
- BeautifulSoup4 + Trafilatura for web content extraction
- Pillow for image processing and brand logo overlays
- PyPDF2 + python-docx for knowledge base document extraction
- Cryptography library (AES-256-GCM) for credential encryption
- Pydantic 2 for request/response validation

**Infrastructure:**
- Supabase (PostgreSQL + Storage + Auth)
- Vercel for Next.js deployment and custom domain DNS management
- Docker Compose for the Python service (API + worker + Redis)
- Environment-based configuration with explicit variable forwarding in Compose

### Database Schema

Twenty tables organized around five functional domains:

**Authentication & Organization:**
`organizations` — Root entity. Stores org name, unique slug, and verified custom domain. Every other table references this via `orgId`.
`profiles` — User profile extending Clerk's auth model. Stores display name, avatar, and current active org.
`organizationMembers` — Org membership records with role assignment (admin / member).

**Brand & Configuration:**
`tenantConfigs` — Legacy per-org configuration table with encrypted `integrations` JSON field storing all CMS credentials and OAuth tokens.
`brandProfiles` — First-class brand identity objects. Each org can have multiple (for agencies managing several brands). Stores voice, industry, audience, colors, logo, and preferred hub theme. One profile is marked `isDefault`.
`knowledgeDocuments` — Knowledge base file metadata. `contentCache` column stores pre-extracted text to avoid re-processing on every generation run.

**Job & Generation:**
`jobs` — Core job tracking record. `request` and `result` stored as JSON text. `status` flows: pending → running → completed / failed. `brandProfileId` links generation output to the brand that requested it.
`jobEvents` — Append-only event log for job progress. Each pipeline phase transition writes an event, enabling real-time progress streaming to the frontend.
`generatedBlogs` — Output of single-article generation. `contentBlocks` is a JSON array of typed block objects (heading, paragraph, image, quote, list, FAQ). `publishedPlatforms` tracks which CMS platforms received the post and when.

**Content Hub Engine:**
`clusters` — Root entity for a topic cluster. `clusterMap` JSON stores the full architect-designed pillar + cluster page plan. `publishSchedule` JSON stores the staggered date assignments (wave 1, wave 2, wave 3).
`clusterPages` — One row per article in a cluster. Stores `contentBlocks`, SEO fields, JSON-LD schema, quality score, and `pageType` (pillar / cluster). `status` progresses through: pending → generating → draft → linked → ready → scheduled → published.

**Autopilot:**
`opportunityQueue` — ROI-scored content opportunities discovered by the discovery pipeline. `discoveryMeta` JSON preserves the raw keyword and competitor data that produced the score. `status` flows: discovered → approved → generating → done / skipped.
`autopilotSettings` — Per-org autopilot configuration. Stores cadence, review mode, publish time, timezone, target days, and the onboarding completion timestamp that gates access to the Autopilot page.
`publishQueue` — Scheduled publishing records. Links a `clusterPageId` or `generatedBlogId` to a `scheduledPublishAt` timestamp and target platform. `status` flows: pending_review → scheduled → publishing → completed / failed.
`growthSnapshots` — Weekly KPI snapshots. Append-only; the growth chart reads the last N rows ordered by `snapshotDate`.

**Supporting:**
`contentSuggestions` — AI-generated topic ideas surfaced in the dashboard. Marked `isUsed` when turned into a generation job.
`notifications` — In-app notification inbox. `readBy` is a JSON array of user IDs.

### AI Agent Architecture

All complex workflows are expressed as LangGraph directed graphs. Each node is an async function that receives a shared `TypedDict` state and returns a delta. Conditional edges route between nodes based on state values, enabling dynamic branching (skip research if architect fails, skip editor if no SERP deltas).

**Agent types:**

*Generation agents* — Called from within LangGraph nodes. `WorldModelBuilder`, `NarrativeArchitect`, `ComponentWriter`, `CoherenceEditor`, `SEOOptimizer`, `FAQGenerator`, `LinkWeaver`. Each agent wraps a Gemini API call with a structured prompt, parses the response, and returns a typed object that the node merges into the shared state.

*Critic agents* — `ClarityСritic`, `CoherenceCritic`, `SEOCritic`, and `RevisionCritic`. These form the inner quality loop inside the section-generation node. The three scoring critics output numerical scores and notes; the `RevisionCritic` aggregates them into an accept/revise decision. This prevents low-quality sections from reaching the coherence stage.

*Discovery agents* — A separate five-agent pipeline (`BusinessContextBuilder`, `CompetitorFinder`, `KeywordUniverseBuilder`, `ClusterFormation`, `ROIScorer`) runs independently from the generation pipeline. These are invoked during onboarding and by the monthly re-discovery cron.

**State machines:**

The `BlogState` TypedDict tracks both a `current_phase` string and an `errors` list. Every node appends to `errors` on failure rather than raising exceptions, allowing the pipeline to complete partial work and surface detailed diagnostics. The phase string maps directly to the UI progress indicator.

### Authentication & Security

**Multi-layer auth model:**

*Clerk organization authentication* — Every API route calls `auth()` from Clerk and extracts `orgId`. Routes return 403 if `orgId` is absent. For resource-specific routes, the fetched resource's `orgId` is compared against the authenticated `orgId` before any data is returned.

*Internal service authentication* — The Next.js layer calls the Python backend with an `X-Internal-Secret` header. The Python service rejects any request where this header doesn't match `INTERNAL_API_SECRET`. This prevents unauthorized external callers from triggering generation jobs.

*Credential encryption* — AES-256-GCM with a 12-byte random IV and 16-byte authentication tag. The encryption key (`INTEGRATIONS_ENCRYPTION_KEY`) is an environment variable that never touches the database. A compromised database dump does not expose any CMS credentials or OAuth tokens.

*Multi-tenancy enforcement* — All service-layer database queries include an explicit `orgId` predicate derived from the authenticated Clerk session. A user cannot access another organization's data even with a valid JWT by manipulating request parameters.

*Domain safety validation* — Custom domains submitted for registration are validated against a blocklist of reserved substrings (marketday, daysai, vercel) and special-use TLDs (localhost, local, internal). IP addresses are rejected. Domains already claimed by another organization return a 409.

### Key Design Decisions

**Fire-and-forget job dispatch**: The Next.js API layer creates a job record and responds immediately. The Python worker processes asynchronously. The frontend polls status from the database. This avoids long-held HTTP connections, works with serverless deployment, and makes the system resilient to frontend disconnections — a generation job continues running even if the user closes the browser.

**Redis-backed job queue with stateless workers**: Workers are stateless; any worker process can pick up any job. The queue is the single source of truth for pending work. Multiple workers can run in parallel for throughput scaling without any inter-worker coordination.

**Staggered content publishing**: CHE clusters don't publish all pages at once. The scheduler staggers them over two weeks: pillar + 2 pages on day 0, 3 more on day 7, remainder on day 14. This mimics the pace of a human content team and signals organic growth to search engines rather than a sudden content dump.

**Opportunity backlog throttle**: The autopilot runner checks current backlog depth before dispatching a new generation job. If the backlog already contains more than two weeks of content at the configured cadence, the runner skips. This prevents the engine from generating hundreds of articles that won't publish for months.

**Shared Supabase database between services**: Both the Next.js layer and the Python backend write to the same PostgreSQL database. This eliminates a sync layer and a message bus. The Python worker writes directly to `generated_blogs`, `cluster_pages`, and `job_events` using the Supabase Python client with the service role key.

**JSON content blocks over raw HTML**: All generated content is stored as a typed JSON array of block objects (`{ type: "heading", level: 2, text: "..." }`) rather than raw HTML or Markdown. This makes content CMS-agnostic — each publisher adapter transforms blocks into its native format (Gutenberg for WordPress, HTML for Ghost, CMS fields for Webflow) without re-parsing HTML.

**Drizzle ORM with text JSON fields**: Schema flexibility is maintained by storing complex nested data (contentBlocks, publishSchedule, discoveryMeta) as serialized text. This avoids JSONB migration churn as schemas evolve and keeps Drizzle type signatures clean. Manual `JSON.parse` / `JSON.stringify` at the service boundary is explicit and auditable.

**TanStack Query optimistic updates**: Client-side actions (approving a review, toggling autopilot) apply immediate cache mutations before the server responds. Three caches are updated simultaneously — the pending review list, the content calendar, and the KPI cards — and rolled back atomically on error. This eliminates the "click and wait" pattern entirely.

**ISR for the public hub**: Content hub pages use Next.js Incremental Static Regeneration with a 5-minute revalidation window. Pages load at static speed from the CDN edge. When a new article is published, the `/api/revalidate` endpoint is called to invalidate the specific page path. Most readers get the cached version; newly published content is live within minutes.

**Popup OAuth for GSC connection**: The Google Search Console OAuth flow opens in a popup window rather than redirecting the main tab. On completion, the callback page uses `window.opener.postMessage` to notify the parent and closes itself. This preserves all in-progress application state — particularly important when connecting GSC mid-onboarding.

## Implementation Highlights

### 1. Context-First Opportunity Discovery

Most keyword research tools start with a seed keyword and expand outward. MarketDay inverts this: it starts with the business itself. The `BusinessContextBuilder` extracts a structured DNA representation from brand profile and knowledge base documents before touching any search API. Every subsequent agent — competitor finding, keyword seeds, cluster formation — is grounded in this business context. The result is opportunities that are both traffic-viable and product-relevant, not just high-volume keywords that happen to share a topic.

### 2. Recursive Section Quality Loop

The section generation inner loop is what prevents the output from reading like undifferentiated AI content. For each section, a `ComponentWriter` generates a draft, then three independent critic agents score it simultaneously: `ClarityСritic` (sentence complexity, transition quality), `CoherenceCritic` (alignment with narrative spine), and `SEOCritic` (keyword placement, header hierarchy). The `RevisionCritic` aggregates scores and issues a structured revision brief if any dimension falls below threshold. The writer rewrites against the brief. This continues for up to N iterations. Sections that pass all three critics on the first draft cost one Gemini call; complex sections may go three rounds.

### 3. Link Weaving Across Cluster Pages

Generating twelve articles that link naturally to each other is a coordination problem that single-article tools cannot solve. The `LinkWeaver` node receives all draft articles simultaneously, reasons across the full cluster to identify semantically appropriate anchor points, and injects `{ type: "internal_link", anchor: "...", targetSlug: "..." }` blocks in context. The result is a cluster where every article references its siblings at natural junctures — the topical authority signal that pillar-cluster SEO strategy depends on.

### 4. Multi-Tenant Custom Domain Routing

Custom domain support is implemented entirely in Next.js middleware without a separate reverse proxy. When a request arrives with a `Host` header that doesn't match the MarketDay application domain, the middleware looks up the host in the `organizations` table. If found, it rewrites the request path to `/hub/{customDomain}/{path}` and lets Next.js routing handle the rest. The user's browser sees their custom domain throughout; Next.js serves the hub route transparently. Domain safety validation, DNS verification against Vercel's API, and conflict detection (one domain per org) are enforced at the API layer.

### 5. Encrypted Multi-Integration Credential Store

Rather than creating separate database columns or tables for each CMS platform's credentials, all integration data is stored as a single encrypted JSON object in `tenantConfigs.integrations`. New platform integrations can be added without a schema migration. The `decryptIntegrationsString` / `encryptIntegrationsString` utility functions handle AES-256-GCM encryption transparently, and the JSON object is structured as `{ wordpress: {...}, shopify: {...}, googleSearchConsole: {...} }`. Each publisher adapter reads only its own key from the decrypted object.

### 6. Staggered Drip Publishing

The CHE pipeline does not publish immediately after generation. The `che_publish` route takes the completed cluster and assigns concrete timestamps to each page: the pillar and two cluster pages get `NOW()`, the next three pages get `NOW() + 7 days`, and the remainder get `NOW() + 14 days`. These go into the `publishQueue` as `scheduled` rows. The publish cron checks the queue every ten minutes and releases each item when its `scheduledPublishAt` timestamp has passed — no in-memory scheduler, no cron drift, fully restartable.

### 7. Autopilot Backlog Management

The autopilot runner prevents runaway content generation through a mathematical backlog check: it counts `publish_queue` rows with status `scheduled` (not yet published), divides by the configured articles-per-week, and estimates how many weeks of content are already queued. If that exceeds two weeks, the runner exits without generating. This ensures the Autopilot never gets more than two weeks ahead of itself regardless of how often the cron fires, keeping the content calendar readable and manageable.

### 8. Real-Time Job Progress via Event Sourcing

Rather than polling a single status field, the frontend subscribes to the `job_events` table for a given job. Every phase transition in the Python pipeline (`world_model_complete`, `narrative_complete`, `section_3_complete`, etc.) inserts an event row. The frontend renders these as an animated progress stepper. Because events are append-only, the progress display is accurate even if the user navigates away and returns mid-job — the full event history is in the database.

## Challenges & Solutions

### Challenge: AI Content That Reads Like AI Content

**Problem**: Naive prompt-response LLM calls produce content that is structurally correct but tonally flat — it optimizes for covering topics rather than having a perspective.

**Solution**: The Narrative Architecture stage creates an emotional blueprint before any content is written. The central metaphor, tone profile, and emotional arc from this blueprint are injected into every subsequent writer prompt as a constraint, not a suggestion. The multi-critic review loop rejects drafts that drift from the narrative spine. The result is content where every section has a consistent voice and a discernible point of view.

### Challenge: Topical Authority at Scale

**Problem**: Publishing individual articles in isolation does not build topical authority in the way search engines reward. The pillar-cluster model is known to work, but executing it manually requires coordinating a dozen articles simultaneously.

**Solution**: The CHE pipeline treats the cluster as a single atomic unit. The Cluster Architect defines the full structure in one pass. The writer generates all articles with awareness of their siblings. The Link Weaver has access to every draft simultaneously when placing internal links. The publish scheduler staggers output to look organic. The entire complexity of pillar-cluster execution collapses to a single trigger.

### Challenge: Custom Domain Routing Without a Reverse Proxy

**Problem**: Supporting custom domains typically requires a separate reverse proxy (nginx, Caddy) or a managed service like Vercel Domains. Adding infrastructure dependencies complicates deployment.

**Solution**: Next.js middleware runs before the router on every request. By intercepting the `Host` header and rewriting the path internally, the same Next.js process serves both the application and any number of custom-domain content hubs. No external infrastructure required. Vercel's domain API handles DNS verification; the middleware handles routing.

### Challenge: Keeping Content Fresh Without Regenerating Everything

**Problem**: Full regeneration of a published article risks overwriting sections that are still accurate and losing the internal link structure painstakingly assembled by the Link Weaver.

**Solution**: The refresh pipeline uses SERP delta detection to identify only the sections that need updating. The Surgical Editor node receives the specific outdated sections alongside the current SERP data and rewrites only those blocks. The `contentBlocks` JSON structure makes surgical block replacement straightforward — the editor patches an array rather than parsing and regenerating an HTML document.

### Challenge: Docker Environment Variable Forwarding

**Problem**: Environment variables defined in a `.env` file are not automatically passed into Docker Compose service containers. `SERPER_API_KEY` existed in the environment file but never reached the Python worker, causing the keyword universe builder to return empty results silently.

**Solution**: All environment variables required by the worker and API containers are explicitly listed in the `environment:` section of `docker-compose.yml` with `${VAR_NAME}` interpolation. This makes the dependency graph of each service's configuration explicit and auditable. Missing variables fail loudly at container startup rather than silently degrading behavior at runtime.

### Challenge: FK Constraint Violations on Brand Profile Deletion

**Problem**: Deleting a brand profile raises a Postgres FK constraint violation because `clusters.brandProfileId` is `NOT NULL` with no `onDelete` cascade. The raw database error propagated to the user as an unreadable toast message.

**Solution**: The delete handler pre-processes all FK references before issuing the delete. Cluster rows are reassigned to the organization's default profile (preserving `NOT NULL` integrity). Nullable FK references in `opportunityQueue` and `autopilotSettings` are set to null. Server-side guards (isDefault, last-profile) enforce business rules independently of the UI, which already hides the delete button for default profiles. Each guard returns a specific, actionable error message.

### Challenge: Multi-Stage Publish Queue Across Two Services

**Problem**: Content generated by the Python service needs to flow through a review queue, get approved by a human, and then publish at a scheduled time — all orchestrated by the Next.js layer without polling the Python service directly.

**Solution**: The Python worker writes generated content directly to the Supabase database and updates job status. The Next.js cron reads the `publishQueue` table on its own schedule. The two services are fully decoupled — the Python service doesn't know when content will publish, and the Next.js cron doesn't know how content was generated. The database is the contract between them.

## Results & Impact

- **Content velocity**: Organizations generate a complete pillar-cluster structure (1 pillar + up to 12 cluster pages, all internally linked) in a single pipeline run that takes minutes rather than weeks
- **Zero ongoing overhead**: Once configured, the Autopilot engine discovers, generates, and publishes content autonomously. Users interact only through the review queue when review mode is on
- **Platform-agnostic publishing**: The same article publishes to WordPress, Shopify, Ghost, and Framer through platform-specific adapters without manual reformatting
- **Search-engine signal quality**: Staggered publishing, internal linking through the Link Weaver, and JSON-LD schema generation produce content that matches the topical authority signals search engines reward
- **Brand-grounded content**: Knowledge base injection and Business DNA extraction ensure generated content is specific to the organization's product, audience, and voice rather than generic topic coverage

## Future Enhancements

The platform is production-ready and actively serving organizations. Planned additions include:

- **SERP rank tracking dashboard** — surface historical rank movement for each published cluster page
- **Competitor content gap detection** — identify topics competitors rank for that the org has not covered
- **Multi-language cluster generation** — generate and publish clusters in target-market languages
- **Webhook notifications** — push job completion and publish events to Slack, Discord, or custom endpoints
- **Advanced autopilot scheduling** — seasonal topic weighting and holiday content calendar integration
- **Mobile companion app** — approve pending review items and check growth KPIs from mobile
- **A/B title testing** — generate multiple title variants and surface click-through data from GSC
- **Comment and engagement tracking** — aggregate reader engagement signals back into the ROI scorer for future opportunity ranking

## AI Pipelines & Orchestration

See [docs/ai-pipelines.md](docs/ai-pipelines.md) for detailed Mermaid state diagrams of the LangGraph workflows, including the 7-stage single-article generator and the 5-stage Content Hub Engine.

## System Sequence Flows

See [docs/sequence-flows.md](docs/sequence-flows.md) for sequence diagrams mapping the asynchronous interactions between the Next.js frontend, FastAPI microservice, and external LLM providers during content generation and publishing.

## Architecture Diagram

See [docs/system-architecture.md](docs/system-architecture.md) for a visual representation of the system including the Next.js + FastAPI service split, LangGraph pipeline stages, Supabase data flows, Redis job queue, and custom domain routing.

## Database Schema

See [docs/database-schema.md](docs/database-schema.md) for the complete entity-relationship diagram showing all twenty tables, foreign key relationships, and key constraints. You can also view the raw SQL definitions in [docs/schema.sql](docs/schema.sql).

## API Reference

See [docs/api-reference.md](docs/api-reference.md) for the full REST API documentation covering all endpoints, authentication requirements, request/response schemas, and integration patterns.

## Closing Notes

MarketDay demonstrates what becomes possible when agentic AI workflows are composed carefully rather than applied naively. A single Gemini call produces mediocre content. A coordinated pipeline of specialized agents — each with a narrow, well-defined responsibility and a feedback loop — produces content that is grounded in real search data, coherent in voice, structurally sound for SEO, and indistinguishable in quality from what a skilled human content team would produce.

The technology choices reflect this philosophy: LangGraph for explicit, auditable workflow graphs rather than opaque autonomous agents; Next.js App Router for a frontend that is fast for end users and developer-legible in structure; Drizzle ORM for a type-safe database layer that surfaces schema changes at compile time; and Supabase as the integration layer that both services share without coupling them to each other.

The result is a platform that removes the ceiling on how much high-quality, search-optimized content an organization can produce — not by making humans faster, but by making the process not require humans for the parts that can be automated.

---

**Note**: This case study documents a production SaaS platform. Implementation details reflect the actual system architecture. Source code is proprietary and not publicly available.
