CREATE OR ALTER PROCEDURE SP_InsertarPropiedadPersonaXML
    @XML XML
AS
BEGIN
    SET NOCOUNT ON;

    /* ============================================================
       Extraer FechaOperacion + Movimiento de <PropiedadPersona>
       ============================================================ */
    ;WITH X AS (
        SELECT
            F.value('@fecha','DATE') AS FechaOperacion,
            M.value('@valorDocumento','VARCHAR(20)') AS ValorDocumento,
            M.value('@numeroFinca','VARCHAR(20)') AS NumeroFinca,
            M.value('@tipoAsociacionId','INT') AS TipoAsociacionId
        FROM @XML.nodes('/Operaciones/FechaOperacion') AS A(FE)
        CROSS APPLY FE.nodes('PropiedadPersona/Movimiento') AS T(M)
        CROSS APPLY (SELECT FE.value('@fecha','DATE') AS FechaOp) AS F
        CROSS APPLY (SELECT FechaOp) AS F1
    )

    /* ============================================================
       ASOCIAR PERSONA → PROPIEDAD (tipoAsociacionId = 1)
       ============================================================ */
    INSERT INTO PropiedadPropietario (PropiedadId, PersonaId, FechaInicio, FechaFin)
    SELECT 
        P.PropiedadId,
        Pe.PersonaId,
        X.FechaOperacion,
        NULL
    FROM X
    INNER JOIN Persona Pe ON Pe.ValorDocumento = X.ValorDocumento
    INNER JOIN Propiedad P ON P.NumeroFinca = X.NumeroFinca
    WHERE X.TipoAsociacionId = 1
      AND NOT EXISTS (
            SELECT 1
            FROM PropiedadPropietario PP
            WHERE PP.PropiedadId = P.PropiedadId
              AND PP.PersonaId = Pe.PersonaId
              AND PP.FechaFin IS NULL
      );

    /* ============================================================
       DESASOCIAR PERSONA (tipoAsociacionId = 2)
       ============================================================ */
    UPDATE PP
    SET FechaFin = X.FechaOperacion
    FROM PropiedadPropietario PP
    INNER JOIN X ON 1 = 1
    INNER JOIN Persona Pe ON Pe.ValorDocumento = X.ValorDocumento
    INNER JOIN Propiedad P ON P.NumeroFinca = X.NumeroFinca
    WHERE X.TipoAsociacionId = 2
      AND PP.PersonaId = Pe.PersonaId
      AND PP.PropiedadId = P.PropiedadId
      AND PP.FechaFin IS NULL;

END;
GO
