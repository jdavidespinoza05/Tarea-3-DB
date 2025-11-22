CREATE OR ALTER PROCEDURE SP_InsertarPropiedadesXML
    @XML XML
AS
BEGIN
    SET NOCOUNT ON;

    /* ============================================================
       1. Extraer nodos <Propiedad ... />
       ============================================================ */
    ;WITH X AS (
        SELECT
            P.value('@numeroFinca','VARCHAR(20)') AS NumeroFinca,
            P.value('@numeroMedidor','VARCHAR(20)') AS NumeroMedidor,
            P.value('@metrosCuadrados','DECIMAL(10,2)') AS MetrosCuadrados,
            P.value('@tipoUsoId','INT') AS TipoUsoId,
            P.value('@tipoZonaId','INT') AS TipoZonaId,
            P.value('@valorFiscal','DECIMAL(18,2)') AS ValorFiscal,
            P.value('@fechaRegistro','DATE') AS FechaRegistro
        FROM @XML.nodes('/Operaciones/FechaOperacion/Propiedades/Propiedad') AS T(P)
    )

    /* ============================================================
       2. Insertar Medidores si NO existen
       ============================================================ */
    INSERT INTO Medidor (NumeroMedidor, SaldoM3)
    SELECT NumeroMedidor, 0
    FROM X
    WHERE NumeroMedidor NOT IN (SELECT NumeroMedidor FROM Medidor);

    /* ============================================================
       3. Insertar Propiedades si NO existen
       ============================================================ */
    INSERT INTO Propiedad
        (NumeroFinca, MedidorId, MetrosCuadrados, TipoUsoId, TipoZonaId, 
         ValorFiscal, FechaRegistro, SaldoM3UltimaFactura)
    SELECT 
        X.NumeroFinca,
        M.MedidorId,
        X.MetrosCuadrados,
        X.TipoUsoId,
        X.TipoZonaId,
        X.ValorFiscal,
        X.FechaRegistro,
        0  -- inicio del ciclo de facturación
    FROM X
    INNER JOIN Medidor M ON M.NumeroMedidor = X.NumeroMedidor
    WHERE X.NumeroFinca NOT IN (SELECT NumeroFinca FROM Propiedad);

END;
GO
