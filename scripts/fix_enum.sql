-- AGREGAR VALOR 'BLOQUEADO' AL ENUM
-- El error indica que el tipo enum 'estado_usuario' no tiene el valor 'BLOQUEADO'.
-- Probablemente solo se crearon 'PENDIENTE' y 'ACTIVO'.

ALTER TYPE votaciones.estado_usuario ADD VALUE IF NOT EXISTS 'BLOQUEADO';
