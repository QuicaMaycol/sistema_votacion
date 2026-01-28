-- FUNCION 1: Reporte de Avance (Quién ya votó y quién falta)
-- Retorna la lista de todos los socios de la empresa de la elección, con su progreso.

CREATE OR REPLACE FUNCTION votaciones.get_reporte_avance(p_eleccion_id UUID)
RETURNS TABLE (
    user_id UUID,
    nombre TEXT,
    dni TEXT,
    estado TEXT, -- 'PENDIENTE', 'PARCIAL', 'COMPLETADO'
    preguntas_respondidas BIGINT,
    total_preguntas BIGINT
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_empresa_id UUID;
    v_total_preguntas BIGINT;
BEGIN
    -- 1. Obtener datos de la elección
    SELECT empresa_id INTO v_empresa_id FROM votaciones.elecciones WHERE id = p_eleccion_id;
    
    -- 2. Contar total de preguntas de esta elección
    SELECT COUNT(*) INTO v_total_preguntas FROM votaciones.preguntas WHERE eleccion_id = p_eleccion_id;

    -- 3. Retornar tabla cruzando Perfiles con Votos
    RETURN QUERY
    SELECT 
        p.id as user_id,
        p.nombre,
        p.dni,
        CASE 
            WHEN COUNT(DISTINCT v.pregunta_id) = 0 THEN 'PENDIENTE'
            WHEN COUNT(DISTINCT v.pregunta_id) < v_total_preguntas THEN 'PARCIAL'
            ELSE 'COMPLETADO'
        END as estado,
        COUNT(DISTINCT v.pregunta_id) as preguntas_respondidas,
        v_total_preguntas as total_preguntas
    FROM votaciones.perfiles p
    LEFT JOIN votaciones.votos v ON v.usuario_id = p.id 
        AND v.pregunta_id IN (SELECT id FROM votaciones.preguntas WHERE eleccion_id = p_eleccion_id)
    WHERE p.empresa_id = v_empresa_id 
      AND p.rol = 'SOCIO'      -- Solo nos interesan los socios
      AND p.estado_acceso = 'ACTIVO' -- Solo socios activos
    GROUP BY p.id, p.nombre, p.dni;
END;
$$;


-- FUNCION 2: Resultados de Conteo (Anónimo)
-- Retorna el conteo de votos por opción para cada pregunta de la elección.

CREATE OR REPLACE FUNCTION votaciones.get_resultados_conteo(p_eleccion_id UUID)
RETURNS TABLE (
    pregunta_id UUID,
    texto_pregunta TEXT,
    opcion_id UUID,     -- Puede ser NULL si es numérica
    texto_opcion TEXT,  -- Puede ser NULL
    valor_numerico NUMERIC, -- Para preguntas numéricas
    conteo BIGINT
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id as pregunta_id,
        p.texto_pregunta,
        o.id as opcion_id,
        o.texto_opcion,
        v.valor_numerico,
        COUNT(v.id) as conteo
    FROM votaciones.preguntas p
    LEFT JOIN votaciones.opciones o ON o.pregunta_id = p.id
    LEFT JOIN votaciones.votos v ON v.pregunta_id = p.id 
        AND (v.opcion_id = o.id OR (v.opcion_id IS NULL AND o.id IS NULL))
    WHERE p.eleccion_id = p_eleccion_id
    GROUP BY p.id, p.texto_pregunta, o.id, o.texto_opcion, v.valor_numerico
    ORDER BY p.orden, conteo DESC;
END;
$$;

-- Permisos
GRANT EXECUTE ON FUNCTION votaciones.get_reporte_avance TO authenticated, anon;
GRANT EXECUTE ON FUNCTION votaciones.get_resultados_conteo TO authenticated, anon;
