-- ACTUALIZACIÓN DE RPC: PREGUNTAS PENDIENTES (Versión Final Robusta)
-- Soluciona ambigüedad de columnas y asegura casting de enums.

DROP FUNCTION IF EXISTS votaciones.get_preguntas_pendientes(UUID);

CREATE OR REPLACE FUNCTION votaciones.get_preguntas_pendientes(p_usuario_id UUID)
RETURNS TABLE (
    id UUID,             -- ID de la pregunta
    eleccion_id UUID,     -- ID de la elección
    texto_pregunta TEXT,
    tipo TEXT,            -- Cast de tipo_pregunta
    orden INT,            -- Orden de la pregunta
    titulo_eleccion TEXT, -- Del join con elecciones
    fecha_inicio TIMESTAMPTZ,
    fecha_fin TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_empresa_id UUID;
BEGIN
    -- 1. Obtener la empresa del usuario
    SELECT p.empresa_id INTO v_empresa_id 
    FROM votaciones.perfiles p 
    WHERE p.id = p_usuario_id;

    -- 2. Retornar preguntas
    RETURN QUERY
    SELECT 
        pr.id,
        pr.eleccion_id,
        pr.texto_pregunta,
        pr.tipo::TEXT, -- Casting explícito del ENUM a TEXTO
        pr.orden,
        e.titulo,
        e.fecha_inicio,
        e.fecha_fin
    FROM votaciones.preguntas pr
    INNER JOIN votaciones.elecciones e ON pr.eleccion_id = e.id
    WHERE e.estado::TEXT = 'ACTIVA' -- Casting por seguridad
      AND e.empresa_id = v_empresa_id
      AND NOT EXISTS (
          SELECT 1 
          FROM votaciones.votos v 
          WHERE v.pregunta_id = pr.id 
            AND v.usuario_id = p_usuario_id
      )
    ORDER BY pr.orden;
END;
$$;

-- Permisos
GRANT EXECUTE ON FUNCTION votaciones.get_preguntas_pendientes TO authenticated;
GRANT EXECUTE ON FUNCTION votaciones.get_preguntas_pendientes TO anon;
