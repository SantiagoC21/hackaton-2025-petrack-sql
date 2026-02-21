-- ----------------------------------------------------------
-- Función: api_user_reset_password_with_code
-- Tabla Afectada: usuarios
-- Fecha: 16/02/2026 11:40
-- Descripción: 
--   Esta función realiza el cambio definitivo de contraseña.
--   1. Recibe email, código y el hash de la nueva contraseña.
--   2. Re-valida que el código sea correcto y no haya expirado (seguridad crítica).
--   3. Si el código expiró, lo borra y retorna error.
--   4. Si es válido, actualiza el campo 'hash_contrasena', limpia el código de reset
--      y actualiza la fecha de modificación.
-- ----------------------------------------------------------

CREATE OR REPLACE FUNCTION api_user_reset_password_with_code(p_request jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_email VARCHAR(255);
    v_code VARCHAR(10); -- Código que el usuario ingresó
    v_new_password_hash VARCHAR(255);
    v_user RECORD;
    v_response jsonb;
BEGIN
    -- 1. Extraer datos del JSON
    v_email := lower(p_request ->> 'email');
    v_code  := p_request ->> 'code'; 
    -- Nota: El JSON de entrada suele mantener 'password_hash' aunque la columna en BD sea 'hash_contrasena'
    v_new_password_hash := p_request ->> 'password_hash';

    IF v_email IS NULL OR v_code IS NULL OR v_new_password_hash IS NULL THEN
        RAISE EXCEPTION 'JSON inválido: Faltan email, código o nueva contraseña.';
    END IF;

    -- 2. Buscar usuario y datos de reset
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
    
    -- 3. Validar coincidencia del código
    IF v_user.codigo_reset_password IS NULL OR v_user.codigo_reset_password != v_code THEN
        v_response := jsonb_build_object(
            'status', 'error', 
            'code', 400, 
            'message', 'Código de restablecimiento inválido o ya utilizado.'
        );
        RETURN v_response;
    END IF;

    -- 4. Validar expiración
    IF v_user.reset_password_expires_at < NOW() THEN
        -- Si expiró, limpiamos el código para evitar confusiones futuras
        UPDATE usuarios 
        SET 
            codigo_reset_password = NULL, 
            reset_password_expires_at = NULL 
        WHERE id = v_user.id;

        v_response := jsonb_build_object(
            'status', 'error', 
            'code', 400, 
            'message', 'El código de restablecimiento ha expirado.'
        );
        RETURN v_response;
    END IF;

    -- 5. Código Válido: Actualizar contraseña y limpiar código
    UPDATE usuarios
    SET
        hash_contrasena = v_new_password_hash, -- Columna correcta según tu tabla
        codigo_reset_password = NULL,          -- Invalidar el código usado
        reset_password_expires_at = NULL,
        fecha_actualizacion = NOW()
    WHERE id = v_user.id;

    v_response := jsonb_build_object(
        'status', 'success',
        'code', 200,
        'message', 'Contraseña restablecida exitosamente.'
    );
    RETURN v_response;

EXCEPTION
    WHEN others THEN
        v_response := jsonb_build_object(
            'status', 'error', 
            'code', 500, 
            'message', COALESCE(SQLERRM, 'Error actualizando contraseña.')
        );
        RETURN v_response;
END;
$function$
;