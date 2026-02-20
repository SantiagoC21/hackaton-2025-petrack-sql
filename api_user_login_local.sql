-- ----------------------------------------------------------
-- Función: api_user_login_local
-- Tabla Afectada: usuarios
-- Fecha: 16/02/2026 11:26
-- Desarrollado por: Pedro Santiago Castillo Silva
-- Descripción: 
--   Esta función gestiona la primera fase del login con email y contraseña.
--   1. Valida el formato del email recibido.
--   2. Busca al usuario en la tabla 'usuarios'.
--   3. Verifica si el email ha sido verificado (esta_verificado_email).
--   4. Verifica si el usuario tiene una contraseña establecida (hash_contrasena).
--   5. Retorna los datos necesarios (incluyendo el hash) para que el backend (Node.js)
--      realice la comparación segura con bcrypt.
-- ----------------------------------------------------------

CREATE OR REPLACE FUNCTION api_user_login_local(p_request jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_email VARCHAR(255);
    v_password_to_check VARCHAR(255); -- Contraseña en texto plano del input
    v_user_record RECORD;
    v_response jsonb;
BEGIN
    -- 1. Extracción y Validación de Parámetros
    BEGIN
        v_email := lower(p_request ->> 'email');
        v_password_to_check := p_request ->> 'password';
        
        IF v_email IS NULL OR v_password_to_check IS NULL THEN
            RAISE EXCEPTION 'JSON inválido: Faltan claves "email" o "password"';
        END IF;
        
        -- Validación básica de regex para email
        IF v_email !~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
            RAISE EXCEPTION 'Formato de email inválido.';
        END IF;
    EXCEPTION
        WHEN others THEN
            v_response := jsonb_build_object(
                'status', 'error', 
                'code', 400, 
                'message', COALESCE(SQLERRM, 'Error procesando JSON de entrada.')
            );
            RETURN v_response;
    END;

    -- 2. Buscar usuario por email en tabla 'usuarios'
    SELECT
        id, 
        email, 
        hash_contrasena, 
        rol,
        esta_verificado_email, 
        esta_activo, 
        numero_telefono
    INTO v_user_record
    FROM usuarios
    WHERE usuarios.email = v_email;

    IF NOT FOUND THEN
        v_response := jsonb_build_object(
            'status', 'error',
            'code', 404, -- Not Found
            'message', 'Usuario no registrado o credenciales incorrectas.' 
        );
        RETURN v_response;
    END IF;

    -- 3. Lógica de Autenticación

    -- CASO A: El usuario tiene un hash_contrasena establecido
    IF v_user_record.hash_contrasena IS NOT NULL AND v_user_record.hash_contrasena != '' THEN
        
        -- A.1: Verificar si el email está verificado
        IF NOT v_user_record.esta_verificado_email THEN
            v_response := jsonb_build_object(
                'status', 'error',
                'code', 403, -- Forbidden
                'message', 'El email no ha sido verificado. Por favor verifica tu correo.',
                'user_data', jsonb_build_object('email', v_user_record.email)
            );
            RETURN v_response;
        END IF;
        
        -- A.2: Verificar si el usuario está activo (Opcional, según lógica de negocio)
        -- Si esta_activo es FALSE aunque esté verificado (ej. baneado), descomentar esto:
        /*
        IF NOT v_user_record.esta_activo THEN
             v_response := jsonb_build_object('status', 'error', 'code', 403, 'message', 'La cuenta está desactivada.');
             RETURN v_response;
        END IF;
        */

        -- A.3: Usuario válido y con contraseña. Retornar hash para validación en Node.js
        v_response := jsonb_build_object(
            'status', 'success',
            'code', 200,
            'message', 'Usuario encontrado. Validar contraseña en backend.',
            'user_data', jsonb_build_object(
                'user_id', v_user_record.id,
                'email', v_user_record.email,
                'rol', v_user_record.rol,
                'password_hash_db', v_user_record.hash_contrasena, -- Clave para que Node compare
                'is_active', v_user_record.esta_activo,
                'show_phone_question_step', (v_user_record.numero_telefono IS NULL)
            )
        );
        RETURN v_response;

    -- CASO B: El usuario NO tiene contraseña (hash_contrasena es NULL)
    -- Esto puede pasar si se registró con Wallet y nunca puso contraseña.
    ELSE 
        v_response := jsonb_build_object(
            'status', 'error',
            'code', 400, -- Bad Request / Precondition Required
            'message', 'Este usuario no tiene una contraseña establecida. Intente iniciar sesión con su Wallet o recupere su contraseña.'
        );
        RETURN v_response;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        v_response := jsonb_build_object(
            'status', 'error', 
            'code', 500, 
            'message', COALESCE(SQLERRM, 'Error inesperado en la función de login.')
        );
        RETURN v_response;
END;
$function$
;