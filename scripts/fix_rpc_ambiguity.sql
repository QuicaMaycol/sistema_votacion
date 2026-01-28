-- Eliminar ambas funciones para limpiar colisión
DROP FUNCTION IF EXISTS votaciones.emitir_voto(uuid, uuid, numeric);
DROP FUNCTION IF EXISTS votaciones.emitir_voto(uuid, uuid, numeric, uuid);

-- Recrear la función ÚNICA correcta que soporte todo (opción o candidato)
CREATE OR REPLACE FUNCTION votaciones.emitir_voto(
    p_pregunta_id UUID,
    p_opcion_id UUID DEFAULT NULL,       -- Para Opción Múltiple
    p_valor_numerico NUMERIC DEFAULT NULL, -- Para Numérico
    p_candidato_id UUID DEFAULT NULL     -- Para Candidatos
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_usuario_id UUID := auth.uid();
    v_existe BOOLEAN;
    v_eleccion_id UUID;
    v_estado_eleccion TEXT;
BEGIN
    -- 1. Verificar estado de la elección
    SELECT e.id, e.estado INTO v_eleccion_id, v_estado_eleccion
    FROM votaciones.preguntas p
    JOIN votaciones.elecciones e ON p.eleccion_id = e.id
    WHERE p.id = p_pregunta_id;

    IF v_estado_eleccion != 'ACTIVA' THEN
        RAISE EXCEPTION 'La elección no está activa.';
    END IF;

    -- 2. Verificar si ya votó en esta pregunta
    SELECT EXISTS (
        SELECT 1 FROM votaciones.votos 
        WHERE usuario_id = v_usuario_id AND pregunta_id = p_pregunta_id
    ) INTO v_existe;

    IF v_existe THEN
        RAISE EXCEPTION 'Ya has votado en esta pregunta.';
    END IF;

    -- 3. Insertar voto (Manejando candidato_id si viene)
    -- NOTA: Si p_candidato_id viene, lo usamos. Si no, usamos opcion_id.
    -- Pero tu app actual manda el ID del candidato como p_opcion_id (porque los tratamos como opciones visualmente).
    -- Para evitar romper el frontend, si p_opcion_id apunta a un candidato, lo movemos.
    
    -- INTELIGENCIA: Si p_opcion_id existe en tabla 'candidatos', es un candidato.
    IF p_opcion_id IS NOT NULL AND p_candidato_id IS NULL THEN
        IF EXISTS (SELECT 1 FROM votaciones.candidatos WHERE id = p_opcion_id) THEN
            p_candidato_id := p_opcion_id;
            p_opcion_id := NULL; -- Limpiamos opción para que no guarde basura
        END IF;
    END IF;

    INSERT INTO votaciones.votos (usuario_id, pregunta_id, opcion_id, candidato_id, valor_numerico)
    VALUES (v_usuario_id, p_pregunta_id, p_opcion_id, p_candidato_id, p_valor_numerico);
END;
$$;

-- Permisos
GRANT EXECUTE ON FUNCTION votaciones.emitir_voto TO authenticated;
