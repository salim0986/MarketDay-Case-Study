# AI Pipelines & Orchestration

MarketDay’s intelligence layer is powered by multiple specialized agentic workflows orchestrated via LangGraph. Instead of relying on a single monolithic LLM call, the system breaks complex content generation into specialized, autonomous agents that pass state, critique each other's work, and recursively improve output.

Below are the detailed state graphs for the core AI pipelines within the FastAPI microservice.

---

## 1. Single-Article Generation Pipeline

A sophisticated 7-stage state graph designed for on-demand blog generation. It emphasizes narrative structure, fact-checking, and internal coherence through a recursive critic loop.

```mermaid
stateDiagram-v2
    direction TB
    
    [*] --> WorldModelNode
    
    WorldModelNode: World Model Node
    WorldModelNode --> NarrativeArchitectureNode : Output WorldModel
    
    NarrativeArchitectureNode: Narrative Architecture Node
    NarrativeArchitectureNode --> SectionLoopNode : Output Narrative Blueprint
    
    state SectionLoopNode {
        direction TB
        Drafting: Component Writer
        Critique: Critic Agents (Clarity, SEO, Coherence)
        Decision: Revision Critic
        
        Drafting --> Critique
        Critique --> Decision
        Decision --> Drafting : Revise (Score < 85)
        Decision --> [*] : Accept
    }
    
    SectionLoopNode --> CoherenceNode : Compiled Sections
    
    CoherenceNode: Global Coherence Check
    CoherenceNode --> ImagesNode : Approved Draft
    
    ImagesNode: Gemini Image Generation
    ImagesNode --> SEOPublishNode : Images + Metadata
    
    SEOPublishNode: SEO & Formatting Gate
    SEOPublishNode --> DBPublishNode : Final Payload
    
    DBPublishNode: Database Persistence
    DBPublishNode --> [*]
```

### Key Innovations:
- **World Model Isolation**: By separating research into its own node, we prevent hallucinations downstream. All writer agents pull facts exclusively from the `world_model` context, not model priors.
- **Recursive Quality Control**: The `SectionLoopNode` runs a mini-graph per section. It utilizes three specialized critic prompts. The `RevisionCritic` makes a hard routing decision, forcing rewrites up to *N* times until quality thresholds are met.

---

## 2. Content Hub Engine (Pillar + Cluster)

The CHE is designed to build entire topic clusters (e.g., 1 Pillar page + 12 Cluster pages) in a single massive parallel execution, injecting topical authority through semantic interlinking.

```mermaid
stateDiagram-v2
    direction TB
    
    [*] --> ClusterArchitect
    
    ClusterArchitect: Cluster Architect Node
    ClusterArchitect --> ParallelResearch : Cluster Map (1+N pages)
    
    state ParallelResearch {
        direction LR
        PillarResearch: Pillar SERP Analysis
        Cluster1Research: Cluster 1 SERP Analysis
        ClusterNResearch: Cluster N SERP Analysis
        
        PillarResearch --> [*]
        Cluster1Research --> [*]
        ClusterNResearch --> [*]
    }
    
    ParallelResearch --> ParallelWriting : Research Bundles
    
    state ParallelWriting {
        direction LR
        PillarWriter: Pillar Writer Loop
        Cluster1Writer: Cluster 1 Writer Loop
        ClusterNWriter: Cluster N Writer Loop
        
        PillarWriter --> [*]
        Cluster1Writer --> [*]
        ClusterNWriter --> [*]
    }
    
    ParallelWriting --> LinkWeaver : Raw Drafts
    
    LinkWeaver: Link Weaver Node
    LinkWeaver --> SchemaQualityGate : Interlinked Drafts
    
    SchemaQualityGate: Schema & Quality Gate
    SchemaQualityGate --> [*] : Publish to Queue
```

### Key Innovations:
- **Parallel Execution**: Both Research and Writing stages fan-out to run asynchronously across the cluster, drastically reducing latency.
- **Global Link Weaver**: Rather than asking writers to "guess" internal links, the Link Weaver node holds the entire generated cluster in context and surgically rewrites paragraphs to insert highly semantic, exact-match anchor text linking the pillar and clusters together.

---

## 3. Opportunity Discovery Engine

A scheduled cron-job pipeline that continuously analyzes the market and competitors to fill the content queue with high-ROI topics.

```mermaid
flowchart TD
    Start((Cron / Trigger)) --> ContextBuilder[Business Context Builder]
    ContextBuilder --> CompetitorFinder[Competitor Finder Agent]
    
    CompetitorFinder --> SerperAPI[(Serper API)]
    SerperAPI --> KeywordUniverse[Keyword Universe Builder]
    
    KeywordUniverse --> ClusterFormation[Cluster Formation Agent]
    ClusterFormation --> ROIScorer[ROI Scorer Agent]
    
    ROIScorer --> OpportunityQueue[(Supabase Opportunity Queue)]
    
    %% Styling
    classDef agent fill:#0f172a,stroke:#3b82f6,stroke-width:2px,color:#fff;
    class ContextBuilder,CompetitorFinder,KeywordUniverse,ClusterFormation,ROIScorer agent;
```

### Agent Responsibilities:
1. **Context Builder**: Synthesizes the tenant's brand guidelines, website copy, and PDFs into a tight vector representation.
2. **Competitor Finder**: Discovers true search competitors (not just product competitors).
3. **Keyword Universe**: Expands seed terms using long-tail permutations.
4. **Cluster Formation**: Groups keywords semantically to avoid cannibalization.
5. **ROI Scorer**: Ranks clusters by search volume vs. domain difficulty, pushing only the most viable options to the tenant's queue.
