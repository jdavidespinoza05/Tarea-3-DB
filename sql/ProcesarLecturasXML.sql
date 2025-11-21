/* ============================================================
   SP: Procesar Lecturas desde XML
   Autor: ChatGPT
   Descripción:
     - Procesa nodos <LecturaMedidor ... />
     - Valida existencia del medidor
     - Calcula diferencias segun el tipo de movimiento:
            1 = Nueva lectura (normal)
            2 = Rebaja de lectura
            3 = Lectura extraordinaria / ajuste hacia arriba
     - Inserta MovimientoMedidor
     - Actualiza SaldoM3 en Medidor y Propiedad
   ============================================================ */

USE Tarea3;
GO
CREATE OR ALTER PROCEDURE SP_ProcesarLecturasXML
    @XmlLecturas XML,
    @FechaOperacion DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRAN;

        /* Extraer los nodos <LecturaMedidor> */
        ;WITH Lecturas AS (
            SELECT
                L.value('@NumeroMedidor','VARCHAR(50)') AS NumeroMedidor,
                L.value('@TipoMovimiento','TINYINT') AS TipoMovimiento,
                L.value('@Valor','DECIMAL(12,3)') AS Valor
            FROM @XmlLecturas.nodes('/FechaOperacion/LecturaMedidor') AS T(L)
        )
        SELECT * INTO #LecturasTMP FROM Lecturas;


        /* Variables */
        DECLARE 
            @MedidorID INT,
            @NumeroMed VARCHAR(50),
            @SaldoActual DECIMAL(12,3),
            @Valor DECIMAL(12,3),
            @TipoMov TINYINT,
            @Diff DECIMAL(12,3);


        /* Cursor para recorrer cada lectura */
        DECLARE c CURSOR FOR
            SELECT NumeroMedidor, TipoMovimiento, Valor
            FROM #LecturasTMP;

        OPEN c;
        FETCH NEXT FROM c INTO @NumeroMed, @TipoMov, @Valor;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            /* Verificar existencia del medidor */
            SELECT 
                @MedidorID = MedidorID,
                @SaldoActual = SaldoM3
            FROM Medidor
            WHERE NumeroMedidor = @NumeroMed;

            IF @MedidorID IS NULL
            BEGIN
                RAISERROR('No existe el medidor %s.', 16, 1, @NumeroMed);
                RETURN;
            END


            /* =====================================================
               TipoMovimiento 1: Nueva lectura normal
               ===================================================== */
            IF @TipoMov = 1
            BEGIN
                SET @Diff = @Valor - @SaldoActual;

                IF @Diff < 0
                    RAISERROR('Lectura menor a la lectura anterior para medidor %s.', 16, 1, @NumeroMed);

                INSERT INTO MovimientoMedidor(MedidorID, FechaOperacion, TipoMovimientoID, Valor, Diferencia)
                VALUES(@MedidorID, @FechaOperacion, @TipoMov, @Valor, @Diff);

                UPDATE Medidor
                   SET SaldoM3 = @Valor
                 WHERE MedidorID = @MedidorID;

                UPDATE Propiedad
                   SET SaldoM3 = @Valor
                 WHERE PropiedadID = (SELECT PropiedadID FROM Medidor WHERE MedidorID = @MedidorID);
            END


            /* =====================================================
               TipoMovimiento 2: Rebaja (ajuste negativo)
               ===================================================== */
            ELSE IF @TipoMov = 2
            BEGIN
                SET @Diff = -@Valor;

                INSERT INTO MovimientoMedidor(MedidorID, FechaOperacion, TipoMovimientoID, Valor, Diferencia)
                VALUES(@MedidorID, @FechaOperacion, @TipoMov, @Diff, @Diff);

                UPDATE Medidor
                   SET SaldoM3 = SaldoM3 + @Diff
                 WHERE MedidorID = @MedidorID;

                UPDATE Propiedad
                   SET SaldoM3 = SaldoM3 + @Diff
                 WHERE PropiedadID = (SELECT PropiedadID FROM Medidor WHERE MedidorID = @MedidorID);
            END


            /* =====================================================
               TipoMovimiento 3: Ajuste extraordinario (positivo)
               ===================================================== */
            ELSE IF @TipoMov = 3
            BEGIN
                SET @Diff = @Valor;

                INSERT INTO MovimientoMedidor(MedidorID, FechaOperacion, TipoMovimientoID, Valor, Diferencia)
                VALUES(@MedidorID, @FechaOperacion, @TipoMov, @Diff, @Diff);

                UPDATE Medidor
                   SET SaldoM3 = SaldoM3 + @Diff
                 WHERE MedidorID = @MedidorID;

                UPDATE Propiedad
                   SET SaldoM3 = SaldoM3 + @Diff
                 WHERE PropiedadID = (SELECT PropiedadID FROM Medidor WHERE MedidorID = @MedidorID);
            END


            FETCH NEXT FROM c INTO @NumeroMed, @TipoMov, @Valor;
        END

        CLOSE c;
        DEALLOCATE c;

        DROP TABLE #LecturasTMP;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 
            ROLLBACK;

        DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@Err, 16, 1);
    END CATCH;
END;
GO
