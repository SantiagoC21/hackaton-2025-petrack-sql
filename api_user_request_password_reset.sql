-- ----------------------------------------------------------
-- Función: api_user_request_password_reset
-- Tabla Afectada: usuarios
-- Fecha: 16/02/2026 11:30
-- Descripción: 
--   Esta función inicia el proceso de recuperación de contraseña.
--   1. Recibe el email del usuario en formato JSON.
--   2. Valida que el email exista en la tabla 'usuarios'.
--   3. Genera un código numérico aleatorio de 6 dígitos.
--   4. Actualiza la tabla 'usuarios' con el código de reset y su expiración (15 min).
--   5. Retorna el código y datos del usuario para que el backend envíe el correo.
-- ----------------------------------------------------------

CREATE OR REPLACE FUNCTION api_user_request_password_reset(p_request jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_email VARCHAR(255);
    v_user RECORD;
    v_reset_code VARCHAR(10); -- Para código numérico
    v_reset_expires_at TIMESTAMP;
    v_response jsonb;
BEGIN
    -- 1. Validar entrada
    v_email := lower(p_request ->> 'email');
    IF v_email IS NULL THEN
        RAISE EXCEPTION 'JSON inválido: Falta el email.';
    END IF;

    -- 2. Buscar usuario (Se omite 'name' ya que no existe en la tabla usuarios)
    SELECT id, email, esta_activo, numero_telefono
    INTO v_user
    FROM public.usuarios
    WHERE public.usuarios.email = v_email;

    -- 3. Validar existencia
    IF NOT FOUND THEN
        v_response := jsonb_build_object(
            'status', 'error',
            'code', 404,
            'message', 'El email ingresado no está registrado'
        );
        RETURN v_response;
    END IF;

    -- Opcional: Validar si el usuario está activo antes de permitir reset
    -- IF v_user.esta_activo IS FALSE THEN ...

    -- 4. Generar código numérico (6 dígitos)
    v_reset_code := LPAD(floor(random() * 900000 + 100000)::text, 6, '0');
    v_reset_expires_at := NOW() + INTERVAL '15 minutes'; -- Tiempo estándar para emails

    -- 5. Actualizar registro en BD
    UPDATE usuarios
    SET
        codigo_reset_password = v_reset_code,
        reset_password_expires_at = v_reset_expires_at,
        fecha_actualizacion = NOW() -- Aunque el trigger lo haga, se fuerza explícitamente por coherencia
    WHERE id = v_user.id;

    -- 6. Construir respuesta
    v_response := jsonb_build_object(
        'status', 'success',
        'code', 200,
        'message', 'Código de restablecimiento generado.',
        'data', jsonb_build_object(
            'email', v_user.email,
            -- 'name', v_user.name, -- ELIMINADO: No existe columna nombre en tabla usuarios
            'phone_number', v_user.numero_telefono,
            'password_reset_code', v_reset_code -- Se envía a Node para el email template
        )
    );
    RETURN v_response;

EXCEPTION
    WHEN others THEN
        v_response := jsonb_build_object(
            'status', 'error', 
            'code', 500, 
            'message', COALESCE(SQLERRM, 'Error generando código de restablecimiento.')
        );
        RETURN v_response;
END;
$function$
;