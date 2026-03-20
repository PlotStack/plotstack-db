-- Full PlotStack initial schema
-- Extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ── Tenants ─────────────────────────────────────
CREATE TABLE tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(63) NOT NULL UNIQUE,
    plan VARCHAR(20) NOT NULL DEFAULT 'free'
        CHECK (plan IN ('free', 'pro', 'team', 'enterprise')),
    credit_balance INTEGER NOT NULL DEFAULT 100,
    settings JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);
CREATE INDEX idx_tenants_slug ON tenants (slug) WHERE deleted_at IS NULL;

-- ── Worlds ──────────────────────────────────────
CREATE TABLE worlds (
    id UUID NOT NULL,
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    version INTEGER NOT NULL DEFAULT 1,
    is_current BOOLEAN NOT NULL DEFAULT true,
    name VARCHAR(255) NOT NULL,
    genre VARCHAR(100),
    tone VARCHAR(100),
    art_style TEXT,
    rules JSONB NOT NULL DEFAULT '{}',
    themes VARCHAR(255)[] DEFAULT '{}',
    visual_prompt_defaults TEXT,
    video_prompt_defaults TEXT,
    lore JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    PRIMARY KEY (id, version)
);
CREATE INDEX idx_worlds_tenant ON worlds (tenant_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_worlds_current ON worlds (id) WHERE is_current = true AND deleted_at IS NULL;

-- ── Locations ───────────────────────────────────
CREATE TABLE locations (
    id UUID NOT NULL,
    world_id UUID NOT NULL,
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    version INTEGER NOT NULL DEFAULT 1,
    is_current BOOLEAN NOT NULL DEFAULT true,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    physical_details TEXT,
    style_notes TEXT,
    environmental_rules JSONB NOT NULL DEFAULT '{}',
    prompt_fragments JSONB NOT NULL DEFAULT '{}',
    reference_images JSONB NOT NULL DEFAULT '[]',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    PRIMARY KEY (id, version)
);
CREATE INDEX idx_locations_world ON locations (world_id) WHERE is_current = true AND deleted_at IS NULL;
CREATE INDEX idx_locations_tenant ON locations (tenant_id) WHERE deleted_at IS NULL;

-- ── Characters ──────────────────────────────────
CREATE TABLE characters (
    id UUID NOT NULL,
    world_id UUID NOT NULL,
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    version INTEGER NOT NULL DEFAULT 1,
    is_current BOOLEAN NOT NULL DEFAULT true,
    name VARCHAR(255) NOT NULL,
    role VARCHAR(100),
    personality TEXT,
    visual_description TEXT,
    voice_notes TEXT,
    canonical_traits JSONB NOT NULL DEFAULT '{}',
    wardrobe JSONB NOT NULL DEFAULT '[]',
    emotional_states JSONB NOT NULL DEFAULT '[]',
    props JSONB NOT NULL DEFAULT '[]',
    relationships JSONB NOT NULL DEFAULT '[]',
    character_bible JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    PRIMARY KEY (id, version)
);
CREATE INDEX idx_characters_world ON characters (world_id) WHERE is_current = true AND deleted_at IS NULL;
CREATE INDEX idx_characters_tenant ON characters (tenant_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_characters_name ON characters USING gin (name gin_trgm_ops) WHERE deleted_at IS NULL;

-- ── Character Image Packs ───────────────────────
CREATE TABLE character_image_packs (
    id UUID NOT NULL,
    character_id UUID NOT NULL,
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    version INTEGER NOT NULL DEFAULT 1,
    is_current BOOLEAN NOT NULL DEFAULT true,
    status VARCHAR(20) NOT NULL DEFAULT 'draft'
        CHECK (status IN ('draft', 'generating', 'review', 'approved', 'archived')),
    shot_list JSONB NOT NULL DEFAULT '[]',
    provider_settings JSONB NOT NULL DEFAULT '{}',
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    PRIMARY KEY (id, version)
);
CREATE INDEX idx_packs_character ON character_image_packs (character_id)
    WHERE is_current = true AND deleted_at IS NULL;
CREATE INDEX idx_packs_tenant ON character_image_packs (tenant_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_packs_status ON character_image_packs (status) WHERE deleted_at IS NULL;

-- ── Pack Assets ─────────────────────────────────
CREATE TABLE pack_assets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pack_id UUID NOT NULL,
    pack_version INTEGER NOT NULL,
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    shot_type VARCHAR(50) NOT NULL,
    variant_label VARCHAR(100),
    storage_key VARCHAR(512) NOT NULL,
    thumbnail_key VARCHAR(512),
    generation_prompt TEXT NOT NULL,
    negative_prompt TEXT,
    seed BIGINT,
    model VARCHAR(100),
    provider VARCHAR(50),
    provider_metadata JSONB NOT NULL DEFAULT '{}',
    status VARCHAR(20) NOT NULL DEFAULT 'generated'
        CHECK (status IN ('generated', 'approved', 'rejected', 'superseded')),
    rating SMALLINT CHECK (rating BETWEEN 1 AND 5),
    review_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    FOREIGN KEY (pack_id, pack_version) REFERENCES character_image_packs(id, version)
);
CREATE INDEX idx_assets_pack ON pack_assets (pack_id, pack_version);
CREATE INDEX idx_assets_status ON pack_assets (pack_id, status);
CREATE INDEX idx_assets_shot ON pack_assets (pack_id, shot_type);
CREATE INDEX idx_assets_tenant ON pack_assets (tenant_id);

-- ── Videos ──────────────────────────────────────
CREATE TABLE videos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    world_id UUID NOT NULL,
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    title VARCHAR(255) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'draft'
        CHECK (status IN ('draft', 'planning', 'scene_editing', 'generating', 'review', 'assembly', 'final', 'published')),
    platform_target VARCHAR(50),
    duration_target_seconds INTEGER,
    tone VARCHAR(100),
    storyline TEXT,
    generation_plan JSONB NOT NULL DEFAULT '{}',
    continuity_state JSONB NOT NULL DEFAULT '{}',
    final_output_key VARCHAR(512),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);
CREATE INDEX idx_videos_world ON videos (world_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_videos_tenant ON videos (tenant_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_videos_status ON videos (status) WHERE deleted_at IS NULL;

-- ── Scenes ──────────────────────────────────────
CREATE TABLE scenes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    video_id UUID NOT NULL REFERENCES videos(id),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    sequence_order INTEGER NOT NULL,
    location_id UUID NOT NULL,
    location_version INTEGER NOT NULL DEFAULT 1,
    camera_angle VARCHAR(50),
    shot_type VARCHAR(50),
    action_description TEXT,
    dialogue TEXT,
    narration TEXT,
    sound_cues JSONB NOT NULL DEFAULT '[]',
    timing_seconds NUMERIC(5,2),
    continuity_notes JSONB NOT NULL DEFAULT '{}',
    transition_in VARCHAR(50) DEFAULT 'cut',
    transition_out VARCHAR(50) DEFAULT 'cut',
    assembled_prompt TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);
CREATE INDEX idx_scenes_video ON scenes (video_id, sequence_order) WHERE deleted_at IS NULL;
CREATE INDEX idx_scenes_tenant ON scenes (tenant_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_scenes_location ON scenes (location_id);

-- ── Scene–Character Join ────────────────────────
CREATE TABLE scene_characters (
    scene_id UUID NOT NULL REFERENCES scenes(id) ON DELETE CASCADE,
    character_id UUID NOT NULL,
    character_version INTEGER NOT NULL,
    role_in_scene VARCHAR(100),
    emotional_state VARCHAR(50),
    wardrobe_variant VARCHAR(100),
    position_notes TEXT,
    PRIMARY KEY (scene_id, character_id)
);
CREATE INDEX idx_scene_chars_character ON scene_characters (character_id);

-- ── Generation Jobs ─────────────────────────────
CREATE TABLE generation_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    job_type VARCHAR(30) NOT NULL
        CHECK (job_type IN ('image_pack_asset', 'scene_image', 'scene_video', 'evaluation')),
    status VARCHAR(20) NOT NULL DEFAULT 'queued'
        CHECK (status IN ('queued', 'active', 'polling', 'completed', 'failed', 'dead', 'cancelled')),
    source_entity_type VARCHAR(50),
    source_entity_id UUID,
    template_id UUID,
    template_version INTEGER,
    input_data JSONB NOT NULL DEFAULT '{}',
    assembled_prompt TEXT,
    negative_prompt TEXT,
    provider VARCHAR(50),
    model VARCHAR(100),
    provider_job_id VARCHAR(255),
    provider_metadata JSONB NOT NULL DEFAULT '{}',
    cost_credits NUMERIC(10,4) DEFAULT 0,
    cost_usd NUMERIC(10,4) DEFAULT 0,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    error_message TEXT,
    retry_count INTEGER NOT NULL DEFAULT 0,
    idempotency_key VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_jobs_tenant ON generation_jobs (tenant_id);
CREATE INDEX idx_jobs_status ON generation_jobs (status);
CREATE INDEX idx_jobs_source ON generation_jobs (source_entity_type, source_entity_id);
CREATE INDEX idx_jobs_idempotency ON generation_jobs (idempotency_key) WHERE idempotency_key IS NOT NULL;
CREATE INDEX idx_jobs_created ON generation_jobs (created_at DESC);

-- ── Generated Outputs ───────────────────────────
CREATE TABLE generated_outputs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL REFERENCES generation_jobs(id),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    output_type VARCHAR(20) NOT NULL
        CHECK (output_type IN ('image', 'video', 'audio', 'text')),
    storage_key VARCHAR(512) NOT NULL,
    thumbnail_key VARCHAR(512),
    mime_type VARCHAR(100),
    file_size_bytes BIGINT,
    width INTEGER,
    height INTEGER,
    duration_seconds NUMERIC(8,3),
    metadata JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_outputs_job ON generated_outputs (job_id);
CREATE INDEX idx_outputs_tenant ON generated_outputs (tenant_id);

-- ── Prompt Templates ────────────────────────────
CREATE TABLE prompt_templates (
    id UUID NOT NULL,
    tenant_id UUID,
    world_id UUID,
    version INTEGER NOT NULL DEFAULT 1,
    is_current BOOLEAN NOT NULL DEFAULT true,
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) NOT NULL,
    category VARCHAR(30) NOT NULL
        CHECK (category IN ('world_builder', 'character_builder', 'image_pack', 'scene_builder', 'video_planner')),
    description TEXT,
    steps JSONB NOT NULL DEFAULT '[]',
    variables JSONB NOT NULL DEFAULT '[]',
    fragments JSONB NOT NULL DEFAULT '{}',
    provider_settings JSONB NOT NULL DEFAULT '{}',
    validation_rules JSONB NOT NULL DEFAULT '[]',
    output_schema JSONB NOT NULL DEFAULT '{}',
    prompt_content TEXT,
    negative_prompt_template TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    PRIMARY KEY (id, version)
);
CREATE INDEX idx_templates_category ON prompt_templates (category) WHERE is_current = true AND deleted_at IS NULL;
CREATE INDEX idx_templates_tenant ON prompt_templates (tenant_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_templates_slug ON prompt_templates (slug) WHERE is_current = true AND deleted_at IS NULL;

-- ── Credit Transactions ─────────────────────────
CREATE TABLE credit_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    job_id UUID REFERENCES generation_jobs(id),
    type VARCHAR(20) NOT NULL
        CHECK (type IN ('debit', 'credit', 'refund', 'purchase', 'grant')),
    amount INTEGER NOT NULL,
    balance_after INTEGER NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_credits_tenant ON credit_transactions (tenant_id, created_at DESC);
CREATE INDEX idx_credits_job ON credit_transactions (job_id) WHERE job_id IS NOT NULL;

-- ── Audit Logs ──────────────────────────────────
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID,
    actor_id UUID,
    actor_type VARCHAR(20),
    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(50),
    entity_id UUID,
    before_state JSONB,
    after_state JSONB,
    metadata JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_audit_tenant_time ON audit_logs (tenant_id, created_at DESC);
CREATE INDEX idx_audit_entity ON audit_logs (entity_type, entity_id);
CREATE INDEX idx_audit_action ON audit_logs (action, created_at DESC);

-- ── Row-Level Security ──────────────────────────
ALTER TABLE worlds ENABLE ROW LEVEL SECURITY;
ALTER TABLE locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE characters ENABLE ROW LEVEL SECURITY;
ALTER TABLE character_image_packs ENABLE ROW LEVEL SECURITY;
ALTER TABLE pack_assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE videos ENABLE ROW LEVEL SECURITY;
ALTER TABLE scenes ENABLE ROW LEVEL SECURITY;
ALTER TABLE generation_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE generated_outputs ENABLE ROW LEVEL SECURITY;
ALTER TABLE prompt_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE credit_transactions ENABLE ROW LEVEL SECURITY;

-- Tenant isolation policies
CREATE POLICY tenant_isolation_worlds ON worlds
    USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);
CREATE POLICY tenant_isolation_locations ON locations
    USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);
CREATE POLICY tenant_isolation_characters ON characters
    USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);
CREATE POLICY tenant_isolation_packs ON character_image_packs
    USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);
CREATE POLICY tenant_isolation_assets ON pack_assets
    USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);
CREATE POLICY tenant_isolation_videos ON videos
    USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);
CREATE POLICY tenant_isolation_scenes ON scenes
    USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);
CREATE POLICY tenant_isolation_jobs ON generation_jobs
    USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);
CREATE POLICY tenant_isolation_outputs ON generated_outputs
    USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);
CREATE POLICY tenant_isolation_credits ON credit_transactions
    USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

-- System templates readable by all
CREATE POLICY system_templates_read ON prompt_templates
    FOR SELECT USING (
        tenant_id IS NULL
        OR tenant_id = current_setting('app.current_tenant_id', true)::uuid
    );
CREATE POLICY tenant_templates_write ON prompt_templates
    FOR ALL USING (
        tenant_id = current_setting('app.current_tenant_id', true)::uuid
    );
