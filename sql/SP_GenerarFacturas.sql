CREATE OR ALTER PROCEDURE SP_GenerarFacturas
    @FechaOperacion DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE 
        @DiaLimitePago INT,
        @DiaLimiteCorte INT;

    SELECT @DiaLimitePago = ValorInt
    FROM ParametrosSistema WHERE Nombre = 'DiasLimitePago';

    SELECT @DiaLimiteCorte = ValorInt
    FROM ParametrosSistema WHERE Nombre = 'DiasLimiteCorte';

    /* ============================================================
       1. Determinar propiedades que facturan hoy
       ============================================================ */

    ;WITH Props AS (
        SELECT 
            P.PropiedadId,
            P.NumeroFinca,
            P.FechaRegistro,
            DAY(P.FechaRegistro) AS DiaRegistro,
            DAY(@FechaOperacion) AS DiaOp
        FROM Propiedad P
    )
    SELECT PropiedadId INTO #PropsHoy
    FROM Props
    WHERE 
        -- Caso normal: mismo día
        DiaRegistro = DiaOp
        OR
        -- Caso 31 → último día del mes
        (DiaRegistro = 31 AND 
         DiaOp = DAY(EOMONTH(@FechaOperacion))
        );

    /* ============================================================
       2. Calcular montos por cada CC asignado a la propiedad
       ============================================================ */

    DECLARE 
        @PropiedadId INT,
        @CCId INT,
        @Monto DECIMAL(18,2),
        @FacturaId INT;

    DECLARE C CURSOR FOR
        SELECT PropiedadId FROM #PropsHoy;

    OPEN C;
    FETCH NEXT FROM C INTO @PropiedadId;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        /* Crear la factura vacía */
        INSERT INTO Factura(PropiedadId, FechaFactura, FechaLimitePago, FechaLimiteCorte,
                            Estado, TotalAPagarOriginal, TotalAPagarFinal)
        VALUES (
            @PropiedadId,
            @FechaOperacion,
            DATEADD(DAY, @DiaLimitePago, @FechaOperacion),
            DATEADD(DAY, @DiaLimiteCorte, @FechaOperacion),
            1,   -- pendiente
            0,
            0
        );

        SET @FacturaId = SCOPE_IDENTITY();

        /* --------------------------------------------------------
           Insertar detalles de CC activos
           -------------------------------------------------------- */
        DECLARE C2 CURSOR FOR
            SELECT CC.CCId
            FROM PropiedadCC PC
            INNER JOIN ConceptoCobro CC ON CC.CCId = PC.CCId
            WHERE PC.PropiedadId = @PropiedadId
              AND PC.FechaFin IS NULL;

        OPEN C2;
        FETCH NEXT FROM C2 INTO @CCId;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            /* ============================
               Calcular montos por tipo CC
               ============================ */

            SET @Monto = 0;

            /* Obtener info de la propiedad */
            DECLARE @M2 DECIMAL(18,2),
                    @ValorProp DECIMAL(18,2),
                    @SaldoM3 DECIMAL(18,2),
                    @UltimaFacturaM3 DECIMAL(18,2);

            SELECT 
                @M2 = MetrosCuadrados,
                @ValorProp = ValorFiscal,
                @SaldoM3 = M.SaldoM3,
                @UltimaFacturaM3 = P.SaldoM3UltimaFactura
            FROM Propiedad P
            INNER JOIN Medidor M ON M.MedidorId = P.MedidorId
            WHERE P.PropiedadId = @PropiedadId;

            /* Obtener info del CC */
            DECLARE 
                @TipoMontoCC INT,
                @Periodo INT,
                @ValorMinimo DECIMAL(18,2),
                @ValorMinimoM3 DECIMAL(18,2),
                @ValorFijoM3 DECIMAL(18,2),
                @ValorPorcentual DECIMAL(18,5),
                @ValorFijo DECIMAL(18,2),
                @ValorM2Min DECIMAL(18,2),
                @ValorTractoM2 DECIMAL(18,2);

            SELECT 
                @TipoMontoCC = TipoMontoCCId,
                @Periodo = PeriodoMontoCCId,
                @ValorMinimo = ValorMinimo,
                @ValorMinimoM3 = ValorMinimoM3,
                @ValorFijoM3 = ValorFijoM3Adicional,
                @ValorPorcentual = ValorPorcentual,
                @ValorFijo = ValorFijo,
                @ValorM2Min = ValorM2Minimo,
                @ValorTractoM2 = ValorTractosM2
            FROM ConceptoCobro
            WHERE CCId = @CCId;

            /* ====================================================
               CÁLCULO SEGÚN TIPO DE CC
               ==================================================== */

            /* 1. Consumo de agua */
            IF @CCId = 1  -- puedes ajustar si tu CC de agua es #1
            BEGIN
                DECLARE @Consumo DECIMAL(18,2) = @SaldoM3 - @UltimaFacturaM3;

                IF @Consumo <= @ValorMinimoM3
                    SET @Monto = @ValorMinimo;
                ELSE
                    SET @Monto = @Consumo * @ValorFijoM3;

                -- actualizar último saldo facturado
                UPDATE Propiedad
                SET SaldoM3UltimaFactura = @SaldoM3
                WHERE PropiedadId = @PropiedadId;
            END

            /* 2. Impuesto a propiedad (1% anual / 12) */
            ELSE IF @CCId = 2
            BEGIN
                SET @Monto = (@ValorProp * @ValorPorcentual) / 12;
            END

            /* 3. Recolección basura según metros cuadrados */
            ELSE IF @CCId = 3
            BEGIN
                IF @M2 < @ValorM2Min
                    SET @Monto = @ValorMinimo;
                ELSE
                    SET @Monto = @ValorMinimo + 
                                 (CEILING( (@M2 - @ValorM2Min) / @ValorTractoM2 ) * @ValorMinimo);
            END

            /* 4. Patente Comercial (mensualización) */
            ELSE IF @CCId = 4
            BEGIN
                SET @Monto = @ValorPorcentual * @ValorProp / 12;
            END

            /* 5. Reconexión (monto fijo) */
            ELSE IF @CCId = 5
            BEGIN
                SET @Monto = @ValorFijo;
            END

            /* Default: CC simple fijo */
            ELSE
            BEGIN
                SET @Monto = COALESCE(@ValorFijo, 0);
            END

            /* insertar detalle */
            INSERT INTO FacturaDetalle(FacturaId, CCId, Monto)
            VALUES (@FacturaId, @CCId, @Monto);

            FETCH NEXT FROM C2 INTO @CCId;
        END
        CLOSE C2;
        DEALLOCATE C2;

        /* Totalizar factura */
        UPDATE Factura
        SET TotalAPagarOriginal = (
                SELECT SUM(Monto) 
                FROM FacturaDetalle 
                WHERE FacturaId = @FacturaId
            ),
            TotalAPagarFinal = (
                SELECT SUM(Monto) 
                FROM FacturaDetalle 
                WHERE FacturaId = @FacturaId
            )
        WHERE FacturaId = @FacturaId;

        FETCH NEXT FROM C INTO @PropiedadId;
    END

    CLOSE C;
    DEALLOCATE C;

END;
GO
