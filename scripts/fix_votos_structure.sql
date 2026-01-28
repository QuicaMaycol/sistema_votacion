-- SCRIPT DE REPARACIÓN DE ESTRUCTURA
-- Al parecer la tabla 'votos' antigua no tenía las columnas necesarias.

-- 1. Asegurar que existan las columnas opcion_id y candidato_id
ALTER TABLE votaciones.votos 
ADD COLUMN IF NOT EXISTS opcion_id UUID REFERENCES votaciones.opciones(id),
ADD COLUMN IF NOT EXISTS candidato_id UUID REFERENCES votaciones.candidatos(id);

-- 2. Asegurar que usuario_id sea UUID (por si acaso)
-- ALTER TABLE votaciones.votos ALTER COLUMN usuario_id TYPE UUID; 

-- 3. Volver a aplicar la función solo por seguridad (aunque ya la tengas)
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

    INSERT INTO votaciones.votos (usuario_id, pregunta_id, opcion_id, candidato_id, valor_numerico)
    VALUES (v_usuario_id, p_pregunta_id, p_opcion_id, p_candidato_id, p_valor_numerico);
END;
$$;
