/* ============================================================
   RECREAR BASE DE DATOS
   ============================================================ */

USE master;
GO

DECLARE @kill varchar(8000) = '';

SELECT @kill = @kill + 'KILL ' + CONVERT(varchar(5), session_id) + ';'
FROM sys.dm_exec_sessions
WHERE database_id = DB_ID('Tarea3');

EXEC(@kill);
GO


ALTER DATABASE Tarea3 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
DROP DATABASE Tarea3;
GO

IF DB_ID('Tarea3') IS NOT NULL
BEGIN
    ALTER DATABASE Tarea3 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Tacrea3;
END;
GO

CREATE DATABASE Tarea3;
GO

USE Tarea3;
GO

/* ============================================================
   1. CATÁLOGOS
   ============================================================ */

CREATE TABLE TipoMovimientoLecturaMedidor(
    TipoMovimientoId INT PRIMARY KEY,   -- 1: Lectura, 2: Ajuste Crédito, 3: Ajuste Débito
    Nombre VARCHAR(50) NOT NULL
);

CREATE TABLE TipoUsoPropiedad(
    TipoUsoId INT PRIMARY KEY,          -- 1 habitación, 2 comercial, etc.
    Nombre VARCHAR(50) NOT NULL
);

CREATE TABLE TipoZonaPropiedad(
    TipoZonaId INT PRIMARY KEY,         -- 1 residencial, 2 agrícola, etc.
    Nombre VARCHAR(50) NOT NULL
);

CREATE TABLE TipoUsuario(
    TipoUsuarioId INT PRIMARY KEY,      -- 1: Administrador, 2: Propietario
    Nombre VARCHAR(50) NOT NULL
);

CREATE TABLE TipoAsociacion(
    TipoAsociacionId INT PRIMARY KEY,   -- 1: Asociar, 2: Desasociar
    Nombre VARCHAR(30) NOT NULL
);

CREATE TABLE TipoMedioPago(
    TipoMedioPagoId INT PRIMARY KEY,    -- 1: Efectivo, 2: Tarjeta
    Nombre VARCHAR(30) NOT NULL
);

CREATE TABLE PeriodoMontoCC(
    PeriodoMontoCCId INT PRIMARY KEY,   -- 1 mensual, 2 trimestral, etc.
    Nombre VARCHAR(50) NOT NULL,
    QMeses INT NOT NULL
);

CREATE TABLE TipoMontoCC(
    TipoMontoCCId INT PRIMARY KEY,      -- 1 monto fijo, 2 variable, 3 porcentaje
    Nombre VARCHAR(50) NOT NULL
);

/* ============================================================
   2. PERSONAS, USUARIOS, MEDIDOR Y PROPIEDAD
   ============================================================ */

CREATE TABLE Persona(
    PersonaId INT IDENTITY PRIMARY KEY,
    ValorDocumento VARCHAR(20) NOT NULL UNIQUE,  -- viene del XML
    Nombre VARCHAR(100) NOT NULL,
    Email VARCHAR(100) NULL,
    Telefono VARCHAR(20) NULL
);

CREATE TABLE Usuario(
    UsuarioId INT IDENTITY PRIMARY KEY,
    PersonaId INT NOT NULL,
    TipoUsuarioId INT NOT NULL,
    NombreUsuario VARCHAR(50) NOT NULL UNIQUE,
    ContrasenaHash VARCHAR(200) NOT NULL,
    FOREIGN KEY (PersonaId) REFERENCES Persona(PersonaId),
    FOREIGN KEY (TipoUsuarioId) REFERENCES TipoUsuario(TipoUsuarioId)
);

CREATE TABLE Medidor(
    MedidorId INT IDENTITY PRIMARY KEY,
    NumeroMedidor VARCHAR(20) NOT NULL UNIQUE,  -- viene del XML
    SaldoM3 DECIMAL(18,2) NOT NULL DEFAULT 0    -- saldo acumulado del medidor
);

CREATE TABLE Propiedad(
    PropiedadId INT IDENTITY PRIMARY KEY,
    NumeroFinca VARCHAR(20) NOT NULL UNIQUE,    -- viene del XML
    MedidorId INT NOT NULL,                     -- 1 medidor por propiedad
    MetrosCuadrados DECIMAL(10,2) NOT NULL,
    TipoUsoId INT NOT NULL,
    TipoZonaId INT NOT NULL,
    ValorFiscal DECIMAL(18,2) NOT NULL,
    FechaRegistro DATE NOT NULL,
    -- campos para consumo de agua
    SaldoM3UltimaFactura DECIMAL(18,2) NOT NULL DEFAULT 0,
    FOREIGN KEY (MedidorId) REFERENCES Medidor(MedidorId),
    FOREIGN KEY (TipoUsoId) REFERENCES TipoUsoPropiedad(TipoUsoId),
    FOREIGN KEY (TipoZonaId) REFERENCES TipoZonaPropiedad(TipoZonaId)
);

/* ============================================================
   3. RELACIÓN PROPIEDAD - PERSONA (PROPIETARIOS)
   ============================================================ */

CREATE TABLE PropiedadPropietario(
    PropiedadPropietarioId INT IDENTITY PRIMARY KEY,
    PropiedadId INT NOT NULL,
    PersonaId INT NOT NULL,
    FechaInicio DATE NOT NULL,
    FechaFin DATE NULL,
    FOREIGN KEY (PropiedadId) REFERENCES Propiedad(PropiedadId),
    FOREIGN KEY (PersonaId) REFERENCES Persona(PersonaId)
);

/* ============================================================
   4. RELACIÓN USUARIO (NO-ADMIN) - PROPIEDAD (PORTAL)
   ============================================================ */

CREATE TABLE UsuarioPropiedad(
    UsuarioPropiedadId INT IDENTITY PRIMARY KEY,
    UsuarioId INT NOT NULL,
    PropiedadId INT NOT NULL,
    FOREIGN KEY (UsuarioId) REFERENCES Usuario(UsuarioId),
    FOREIGN KEY (PropiedadId) REFERENCES Propiedad(PropiedadId),
    CONSTRAINT UQ_UsuarioPropiedad UNIQUE (UsuarioId, PropiedadId)
);

/* ============================================================
   5. CONCEPTOS DE COBRO (CC) Y ASOCIACIÓN A PROPIEDADES
   ============================================================ */

CREATE TABLE ConceptoCobro(
    CCId INT PRIMARY KEY,                     -- viene del XML de CCs
    Nombre VARCHAR(100) NOT NULL,
    PeriodoMontoCCId INT NOT NULL,
    TipoMontoCCId INT NOT NULL,
    ValorMinimo DECIMAL(18,2) NULL,
    ValorMinimoM3 DECIMAL(18,2) NULL,
    ValorFijoM3Adicional DECIMAL(18,2) NULL,
    ValorPorcentual DECIMAL(10,5) NULL,
    ValorFijo DECIMAL(18,2) NULL,
    ValorM2Minimo DECIMAL(18,2) NULL,
    ValorTractosM2 DECIMAL(18,2) NULL,
    FOREIGN KEY (PeriodoMontoCCId) REFERENCES PeriodoMontoCC(PeriodoMontoCCId),
    FOREIGN KEY (TipoMontoCCId) REFERENCES TipoMontoCC(TipoMontoCCId)
);

CREATE TABLE PropiedadCC(
    PropiedadCCId INT IDENTITY PRIMARY KEY,
    PropiedadId INT NOT NULL,
    CCId INT NOT NULL,
    Activo BIT NOT NULL DEFAULT 1,
    FechaInicio DATE NOT NULL,
    FechaFin DATE NULL,
    FOREIGN KEY (PropiedadId) REFERENCES Propiedad(PropiedadId),
    FOREIGN KEY (CCId) REFERENCES ConceptoCobro(CCId),
    CONSTRAINT UQ_Propiedad_CC UNIQUE (PropiedadId, CCId, FechaInicio)
);

/* ============================================================
   6. MOVIMIENTOS DE MEDIDOR (LECTURAS / AJUSTES)
   ============================================================ */

CREATE TABLE MovimientoMedidor(
    MovimientoMedidorId INT IDENTITY PRIMARY KEY,
    MedidorId INT NOT NULL,
    TipoMovimientoId INT NOT NULL,
    FechaOperacion DATE NOT NULL,
    Valor DECIMAL(18,2) NOT NULL,           -- valor usado para variación o ajuste
    FOREIGN KEY (MedidorId) REFERENCES Medidor(MedidorId),
    FOREIGN KEY (TipoMovimientoId) REFERENCES TipoMovimientoLecturaMedidor(TipoMovimientoId)
);

/* ============================================================
   7. FACTURAS Y DETALLE DE FACTURAS
   ============================================================ */

CREATE TABLE Factura(
    FacturaId INT IDENTITY PRIMARY KEY,
    PropiedadId INT NOT NULL,
    FechaFactura DATE NOT NULL,
    FechaLimitePago DATE NOT NULL,
    FechaLimiteCorte DATE NOT NULL,
    Estado INT NOT NULL DEFAULT 1,  -- 1: Pendiente, 2: Pagado normal
    TotalAPagarOriginal DECIMAL(18,2) NOT NULL,
    TotalAPagarFinal DECIMAL(18,2) NOT NULL,
    FOREIGN KEY (PropiedadId) REFERENCES Propiedad(PropiedadId)
);

CREATE TABLE FacturaDetalle(
    FacturaDetalleId INT IDENTITY PRIMARY KEY,
    FacturaId INT NOT NULL,
    CCId INT NOT NULL,
    Monto DECIMAL(18,2) NOT NULL,
    FOREIGN KEY (FacturaId) REFERENCES Factura(FacturaId),
    FOREIGN KEY (CCId) REFERENCES ConceptoCobro(CCId)
);

/* ============================================================
   8. PAGOS Y COMPROBANTES
   ============================================================ */

CREATE TABLE Pago(
    PagoId INT IDENTITY PRIMARY KEY,
    FacturaId INT NOT NULL,
    FechaPago DATE NOT NULL,
    TipoMedioPagoId INT NOT NULL,
    NumeroReferencia VARCHAR(50) NULL,      -- viene del XML: NumeroReferenciaComprobantePago
    MontoPagado DECIMAL(18,2) NOT NULL,
    FOREIGN KEY (FacturaId) REFERENCES Factura(FacturaId),
    FOREIGN KEY (TipoMedioPagoId) REFERENCES TipoMedioPago(TipoMedioPagoId)
);

CREATE TABLE ComprobantePago(
    ComprobantePagoId INT IDENTITY PRIMARY KEY,
    PagoId INT NOT NULL,
    Fecha DATE NOT NULL,
    NumeroReferencia VARCHAR(50) NULL,
    Monto DECIMAL(18,2) NOT NULL,
    FOREIGN KEY (PagoId) REFERENCES Pago(PagoId)
);

/* ============================================================
   9. ÓRDENES DE CORTE Y RECONEXIÓN
   ============================================================ */

CREATE TABLE OrdenCorte(
    OrdenCorteId INT IDENTITY PRIMARY KEY,
    PropiedadId INT NOT NULL,
    FacturaId INT NOT NULL,      -- factura que generó la corta
    FechaOrden DATE NOT NULL,
    Estado INT NOT NULL DEFAULT 1, -- 1: Pago reconexión pendiente, 2: Pago reconexión realizado
    FOREIGN KEY (PropiedadId) REFERENCES Propiedad(PropiedadId),
    FOREIGN KEY (FacturaId) REFERENCES Factura(FacturaId)
);

CREATE TABLE OrdenReconexion(
    OrdenReconexionId INT IDENTITY PRIMARY KEY,
    OrdenCorteId INT NOT NULL,
    FechaReconexion DATE NOT NULL,
    FOREIGN KEY (OrdenCorteId) REFERENCES OrdenCorte(OrdenCorteId)
);

/* ============================================================
   10. PARÁMETROS DEL SISTEMA
   ============================================================ */

CREATE TABLE ParametrosSistema(
    ParametroId INT IDENTITY PRIMARY KEY,
    Nombre VARCHAR(100) NOT NULL,
    ValorInt INT NULL,
    ValorDecimal DECIMAL(18,2) NULL,
    ValorTexto VARCHAR(200) NULL
);

/* ============================================================
   11. (OPCIONAL) VALORES INICIALES DE CATÁLOGOS
   ============================================================ */

INSERT INTO TipoMovimientoLecturaMedidor (TipoMovimientoId, Nombre) VALUES
(1, 'Lectura'), (2, 'Ajuste Crédito'), (3, 'Ajuste Débito');

INSERT INTO TipoUsuario (TipoUsuarioId, Nombre) VALUES
(1, 'Administrador'),
(2, 'Propietario');

INSERT INTO TipoAsociacion (TipoAsociacionId, Nombre) VALUES
(1, 'Asociar'),
(2, 'Desasociar');

INSERT INTO TipoMedioPago (TipoMedioPagoId, Nombre) VALUES
(1, 'Efectivo'),
(2, 'Tarjeta bancaria');

INSERT INTO PeriodoMontoCC (PeriodoMontoCCId, Nombre, QMeses) VALUES
(1, 'Mensual', 1),
(2, 'Trimestral', 3),
(4, 'Semestral', 6),
(5, 'Anual', 12),
(6, 'Cobro único no recurrente', 1),
(7, 'Diario intereses moratorios', 30);

INSERT INTO TipoMontoCC (TipoMontoCCId, Nombre) VALUES
(1, 'Monto fijo'),
(2, 'Monto variable'),
(3, 'Monto por porcentaje');
