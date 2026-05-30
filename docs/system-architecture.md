# System Architecture Diagram

## Overview Architecture

```mermaid
graph TB
    subgraph Client["Client Layer"]
        Browser[Web Browser]
        Mobile[Mobile Browser]
    end

    subgraph Frontend["Frontend Layer - Next.js 16"]
        AppRouter[App Router]
        ServerComp[React Server Components]
        ClientComp[React Client Components]
        TanStack[TanStack Query]
        PublicHub[Public Content Hub]
    end

    subgraph Auth["Authentication Layer"]
        ClerkAuth[Clerk Auth & Organizations]
        SessionMgr[Session Handler]
    end

    subgraph API_Layer["Next.js API Layer"]
        Middleware[Domain Routing Middleware]
        APIRoutes[REST API Routes]
        Drizzle[Drizzle ORM]
        VercelCron[Vercel Cron Triggers]
    end

    subgraph PythonWorker["AI Microservice - Python FastAPI"]
        FastAPI[FastAPI Endpoints]
        QueueWorker[Redis Async Worker]
        LangGraph[LangGraph Pipelines]
    end

    subgraph Modules["AI Agents (LangGraph Nodes)"]
        DiscoveryAgents[Discovery Pipeline]
        CHEArchitect[Cluster Architect]
        WriterAgents[Section Writers]
        CriticAgents[Critic & Review Loop]
        LinkWeaver[Internal Link Weaver]
    end

    subgraph Database["Database Layer - Supabase"]
        Postgres[(PostgreSQL shared DB)]
        Storage[(Supabase Storage)]
    end

    subgraph External["External Integrations"]
        Gemini[Google Gemini 2.0]
        Serper[Serper API]
        GSC[Google Search Console]
        CMS[CMS Platforms: WP, Shopify...]
    end

    %% Client flows
    Browser --> AppRouter
    Mobile --> AppRouter
    AppRouter --> ServerComp
    AppRouter --> ClientComp
    ClientComp --> TanStack
    TanStack -->|HTTPS + Session| APIRoutes
    PublicHub -->|Host Rewrites| Middleware

    %% Auth flows
    APIRoutes -.->|Validate JWT & orgId| ClerkAuth
    ClerkAuth --> SessionMgr

    %% API to DB
    APIRoutes --> Drizzle
    Drizzle --> Postgres

    %% API to Python
    VercelCron --> APIRoutes
    APIRoutes -->|HTTP X-Internal-Secret| FastAPI
    FastAPI --> QueueWorker
    QueueWorker --> LangGraph
    
    %% LangGraph to Agents
    LangGraph --> DiscoveryAgents
    LangGraph --> CHEArchitect
    LangGraph --> WriterAgents
    WriterAgents <--> CriticAgents
    LangGraph --> LinkWeaver

    %% Python to Data & External
    LangGraph -->|Direct SQL / supabase-py| Postgres
    LangGraph -.->|RAG| Storage
    LangGraph --> Gemini
    LangGraph --> Serper
    DiscoveryAgents --> GSC
    APIRoutes --> CMS

    style Client fill:#e3f2fd
    style Frontend fill:#bbdefb
    style Auth fill:#fff9c4
    style API_Layer fill:#c8e6c9
    style PythonWorker fill:#f8bbd0
    style Modules fill:#f48fb1
    style Database fill:#ffccbc
    style External fill:#e1bee7
```

## Detailed Request Flow: Content Hub Generation

```mermaid
sequenceDiagram
    participant Cron as Vercel Cron
    participant API as Next.js API
    participant Clerk as Clerk Auth
    participant DB as Supabase PostgreSQL
    participant Worker as FastAPI Worker
    participant Graph as LangGraph Pipeline
    participant LLM as Gemini 2.0
    participant UI as Client UI

    Cron->>API: GET /api/publish/cron
    API->>DB: Check Backlog Limit
    DB-->>API: Backlog < 2 Weeks (OK)
    API->>DB: Update Opportunity -> 'generating'
    API->>Worker: POST /internal/jobs/che-generate (X-Internal-Secret)
    Worker-->>API: 202 Accepted (Job Enqueued)
    API-->>Cron: 200 OK
    
    Worker->>Graph: Initialize CHE Pipeline
    Graph->>DB: Write JobEvent (Architect Phase)
    
    UI->>DB: Poll /api/jobs/:id/events
    DB-->>UI: Stream Event Updates
    
    Graph->>LLM: Generate Cluster Architecture
    LLM-->>Graph: JSON Architecture output
    Graph->>DB: Write JobEvent (Research Phase)
    
    Graph->>Graph: Spawn Parallel Research Nodes
    
    Graph->>LLM: ComponentWriter drafts section
    LLM-->>Graph: Initial Draft
    Graph->>LLM: Three-Critic Review
    LLM-->>Graph: Critic Scores (Coherence, SEO, Clarity)
    Graph->>Graph: Revision Critic validates
    
    Graph->>LLM: Link Weaver Node passes
    LLM-->>Graph: Content with internal links
    
    Graph->>DB: Write to cluster_pages
    Graph->>DB: Schedule publishing in publish_queue
    Graph->>DB: Write JobEvent (Completed)
    
    UI->>DB: Poll events
    DB-->>UI: Completed Event -> UI Updates to Done
```

## Multi-Tenant Architecture

```mermaid
graph LR
    subgraph Org1["Organization A (Acme)"]
        User1[Admin User]
        User2[Content Editor]
        Data1[(Acme Data)]
    end

    subgraph Org2["Organization B (Global)"]
        User3[Admin User]
        Data2[(Global Data)]
    end

    subgraph SharedDB["Shared Supabase PostgreSQL"]
        AllData[(Single Schema)]
    end

    subgraph AppLevel["Next.js Auth & Drizzle"]
        ClerkSession[Clerk Session Verification]
        OrgFilter[Drizzle orgId Predicate]
    end

    User1 -->|org_id: acme_123| ClerkSession
    User2 -->|org_id: acme_123| ClerkSession
    User3 -->|org_id: global_456| ClerkSession

    ClerkSession --> OrgFilter
    OrgFilter -->|WHERE org_id = acme_123| Data1
    OrgFilter -->|WHERE org_id = global_456| Data2
    Data1 -.-> AllData
    Data2 -.-> AllData

    style Org1 fill:#e8f5e9
    style Org2 fill:#e3f2fd
    style SharedDB fill:#ffecb3
    style AppLevel fill:#f3e5f5
```

## Custom Domain Routing Architecture

```mermaid
graph TB
    subgraph Internet
        Req1[Request: https://hub.acme.com/article-1]
        Req2[Request: https://marketday.com/dashboard]
    end

    subgraph VercelEdge["Vercel Edge Network"]
        Middleware[Next.js Middleware]
    end

    subgraph AppRouter["Next.js App Router"]
        Route1["/app/[...routes] (Dashboard UI)"]
        Route2["/hub/[domain]/[slug] (Public Hub Pages)"]
    end

    Req1 --> Middleware
    Req2 --> Middleware

    Middleware -->|Host == marketday.com| Route1
    Middleware -->|Host == hub.acme.com <br/> Rewrite -> /hub/hub.acme.com/article-1| Route2

    style VercelEdge fill:#ffcdd2
    style AppRouter fill:#c8e6c9
```

## Security & Integration Architecture

```mermaid
graph TB
    subgraph SecurityLayers["Security Layers"]
        Clerk[Clerk RBAC & Organization Context]
        Secret[X-Internal-Secret Gateway]
        Encryption[AES-256-GCM Integration Cipher]
        DataIsolation[Multi-Tenant Query Isolation]
    end

    subgraph Services
        NextJS[Next.js API]
        Python[Python AI Worker]
    end

    Client[User Request] --> Clerk
    Clerk -->|Valid JWT & Context| NextJS
    NextJS -->|Validates secret| Secret
    Secret -->|Authorized Backend Job| Python
    
    NextJS --> Encryption
    Encryption -->|Encrypts OAuth Tokens| DB[(Database)]
    Encryption -->|Decrypts CMS Keys| Publisher[CMS Publish Adapter]
    
    NextJS --> DataIsolation
    Python --> DataIsolation
    DataIsolation --> DB

    style SecurityLayers fill:#fff9c4
    style Services fill:#bbdefb
```
