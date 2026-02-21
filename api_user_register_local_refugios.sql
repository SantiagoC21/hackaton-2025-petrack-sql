CREATE OR REPLACE FUNCTION api_user_register_local_refugios(p_request jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_user_id UUID;
    v_refugios_id UUID;
    v_nombre VARCHAR(100); -- Consistente
    v_ubicacion VARCHAR(255);
    v_email VARCHAR(255);
    v_password_hash VARCHAR(255);
    v_phone_number VARCHAR(50);
    v_response jsonb;
    v_email_verification_code VARCHAR(10);
    v_email_verification_expires_at TIMESTAMP;
BEGIN
    -- 1. Extracción y Validación
    BEGIN
        v_nombre := p_request ->> 'name'; -- Antes era v_name (error)
        v_ubicacion := p_request ->> 'ubicacion';
        v_email := lower(p_request ->> 'email');
        v_password_hash := p_request ->> 'password_hash';
        v_phone_number := p_request ->> 'phone_number';

        -- Validación ajustada para Refugios
        IF v_nombre IS NULL OR v_ubicacion IS NULL OR v_email IS NULL OR v_password_hash IS NULL THEN
            RAISE EXCEPTION 'JSON inválido: Faltan claves (name, ubicacion, email, password_hash)';
        END IF;

        IF v_email !~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
            RAISE EXCEPTION 'Formato de email inválido.';
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            RETURN jsonb_build_object(
                'status', 'error',
                'code', 400,
                'message', SQLERRM
            );
    END;

    -- 2. Verificar existencia
    IF EXISTS (SELECT 1 FROM usuarios WHERE email = v_email) THEN
        RETURN jsonb_build_object('status', 'error', 'code', 409, 'message', 'Email ya registrado.');
    END IF;

    v_email_verification_code := LPAD(floor(random() * 900000 + 100000)::text, 6, '0');
    v_email_verification_expires_at := NOW() + INTERVAL '15 minutes';

    -- 3. Inserción
    BEGIN
        INSERT INTO usuarios (
            email, hash_contrasena, rol, numero_telefono, 
            esta_verificado_email, codigo_verificacion_email, 
            verificicacion_email_expires_at, esta_telefono_verificado, esta_activo
        )
        VALUES (v_email, v_password_hash, 'refugio', v_phone_number, FALSE, v_email_verification_code, v_email_verification_expires_at, FALSE, TRUE)
        RETURNING id INTO v_user_id;

        INSERT INTO refugios (usuario_id, nombre, ubicacion)
        VALUES (v_user_id, v_nombre, v_ubicacion)
        RETURNING id INTO v_refugios_id;

    EXCEPTION
        WHEN OTHERS THEN
            RETURN jsonb_build_object('status', 'error', 'code', 500, 'message', 'Error al insertar: ' || SQLERRM);
    END;

    -- 4. Éxito
    RETURN jsonb_build_object(
        'status', 'success',
        'code', 201,
        'message', 'Registro de refugio exitoso.',
        'user_data', jsonb_build_object(
            'usuario_id', v_user_id,
            'refugio_id', v_refugios_id,
            'email', v_email,
            'nombre', v_nombre,
            'rol', 'refugio',
            'email_verification_code', v_email_verification_code 
        )
    );
END;
$function$;