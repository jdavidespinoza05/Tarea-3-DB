CREATE OR ALTER PROCEDURE SP_InsertarCCPropiedadXML
    @XML XML
AS
BEGIN
    SET NOCOUNT ON;

    /* ============================================================
       Extraer FechaOperacion + Movimientos CCPropiedad
       ============================================================ */
    ;WITH X AS (
        SELECT
            FE.value('@fecha','DATE') AS FechaOperacion,
            M.value('@numeroFinca','VARCHAR(20)') AS NumeroFinca,
            M.value('@idCC','INT') AS CCId,
            M.value('@tipoAsociacionId','INT') AS TipoAsociacionId
        FROM @XML.nodes('/Operaciones/FechaOperacion') AS F(FE)
        CROSS APPLY FE.nodes('CCPropiedad/Movimiento') AS T(M)
    )

    /* ============================================================
       INSERTAR CC (tipoAsociacionId = 1)
       ============================================================ */
    INSERT INTO PropiedadCC (PropiedadId, CCId, Activo, FechaInicio, FechaFin)
    SELECT
        P.PropiedadId,
        X.CCId,
        1,                         -- Activo
        X.FechaOperacion,
        NULL
    FROM X
    INNER JOIN Propiedad P ON P.NumeroFinca = X.NumeroFinca
    WHERE X.TipoAsociacionId = 1
      AND NOT EXISTS (
            SELECT 1
            FROM PropiedadCC PC
            WHERE PC.PropiedadId = P.PropiedadId
              AND PC.CCId = X.CCId
              AND PC.FechaFin IS NULL
      );

    /* ============================================================
       DESASOCIAR CC (tipoAsociacionId = 2)
       ============================================================ */
    UPDATE PC
    SET FechaFin = X.FechaOperacion,
        Activo = 0
    FROM PropiedadCC PC
    INNER JOIN X 
        ON X.TipoAsociacionId = 2
       AND PC.CCId = X.CCId
    INNER JOIN Propiedad P 
        ON P.PropiedadId = PC.PropiedadId
       AND P.NumeroFinca = X.NumeroFinca
    WHERE PC.FechaFin IS NULL;  -- solo cerrar activos

END;
GO
