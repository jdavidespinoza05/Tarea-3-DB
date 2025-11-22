CREATE OR ALTER PROCEDURE SP_ProcesarXMLCompleto
    @XML XML
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    /* ============================================================
       1. Extraer todas las fechas de operación en orden
       ============================================================ */
    ;WITH Fechas AS (
        SELECT
            FE.value('@fecha','DATE') AS FechaOperacion,
            FE.query('.') AS NodoFecha
        FROM @XML.nodes('/Operaciones/FechaOperacion') AS F(FE)
    )
    SELECT * INTO #Fechas FROM Fechas ORDER BY FechaOperacion;

    DECLARE 
        @FechaOperacion DATE,
        @Nodo XML;

    DECLARE C CURSOR FOR
        SELECT FechaOperacion, NodoFecha
        FROM #Fechas
        ORDER BY FechaOperacion;

    OPEN C;
    FETCH NEXT FROM C INTO @FechaOperacion, @Nodo;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        PRINT 'Procesando FechaOperacion: ' + CONVERT(VARCHAR, @FechaOperacion);

        /* ========================================================
           2. Procesar entidades según orden lógico
           ======================================================== */

        EXEC SP_InsertarPersonasXML @XML = @Nodo;
        EXEC SP_InsertarPropiedadesXML @XML = @Nodo;
        EXEC SP_InsertarPropiedadPersonaXML @XML = @Nodo;
        EXEC SP_InsertarCCPropiedadXML @XML = @Nodo;
        EXEC SP_ProcesarLecturasXML @XML = @Nodo;
        EXEC SP_ProcesarPagosXML @XML = @Nodo;
        EXEC SP_ProcesarPropiedadCambioXML @XML = @Nodo;

        /* ========================================================
           3. Procesos masivos del día
           ======================================================== */
        EXEC SP_GenerarFacturas @FechaOperacion = @FechaOperacion;
        EXEC SP_GenerarOrdenesCorte @FechaOperacion = @FechaOperacion;
        EXEC SP_GenerarOrdenesReconexion @FechaOperacion = @FechaOperacion;

        PRINT '--- Procesado completo del día ' + CONVERT(VARCHAR, @FechaOperacion) + ' ---';
        PRINT ' ';

        FETCH NEXT FROM C INTO @FechaOperacion, @Nodo;
    END

    CLOSE C;
    DEALLOCATE C;

    DROP TABLE #Fechas;
END;
GO
