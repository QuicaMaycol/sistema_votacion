const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');

/**
 * CONFIGURACIÓN
 * 1. Crea un archivo .env o edita las constantes abajo.
 * 2. Necesitas la 'SERVICE_ROLE_KEY' (no la Anon Key) para crear usuarios sin enviar emails de confirmación.
 */

const SUPABASE_URL = 'TU_SUPABASE_URL_AQUI (ej: https://xyz.supabase.co)';
const SERVICE_ROLE_KEY = 'TU_SERVICE_ROLE_KEY_AQUI';

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: {
        autoRefreshToken: false,
        persistSession: false
    }
});

// AQUI PEGA TU LISTA DE SOCIOS O LEE DE UN CSV
// Formato simple: { dni: '12345678', nombre: 'JUAN PEREZ' }
const padron = [
    { dni: '11111111', nombre: 'SOCIO PRUEBA UNO' },
    { dni: '22222222', nombre: 'SOCIO PRUEBA DOS' },
    // ... pega aquí tus 1000 registros
];

async function importarPadron() {
    console.log(`Iniciando importación de ${padron.length} socios...`);

    for (const socio of padron) {
        // Usar email real si existe, de lo contrario el ficticio
        const emailFinal = socio.email || `${socio.dni}@padron.votacion`;
        const passwordInicial = socio.dni;

        console.log(`Procesando: ${socio.dni} - ${socio.nombre} (${emailFinal})`);

        // 1. Crear Usuario en AUTH
        const { data: authData, error: authError } = await supabase.auth.admin.createUser({
            email: emailFinal,
            password: passwordInicial,
            email_confirm: true,
            user_metadata: {
                nombre_completo: socio.nombre,
                dni: socio.dni
            }
        });

        if (authError) {
            console.error(`  ❌ Error creando Auth para ${socio.dni}:`, authError.message);
            continue; // Saltamos al siguiente si falla auth
        }

        const userId = authData.user.id;
        console.log(`  ✅ Auth creado. ID: ${userId}`);

        // 2. Crear Perfil en TABLA PUBLICA (votaciones.perfiles)
        // Nota: Esto depende de si tienes un Trigger automático. 
        // Si TIENES un trigger que crea el perfil al crear usuario, este paso sobra o es un 'update'.
        // Si NO tienes trigger, este paso es OBLIGATORIO.
        // Asumiremos inserción directa para asegurar los datos.

        const { error: dbError } = await supabase
            .schema('votaciones') // Ajusta si tu schema es 'public'
            .from('perfiles')
            .upsert({
                id: userId,
                nombre: socio.nombre,
                email: emailFinal,
                dni: socio.dni,
                rol: 'SOCIO',
                estado_acceso: 'ACTIVO'
            });

        if (dbError) {
            console.error(`  ⚠️ Error insertando BD para ${socio.dni}:`, dbError.message);
        } else {
            console.log(`  ✅ Perfil BD sincronizado.`);
        }
    }

    console.log('--- Proceso Finalizado ---');
}

importarPadron();
