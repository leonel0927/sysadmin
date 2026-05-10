CREATE TABLE IF NOT EXISTS usuarios (
    id        SERIAL PRIMARY KEY,
    nombre    VARCHAR(100) NOT NULL,
    email     VARCHAR(150) UNIQUE NOT NULL,
    creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO usuarios (nombre, email) VALUES
    ('Admin P11',  'admin@practica11.local'),
    ('Usuario P11','user@practica11.local')
ON CONFLICT (email) DO NOTHING;
