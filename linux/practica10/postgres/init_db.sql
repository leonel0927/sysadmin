-- ================================================================
--  init_db.sql - Practica 10 | PostgreSQL
--  Se ejecuta automaticamente al crear el contenedor
-- ================================================================

-- Tabla principal de usuarios
CREATE TABLE IF NOT EXISTS usuarios (
    id        SERIAL PRIMARY KEY,
    nombre    VARCHAR(100) NOT NULL,
    email     VARCHAR(150) UNIQUE NOT NULL,
    rol       VARCHAR(50)  DEFAULT 'usuario',
    activo    BOOLEAN      DEFAULT TRUE,
    creado_en TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);

-- Tabla de logs de acceso
CREATE TABLE IF NOT EXISTS logs_acceso (
    id         SERIAL PRIMARY KEY,
    usuario_id INT REFERENCES usuarios(id) ON DELETE SET NULL,
    accion     VARCHAR(200),
    ip_origen  VARCHAR(45),
    timestamp  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Datos iniciales de prueba
INSERT INTO usuarios (nombre, email, rol) VALUES
    ('Administrador', 'admin@practica10.local',  'admin'),
    ('Juan Perez',    'juan@practica10.local',   'usuario'),
    ('Maria Lopez',   'maria@practica10.local',  'usuario'),
    ('Carlos Ruiz',   'carlos@practica10.local', 'moderador')
ON CONFLICT (email) DO NOTHING;

-- Confirmacion
DO $$
BEGIN
    RAISE NOTICE 'Base de datos practica10_db inicializada.';
    RAISE NOTICE 'Tablas: usuarios, logs_acceso';
END $$;
