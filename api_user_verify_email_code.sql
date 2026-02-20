CREATE OR REPLACE FUNCTION api_user_verify_email_code(p_request jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_email VARCHAR(255);
    v_code VARCHAR(10);
    v_user RECORD; -- Para almacenar los datos del usuario encontrado
    v_response jsonb;
BEGIN
    -- 1. Extracción de Parámetros
    BEGIN
        v_email := lower(p_request ->> 'email');
        v_code := p_request ->> 'code';

        IF v_email IS NULL OR v_code IS NULL THEN
            RAISE EXCEPTION 'JSON inválido: Faltan email o código de verificación.';
        END IF;
    EXCEPTION
        WHEN others THEN
            v_response := jsonb_build_object(
                'status', 'error',
                'code', 400,
                'message', COALESCE(SQLERRM, 'Error procesando JSON de entrada para verificación.')
            );
            RETURN v_response;
    END;

    -- 2. Buscar al usuario y verificar el código
    SELECT 
        id, 
        email, 
        rol,
        esta_verificado_email, 
        codigo_verificacion_email, 
        verificicacion_email_expires_at, -- Nota: Se mantiene el error tipográfico de la definición de la tabla
        numero_telefono
    INTO v_userq
    FROM usuarios
    WHERE usuarios.email = v_email;

    IF NOT FOUND THEN
        v_response := jsonb_build_object(
            'status', 'error',
            'code', 404,
            'message', 'Usuario no encontrado con el email proporcionado.'
        );
        RETURN v_response;
    END IF;

    IF v_user.esta_verificado_email THEN
        v_response := jsonb_build_object(
            'status', 'error',
            'code', 400,
            'message', 'Este email ya ha sido verificado.'
        );
        RETURN v_response; 
    END IF;

    -- Verificación del código
    IF v_user.codigo_verificacion_email IS NULL OR v_user.codigo_verificacion_email != v_code THEN
        v_response := jsonb_build_object(
            'status', 'error',
            'code', 400,
            'message', 'Código de verificación incorrecto.'
        );
        RETURN v_response;
    END IF;
    
    -- Verificación de expiración
    IF v_user.verificicacion_email_expires_at < NOW() THEN
        v_response := jsonb_build_object(
            'status', 'error',
            'code', 400,
            'message', 'El código ha expirado. Por favor, solicita uno nuevo.'
        );
        RETURN v_response;
    END IF;

    -- 3. Código Válido: Actualizar usuario
    BEGIN
        UPDATE usuarios
        SET
            esta_verificado_email = TRUE,
            esta_activo = TRUE, -- Activamos el usuario
            codigo_verificacion_email = NULL, -- Limpiar el código
            verificicacion_email_expires_at = NULL, -- Limpiar la expiración
            fecha_actualizacion = NOW()
        WHERE usuarios.id = v_user.id;
    EXCEPTION
        WHEN others THEN
            v_response := jsonb_build_object(
                'status', 'error',
                'code', 500,
                'message', COALESCE(SQLERRM, 'Error actualizando el estado del usuario.')
            );
            RETURN v_response;
    END;

    -- 4. Respuesta Exitosa
    v_response := jsonb_build_object(
        'status', 'success',
        'code', 200,
        'message', 'Email verificado exitosamente. Sesión iniciada.',
        'user_data', jsonb_build_object( 
            'user_id', v_user.id,
            'email', v_user.email,
            'rol', v_user.rol,
            'show_phone_question_step', (v_user.numero_telefono IS NULL)
        )
    );
    RETURN v_response;

END;
$function$
;