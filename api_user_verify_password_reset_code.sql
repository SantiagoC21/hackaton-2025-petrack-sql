-- ----------------------------------------------------------
-- Función: api_user_verify_password_reset_code
-- Tabla Afectada: usuarios (Lectura)
-- Fecha: 16/02/2026 11:35
-- Descripción: 
--   Esta función valida el código de restablecimiento de contraseña ingresado por el usuario.
--   1. Recibe el email y el código en formato JSON.
--   2. Busca al usuario por email en la tabla 'usuarios'.
--   3. Verifica que el código coincida con 'codigo_reset_password'.
--   4. Verifica que el código no haya expirado ('reset_password_expires_at').
--   5. Retorna éxito si todo es correcto, permitiendo al frontend/backend proceder al cambio de contraseña.
-- ----------------------------------------------------------

CREATE OR REPLACE FUNCTION api_user_verify_password_reset_code(p_request jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_email VARCHAR(255);
    v_code VARCHAR(10);
    v_user RECORD;
    v_response jsonb;
BEGIN
    v_email := lower(p_request ->> 'email');
    v_code  := p_request ->> 'code';

    IF v_email IS NULL OR v_code IS NULL THEN
        RAISE EXCEPTION 'JSON inválido: Faltan email o código.';
    END IF;

    -- Seleccionamos las columnas correspondientes de la tabla 'usuarios'
    SELECT id, codigo_reset_password, reset_password_expires_at
    INTO v_user
    FROM usuarios
    WHERE usuarios.email = v_email;

    IF NOT FOUND THEN
        v_response := jsonb_build_object(
            'status', 'error', 
            'code', 404, 
            'message', 'Usuario no encontrado.'
        );
        RETURN v_response;
    END IF;

    -- Verificamos si el código coincide
    IF v_user.codigo_reset_password IS NULL OR v_user.codigo_reset_password != v_code THEN
        v_response := jsonb_build_object(
            'status', 'error', 
            'code', 400, 
            'message', 'Código de restablecimiento incorrecto.'
        );
        RETURN v_response;
    END IF;

    -- Verificamos si el código ha expirado
    IF v_user.reset_password_expires_at < NOW() THEN
        v_response := jsonb_build_object(
            'status', 'error', 
            'code', 400, 
            'message', 'El código ha expirado. Por favor, solicita uno nuevo.'
        );
        RETURN v_response;
    END IF;

    -- Código válido y vigente
    v_response := jsonb_build_object(
        'status', 'success',
        'code', 200,
        'message', 'Código de restablecimiento validado. Procede a cambiar tu contraseña.',
        'data', jsonb_build_object(
            'email', v_email,
            'id', v_user.id -- Se puede retornar el ID para facilitar el siguiente paso
        ) 
    );
    RETURN v_response;

EXCEPTION
    WHEN others THEN
        v_response := jsonb_build_object(
            'status', 'error', 
            'code', 500, 
            'message', COALESCE(SQLERRM, 'Error validando código.')
        );
        RETURN v_response;
END;
$function$
;