-- FUNCIÓN PARA LOGIN DE SOCIOS ( SIN AUTH )
-- Esta función busca un usuario en 'perfiles' por DNI.
-- Retorna el perfil completo si existe y es SOCIO.

CREATE OR REPLACE FUNCTION votaciones.login_socio(dni_input text)
RETURNS SETOF votaciones.perfiles
LANGUAGE plpgsql
SECURITY DEFINER -- Se ejecuta con permisos de superusuario para poder leer aunque no haya sesión
AS $$
BEGIN
  RETURN QUERY
  SELECT *
  FROM votaciones.perfiles
  WHERE dni = dni_input
    AND rol = 'SOCIO'
    AND estado_acceso = 'ACTIVO'; -- Asumimos que al cargarlos ya están activos
END;
$$;

-- POLÍTICAS (RLS) PARA PERFILES
-- Asegurarnos que el ADMIN pueda insertar/actualizar perfiles.

ALTER TABLE votaciones.perfiles ENABLE ROW LEVEL SECURITY;

-- 1. Permitir lectura pública (o restringida por RPC, pero RLS podría bloquearlo si no usamos SECURITY DEFINER en la RPC)
-- La RPC usa SECURITY DEFINER, así que salta RLS para la lectura del login.

-- 2. Permitir al ADMIN (autenticado) insertar/modificar perfiles (Carga Masiva)
CREATE POLICY "Admin full access to perfiles"
ON votaciones.perfiles
FOR ALL
TO authenticated
USING (
  auth.jwt() ->> 'email' IN (SELECT email FROM auth.users WHERE auth.uid() = id) -- Validación básica, mejorable con roles claims
  -- O simplemente confiar en que solo los admin tienen acceso a la UI de carga.
  -- Para simplificar en desarrollo:
  -- true
);

-- Si quieres ser estricto con RLS y roles:
-- Deberías tener una función que chequee si el usuario actual es admin.
-- Por ahora, asumiremos que si está autenticado en Supabase Auth, es Admin (ya que los socios no se loguean en Auth).
DROP POLICY IF EXISTS "Enable all for authenticated users" ON votaciones.perfiles;

CREATE POLICY "Enable all for authenticated users"
ON votaciones.perfiles
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);
