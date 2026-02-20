-- ----------------------------------------------------------
-- Función: api_user_resend_verification_code
-- Tabla Afectada: usuarios
-- Fecha: 16/02/2026 11:26
-- Desarrollado por: Pedro Santiago Castillo Silva
-- Descripción: 
--   Esta función permite solicitar un nuevo código de verificación de email.
--   1. Recibe el email del usuario en formato JSON.
--   2. Valida que el usuario exista y que el email no esté verificado previamente.
--   3. Genera un nuevo código numérico aleatorio de 6 dígitos.
--   4. Actualiza la tabla 'usuarios' con el nuevo código y renueva la fecha de expiración (15 min).
--   5. Retorna el nuevo código en la respuesta para que el backend (Node.js) envíe el correo.
-- ----------------------------------------------------------

CREATE OR REPLACE FUNCTION api_user_resend_verification_code(p_request jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_email VARCHAR(255);
    v_user RECORD;
    v_new_code VARCHAR(10);
    v_new_expires_at TIMESTAMP;
    v_response jsonb;
BEGIN
    -- 1. Extracción de Parámetros
    BEGIN
        v_email := lower(p_request ->> 'email');

        IF v_email IS NULL THEN
            RAISE EXCEPTION 'JSON inválido: Falta el email.';
        END IF;
    EXCEPTION
        WHEN others THEN
            v_response := jsonb_build_object(
                'status', 'error',
                'code', 400,
                'message', COALESCE(SQLERRM, 'Error procesando JSON de entrada para reenvío de código.')
            );
            RETURN v_response;
    END;

    -- 2. Buscar al usuario
    SELECT 
        id, 
        email, 
        esta_verificado_email, 
        numero_telefono
    INTO v_user
    FROM usuarios
    WHERE usuarios.email = v_email;

    IF NOT FOUND THEN
        v_response := jsonb_build_object(
            'status', 'error',
            'code', 404, -- Not Found
            'message', 'Usuario no encontrado con el email proporcionado.'
        );
        RETURN v_response;
    END IF;

    -- 3. Verificar si el email ya está verificado
    IF v_user.esta_verificado_email THEN
        v_response := jsonb_build_object(
            'status', 'error',
            'code', 409,      -- Conflict
            'message', 'Este email ya ha sido verificado.'
        );
        RETURN v_response;
    END IF;

    -- 4. Generar nuevo código y fecha de expiración
    -- Genera un número aleatorio entre 100000 y 999999
    v_new_code := LPAD(floor(random() * 900000 + 100000)::text, 6, '0'); 
    v_new_expires_at := NOW() + INTERVAL '15 minutes'; -- Código expira en 15 minutos

    -- 5. Actualizar el usuario con el nuevo código
    BEGIN
        UPDATE usuarios
        SET
            codigo_verificacion_email = v_new_code,
            verificicacion_email_expires_at = v_new_expires_at, -- Nota: Se respeta el nombre de la columna original
            fecha_actualizacion = NOW()
        WHERE usuarios.id = v_user.id;
    EXCEPTION
        WHEN others THEN
            v_response := jsonb_build_object(
                'status', 'error',
                'code', 500,
                'message', COALESCE(SQLERRM, 'Error actualizando el código de verificación del usuario.')
            );
            RETURN v_response;
    END;

    -- 6. Respuesta Exitosa con datos para que Node.js envíe el email
    v_response := jsonb_build_object(
        'status', 'success',
        'code', 200,
        'message', 'Se ha generado y enviado un nuevo código de verificación a su email.',
        'data', jsonb_build_object(
            'email', v_user.email,
            'phone_number', v_user.numero_telefono,
            'email_verification_code', v_new_code -- Dato crítico para el envío del correo desde el backend
        )
    );
    RETURN v_response;

END;
$function$
;