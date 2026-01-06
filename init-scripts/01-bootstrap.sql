-- 1. EXTENSIONS AND SCHEMAS
CREATE SCHEMA IF NOT EXISTS extensions;
CREATE EXTENSION IF NOT EXISTS pgcrypto SCHEMA extensions;
CREATE SCHEMA IF NOT EXISTS auth;

-- 2. ROLES (API USERS)
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'web_anon') THEN
        CREATE ROLE web_anon NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'api_user') THEN
        CREATE ROLE api_user NOLOGIN;
    END IF;
END
$$;

GRANT usage ON SCHEMA public TO web_anon, api_user;
GRANT usage ON SCHEMA auth TO web_anon, api_user;
GRANT usage ON SCHEMA extensions TO web_anon, api_user;

-- Ensures that PostgREST focuses only on the public schema for the interface.
ALTER ROLE web_anon SET search_path TO public;
ALTER ROLE api_user SET search_path TO public;

-- 3. CRYPTOGRAPHY FUNCTIONS (AUTH SCHEMA)
CREATE OR REPLACE FUNCTION auth.url_encode(data bytea) RETURNS text LANGUAGE sql AS $$
    SELECT translate(encode(data, 'base64'), E'+/=\n\r ', '-_  ');
$$;

CREATE OR REPLACE FUNCTION auth.algorithm_sign(signables text, secret text, algorithm text)
RETURNS text LANGUAGE sql AS $$
    SELECT auth.url_encode(extensions.hmac(signables::bytea, secret::bytea, 'sha256'));
$$;

CREATE OR REPLACE FUNCTION auth.sign(payload json, secret text, algorithm text DEFAULT 'HS256')
RETURNS text LANGUAGE sql AS $$
WITH
  header AS (SELECT auth.url_encode(convert_to('{"alg":"' || algorithm || '","typ":"JWT"}', 'utf8')) AS data),
  payload AS (SELECT auth.url_encode(convert_to(payload::text, 'utf8')) AS data),
  signables AS (SELECT header.data || '.' || payload.data AS data FROM header, payload)
SELECT
  translate(signables.data || '.' || auth.algorithm_sign(signables.data, secret, algorithm), E'\n\r ', '') FROM signables;
$$;

-- 4. TABLE AUTOMATION PROCEDURE
CREATE OR REPLACE PROCEDURE public.setup_table_api(target_table text)
LANGUAGE plpgsql AS $$
BEGIN
    EXECUTE format('GRANT SELECT ON public.%I TO web_anon', target_table);
    EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON public.%I TO api_user', target_table);
    EXECUTE format('GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO api_user');
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', target_table);
    EXECUTE format('DROP POLICY IF EXISTS api_user_policy ON public.%I', target_table);
    EXECUTE format('CREATE POLICY api_user_policy ON public.%I FOR ALL TO api_user USING (true) WITH CHECK (true)', target_table);
    RAISE NOTICE '✅ Table % configured successfully!', target_table;
END;
$$;

-- 5. LOGIN FUNCTION (Using PostgreSQL environment variables)
CREATE OR REPLACE FUNCTION public.login(api_key text) RETURNS text AS $$
DECLARE
  _token text;
  _secret text;
  _master_key text;
  _payload_raw text;
BEGIN
    -- We look for values defined in docker-compose / .env
    _secret := current_setting('app.jwt_secret', true);
    _master_key := current_setting('app.api_master_key', true);

    IF api_key = _master_key THEN
        _payload_raw := '{"role":"api_user","exp":' || (extract(epoch from now())::integer + 3600) || '}';

        SELECT auth.sign(_payload_raw::json, _secret) INTO _token;
        RETURN _token;
    ELSE
        RAISE EXCEPTION 'Invalid API key' USING ERRCODE = 'P0001';
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Ensures that the anonymous user can attempt login
GRANT EXECUTE ON FUNCTION public.login(text) TO web_anon;