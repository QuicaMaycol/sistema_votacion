# Habilitar Realtime en Supabase

Si ves el error de "Desconectado" persistentemente, es muy probable que Realtime no esté activado en tu tabla o base de datos.

Sigue estos pasos:

1.  Ve a tu **Supabase Dashboard**.
2.  Entra a **Database** (icono de base de datos en la izquierda) -> **Replication**.
3.  Verás una tabla llamada `supabase_realtime`.
4.  Si no ves nada o está vacía, o dice "0 tables", haz clic en **Source** (o Configuración).
5.  Asegúrate de que el toggle **Enable Realtime** esté activado para la tabla `votaciones.pregunta` (o globalmente).
    *   *Nota: Para Presence puro técnicamente no se necesita replicación de tablas, pero configurar esto suele "despertar" el servicio.*

## Verificar configuración de Canales
Si estás usando Canales Privados (RLS), asegúrate de que existen Políticas (Policies) que permitan acceso `SELECT` a la tabla involucrada.

Al ser Socio (sin Login de Supabase), estás usando acceso PÚBLICO (Anon).
Si el canal falla con `CHANNEL_ERROR` o `401 Unauthorized`, significa que Supabase está rechazando conexiones anónimas.

**Solución rápida:**
Asegúrate de que no haya restricciones extrañas en tu configuración de "Project Settings -> API".
