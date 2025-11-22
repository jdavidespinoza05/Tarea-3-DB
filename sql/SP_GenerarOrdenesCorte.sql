CREATE OR ALTER PROCEDURE SP_GenerarOrdenesCorte
    @FechaOperacion DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @CCAguaId INT = 1;             -- Ajustalo si el CC de Agua no es 1
    DECLARE @CCReconexionId INT = 5;       -- Ajustalo si el CC de Reconexión no es 5

    /* ============================================================
       1. Propiedades con CC de AGUA activo
       ============================================================ */
    ;WITH PropsAgua AS (
        SELECT PropiedadId
        FROM PropiedadCC
        WHERE CCId = @CCAguaId
          AND FechaFin IS NULL
    ),

    /* ============================================================
       2. Facturas vencidas para esas propiedades
       ============================================================ */
    FacturasVencidas AS (
        SELECT F.FacturaId, F.PropiedadId, F.FechaLimitePago, F.FechaLimiteCorte,
               F.TotalAPagarFinal
        FROM Factura F
        INNER JOIN PropsAgua PA ON PA.PropiedadId = F.PropiedadId
        WHERE F.Estado = 1
          AND @FechaOperacion > F.FechaLimiteCorte
    ),

    /* ============================================================
       3. Propiedades que NO tienen orden de corte activa
       ============================================================ */
    PropsSinCorte AS (
        SELECT FV.*
        FROM FacturasVencidas FV
        WHERE NOT EXISTS (
            SELECT 1
            FROM OrdenCorte OC
            WHERE OC.PropiedadId = FV.PropiedadId
              AND OC.Estado = 1     -- corte pendiente
        )
    )

    /* ============================================================
       4. Generar ORDEN DE CORTE + COBRO DE RECONEXIÓN
       ============================================================ */
    SELECT *
    INTO #Pendientes
    FROM PropsSinCorte;

    DECLARE 
        @PropiedadId INT,
        @FacturaId INT,
        @ValorReconex DECIMAL(18,2);

    SELECT @ValorReconex = ValorFijo
    FROM ConceptoCobro
    WHERE CCId = @CCReconexionId;

    DECLARE C CURSOR FOR
        SELECT PropiedadId, FacturaId
        FROM #Pendientes;

    OPEN C;
    FETCH NEXT FROM C INTO @PropiedadId, @FacturaId;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        /* Crear la orden */
        INSERT INTO OrdenCorte (PropiedadId, FacturaId, FechaOrden, Estado)
        VALUES (@PropiedadId, @FacturaId, @FechaOperacion, 1);

        /* Insertar CC de reconexión */
        INSERT INTO FacturaDetalle (FacturaId, CCId, Monto)
        VALUES (@FacturaId, @CCReconexionId, @ValorReconex);

        /* Aumentar total de la factura */
        UPDATE Factura
        SET TotalAPagarFinal = TotalAPagarFinal + @ValorReconex
        WHERE FacturaId = @FacturaId;

        FETCH NEXT FROM C INTO @PropiedadId, @FacturaId;
    END

    CLOSE C;
    DEALLOCATE C;

    DROP TABLE #Pendientes;

END;
GO
