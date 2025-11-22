CREATE OR ALTER PROCEDURE SP_ProcesarPropiedadCambioXML
    @XML XML
AS
BEGIN
    SET NOCOUNT ON;

    /* ============================================================
       Extraer FechaOperacion + Cambios de propiedad
       ============================================================ */
    ;WITH X AS (
        SELECT
            FE.value('@fecha','DATE') AS FechaOperacion,
            C.value('@numeroFinca','VARCHAR(20)') AS NumeroFinca,
            C.value('@nuevoValor','DECIMAL(18,2)') AS NuevoValor
        FROM @XML.nodes('/Operaciones/FechaOperacion') AS F(FE)
        CROSS APPLY FE.nodes('PropiedadCambio/Cambio') AS T(C)
    )

    /* ============================================================
       Aplicar cambios al valor fiscal
       ============================================================ */
    UPDATE P
    SET ValorFiscal = X.NuevoValor
    FROM Propiedad P
    INNER JOIN X ON X.NumeroFinca = P.NumeroFinca;

END;
GO
