-- SCRIPT CONSOLIDADO: ARREGLAR HISTORIAL Y PREGUNTAS PENDIENTES
-- Este script soluciona 2 problemas:
-- 1. Que las preguntas ya votadas sigan apareciendo (porque no se sabía quién votó).
-- 2. Que el historial salga vacío (por la misma razón).

-------------------------------------------------------------------------------
-- 1. FUNCIÓN PARA OBTENER HISTORIAL DE VOTOS (Corrigiendo 'timestamp')
-------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION votaciones.get_historial_votos(p_usuario_id UUID)
RETURNS TABLE (
    id UUID,
    fecha_voto TIMESTAMPTZ, -- Renombrado para evitar error de sintaxis
    texto_pregunta TEXT,
    texto_opcion TEXT,
    valor_numerico NUMERIC,
    nombre_candidato TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        v.id,
        v.timestamp AS fecha_voto,
        p.texto_pregunta,
        o.texto_opcion,
        v.valor_numerico,
        c.nombre_completo AS nombre_candidato
    FROM votaciones.votos v
    JOIN votaciones.preguntas p ON v.pregunta_id = p.id
    LEFT JOIN votaciones.opciones o ON v.opcion_elegida_id = o.id
    LEFT JOIN votaciones.candidatos c ON v.candidato_id = c.id
    WHERE v.usuario_id = p_usuario_id
    ORDER BY v.timestamp DESC;
END;
$$;

-------------------------------------------------------------------------------
-- 2. FUNCIÓN PARA OBTENER PREGUNTAS PENDIENTES (Filtrando por usuario real)
-------------------------------------------------------------------------------
-- Primero eliminamos la versión anterior si existía con otra firma para evitar conflictos
DROP FUNCTION IF EXISTS votaciones.get_preguntas_pendientes();
DROP FUNCTION IF EXISTS votaciones.get_preguntas_pendientes(UUID);

CREATE OR REPLACE FUNCTION votaciones.get_preguntas_pendientes(p_usuario_id UUID)
RETURNS SETOF votaciones.preguntas
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Retorna preguntas de elecciones activas que el usuario NO ha votado
    RETURN QUERY
    SELECT p.*
    FROM votaciones.preguntas p
    JOIN votaciones.elecciones e ON p.eleccion_id = e.id
    WHERE e.estado = 'ACTIVA'
    AND NOT EXISTS (
        SELECT 1 
        FROM votaciones.votos v 
        WHERE v.pregunta_id = p.id 
        AND v.usuario_id = p_usuario_id
    )
    ORDER BY p.orden;
END;
$$;

-- Otorgar permisos
GRANT EXECUTE ON FUNCTION votaciones.get_historial_votos TO authenticated;
GRANT EXECUTE ON FUNCTION votaciones.get_historial_votos TO anon;
GRANT EXECUTE ON FUNCTION votaciones.get_preguntas_pendientes TO authenticated;
GRANT EXECUTE ON FUNCTION votaciones.get_preguntas_pendientes TO anon;
