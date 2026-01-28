-- CORRECCIÓN FINAL DE FUNCIONES DE REPORTE
-- 1. Soporte para candidatos y opciones múltiples
-- 2. Uso de la columna correcta 'opcion_elegida_id'

CREATE OR REPLACE FUNCTION votaciones.get_resultados_conteo(p_eleccion_id UUID)
RETURNS TABLE (
    pregunta_id UUID,
    texto_pregunta TEXT,
    opcion_id UUID,
    texto_opcion TEXT,
    valor_numerico NUMERIC,
    conteo BIGINT
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    -- Unir resultados de opciones múltiples
    SELECT 
        p.id as pregunta_id,
        p.texto_pregunta,
        o.id as opcion_id,
        o.texto_opcion,
        NULL::NUMERIC as valor_numerico,
        COUNT(v.id) as conteo
    FROM votaciones.preguntas p
    LEFT JOIN votaciones.opciones o ON o.pregunta_id = p.id
    LEFT JOIN votaciones.votos v ON v.pregunta_id = p.id AND v.opcion_elegida_id = o.id
    WHERE p.eleccion_id = p_eleccion_id AND p.tipo = 'OPCION_MULTIPLE'
    GROUP BY p.id, p.texto_pregunta, o.id, o.texto_opcion
    
    UNION ALL
    
    -- Unir resultados de candidatos
    SELECT 
        p.id as pregunta_id,
        p.texto_pregunta,
        c.id as opcion_id,
        c.nombre_completo || ' (#' || c.numero_candidatura || ')' as texto_opcion,
        NULL::NUMERIC as valor_numerico,
        COUNT(v.id) as conteo
    FROM votaciones.preguntas p
    LEFT JOIN votaciones.candidatos c ON c.pregunta_id = p.id
    LEFT JOIN votaciones.votos v ON v.pregunta_id = p.id AND v.candidato_id = c.id
    WHERE p.eleccion_id = p_eleccion_id AND p.tipo = 'CANDIDATOS'
    GROUP BY p.id, p.texto_pregunta, c.id, c.nombre_completo, c.numero_candidatura
    
    UNION ALL
    
    -- Unir resultados de entrada numérica
    SELECT 
        p.id as pregunta_id,
        p.texto_pregunta,
        NULL::UUID as opcion_id,
        'Valor: ' || v.valor_numerico::TEXT as texto_opcion,
        v.valor_numerico,
        COUNT(v.id) as conteo
    FROM votaciones.preguntas p
    JOIN votaciones.votos v ON v.pregunta_id = p.id
    WHERE p.eleccion_id = p_eleccion_id AND p.tipo = 'INPUT_NUMERICO'
    GROUP BY p.id, p.texto_pregunta, v.valor_numerico
    
    ORDER BY texto_pregunta, conteo DESC;
END;
$$;

-- Asegurar permisos
GRANT EXECUTE ON FUNCTION votaciones.get_resultados_conteo TO authenticated, anon;
GRANT EXECUTE ON FUNCTION votaciones.get_reporte_avance TO authenticated, anon;
