-- AGREGAR RESTRICCIÓN ÚNICA PARA UPSERT
-- Esto es necesario para que la "Carga Masiva" pueda detectar si un DNI ya existe y actualizarlo en lugar de duplicarlo.
-- Usamos (dni, empresa_id) para que un mismo DNI pueda existir en empresas diferentes si fuera necesario.

ALTER TABLE votaciones.perfiles
ADD CONSTRAINT perfiles_dni_empresa_unique UNIQUE (dni, empresa_id);
