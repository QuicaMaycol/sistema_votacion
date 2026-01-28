-- REMOVER RESTRICCIÓN DE CLAVE FORÁNEA EN PERFILES
-- El error "violates foreign key constraint perfiles_id_fkey" ocurre porque estamos intentando insertar
-- socios en la tabla 'perfiles' que NO tienen un usuario correspondiente en 'auth.users'.
-- Como definimos en el plan, estos son "usuarios virtuales" (solo DNI), por lo que debemos quitar esta restricción estricta.

ALTER TABLE votaciones.perfiles
DROP CONSTRAINT IF EXISTS perfiles_id_fkey;

-- Opcional: Si existía otra constraint con otro nombre apuntando a auth.users, también habría que borrarla.
-- Pero el mensaje de error confirmó que se llama "perfiles_id_fkey".
