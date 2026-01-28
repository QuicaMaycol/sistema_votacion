-- CORRECCIÓN DE NOMBRE DE COLUMNA EN FUNCIÓN
-- Tu tabla usa 'opcion_elegida_id' pero la función buscaba 'opcion_id'.

CREATE OR REPLACE FUNCTION votaciones.emitir_voto(
    p_pregunta_id UUID,
    p_opcion_id UUID DEFAULT NULL,
    p_valor_numerico NUMERIC DEFAULT NULL,
    p_candidato_id UUID DEFAULT NULL
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
    SELECT e.id, e.estado INTO v_eleccion_id, v_estado_eleccion
    FROM votaciones.preguntas p
    JOIN votaciones.elecciones e ON p.eleccion_id = e.id
    WHERE p.id = p_pregunta_id;

    IF v_estado_eleccion != 'ACTIVA' THEN
        RAISE EXCEPTION 'La elección no está activa.';
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM votaciones.votos 
        WHERE usuario_id = v_usuario_id AND pregunta_id = p_pregunta_id
    ) INTO v_existe;

    IF v_existe THEN
        RAISE EXCEPTION 'Ya has votado en esta pregunta.';
    END IF;

    -- Lógica de candidato vs opción
    IF p_opcion_id IS NOT NULL AND p_candidato_id IS NULL THEN
        IF EXISTS (SELECT 1 FROM votaciones.candidatos WHERE id = p_opcion_id) THEN
            p_candidato_id := p_opcion_id;
            p_opcion_id := NULL;
        END IF;
    END IF;

    -- AQUÍ ESTABA EL ERROR: Usar opcion_elegida_id en lugar de opcion_id
    INSERT INTO votaciones.votos (usuario_id, pregunta_id, opcion_elegida_id, candidato_id, valor_numerico)
    VALUES (v_usuario_id, p_pregunta_id, p_opcion_id, p_candidato_id, p_valor_numerico);
END;
$$;
