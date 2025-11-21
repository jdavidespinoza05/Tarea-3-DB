/* ============================================================
   SP: SP_GenerarFacturasDiarias (VERSION CORREGIDA)
   ============================================================ */
USE Tarea3;
GO
CREATE OR ALTER PROCEDURE SP_GenerarFacturasDiarias
  @FechaOperacion DATE
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;

  BEGIN TRY
    BEGIN TRAN;

    /* --------- PARAMETROS DEL SISTEMA ---------- */
    DECLARE @DiasVencimiento INT = NULL;

    SELECT @DiasVencimiento = TRY_CAST(ParametroValor AS INT)
    FROM ParametrosSistema
    WHERE ParametroClave = 'DiasVencimiento';

    IF @DiasVencimiento IS NULL SET @DiasVencimiento = 8;


    /* --------- DATOS DE FECHA ---------- */
    DECLARE @Anio INT = YEAR(@FechaOperacion),
            @Mes  INT = MONTH(@FechaOperacion),
            @UltimoDiaMes INT = DAY(EOMONTH(@FechaOperacion));


    /* =======================================================
       SELECCIÓN DE PROPIEDADES A FACTURAR
       (solo UNA creación de #PropCandidatas, limpio)
       ======================================================= */
    SELECT
      p.PropiedadID,
      p.NumeroFinca,
      p.MetrosCuadrados,
      p.TipoUsoPropiedadID,
      p.TipoZonaPropiedadID,
      p.ValorFiscal,
      p.SaldoM3,
      p.SaldoM3UltimaFactura,
      p.FechaRegistro,
      CASE 
        WHEN DAY(p.FechaRegistro) <= @UltimoDiaMes 
        THEN DAY(p.FechaRegistro) 
        ELSE @UltimoDiaMes 
      END AS DiaFacturacion
    INTO #PropCandidatas
    FROM Propiedad p
    WHERE CASE 
            WHEN DAY(p.FechaRegistro) <= @UltimoDiaMes 
            THEN DAY(p.FechaRegistro) 
            ELSE @UltimoDiaMes 
          END = DAY(@FechaOperacion);


    IF NOT EXISTS (SELECT 1 FROM #PropCandidatas)
    BEGIN
      PRINT 'No hay propiedades para facturar en esta fecha.';
      COMMIT;
      RETURN;
    END


    /* =======================================================
       PREPARAR PROPIEDADES PARA PROCESAR EN CURSOR
       ======================================================= */
    CREATE TABLE #FacturasParaGenerar (
      PropiedadID INT PRIMARY KEY,
      NumeroFinca VARCHAR(50),
      SaldoM3 DECIMAL(18,3),
      SaldoM3UltimaFactura DECIMAL(18,3)
    );

    INSERT INTO #FacturasParaGenerar
    SELECT PropiedadID, NumeroFinca, SaldoM3, SaldoM3UltimaFactura
    FROM #PropCandidatas;


    /* =======================================================
       CURSOR DE PROPIEDADES
       ======================================================= */
    DECLARE @PropID INT, @NumeroFinca VARCHAR(50), @SaldoM3 DECIMAL(18,3), @SaldoUlt DECIMAL(18,3);

    DECLARE curProp CURSOR LOCAL FAST_FORWARD FOR
      SELECT PropiedadID, NumeroFinca, SaldoM3, SaldoM3UltimaFactura
      FROM #FacturasParaGenerar;

    OPEN curProp;
    FETCH NEXT FROM curProp INTO @PropID, @NumeroFinca, @SaldoM3, @SaldoUlt;

    WHILE @@FETCH_STATUS = 0
    BEGIN

      /* EVITAR DOBLE FACTURACIÓN */
      IF EXISTS (
        SELECT 1 FROM Factura
        WHERE PropiedadID = @PropID
          AND YEAR(FechaEmision) = @Anio
          AND MONTH(FechaEmision) = @Mes
      )
      BEGIN
        FETCH NEXT FROM curProp INTO @PropID, @NumeroFinca, @SaldoM3, @SaldoUlt;
        CONTINUE;
      END


      /* =======================================================
         CREAR FACTURA BASE
         ======================================================= */
      DECLARE @NumeroFactura BIGINT;

      SELECT @NumeroFactura = ISNULL(MAX(NumeroFactura), @Anio*1000000 + @Mes*10000) + 1
      FROM Factura;

      INSERT INTO Factura
        (NumeroFactura, PropiedadID, FechaEmision, FechaVencimiento, 
         TotalAPagarOriginal, TotalAPagarFinal, EstadoID, GeneradaPorProceso)
      VALUES
        (@NumeroFactura, @PropID, @FechaOperacion,
         DATEADD(DAY, @DiasVencimiento, @FechaOperacion),
         0, 0, 1, 1);

      DECLARE @FacturaID INT = SCOPE_IDENTITY();


      /* =======================================================
         AGREGAR DETALLES DE CC
         ======================================================= */

      DECLARE 
        @CCID INT, @PeriodoID TINYINT, @TipoMontoID TINYINT,
        @ValorMinimo DECIMAL(18,2), @ValorMinimoM3 DECIMAL(18,3),
        @CostoM3 DECIMAL(18,2), @ValorPorcentual DECIMAL(18,6),
        @ValorFijo DECIMAL(18,2), @ValorM2Minimo DECIMAL(18,2),
        @ValorTractosM2 DECIMAL(18,2),
        @MontoLinea DECIMAL(18,2),
        @Cantidad DECIMAL(18,3);

      DECLARE curCC CURSOR LOCAL FAST_FORWARD FOR
        SELECT pc.CCID, c.PeriodoMontoCCID, c.TipoMontoCCID,
               c.ValorMinimo, c.ValorMinimoM3, c.CostoM3,
               c.ValorPorcentual, c.ValorFijo,
               c.ValorM2Minimo, c.ValorTractosM2
        FROM PropiedadCC pc
        JOIN ConceptoCobro c ON pc.CCID = c.CCID
        WHERE pc.PropiedadID = @PropID AND pc.Activo = 1;

      OPEN curCC;
      FETCH NEXT FROM curCC INTO 
            @CCID, @PeriodoID, @TipoMontoID, @ValorMinimo,
            @ValorMinimoM3, @CostoM3, @ValorPorcentual,
            @ValorFijo, @ValorM2Minimo, @ValorTractosM2;

      WHILE @@FETCH_STATUS = 0
      BEGIN
        /* =========================
           CCID 1 → AGUA
           ========================= */
        IF @CCID = 1
        BEGIN
          DECLARE @Consumo DECIMAL(18,3) = @SaldoM3 - @SaldoUlt;
          IF @Consumo < 0 SET @Consumo = 0;

          SET @Cantidad = @Consumo;

          IF (@Consumo * ISNULL(@ValorMinimoM3,0)) > ISNULL(@ValorMinimo,0)
            SET @MontoLinea = ROUND(@Consumo * ISNULL(@CostoM3,0), 2);
          ELSE
            SET @MontoLinea = ISNULL(@ValorMinimo,0);

          INSERT INTO FacturaDetalle
            (FacturaID, CCID, Descripcion, Monto, Cantidad)
          VALUES
            (@FacturaID, @CCID, 'Consumo Agua', @MontoLinea, @Cantidad);
        END


        /* =========================
           IMPUESTO (%)
           ========================= */
        ELSE IF @TipoMontoID = 3
        BEGIN
          DECLARE @QMeses INT = (SELECT QMeses FROM PeriodoMontoCC WHERE PeriodoMontoCCID = @PeriodoID);
          IF @QMeses IS NULL OR @QMeses = 0 SET @QMeses = 12;

          SET @MontoLinea =
              ROUND( (ISNULL(@ValorPorcentual,0) * (SELECT ValorFiscal FROM Propiedad WHERE PropiedadID=@PropID)) / @QMeses, 2);

          INSERT INTO FacturaDetalle
            (FacturaID, CCID, Descripcion, Monto)
          VALUES
            (@FacturaID, @CCID, 'Impuesto a la propiedad', @MontoLinea);
        END


        /* =========================
           MONTO FIJO (PATENTE, RECONEXIÓN, etc.)
           ========================= */
        ELSE IF @TipoMontoID = 1
        BEGIN
          DECLARE @QMeses2 INT = (SELECT QMeses FROM PeriodoMontoCC WHERE PeriodoMontoCCID = @PeriodoID);
          IF @QMeses2 IS NULL OR @QMeses2=0 SET @QMeses2 = 1;

          SET @MontoLinea = ROUND(ISNULL(@ValorFijo,0)/@QMeses2,2);

          INSERT INTO FacturaDetalle
            (FacturaID, CCID, Descripcion, Monto)
          VALUES
            (@FacturaID, @CCID, 'Cobro ' + CAST(@CCID AS NVARCHAR(10)), @MontoLinea);
        END


        /* =========================
           BASURA (CCID 3)
           ========================= */
        ELSE IF @CCID = 3
        BEGIN
          DECLARE @M2 DECIMAL(18,2) = (SELECT MetrosCuadrados FROM Propiedad WHERE PropiedadID = @PropID);

          IF @M2 <= ISNULL(@ValorM2Minimo,400)
            SET @MontoLinea = ISNULL(@ValorMinimo,150);
          ELSE
          BEGIN
            DECLARE @Exceso DECIMAL(18,2) = @M2 - ISNULL(@ValorM2Minimo,400);
            DECLARE @Tramos INT = FLOOR(@Exceso / 200); -- TRAMO DE 200 m2
            SET @MontoLinea = 150 + @Tramos * 75;
          END

          INSERT INTO FacturaDetalle(FacturaID, CCID, Descripcion, Monto)
          VALUES(@FacturaID, 3, 'Recolección de basura', @MontoLinea);
        END

        FETCH NEXT FROM curCC INTO 
              @CCID, @PeriodoID, @TipoMontoID, @ValorMinimo,
              @ValorMinimoM3, @CostoM3, @ValorPorcentual,
              @ValorFijo, @ValorM2Minimo, @ValorTractosM2;
      END

      CLOSE curCC;
      DEALLOCATE curCC;


      /* UPDATE de totales */
      DECLARE @Total DECIMAL(18,2) = (
          SELECT SUM(Monto) FROM FacturaDetalle WHERE FacturaID=@FacturaID
      );

      UPDATE Factura
      SET TotalAPagarOriginal = @Total,
          TotalAPagarFinal = @Total
      WHERE FacturaID = @FacturaID;


      /* Actualizar lectura base */
      UPDATE Propiedad
      SET SaldoM3UltimaFactura = @SaldoM3
      WHERE PropiedadID = @PropID;


      FETCH NEXT FROM curProp INTO @PropID, @NumeroFinca, @SaldoM3, @SaldoUlt;
    END

    CLOSE curProp;
    DEALLOCATE curProp;

    DROP TABLE #FacturasParaGenerar;
    DROP TABLE #PropCandidatas;

    COMMIT;
  END TRY
  BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(@ErrMsg,16,1);
  END CATCH;
END;
GO
