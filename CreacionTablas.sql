SET NOCOUNT ON;
GO

IF NOT EXISTS(SELECT 1 FROM sys.schemas WHERE name = 'dbo')
  EXEC('CREATE SCHEMA dbo');
GO

CREATE TABLE TipoUsoPropiedad (
  TipoUsoPropiedadID TINYINT PRIMARY KEY,
  Nombre NVARCHAR(100) NOT NULL
);

CREATE TABLE TipoZonaPropiedad (
  TipoZonaPropiedadID TINYINT PRIMARY KEY,
  Nombre NVARCHAR(100) NOT NULL
);

CREATE TABLE TipoUsuario (
  TipoUsuarioID TINYINT PRIMARY KEY,
  Nombre NVARCHAR(100) NOT NULL
);

CREATE TABLE TipoMovimientoLecturaMedidor (
  TipoMovimientoID TINYINT PRIMARY KEY,
  Nombre NVARCHAR(100) NOT NULL
);

CREATE TABLE PeriodoMontoCC (
  PeriodoMontoCCID TINYINT PRIMARY KEY,
  Nombre NVARCHAR(50) NOT NULL,
  QMeses TINYINT NOT NULL
);

CREATE TABLE TipoMontoCC (
  TipoMontoCCID TINYINT PRIMARY KEY,
  Nombre NVARCHAR(50) NOT NULL
);

CREATE TABLE TipoMedioPago (
  TipoMedioPagoID TINYINT PRIMARY KEY,
  Nombre NVARCHAR(50) NOT NULL
);


CREATE TABLE Persona (
  PersonaID INT IDENTITY(1,1) PRIMARY KEY,
  ValorDocumentoIdentidad VARCHAR(50) NOT NULL UNIQUE,
  Nombre NVARCHAR(200) NOT NULL,
  Email NVARCHAR(100) NULL,
  Telefono1 VARCHAR(20) NULL,
  Telefono2 VARCHAR(20) NULL,
  EsJuridica BIT NOT NULL DEFAULT(0),
  FechaCreacion DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);


CREATE TABLE Propiedad (
  PropiedadID INT IDENTITY(1,1) PRIMARY KEY,
  NumeroFinca VARCHAR(50) NOT NULL UNIQUE,
  MetrosCuadrados DECIMAL(12,2) NOT NULL,
  TipoUsoPropiedadID TINYINT NOT NULL,
  TipoZonaPropiedadID TINYINT NOT NULL,
  ValorFiscal DECIMAL(18,2) NOT NULL,
  FechaRegistro DATE NOT NULL,
  SaldoM3 DECIMAL(12,3) NOT NULL DEFAULT(0.0),
  SaldoM3UltimaFactura DECIMAL(12,3) NOT NULL DEFAULT(0.0),
  FechaCreacion DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
  Activo BIT NOT NULL DEFAULT(1),
  CONSTRAINT FK_Propiedad_TipoUso FOREIGN KEY (TipoUsoPropiedadID) REFERENCES TipoUsoPropiedad(TipoUsoPropiedadID),
  CONSTRAINT FK_Propiedad_TipoZona FOREIGN KEY (TipoZonaPropiedadID) REFERENCES TipoZonaPropiedad(TipoZonaPropiedadID)
);

/* --------------------
   PropiedadPropietario (histórico)
   -------------------- */
CREATE TABLE PropiedadPropietario (
  PropiedadPropietarioID INT IDENTITY(1,1) PRIMARY KEY,
  PropiedadID INT NOT NULL,
  PersonaID INT NOT NULL,
  FechaInicio DATE NOT NULL,
  FechaFin DATE NULL,
  TipoAsociacionID TINYINT NULL,
  CONSTRAINT FK_PP_Propiedad FOREIGN KEY (PropiedadID) REFERENCES Propiedad(PropiedadID),
  CONSTRAINT FK_PP_Persona FOREIGN KEY (PersonaID) REFERENCES Persona(PersonaID)
);

/* --------------------
   Usuario
   -------------------- */
CREATE TABLE Usuario (
  UsuarioID INT IDENTITY(1,1) PRIMARY KEY,
  PersonaID INT NULL,
  Username NVARCHAR(100) NOT NULL UNIQUE,
  PasswordHash VARBINARY(256) NOT NULL,
  TipoUsuarioID TINYINT NOT NULL,
  FechaCreacion DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
  Activo BIT NOT NULL DEFAULT(1),
  CONSTRAINT FK_Usuario_Persona FOREIGN KEY (PersonaID) REFERENCES Persona(PersonaID),
  CONSTRAINT FK_Usuario_TipoUsuario FOREIGN KEY (TipoUsuarioID) REFERENCES TipoUsuario(TipoUsuarioID)
);

/* --------------------
   UsuarioPropiedad
   -------------------- */
CREATE TABLE UsuarioPropiedad (
  UsuarioPropiedadID INT IDENTITY(1,1) PRIMARY KEY,
  UsuarioID INT NOT NULL,
  PropiedadID INT NOT NULL,
  FechaInicio DATE NOT NULL,
  FechaFin DATE NULL,
  CONSTRAINT FK_UP_Usuario FOREIGN KEY (UsuarioID) REFERENCES Usuario(UsuarioID),
  CONSTRAINT FK_UP_Propiedad FOREIGN KEY (PropiedadID) REFERENCES Propiedad(PropiedadID)
);

/* --------------------
   Medidor y MovimientoMedidor
   -------------------- */
CREATE TABLE Medidor (
  MedidorID INT IDENTITY(1,1) PRIMARY KEY,
  NumeroMedidor VARCHAR(50) NOT NULL UNIQUE,
  PropiedadID INT NOT NULL,
  SaldoM3 DECIMAL(12,3) NOT NULL DEFAULT(0.0),
  FechaCreacion DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
  CONSTRAINT FK_Medidor_Propiedad FOREIGN KEY (PropiedadID) REFERENCES Propiedad(PropiedadID)
);

CREATE TABLE MovimientoMedidor (
  MovimientoMedidorID INT IDENTITY(1,1) PRIMARY KEY,
  MedidorID INT NOT NULL,
  FechaOperacion DATE NOT NULL,
  TipoMovimientoID TINYINT NOT NULL,
  Valor DECIMAL(12,3) NOT NULL,
  Diferencia DECIMAL(12,3) NULL,
  Observaciones NVARCHAR(500) NULL,
  UsuarioRegistro NVARCHAR(100) NULL,
  CONSTRAINT FK_MM_Medidor FOREIGN KEY (MedidorID) REFERENCES Medidor(MedidorID),
  CONSTRAINT FK_MM_TipoMovimiento FOREIGN KEY (TipoMovimientoID) REFERENCES TipoMovimientoLecturaMedidor(TipoMovimientoID)
);

/* --------------------
   ConceptoCobro (CC) - IDs cargados desde XML (no identity)
   -------------------- */
CREATE TABLE ConceptoCobro (
  CCID INT PRIMARY KEY,
  Nombre NVARCHAR(200) NOT NULL,
  PeriodoMontoCCID TINYINT NOT NULL,
  TipoMontoCCID TINYINT NOT NULL,
  ValorMinimo DECIMAL(18,2) NULL,
  ValorMinimoM3 DECIMAL(12,3) NULL,
  ValorFijo DECIMAL(18,2) NULL,
  CostoM3 DECIMAL(18,2) NULL,
  ValorPorcentual DECIMAL(10,6) NULL,
  ValorM2Minimo DECIMAL(12,2) NULL,
  ValorTractosM2 DECIMAL(12,2) NULL,
  OtrosParametros NVARCHAR(MAX) NULL,
  CONSTRAINT FK_CC_Periodo FOREIGN KEY (PeriodoMontoCCID) REFERENCES PeriodoMontoCC(PeriodoMontoCCID),
  CONSTRAINT FK_CC_TipoMonto FOREIGN KEY (TipoMontoCCID) REFERENCES TipoMontoCC(TipoMontoCCID)
);

/* --------------------
   PropiedadCC (qué CC aplican a una propiedad)
   -------------------- */
CREATE TABLE PropiedadCC (
  PropiedadCCID INT IDENTITY(1,1) PRIMARY KEY,
  PropiedadID INT NOT NULL,
  CCID INT NOT NULL,
  FechaInicio DATE NOT NULL,
  FechaFin DATE NULL,
  Activo BIT NOT NULL DEFAULT(1),
  ConfiguracionLocal NVARCHAR(MAX) NULL,
  CONSTRAINT FK_PC_Propiedad FOREIGN KEY (PropiedadID) REFERENCES Propiedad(PropiedadID),
  CONSTRAINT FK_PC_CC FOREIGN KEY (CCID) REFERENCES ConceptoCobro(CCID)
);

/* --------------------
   Factura y FacturaDetalle
   -------------------- */
CREATE TABLE Factura (
  FacturaID INT IDENTITY(1,1) PRIMARY KEY,
  NumeroFactura BIGINT NOT NULL UNIQUE,
  PropiedadID INT NOT NULL,
  FechaEmision DATE NOT NULL,
  FechaVencimiento DATE NOT NULL,
  TotalAPagarOriginal DECIMAL(18,2) NOT NULL,
  TotalAPagarFinal DECIMAL(18,2) NOT NULL,
  EstadoID TINYINT NOT NULL DEFAULT(1),
  GeneradaPorProceso BIT NOT NULL DEFAULT(1),
  FechaPago DATETIME2 NULL,
  UsuarioPagoID INT NULL,
  CONSTRAINT FK_Factura_Propiedad FOREIGN KEY (PropiedadID) REFERENCES Propiedad(PropiedadID),
  CONSTRAINT FK_Factura_UsuarioPago FOREIGN KEY (UsuarioPagoID) REFERENCES Usuario(UsuarioID)
);

CREATE TABLE FacturaDetalle (
  FacturaDetalleID INT IDENTITY(1,1) PRIMARY KEY,
  FacturaID INT NOT NULL,
  CCID INT NOT NULL,
  Descripcion NVARCHAR(300) NULL,
  Monto DECIMAL(18,2) NOT NULL,
  Cantidad DECIMAL(12,3) NULL,
  ReferenciaID INT NULL,
  CONSTRAINT FK_FD_Factura FOREIGN KEY (FacturaID) REFERENCES Factura(FacturaID),
  CONSTRAINT FK_FD_CC FOREIGN KEY (CCID) REFERENCES ConceptoCobro(CCID)
);

/* --------------------
   Pago y Comprobante
   -------------------- */
CREATE TABLE Pago (
  PagoID INT IDENTITY(1,1) PRIMARY KEY,
  FacturaID INT NOT NULL,
  FechaPago DATETIME2 NOT NULL,
  MontoPagado DECIMAL(18,2) NOT NULL,
  TipoMedioPagoID TINYINT NOT NULL,
  NumeroReferenciaComprobantePago NVARCHAR(100) NULL,
  UsuarioRegistroID INT NULL,
  CONSTRAINT FK_Pago_Factura FOREIGN KEY (FacturaID) REFERENCES Factura(FacturaID),
  CONSTRAINT FK_Pago_TipoMedio FOREIGN KEY (TipoMedioPagoID) REFERENCES TipoMedioPago(TipoMedioPagoID),
  CONSTRAINT FK_Pago_UsuarioRegistro FOREIGN KEY (UsuarioRegistroID) REFERENCES Usuario(UsuarioID)
);

CREATE TABLE ComprobantePago (
  ComprobanteID INT IDENTITY(1,1) PRIMARY KEY,
  PagoID INT NOT NULL,
  CodigoComprobante NVARCHAR(100) NOT NULL UNIQUE,
  FechaEmision DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
  CONSTRAINT FK_CP_Pago FOREIGN KEY (PagoID) REFERENCES Pago(PagoID)
);

/* --------------------
   OrdenCorte y OrdenReconexión
   -------------------- */
CREATE TABLE OrdenCorte (
  OrdenCorteID INT IDENTITY(1,1) PRIMARY KEY,
  PropiedadID INT NOT NULL,
  FacturaID INT NOT NULL,
  FechaGeneracion DATE NOT NULL,
  EstadoID TINYINT NOT NULL DEFAULT(1),
  FechaCambioEstado DATE NULL,
  CONSTRAINT FK_OC_Propiedad FOREIGN KEY (PropiedadID) REFERENCES Propiedad(PropiedadID),
  CONSTRAINT FK_OC_Factura FOREIGN KEY (FacturaID) REFERENCES Factura(FacturaID)
);

CREATE TABLE OrdenReconexion (
  OrdenReconID INT IDENTITY(1,1) PRIMARY KEY,
  OrdenCorteID INT NOT NULL,
  FacturaID INT NOT NULL,
  FechaGeneracion DATE NOT NULL,
  UsuarioGeneraID INT NULL,
  CONSTRAINT FK_OR_OrdenCorte FOREIGN KEY (OrdenCorteID) REFERENCES OrdenCorte(OrdenCorteID),
  CONSTRAINT FK_OR_Factura FOREIGN KEY (FacturaID) REFERENCES Factura(FacturaID),
  CONSTRAINT FK_OR_Usuario FOREIGN KEY (UsuarioGeneraID) REFERENCES Usuario(UsuarioID)
);

/* --------------------
   ParametrosSistema
   -------------------- */
CREATE TABLE ParametrosSistema (
  ParametroClave NVARCHAR(100) PRIMARY KEY,
  ParametroValor NVARCHAR(200) NOT NULL,
  FechaActualizacion DATETIME2 NULL
);

/* --------------------
   Índices recomendados
   -------------------- */
CREATE INDEX IX_Factura_Propiedad_Estado_Vencimiento ON Factura(PropiedadID, EstadoID, FechaVencimiento);
CREATE INDEX IX_MovimientoMedidor_Medidor_Fecha ON MovimientoMedidor(MedidorID, FechaOperacion);
CREATE INDEX IX_PropiedadCC_Propiedad ON PropiedadCC(PropiedadID);
CREATE INDEX IX_Pago_Factura_Fecha ON Pago(FacturaID, FechaPago);

/* --------------------
   Trigger: al insertar Propiedad -> asignar CCs por defecto
   NOTA: Este trigger asume que los CC con IDs conocidos existen en ConceptoCobro
         (p.ej. CC Agua = 1, Impuesto = 2, Recoleccion=3, Mantenimiento=7)
   Ajusta los IDs según el XML de catálogos.
   -------------------- */
GO
CREATE OR ALTER TRIGGER TR_Propiedad_Insert
ON Propiedad
AFTER INSERT
AS
BEGIN
  SET NOCOUNT ON;
  -- Parche: usar tabla temporal de IDs por defecto (ajustar según catálogo real)
  DECLARE @CC_Agua INT = 1;
  DECLARE @CC_Impuesto INT = 2;
  DECLARE @CC_Recoleccion INT = 3;
  DECLARE @CC_Mantenimiento INT = 7;

  INSERT INTO PropiedadCC(PropiedadID, CCID, FechaInicio, Activo)
  SELECT p.PropiedadID, @CC_Agua, CAST(GETDATE() AS DATE), 1
  FROM inserted p;

  INSERT INTO PropiedadCC(PropiedadID, CCID, FechaInicio, Activo)
  SELECT p.PropiedadID, @CC_Impuesto, CAST(GETDATE() AS DATE), 1
  FROM inserted p;

  -- Recoleccion si TipoZonaPropiedad != agrícola (suponiendo id 2 = agricola)
  INSERT INTO PropiedadCC(PropiedadID, CCID, FechaInicio, Activo)
  SELECT p.PropiedadID, @CC_Recoleccion, CAST(GETDATE() AS DATE), 1
  FROM inserted p
  WHERE p.TipoZonaPropiedadID <> 2;

  -- Mantenimiento si TipoUso es residencial(1) o comercial(2)
  INSERT INTO PropiedadCC(PropiedadID, CCID, FechaInicio, Activo)
  SELECT p.PropiedadID, @CC_Mantenimiento, CAST(GETDATE() AS DATE), 1
  FROM inserted p
  WHERE p.TipoUsoPropiedadID IN (1,2);
END;
GO


INSERT INTO TipoUsoPropiedad(TipoUsoPropiedadID, Nombre) VALUES
(1,'Habitacion'),(2,'Comercial'),(3,'Industrial'),(4,'Lote Baldio'),(5,'Agricola');

INSERT INTO TipoZonaPropiedad(TipoZonaPropiedadID, Nombre) VALUES
(1,'Residencial'),(2,'Agricola'),(3,'Bosque'),(4,'Zona Industrial'),(5,'Zona Comercial');

INSERT INTO TipoUsuario(TipoUsuarioID, Nombre) VALUES
(1,'Administrador'),(2,'Propietario');

INSERT INTO TipoMovimientoLecturaMedidor(TipoMovimientoID, Nombre) VALUES
(1,'Lectura'),(2,'Ajuste Credito'),(3,'Ajuste Debito');

INSERT INTO PeriodoMontoCC(PeriodoMontoCCID, Nombre, QMeses) VALUES
(1,'Mensual',1),(2,'Trimestral',3),(4,'Semestral',6),(5,'Anual',12),(6,'Cobro Unico',1),(7,'Diario Intereses',30);

INSERT INTO TipoMontoCC(TipoMontoCCID, Nombre) VALUES
(1,'Monto Fijo'),(2,'Monto Variable'),(3,'Monto x Porcentaje');

INSERT INTO TipoMedioPago(TipoMedioPagoID, Nombre) VALUES
(1,'Efectivo'),(2,'Tarjeta');

INSERT INTO ConceptoCobro(CCID, Nombre, PeriodoMontoCCID, TipoMontoCCID, ValorMinimo, ValorMinimoM3, CostoM3, ValorPorcentual, ValorFijo, ValorM2Minimo, ValorTractosM2)
VALUES
(1,'ConsumoAgua',1,2,5000,30,1000,NULL,NULL,NULL,NULL),
(2,'ImpuestoPropiedad',5,3,NULL,NULL,NULL,0.01,NULL,NULL,NULL),
(3,'RecoleccionBasura',1,1,150,NULL,NULL,NULL,300,400,200),
(5,'Reconexion',6,1,NULL,NULL,NULL,NULL,30000,NULL,NULL),
(6,'InteresesMoratorios',7,3,NULL,NULL,NULL,0.04,NULL,NULL,NULL),
(7,'MantenimientoParques',1,1,NULL,NULL,NULL,NULL,10000,NULL,NULL);

GO

PRINT 'DDL creado. Revisa los IDs de ConceptoCobro y catálogos según tu XML de prueba antes de ejecutar procesos masivos.';
GO
