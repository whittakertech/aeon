\restrict j8Hya3ng30ad0iirYD1DKvccNQr7paf2tyAn3KD6QP9uNTGmtnphn7UoemX8oaT

-- Dumped from database version 16.13
-- Dumped by pg_dump version 16.14 (Debian 16.14-1.pgdg12+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: wt_aeon; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA wt_aeon;


--
-- Name: guard_allocation_temporal_fields(); Type: FUNCTION; Schema: wt_aeon; Owner: -
--

CREATE FUNCTION wt_aeon.guard_allocation_temporal_fields() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- Tier 1: hard-blocked fields (no bypass)
  IF (OLD.temporal_kind IS DISTINCT FROM NEW.temporal_kind) OR
     (OLD.starts_at IS DISTINCT FROM NEW.starts_at) OR
     (OLD.duration_seconds IS DISTINCT FROM NEW.duration_seconds) OR
     (OLD.timezone IS DISTINCT FROM NEW.timezone) OR
     (OLD.rrule IS DISTINCT FROM NEW.rrule) OR
     (OLD.valid_from IS DISTINCT FROM NEW.valid_from) OR
     (OLD.supersedes_allocation_id IS DISTINCT FROM NEW.supersedes_allocation_id) OR
     (OLD.schedulable_type IS DISTINCT FROM NEW.schedulable_type) OR
     (OLD.schedulable_id IS DISTINCT FROM NEW.schedulable_id) OR
     (OLD.schedulable_label IS DISTINCT FROM NEW.schedulable_label) THEN
    RAISE EXCEPTION 'cannot mutate temporal fields on a persisted Allocation'
      USING ERRCODE = 'raise_exception';
  END IF;

  -- Tier 2: service-mutable fields (bypass via session variable)
  IF current_setting('aeon.bypass_guard', true) = 'true' THEN
    RETURN NEW;
  END IF;

  IF (OLD.valid_to IS DISTINCT FROM NEW.valid_to) OR
     (OLD.projected_until IS DISTINCT FROM NEW.projected_until) THEN
    RAISE EXCEPTION 'cannot mutate temporal fields on a persisted Allocation'
      USING ERRCODE = 'raise_exception';
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: guard_occurrence_coordinates(); Type: FUNCTION; Schema: wt_aeon; Owner: -
--

CREATE FUNCTION wt_aeon.guard_occurrence_coordinates() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF (OLD.time_range IS DISTINCT FROM NEW.time_range) OR
     (OLD.starts_at IS DISTINCT FROM NEW.starts_at) OR
     (OLD.ends_at IS DISTINCT FROM NEW.ends_at) OR
     (OLD.allocation_id IS DISTINCT FROM NEW.allocation_id) THEN
    RAISE EXCEPTION 'cannot mutate coordinate fields on a persisted Occurrence'
      USING ERRCODE = 'raise_exception';
  END IF;
  RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: schedulable_hosts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schedulable_hosts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying,
    created_at timestamp(6) without time zone DEFAULT now() NOT NULL,
    updated_at timestamp(6) without time zone DEFAULT now() NOT NULL
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: allocations; Type: TABLE; Schema: wt_aeon; Owner: -
--

CREATE TABLE wt_aeon.allocations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    schedulable_type character varying NOT NULL,
    schedulable_id uuid NOT NULL,
    temporal_kind integer NOT NULL,
    starts_at timestamp with time zone NOT NULL,
    duration_seconds integer,
    timezone character varying,
    rrule jsonb,
    valid_from timestamp with time zone NOT NULL,
    valid_to timestamp with time zone,
    projected_until timestamp with time zone NOT NULL,
    supersedes_allocation_id uuid,
    disposal_policy character varying,
    attachment_version_ref character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    schedulable_label character varying(64) NOT NULL
);


--
-- Name: occurrences; Type: TABLE; Schema: wt_aeon; Owner: -
--

CREATE TABLE wt_aeon.occurrences (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    allocation_id uuid NOT NULL,
    time_range tstzrange NOT NULL,
    starts_at timestamp with time zone NOT NULL,
    ends_at timestamp with time zone NOT NULL,
    state integer DEFAULT 0 NOT NULL,
    projection_fingerprint character varying,
    projected_at timestamp with time zone,
    invalidated_at timestamp with time zone,
    invalidated_by_allocation_id uuid,
    purged_at timestamp with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: overrides; Type: TABLE; Schema: wt_aeon; Owner: -
--

CREATE TABLE wt_aeon.overrides (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    occurrence_id uuid NOT NULL,
    replacement_time_range tstzrange,
    canceled boolean DEFAULT false NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: schedulable_hosts schedulable_hosts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schedulable_hosts
    ADD CONSTRAINT schedulable_hosts_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: allocations allocations_pkey; Type: CONSTRAINT; Schema: wt_aeon; Owner: -
--

ALTER TABLE ONLY wt_aeon.allocations
    ADD CONSTRAINT allocations_pkey PRIMARY KEY (id);


--
-- Name: occurrences occurrences_pkey; Type: CONSTRAINT; Schema: wt_aeon; Owner: -
--

ALTER TABLE ONLY wt_aeon.occurrences
    ADD CONSTRAINT occurrences_pkey PRIMARY KEY (id);


--
-- Name: overrides overrides_pkey; Type: CONSTRAINT; Schema: wt_aeon; Owner: -
--

ALTER TABLE ONLY wt_aeon.overrides
    ADD CONSTRAINT overrides_pkey PRIMARY KEY (id);


--
-- Name: idx_aeon_allocations_active_per_schedulable; Type: INDEX; Schema: wt_aeon; Owner: -
--

CREATE UNIQUE INDEX idx_aeon_allocations_active_per_schedulable ON wt_aeon.allocations USING btree (schedulable_type, schedulable_id, schedulable_label) WHERE (valid_to IS NULL);


--
-- Name: idx_aeon_allocations_on_schedulable; Type: INDEX; Schema: wt_aeon; Owner: -
--

CREATE INDEX idx_aeon_allocations_on_schedulable ON wt_aeon.allocations USING btree (schedulable_type, schedulable_id, schedulable_label);


--
-- Name: idx_aeon_occurrences_active; Type: INDEX; Schema: wt_aeon; Owner: -
--

CREATE INDEX idx_aeon_occurrences_active ON wt_aeon.occurrences USING btree (allocation_id, starts_at) WHERE ((invalidated_at IS NULL) AND (purged_at IS NULL));


--
-- Name: idx_aeon_occurrences_on_time_range; Type: INDEX; Schema: wt_aeon; Owner: -
--

CREATE INDEX idx_aeon_occurrences_on_time_range ON wt_aeon.occurrences USING gist (time_range);


--
-- Name: idx_aeon_occurrences_unique_per_allocation; Type: INDEX; Schema: wt_aeon; Owner: -
--

CREATE UNIQUE INDEX idx_aeon_occurrences_unique_per_allocation ON wt_aeon.occurrences USING btree (allocation_id, starts_at);


--
-- Name: idx_aeon_overrides_unique_per_occurrence; Type: INDEX; Schema: wt_aeon; Owner: -
--

CREATE UNIQUE INDEX idx_aeon_overrides_unique_per_occurrence ON wt_aeon.overrides USING btree (occurrence_id);


--
-- Name: allocations guard_allocation_temporal_fields; Type: TRIGGER; Schema: wt_aeon; Owner: -
--

CREATE TRIGGER guard_allocation_temporal_fields BEFORE UPDATE ON wt_aeon.allocations FOR EACH ROW EXECUTE FUNCTION wt_aeon.guard_allocation_temporal_fields();


--
-- Name: occurrences guard_occurrence_coordinates; Type: TRIGGER; Schema: wt_aeon; Owner: -
--

CREATE TRIGGER guard_occurrence_coordinates BEFORE UPDATE ON wt_aeon.occurrences FOR EACH ROW EXECUTE FUNCTION wt_aeon.guard_occurrence_coordinates();


--
-- Name: allocations fk_aeon_allocations_supersedes; Type: FK CONSTRAINT; Schema: wt_aeon; Owner: -
--

ALTER TABLE ONLY wt_aeon.allocations
    ADD CONSTRAINT fk_aeon_allocations_supersedes FOREIGN KEY (supersedes_allocation_id) REFERENCES wt_aeon.allocations(id);


--
-- Name: occurrences fk_aeon_occurrences_allocation; Type: FK CONSTRAINT; Schema: wt_aeon; Owner: -
--

ALTER TABLE ONLY wt_aeon.occurrences
    ADD CONSTRAINT fk_aeon_occurrences_allocation FOREIGN KEY (allocation_id) REFERENCES wt_aeon.allocations(id);


--
-- Name: occurrences fk_aeon_occurrences_invalidated_by; Type: FK CONSTRAINT; Schema: wt_aeon; Owner: -
--

ALTER TABLE ONLY wt_aeon.occurrences
    ADD CONSTRAINT fk_aeon_occurrences_invalidated_by FOREIGN KEY (invalidated_by_allocation_id) REFERENCES wt_aeon.allocations(id);


--
-- Name: overrides fk_aeon_overrides_occurrence; Type: FK CONSTRAINT; Schema: wt_aeon; Owner: -
--

ALTER TABLE ONLY wt_aeon.overrides
    ADD CONSTRAINT fk_aeon_overrides_occurrence FOREIGN KEY (occurrence_id) REFERENCES wt_aeon.occurrences(id);


--
-- PostgreSQL database dump complete
--

\unrestrict j8Hya3ng30ad0iirYD1DKvccNQr7paf2tyAn3KD6QP9uNTGmtnphn7UoemX8oaT

SET search_path TO public,wt_aeon;

INSERT INTO "schema_migrations" (version) VALUES
('20250601000002'),
('20250601000001');

