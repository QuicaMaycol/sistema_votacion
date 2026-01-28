-- Tabla para tracking de presencia robusto (Sin WebSockets)
CREATE TABLE IF NOT EXISTS votaciones.presence_heartbeat (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    metadata JSONB DEFAULT '{}'::jsonb
);

-- Habilitar RLS
ALTER TABLE votaciones.presence_heartbeat ENABLE ROW LEVEL SECURITY;

-- Política: Cualquiera puede ver quién está conectado (o filtrar por empresa en la app)
CREATE POLICY "Ver presencia publica" ON votaciones.presence_heartbeat
    FOR SELECT
    USING (true);

-- Política: Cada usuario solo puede actualizar su propio registro
-- (El insert se maneja con un UPSERT desde la app)
CREATE POLICY "Actualizar mi propia presencia" ON votaciones.presence_heartbeat
    FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Permisos
GRANT ALL ON votaciones.presence_heartbeat TO authenticated, anon;
