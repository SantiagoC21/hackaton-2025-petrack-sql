-- ----------------------------------------------------------
-- Tabla: SESSIONS
-- Fecha: 16/02/2026 11:26
-- ----------------------------------------------------------
CREATE TABLE sessions (
    session_id varchar(255) not null,
    usuario_id UUID NOT NULL UNIQUE REFERENCES usuarios(id) ON DELETE CASCADE,
    user_agent text null,
    ip_address varchar(45) null,
    expires_at TIMESTAMP not null,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP null,
    last_activity_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP null,
    CONSTRAINT session_pkey PRIMARY KEY (session_id)
);
CREATE INDEX idx_sessions_expires_at ON sessions USING btree (expires_at);
CREATE INDEX idx_sessions_usuario_id ON sessions USING btree (usuario_id);



-- ==========================================================
-- SCRIPT DE BASE DE DATOS - PETRACK (Corregido sin extensión)
-- ==========================================================

-- NOTA: No necesitamos 'CREATE EXTENSION "uuid-ossp"'
-- Usaremos la función nativa gen_random_uuid()

-- 1. Definición de TIPOS ENUM
CREATE TYPE rol_usuario AS ENUM ('donante', 'refugio', 'admin');
CREATE TYPE metodo_verificacion AS ENUM ('dni', 'wallet');
CREATE TYPE nivel_reputacion AS ENUM ('bajo', 'medio', 'alto');
CREATE TYPE estado_donacion AS ENUM ('pendiente', 'bloqueado', 'liberado', 'reembolsado');
CREATE TYPE estado_solicitud AS ENUM ('pendiente', 'votacion_activa', 'aprobada', 'rechazada', 'en_disputa');
CREATE TYPE decision_voto AS ENUM ('si', 'no');
CREATE TYPE etapa_nft AS ENUM ('huevo', 'cachorro', 'guardian', 'protector', 'leyenda');
CREATE TYPE tipo_actividad AS ENUM ('donacion', 'voto', 'solicitud_aprobada', 'solicitud_rechazada', 'subida_nivel', 'nft_evolucionado');

-- ----------------------------------------------------------
-- 2. Tabla: USUARIOS
-- ----------------------------------------------------------
CREATE TABLE usuarios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- FUNCIÓN NATIVA
    email VARCHAR(255) UNIQUE,
    hash_contrasena VARCHAR(255),
    rol rol_usuario NOT NULL,
    direccion_wallet VARCHAR(42) UNIQUE, 
    fecha_creacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_wallet_minusculas CHECK (direccion_wallet = lower(direccion_wallet))
);

-- ----------------------------------------------------------
-- 3. Tabla: DONANTES
-- ----------------------------------------------------------
CREATE TABLE donantes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL UNIQUE REFERENCES usuarios(id) ON DELETE CASCADE,
    nombre VARCHAR(100) NOT NULL,
    esta_verificado BOOLEAN DEFAULT FALSE,
    metodo_verificacion metodo_verificacion,
    experiencia INTEGER DEFAULT 0,
    nivel INTEGER DEFAULT 1,
    total_donado DECIMAL(20, 8) DEFAULT 0,
    total_auditorias INTEGER DEFAULT 0,
    votos_correctos INTEGER DEFAULT 0,
    fecha_creacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ----------------------------------------------------------
-- 4. Tabla: REFUGIOS
-- ----------------------------------------------------------
CREATE TABLE refugios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL UNIQUE REFERENCES usuarios(id) ON DELETE CASCADE,
    nombre VARCHAR(100) NOT NULL,
    ubicacion VARCHAR(255),
    url_imagen TEXT,
    esta_verificado BOOLEAN DEFAULT FALSE,
    puntaje_reputacion INTEGER DEFAULT 0 CHECK (puntaje_reputacion BETWEEN 0 AND 100),
    nivel_reputacion nivel_reputacion DEFAULT 'bajo',
    animales_activos INTEGER DEFAULT 0,
    tasa_aprobacion DECIMAL(5, 2) DEFAULT 0,
    balance_wallet DECIMAL(20, 8) DEFAULT 0,
    fondos_congelados DECIMAL(20, 8) DEFAULT 0,
    ultima_sincronizacion_chain TIMESTAMP WITH TIME ZONE,
    fecha_creacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ----------------------------------------------------------
-- 5. Tabla: NFTS_GUARDIANES
-- ----------------------------------------------------------
CREATE TABLE nfts_guardianes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donante_id UUID NOT NULL REFERENCES donantes(id) ON DELETE CASCADE,
    token_id VARCHAR(255),
    url_metadatos TEXT,
    etapa_evolucion etapa_nft DEFAULT 'huevo',
    nivel INTEGER DEFAULT 1,
    xp_actual INTEGER DEFAULT 0,
    xp_siguiente_nivel INTEGER DEFAULT 100,
    fecha_creacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    fecha_evolucion TIMESTAMP WITH TIME ZONE
);

-- ----------------------------------------------------------
-- 6. Tabla: DONACIONES
-- ----------------------------------------------------------
CREATE TABLE donaciones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donante_id UUID NOT NULL REFERENCES donantes(id),
    refugio_id UUID NOT NULL REFERENCES refugios(id),
    monto DECIMAL(20, 8) NOT NULL CHECK (monto > 0),
    estado estado_donacion DEFAULT 'pendiente',
    hash_transaccion VARCHAR(66),
    direccion_contrato VARCHAR(42),
    fecha_creacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    fecha_procesamiento TIMESTAMP WITH TIME ZONE
);

-- ----------------------------------------------------------
-- 7. Tabla: SOLICITUDES_FONDOS
-- ----------------------------------------------------------
CREATE TABLE solicitudes_fondos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    refugio_id UUID NOT NULL REFERENCES refugios(id),
    titulo VARCHAR(150) NOT NULL,
    descripcion TEXT NOT NULL,
    monto_solicitado DECIMAL(20, 8) NOT NULL,
    monto_fianza DECIMAL(20, 8) NOT NULL,
    porcentaje_fianza INTEGER DEFAULT 20,
    archivos_evidencia JSONB DEFAULT '[]'::jsonb,
    estado estado_solicitud DEFAULT 'pendiente',
    id_propuesta_chain VARCHAR(255),
    fecha_limite_votacion TIMESTAMP WITH TIME ZONE,
    votos_si INTEGER DEFAULT 0,
    votos_no INTEGER DEFAULT 0,
    resultado_final estado_solicitud,
    fecha_creacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ----------------------------------------------------------
-- 8. Tabla: VOTOS
-- ----------------------------------------------------------
CREATE TABLE votos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    solicitud_id UUID NOT NULL REFERENCES solicitudes_fondos(id) ON DELETE CASCADE,
    donante_id UUID NOT NULL REFERENCES donantes(id),
    decision decision_voto NOT NULL,
    poder_voto INTEGER DEFAULT 1,
    firma_digital TEXT,
    es_correcto BOOLEAN,
    recompensa_xp INTEGER DEFAULT 0,
    fecha_creacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(solicitud_id, donante_id)
);

-- ----------------------------------------------------------
-- 9. Tabla: ACTIVIDADES
-- ----------------------------------------------------------
CREATE TABLE actividades (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuarios(id),
    tipo tipo_actividad NOT NULL,
    titulo VARCHAR(255) NOT NULL,
    descripcion TEXT,
    xp_ganada INTEGER DEFAULT 0,
    metadatos JSONB DEFAULT '{}'::jsonb,
    donacion_relacionada_id UUID REFERENCES donaciones(id),
    solicitud_relacionada_id UUID REFERENCES solicitudes_fondos(id),
    fecha_creacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ==========================================================
-- ÍNDICES
-- ==========================================================
CREATE INDEX idx_usuarios_email ON usuarios(email);
CREATE INDEX idx_usuarios_wallet ON usuarios(direccion_wallet);
CREATE INDEX idx_donaciones_donante ON donaciones(donante_id);
CREATE INDEX idx_donaciones_refugio ON donaciones(refugio_id);
CREATE INDEX idx_solicitudes_estado ON solicitudes_fondos(estado);
CREATE INDEX idx_solicitudes_refugio ON solicitudes_fondos(refugio_id);
CREATE INDEX idx_votos_solicitud ON votos(solicitud_id);
CREATE INDEX idx_actividad_usuario_fecha ON actividades(usuario_id, fecha_creacion DESC);

-- ==========================================================
-- TRIGGERS
-- ==========================================================
CREATE OR REPLACE FUNCTION actualizar_fecha_modificacion()
RETURNS TRIGGER AS $$
BEGIN
    NEW.fecha_actualizacion = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER trg_usuarios_mod BEFORE UPDATE ON usuarios FOR EACH ROW EXECUTE PROCEDURE actualizar_fecha_modificacion();
CREATE TRIGGER trg_donantes_mod BEFORE UPDATE ON donantes FOR EACH ROW EXECUTE PROCEDURE actualizar_fecha_modificacion();
CREATE TRIGGER trg_refugios_mod BEFORE UPDATE ON refugios FOR EACH ROW EXECUTE PROCEDURE actualizar_fecha_modificacion();
CREATE TRIGGER trg_solicitudes_mod BEFORE UPDATE ON solicitudes_fondos FOR EACH ROW EXECUTE PROCEDURE actualizar_fecha_modificacion();