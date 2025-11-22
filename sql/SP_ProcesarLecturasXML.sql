CREATE OR ALTER PROCEDURE SP_ProcesarLecturasXML
    @XML XML
AS
BEGIN
    SET NOCOUNT ON;

    /* ============================================================
       Extraer FechaOperacion + Lecturas
       ============================================================ */
    ;WITH X AS (
        SELECT
            FE.value('@fecha','DATE') AS FechaOperacion,
            L.value('@numeroMedidor','VARCHAR(20)') AS NumeroMedidor,
            L.value('@tipoMovimientoId','INT') AS TipoMovimientoId,
            L.value('@valor','DECIMAL(18,2)') AS Valor
        FROM @XML.nodes('/Operaciones/FechaOperacion') AS F(FE)
        CROSS APPLY FE.nodes('LecturasMedidor/Lectura') AS T(L)
    )

    /* ============================================================
       Procesar cada lectura
       ============================================================ */
    SELECT * INTO #Lecturas FROM X;  -- copiar a tabla temporal

    DECLARE @NumeroMedidor VARCHAR(20),
            @TipoMovimientoId INT,
            @Valor DECIMAL(18,2),
            @FechaOperacion DATE,
            @MedidorId INT,
            @SaldoActual DECIMAL(18,2),
            @MontoMovimiento DECIMAL(18,2);

    DECLARE C CURSOR FOR
        SELECT NumeroMedidor, TipoMovimientoId, Valor, FechaOperacion
        FROM #Lecturas;

    OPEN C;
    FETCH NEXT FROM C INTO @NumeroMedidor, @TipoMovimientoId, @Valor, @FechaOperacion;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT @MedidorId = MedidorId, 
               @SaldoActual = SaldoM3 
        FROM Medidor 
        WHERE NumeroMedidor = @NumeroMedidor;

        /* ========================================================
           Caso 1: Lectura (TipoMovimientoId = 1)
           ======================================================== */
        IF @TipoMovimientoId = 1
        BEGIN
            SET @MontoMovimiento = @Valor - @SaldoActual; -- diferencia m3

            INSERT INTO MovimientoMedidor (MedidorId, TipoMovimientoId, FechaOperacion, Valor)
            VALUES (@MedidorId, 1, @FechaOperacion, @MontoMovimiento);

            -- Actualizar saldo del medidor
            UPDATE Medidor
            SET SaldoM3 = @Valor
            WHERE MedidorId = @MedidorId;
        END

        /* ========================================================
           Caso 2: Ajuste Crédito (TipoMovimientoId = 2)
           ======================================================== */
        ELSE IF @TipoMovimientoId = 2
        BEGIN
            SET @MontoMovimiento = -@Valor;

            INSERT INTO MovimientoMedidor (MedidorId, TipoMovimientoId, FechaOperacion, Valor)
            VALUES (@MedidorId, 2, @FechaOperacion, @MontoMovimiento);

            UPDATE Medidor
            SET SaldoM3 = SaldoM3 - @Valor
            WHERE MedidorId = @MedidorId;
        END

        /* ========================================================
           Caso 3: Ajuste Débito (TipoMovimientoId = 3)
           ======================================================== */
        ELSE IF @TipoMovimientoId = 3
        BEGIN
            SET @MontoMovimiento = @Valor;

            INSERT INTO MovimientoMedidor (MedidorId, TipoMovimientoId, FechaOperacion, Valor)
            VALUES (@MedidorId, 3, @FechaOperacion, @MontoMovimiento);

            UPDATE Medidor
            SET SaldoM3 = SaldoM3 + @Valor
            WHERE MedidorId = @MedidorId;
        END

        FETCH NEXT FROM C INTO @NumeroMedidor, @TipoMovimientoId, @Valor, @FechaOperacion;
    END

    CLOSE C;
    DEALLOCATE C;

    DROP TABLE #Lecturas;
END;
GO
