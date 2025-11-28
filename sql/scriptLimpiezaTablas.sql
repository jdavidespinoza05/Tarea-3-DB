USE Tarea3;
GO

BEGIN TRY
    BEGIN TRAN;

    ---------------------------------------------------------
    -- 1. Tablas más dependientes (hijas de Pago / Factura / Propiedad)
    ---------------------------------------------------------

    -- Ordenes de reconexión
    IF OBJECT_ID('dbo.OrdenReconexion','U') IS NOT NULL
        DELETE FROM dbo.OrdenReconexion;

    -- Ordenes de corte
    IF OBJECT_ID('dbo.OrdenCorte','U') IS NOT NULL
        DELETE FROM dbo.OrdenCorte;

    -- Comprobantes de pago
    IF OBJECT_ID('dbo.ComprobantePago','U') IS NOT NULL
        DELETE FROM dbo.ComprobantePago;

    -- Pagos
    IF OBJECT_ID('dbo.Pago','U') IS NOT NULL
        DELETE FROM dbo.Pago;

    -- Detalle de factura
    IF OBJECT_ID('dbo.FacturaDetalle','U') IS NOT NULL
        DELETE FROM dbo.FacturaDetalle;

    -- Facturas
    IF OBJECT_ID('dbo.Factura','U') IS NOT NULL
        DELETE FROM dbo.Factura;

    ---------------------------------------------------------
    -- 2. Movimientos y relaciones varias
    ---------------------------------------------------------

    -- Movimientos de medidor
    IF OBJECT_ID('dbo.MovimientoMedidor','U') IS NOT NULL
        DELETE FROM dbo.MovimientoMedidor;

    -- Tabla vieja PropiedadPersona (la que te dio el error de FK)
    IF OBJECT_ID('dbo.PropiedadPersona','U') IS NOT NULL
        DELETE FROM dbo.PropiedadPersona;

    -- PropiedadPropietario (la nueva)
    IF OBJECT_ID('dbo.PropiedadPropietario','U') IS NOT NULL
        DELETE FROM dbo.PropiedadPersona;

    -- PropiedadCC
    IF OBJECT_ID('dbo.PropiedadCC','U') IS NOT NULL
        DELETE FROM dbo.PropiedadCC;


    ---------------------------------------------------------
    -- 4. Entidades base del XML: Propiedad y Persona
    ---------------------------------------------------------

    -- Propiedad (hija de Medidor, pero no tocamos Medidor)
    IF OBJECT_ID('dbo.Propiedad','U') IS NOT NULL
        DELETE FROM dbo.Propiedad;

    -- Persona
    IF OBJECT_ID('dbo.Persona','U') IS NOT NULL
        DELETE FROM dbo.Persona;

    ---------------------------------------------------------
    -- IMPORTANTE:
    -- No tocamos:
    --   - XML_Input
    --   - Medidor
    --   - ConceptoCobro
    --   - PeriodoMontoCC
    --   - ParametrosSistema
    --   - Tipo* (TipoUsoPropiedad, TipoZonaPropiedad, etc.)
    ---------------------------------------------------------

    COMMIT TRAN;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRAN;
    THROW;
END CATCH;
GO
