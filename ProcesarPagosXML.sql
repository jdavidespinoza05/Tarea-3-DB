/* ============================================================
   SP: Procesar Pagos desde XML
   Autor: ChatGPT
   Descripción:
     - Procesa nodos <Pago ... />
     - Identifica factura pendiente más vieja
     - Calcula intereses moratorios si aplica
     - Actualiza factura, detalle, total final
     - Registra pago y comprobante
     - Genera orden de reconexión si corresponde
   ============================================================ */

USE Tarea3;
GO
CREATE OR ALTER PROCEDURE SP_ProcesarPagosXML
    @XmlPagos XML,
    @FechaOperacion DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRAN;

        /* Extraer nodos <Pago> del XML */
        ;WITH Pagos AS (
            SELECT
                P.value('@NumeroFinca','VARCHAR(50)') AS NumeroFinca,
                P.value('@TipoMedioPago','TINYINT') AS TipoMedioPago,
                P.value('@NumeroReferenciaComprobantePago','NVARCHAR(100)') AS NumRef
            FROM @XmlPagos.nodes('/FechaOperacion/Pago') AS t(P)
        )
        SELECT * INTO #PagosTmp FROM Pagos;


        /* Variables */
        DECLARE 
            @NumeroFinca VARCHAR(50),
            @TipoMedioPago TINYINT,
            @NumRef NVARCHAR(100),
            @PropiedadID INT,
            @FacturaID INT,
            @FechaVenc DATE,
            @TotalOriginal DECIMAL(18,2),
            @TotalFinal DECIMAL(18,2),
            @DiasMora INT,
            @Intereses DECIMAL(18,2),
            @MontoAPagar DECIMAL(18,2);

        /* Parámetros del sistema */
        DECLARE 
            @DiasIntereses INT = 30,   -- base de cálculo
            @TasaInteres DECIMAL(10,4) = 0.04;  -- 4% mensual

        /* Cursor para procesar cada pago */
        DECLARE c CURSOR FOR
            SELECT NumeroFinca, TipoMedioPago, NumRef
            FROM #PagosTmp;

        OPEN c;
        FETCH NEXT FROM c INTO @NumeroFinca, @TipoMedioPago, @NumRef;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            /* 1. Ubicar la propiedad */
            SELECT @PropiedadID = PropiedadID
            FROM Propiedad
            WHERE NumeroFinca = @NumeroFinca;

            IF @PropiedadID IS NULL
            BEGIN
                RAISERROR('No existe propiedad con Número de Finca %s', 16, 1, @NumeroFinca);
                RETURN;
            END


            /* 2. Seleccionar la factura pendiente más vieja */
            SELECT TOP 1
                @FacturaID = FacturaID,
                @FechaVenc = FechaVencimiento,
                @TotalOriginal = TotalAPagarOriginal,
                @TotalFinal = TotalAPagarFinal
            FROM Factura
            WHERE PropiedadID = @PropiedadID
              AND EstadoID = 1  -- Pendiente
            ORDER BY FechaVencimiento ASC, FacturaID ASC;

            IF @FacturaID IS NULL
            BEGIN
                RAISERROR('No hay facturas pendientes para finca %s', 16, 1, @NumeroFinca);
                FETCH NEXT FROM c INTO @NumeroFinca, @TipoMedioPago, @NumRef;
                CONTINUE;
            END


            /* 3. Calcular si hay mora */
            SET @DiasMora = DATEDIFF(DAY, @FechaVenc, @FechaOperacion);

            IF @DiasMora < 0 SET @DiasMora = 0;

            SET @Intereses = 0;

            IF @DiasMora > 0
            BEGIN
                -- fórmula: TotalOriginal * 0.04 / 30 * diasMora
                SET @Intereses = (@TotalOriginal * @TasaInteres / @DiasIntereses) * @DiasMora;

                -- Insertar detalle por intereses
                INSERT INTO FacturaDetalle(FacturaID, CCID, Descripcion, Monto, Cantidad)
                VALUES(@FacturaID, 6, 'Intereses Moratorios', @Intereses, @DiasMora);

                -- Actualizar total final
                UPDATE Factura
                SET TotalAPagarFinal = TotalAPagarFinal + @Intereses
                WHERE FacturaID = @FacturaID;
            END


            /* 4. Registrar el pago */
            SET @MontoAPagar = (SELECT TotalAPagarFinal FROM Factura WHERE FacturaID = @FacturaID);

            INSERT INTO Pago(FacturaID, FechaPago, MontoPagado, TipoMedioPagoID, NumeroReferenciaComprobantePago)
            VALUES(@FacturaID, @FechaOperacion, @MontoAPagar, @TipoMedioPago, @NumRef);

            DECLARE @PagoID INT = SCOPE_IDENTITY();


            /* 5. Crear comprobante */
            INSERT INTO ComprobantePago(PagoID, CodigoComprobante)
            VALUES(@PagoID, CONCAT('CP-', @FacturaID, '-', @PagoID, '-', FORMAT(@FechaOperacion,'yyyyMMdd')));


            /* 6. Cambiar estado de factura */
            UPDATE Factura
            SET EstadoID = 2,  -- Pagado Normal
                FechaPago = @FechaOperacion,
                UsuarioPagoID = NULL  -- pagos XML no tienen usuario del portal
            WHERE FacturaID = @FacturaID;


            /* 7. Verificar si existía orden de corte → generar reconexión */
            IF EXISTS(
                SELECT 1 FROM OrdenCorte
                WHERE PropiedadID = @PropiedadID
                  AND FacturaID = @FacturaID
                  AND EstadoID = 1  -- pendiente
            )
            BEGIN
                /* Crear orden de reconexión */
                INSERT INTO OrdenReconexion(OrdenCorteID, FacturaID, FechaGeneracion)
                SELECT OrdenCorteID, @FacturaID, @FechaOperacion
                FROM OrdenCorte
                WHERE PropiedadID = @PropiedadID
                  AND FacturaID = @FacturaID
                  AND EstadoID = 1;

                /* Cambiar orden de corte a pagada */
                UPDATE OrdenCorte
                SET EstadoID = 2, FechaCambioEstado = @FechaOperacion
                WHERE PropiedadID = @PropiedadID
                  AND FacturaID = @FacturaID;
            END


            FETCH NEXT FROM c INTO @NumeroFinca, @TipoMedioPago, @NumRef;
        END

        CLOSE c;
        DEALLOCATE c;
        DROP TABLE #PagosTmp;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;

        DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@Err, 16, 1);
    END CATCH;
END;
GO
