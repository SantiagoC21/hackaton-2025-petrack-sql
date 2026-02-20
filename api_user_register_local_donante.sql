CREATE OR REPLACE FUNCTION api_user_register_local_donante(p_request jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_user_id UUID;
    v_donante_id UUID;
    v_name VARCHAR(100);
    v_lastname VARCHAR(100);
    v_email VARCHAR(255);
    v_password_hash VARCHAR(255);
    v_phone_number VARCHAR(50);
    v_response jsonb;
    v_email_verification_code VARCHAR(10);
    v_email_verification_expires_at TIMESTAMP;
BEGIN
    -- 1. Extracción y Validación de Parámetros
    BEGIN
        v_name := p_request ->> 'name';
        v_lastname := p_request ->> 'lastname';
        v_email := lower(p_request ->> 'email');
        v_password_hash := p_request ->> 'password_hash';
        v_phone_number := p_request ->> 'phone_number';

        -- Error corregido: Eliminado v_rol de la validación ya que no es un parámetro de entrada
        IF v_name IS NULL OR v_lastname IS NULL OR v_email IS NULL OR v_password_hash IS NULL THEN
            RAISE EXCEPTION 'JSON inválido: Faltan claves requeridas (name, lastname, email, password_hash)';
        END IF;

        IF v_email !~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
            RAISE EXCEPTION 'Formato de email inválido.';
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            RETURN jsonb_build_object(
                'status', 'error',
                'code', 400,
                'message', COALESCE(SQLERRM, 'Error procesando JSON de entrada.')
            );
    END;

    -- 2. Verificar duplicados
    IF EXISTS (SELECT 1 FROM usuarios WHERE email = v_email) THEN
        RETURN jsonb_build_object('status', 'error', 'code', 409, 'message', 'El email ya está registrado.');
    END IF;

    IF v_phone_number IS NOT NULL AND EXISTS (SELECT 1 FROM usuarios WHERE numero_telefono = v_phone_number) THEN
        RETURN jsonb_build_object('status', 'error', 'code', 409, 'message', 'El teléfono ya está registrado.');
    END IF;

    v_email_verification_code := LPAD(floor(random() * 900000 + 100000)::text, 6, '0');
    v_email_verification_expires_at := NOW() + INTERVAL '15 minutes';

    -- 3. Inserción Atómica
    BEGIN
        INSERT INTO usuarios (
            email, hash_contrasena, rol, numero_telefono, 
            esta_verificado_email, codigo_verificacion_email, 
            verificicacion_email_expires_at, esta_telefono_verificado, esta_activo
        )
        VALUES (v_email, v_password_hash, 'donante', v_phone_number, FALSE, v_email_verification_code, v_email_verification_expires_at, FALSE, TRUE)
        RETURNING id INTO v_user_id;

        INSERT INTO donantes (usuario_id, nombre, apellidos)
        VALUES (v_user_id, v_name, v_lastname)
        RETURNING id INTO v_donante_id;

    EXCEPTION
        WHEN unique_violation THEN
            RETURN jsonb_build_object('status', 'error', 'code', 409, 'message', 'Error: Datos duplicados.');
        WHEN OTHERS THEN
            RETURN jsonb_build_object('status', 'error', 'code', 500, 'message', 'Error interno: ' || SQLERRM);
    END;

    RETURN jsonb_build_object(
        'status', 'success',
        'code', 201,
        'message', 'Se envió un código de verificación a su email.',
        'user_data', jsonb_build_object(
            'usuario_id', v_user_id,
            'donante_id', v_donante_id,
            'email', v_email,
            'nombre', v_name,
            'rol', 'donante'
        )
    );
END;
$function$;