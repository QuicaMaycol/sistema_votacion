-- FUNCIÓN PARA OBTENER HISTORIAL DE VOTOS (DNI MODE COMPATIBLE)
-- Corregido: Renombrado 'timestamp' a 'fecha_voto' para evitar error de sintaxis 42601

CREATE OR REPLACE FUNCTION votaciones.get_historial_votos(p_usuario_id UUID)
RETURNS TABLE (
    id UUID,
    fecha_voto TIMESTAMPTZ,
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
        o.texto_opcion,  -- Puede ser NULL si es numérico o candidato puro
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

GRANT EXECUTE ON FUNCTION votaciones.get_historial_votos TO authenticated;
GRANT EXECUTE ON FUNCTION votaciones.get_historial_votos TO anon;
