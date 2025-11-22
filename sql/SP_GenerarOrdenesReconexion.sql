CREATE OR ALTER PROCEDURE SP_GenerarOrdenesReconexion
    @FechaOperacion DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    /* ============================================================
       Candidatos a reconexión:
       - OrdenCorte con Estado = 1 (pendiente)
       - La factura asociada está pagada (Estado = 2)
       - No hay otra factura pendiente vencida para esa propiedad
       - Aún no existe OrdenReconexion para esa OrdenCorte
       ============================================================ */
    ;WITH Candidatos AS (
        SELECT 
            OC.OrdenCorteId,
            OC.PropiedadId,
            OC.FacturaId
        FROM OrdenCorte OC
        INNER JOIN Factura F ON F.FacturaId = OC.FacturaId
        WHERE OC.Estado = 1              -- corte pendiente
          AND F.Estado = 2               -- factura ya pagada
          AND NOT EXISTS (               -- aún no tiene orden de reconexión
                SELECT 1
                FROM OrdenReconexion ORC
                WHERE ORC.OrdenCorteId = OC.OrdenCorteId
          )
          AND NOT EXISTS (               -- NO hay otras facturas vencidas pendientes
                SELECT 1
                FROM Factura F2
                WHERE F2.PropiedadId = OC.PropiedadId
                  AND F2.Estado = 1      -- pendiente
                  AND F2.FechaLimitePago < @FechaOperacion  -- ya vencida
          )
    )
    SELECT * INTO #Candidatos FROM Candidatos;

    DECLARE 
        @OrdenCorteId INT;

    DECLARE C CURSOR FOR
        SELECT OrdenCorteId FROM #Candidatos;

    OPEN C;
    FETCH NEXT FROM C INTO @OrdenCorteId;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        /* Crear orden de reconexión */
        INSERT INTO OrdenReconexion (OrdenCorteId, FechaReconexion)
        VALUES (@OrdenCorteId, @FechaOperacion);

        /* Marcar la orden de corte como reconectada (estado 2) */
        UPDATE OrdenCorte
        SET Estado = 2
        WHERE OrdenCorteId = @OrdenCorteId;

        FETCH NEXT FROM C INTO @OrdenCorteId;
    END

    CLOSE C;
    DEALLOCATE C;

    DROP TABLE #Candidatos;
END;
GO
