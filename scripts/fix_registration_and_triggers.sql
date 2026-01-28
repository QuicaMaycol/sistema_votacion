-- REPARACIÓN DE REGISTRO V4: DIAGNÓSTICO Y CASTEOS ROBUSTOS

-- 1. LIMPIEZA DE PRUEBAS (Desbloquear RUCs)
DELETE FROM votaciones.perfiles WHERE empresa_id IN (SELECT id FROM votaciones.empresas WHERE ruc IN ('10725032164', '123456786', '123456789', '12345678'));
DELETE FROM votaciones.empresas WHERE ruc IN ('10725032164', '123456786', '123456789', '12345678');

-- 2. ASEGURAR COLUMNAS Y TIPOS
ALTER TABLE votaciones.perfiles ADD COLUMN IF NOT EXISTS celular TEXT;
ALTER TABLE votaciones.perfiles ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE votaciones.perfiles ALTER COLUMN dni DROP NOT NULL;

-- 3. Trigger Robusto con Logging de Errores
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  BEGIN
    INSERT INTO votaciones.perfiles (id, nombre, email, empresa_id, rol, estado_acceso, celular, dni)
    VALUES (
      new.id, 
      COALESCE(new.raw_user_meta_data->>'nombre', 'Usuario Nuevo'),
      new.email,
      (NULLIF(new.raw_user_meta_data->>'empresa_id', ''))::uuid,
      (COALESCE(new.raw_user_meta_data->>'rol', 'SOCIO'))::votaciones.rol_usuario,
      (COALESCE(new.raw_user_meta_data->>'estado_acceso', 'PENDIENTE'))::votaciones.estado_usuario,
      new.raw_user_meta_data->>'celular',
      new.raw_user_meta_data->>'dni'
    )
    ON CONFLICT (id) DO UPDATE SET
      nombre = EXCLUDED.nombre,
      email = EXCLUDED.email,
      empresa_id = EXCLUDED.empresa_id,
      rol = EXCLUDED.rol,
      estado_acceso = EXCLUDED.estado_acceso,
      celular = EXCLUDED.celular,
      dni = EXCLUDED.dni;
  EXCEPTION WHEN OTHERS THEN
    -- Si falla, registramos el error en la tabla de debug que vimos en tu esquema
    INSERT INTO votaciones.debug_logs (mensaje, detalles)
    VALUES ('Error en handle_new_user', jsonb_build_object(
        'error', SQLERRM, 
        'user_id', new.id,
        'metadata', new.raw_user_meta_data
    ));
  END;
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Re-activar Trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 5. RPC de Vinculación (Sincronización manual)
CREATE OR REPLACE FUNCTION public.vincular_usuario_a_sistema(p_email TEXT, p_metadata JSONB)
RETURNS VOID AS $$
DECLARE
    v_user_id UUID;
BEGIN
    SELECT id INTO v_user_id FROM auth.users WHERE email = p_email;
    
    IF v_user_id IS NOT NULL THEN
        UPDATE auth.users 
        SET raw_user_meta_data = raw_user_meta_data || p_metadata
        WHERE id = v_user_id;

        BEGIN
            INSERT INTO votaciones.perfiles (id, nombre, email, empresa_id, rol, estado_acceso, celular, dni)
            VALUES (
                v_user_id,
                COALESCE(p_metadata->>'nombre', 'Usuario'),
                p_email,
                (NULLIF(p_metadata->>'empresa_id', ''))::uuid,
                (COALESCE(p_metadata->>'rol', 'SOCIO'))::votaciones.rol_usuario,
                (COALESCE(p_metadata->>'estado_acceso', 'PENDIENTE'))::votaciones.estado_usuario,
                p_metadata->>'celular',
                p_metadata->>'dni'
            )
            ON CONFLICT (id) DO UPDATE SET
                nombre = EXCLUDED.nombre,
                email = EXCLUDED.email,
                empresa_id = EXCLUDED.empresa_id,
                rol = EXCLUDED.rol,
                estado_acceso = EXCLUDED.estado_acceso,
                celular = EXCLUDED.celular,
                dni = EXCLUDED.dni;
        EXCEPTION WHEN OTHERS THEN
            INSERT INTO votaciones.debug_logs (mensaje, detalles)
            VALUES ('Error en vincular_usuario_a_sistema', jsonb_build_object('error', SQLERRM, 'metadata', p_metadata));
        END;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. RPC de Verificación
CREATE OR REPLACE FUNCTION public.verificar_perfil_creado(u_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (SELECT 1 FROM votaciones.perfiles WHERE id = u_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Otorgar permisos
GRANT EXECUTE ON FUNCTION public.vincular_usuario_a_sistema TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.verificar_perfil_creado TO authenticated, anon;
