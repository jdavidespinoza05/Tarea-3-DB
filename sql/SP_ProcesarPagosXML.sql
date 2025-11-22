CREATE OR ALTER PROCEDURE SP_ProcesarPagosXML
    @XML XML
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRAN;

        /* ============================================================
           1. Extraer pagos del XML
              <FechaOperacion fecha="...">
                <Pagos>
                  <Pago numeroFinca="F-0003" tipoMedioPagoId="1" numeroReferencia="..."/>
                </Pagos>
              </FechaOperacion>
           ============================================================ */
        ;WITH X AS (
            SELECT
                FE.value('@fecha','DATE') AS FechaOperacion,
                P.value('@numeroFinca','VARCHAR(20)') AS NumeroFinca,
                P.value('@tipoMedioPagoId','INT') AS TipoMedioPagoId,
                P.value('@numeroReferencia','VARCHAR(50)') AS NumeroReferencia
            FROM @XML.nodes('/Operaciones/FechaOperacion') AS F(FE)
            CROSS APPLY FE.nodes('Pagos/Pago') AS T(P)
        )
        SELECT * INTO #Pagos FROM X;

        /* ============================================================
           2. Obtener el CC de intereses moratorios desde parámetros
           ============================================================ */
        DECLARE @CCInteresMoratorio INT;
        SELECT @CCInteresMoratorio = ValorInt
        FROM ParametrosSistema
        WHERE Nombre = 'IdCCInteresMoratorio';

        /* ============================================================
           3. Variables para iterar pagos
           ============================================================ */
        DECLARE 
            @FechaOperacion DATE,
            @NumeroFinca VARCHAR(20),
            @TipoMedioPagoId INT,
            @NumeroReferencia VARCHAR(50),

            @PropiedadId INT,
            @FacturaId INT,
            @FechaLimitePago DATE,
            @TotalAPagarFinal DECIMAL(18,2),
            @DiasMora INT,
            @Interes DECIMAL(18,4),

            @PagoId INT;

        DECLARE C CURSOR FOR
            SELECT FechaOperacion, NumeroFinca, TipoMedioPagoId, NumeroReferencia
            FROM #Pagos;

        OPEN C;
        FETCH NEXT FROM C INTO @FechaOperacion, @NumeroFinca, @TipoMedioPagoId, @NumeroReferencia;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            /* --------------------------------------------------------
               3.1 Evitar reprocesar pagos ya aplicados (por referencia)
               -------------------------------------------------------- */
            IF EXISTS (SELECT 1 FROM Pago WHERE NumeroReferencia = @NumeroReferencia)
            BEGIN
                FETCH NEXT FROM C INTO @FechaOperacion, @NumeroFinca, @TipoMedioPagoId, @NumeroReferencia;
                CONTINUE;
            END

            /* --------------------------------------------------------
               3.2 Obtener Propiedad
               -------------------------------------------------------- */
            SELECT @PropiedadId = PropiedadId
            FROM Propiedad
            WHERE NumeroFinca = @NumeroFinca;

            IF @PropiedadId IS NULL
            BEGIN
                -- Propiedad no encontrada, ignorar este pago
                FETCH NEXT FROM C INTO @FechaOperacion, @NumeroFinca, @TipoMedioPagoId, @NumeroReferencia;
                CONTINUE;
            END

            /* --------------------------------------------------------
               3.3 Obtener factura pendiente más vieja de esa propiedad
               -------------------------------------------------------- */
            SELECT TOP 1 
                @FacturaId = FacturaId,
                @FechaLimitePago = FechaLimitePago,
                @TotalAPagarFinal = TotalAPagarFinal
            FROM Factura
            WHERE PropiedadId = @PropiedadId
              AND Estado = 1          -- pendiente
            ORDER BY FechaLimitePago, FacturaId;

            IF @FacturaId IS NULL
            BEGIN
                -- No hay facturas pendientes para esa finca
                FETCH NEXT FROM C INTO @FechaOperacion, @NumeroFinca, @TipoMedioPagoId, @NumeroReferencia;
                CONTINUE;
            END

            /* --------------------------------------------------------
               3.4 Calcular intereses moratorios si factura está vencida
               -------------------------------------------------------- */
            SET @DiasMora = DATEDIFF(DAY, @FechaLimitePago, @FechaOperacion);

            IF @DiasMora > 0 AND @CCInteresMoratorio IS NOT NULL
            BEGIN
                -- 4% mensual / 30 * días de mora * total actual de la factura
                SET @Interes = @TotalAPagarFinal * 0.04 / 30.0 * @DiasMora;

                IF @Interes > 0
                BEGIN
                    INSERT INTO FacturaDetalle (FacturaId, CCId, Monto)
                    VALUES (@FacturaId, @CCInteresMoratorio, @Interes);

                    UPDATE Factura
                    SET TotalAPagarFinal = TotalAPagarFinal + @Interes
                    WHERE FacturaId = @FacturaId;

                    -- refrescar total final para usarlo como monto pagado
                    SELECT @TotalAPagarFinal = TotalAPagarFinal
                    FROM Factura
                    WHERE FacturaId = @FacturaId;
                END
            END

            /* --------------------------------------------------------
               3.5 Registrar el pago (asumimos pago total)
               -------------------------------------------------------- */
            INSERT INTO Pago (FacturaId, FechaPago, TipoMedioPagoId, NumeroReferencia, MontoPagado)
            VALUES (@FacturaId, @FechaOperacion, @TipoMedioPagoId, @NumeroReferencia, @TotalAPagarFinal);

            SET @PagoId = SCOPE_IDENTITY();

            INSERT INTO ComprobantePago (PagoId, Fecha, NumeroReferencia, Monto)
            VALUES (@PagoId, @FechaOperacion, @NumeroReferencia, @TotalAPagarFinal);

            /* --------------------------------------------------------
               3.6 Cambiar estado de la factura a PAGADA
               -------------------------------------------------------- */
            UPDATE Factura
            SET Estado = 2  -- Pagado normal
            WHERE FacturaId = @FacturaId;

            FETCH NEXT FROM C INTO @FechaOperacion, @NumeroFinca, @TipoMedioPagoId, @NumeroReferencia;
        END

        CLOSE C;
        DEALLOCATE C;

        DROP TABLE #Pagos;

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRAN;

        THROW;
    END CATCH
END;
GO
