-- CORRECCIÓN: Pasar usuario_id explícitamente
-- auth.uid() es nulo porque los socios no usan Supabase Auth estándar.

DROP FUNCTION IF EXISTS votaciones.emitir_voto(uuid, uuid, numeric, uuid);

CREATE OR REPLACE FUNCTION votaciones.emitir_voto(
    p_usuario_id UUID,       -- NUEVO: Recibimos el ID del usuario
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
    v_existe BOOLEAN;
    v_eleccion_id UUID;
    v_estado_eleccion TEXT;
BEGIN
    -- Validamos que venga el usuario
    IF p_usuario_id IS NULL THEN
        RAISE EXCEPTION 'El ID de usuario es obligatorio.';
    END IF;

    -- 1. Verificar estado de la elección
    SELECT e.id, e.estado INTO v_eleccion_id, v_estado_eleccion
    FROM votaciones.preguntas p
    JOIN votaciones.elecciones e ON p.eleccion_id = e.id
    WHERE p.id = p_pregunta_id;

    IF v_estado_eleccion != 'ACTIVA' THEN
        RAISE EXCEPTION 'La elección no está activa.';
    END IF;

    -- 2. Verificar si ya votó
    SELECT EXISTS (
        SELECT 1 FROM votaciones.votos 
        WHERE usuario_id = p_usuario_id AND pregunta_id = p_pregunta_id
    ) INTO v_existe;

    IF v_existe THEN
        RAISE EXCEPTION 'Ya has votado en esta pregunta.';
    END IF;

    -- 3. Lógica de candidato vs opción
    -- Si mandan un ID en p_opcion_id pero resulta que es de un candidato, lo movemos.
    IF p_opcion_id IS NOT NULL AND p_candidato_id IS NULL THEN
        IF EXISTS (SELECT 1 FROM votaciones.candidatos WHERE id = p_opcion_id) THEN
            p_candidato_id := p_opcion_id;
            p_opcion_id := NULL;
        END IF;
    END IF;

    -- 4. Insertar usando el usuario_id recibido explícitamente
    -- Usamos opcion_elegida_id como vimos en tu estructura
    INSERT INTO votaciones.votos (usuario_id, pregunta_id, opcion_elegida_id, candidato_id, valor_numerico)
    VALUES (p_usuario_id, p_pregunta_id, p_opcion_id, p_candidato_id, p_valor_numerico);
END;
$$;
