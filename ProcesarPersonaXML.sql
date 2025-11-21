/* ============================================================
   BLOQUE 1 — SP_ProcesarPersonaXML  y  SP_ProcesarPropiedadXML
   - Diseñados para el xml: /mnt/data/xmlUltimo.xml
   - Ambos usan transacciones y manejo TRY/CATCH
   ============================================================ */

GO
/* ---------------------------
   SP_ProcesarPersonaXML
   --------------------------- */
CREATE OR ALTER PROCEDURE SP_ProcesarPersonaXML
  @XmlPersonas XML
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;

  BEGIN TRY
    BEGIN TRAN;

    -- Extraemos personas del XML: asumimos nodos /FechaOperacion/Persona
    ;WITH CTE_Personas AS (
      SELECT
        P.value('@ValorDocumentoIdentidad','VARCHAR(50)')           AS ValorDocumentoIdentidad,
        P.value('@Nombre','NVARCHAR(200)')                           AS Nombre,
        P.value('@Email','NVARCHAR(100)')                            AS Email,
        P.value('@Telefono1','VARCHAR(20)')                          AS Telefono1,
        P.value('@Telefono2','VARCHAR(20)')                          AS Telefono2,
        P.value('@EsJuridica','BIT')                                 AS EsJuridica
      FROM @XmlPersonas.nodes('/FechaOperacion/Persona') AS T(P)
    )
    SELECT * INTO #PersonasTmp FROM CTE_Personas;

    -- Recorrer cada persona y hacer UPSERT (MERGE)
    DECLARE @doc VARCHAR(50), @nombre NVARCHAR(200), @email NVARCHAR(100),
            @t1 VARCHAR(20), @t2 VARCHAR(20), @esJur BIT, @PersonaID INT;

    DECLARE curPers CURSOR LOCAL FAST_FORWARD FOR
      SELECT ValorDocumentoIdentidad, Nombre, Email, Telefono1, Telefono2, EsJuridica
      FROM #PersonasTmp;

    OPEN curPers;
    FETCH NEXT FROM curPers INTO @doc, @nombre, @email, @t1, @t2, @esJur;

    WHILE @@FETCH_STATUS = 0
    BEGIN
      IF @doc IS NULL OR LTRIM(RTRIM(@doc)) = ''
      BEGIN
        -- ignorar registros sin documento
        FETCH NEXT FROM curPers INTO @doc, @nombre, @email, @t1, @t2, @esJur;
        CONTINUE;
      END

      -- Si existe persona con mismo ValorDocumentoIdentidad -> actualizar
      IF EXISTS (SELECT 1 FROM Persona WHERE ValorDocumentoIdentidad = @doc)
      BEGIN
        UPDATE Persona
        SET Nombre = ISNULL(@nombre, Nombre),
            Email = ISNULL(@email, Email),
            Telefono1 = ISNULL(@t1, Telefono1),
            Telefono2 = ISNULL(@t2, Telefono2),
            EsJuridica = COALESCE(@esJur, EsJuridica)
        WHERE ValorDocumentoIdentidad = @doc;

        SELECT @PersonaID = PersonaID FROM Persona WHERE ValorDocumentoIdentidad = @doc;
      END
      ELSE
      BEGIN
        INSERT INTO Persona (ValorDocumentoIdentidad, Nombre, Email, Telefono1, Telefono2, EsJuridica)
        VALUES (@doc, @nombre, @email, @t1, @t2, COALESCE(@esJur, 0));

        SET @PersonaID = SCOPE_IDENTITY();
      END

      -- (Opcional) puedes escribir en un log de importación aquí.

      FETCH NEXT FROM curPers INTO @doc, @nombre, @email, @t1, @t2, @esJur;
    END

    CLOSE curPers;
    DEALLOCATE curPers;

    DROP TABLE #PersonasTmp;

    COMMIT;
  END TRY
  BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR('SP_ProcesarPersonaXML: %s', 16, 1, @Err);
  END CATCH;
END;
GO

/* ---------------------------
   SP_ProcesarPropiedadXML
   - Inserta/actualiza Propiedad
   - Inserta Medidor si NumeroMedidor viene en el nodo
   --------------------------- */
CREATE OR ALTER PROCEDURE SP_ProcesarPropiedadXML
  @XmlPropiedades XML
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;

  BEGIN TRY
    BEGIN TRAN;

    -- Extraemos propiedades del XML: asumimos nodos /FechaOperacion/Propiedad
    ;WITH CTE_Props AS (
      SELECT
        P.value('@NumeroFinca','VARCHAR(50)')      AS NumeroFinca,
        P.value('@MetrosCuadrados','DECIMAL(12,2)')AS MetrosCuadrados,
        P.value('@TipoUso','TINYINT')              AS TipoUsoPropiedadID,
        P.value('@TipoZona','TINYINT')             AS TipoZonaPropiedadID,
        P.value('@ValorFiscal','DECIMAL(18,2)')    AS ValorFiscal,
        P.value('@NumeroMedidor','VARCHAR(50)')    AS NumeroMedidor,
        P.value('@FechaRegistro','DATE')           AS FechaRegistro
      FROM @XmlPropiedades.nodes('/FechaOperacion/Propiedad') AS T(P)
    )
    SELECT * INTO #PropsTmp FROM CTE_Props;

    -- Cursor para procesar cada propiedad
    DECLARE @NumeroFinca VARCHAR(50),
            @Metros DECIMAL(12,2),
            @TipoUso TINYINT,
            @TipoZona TINYINT,
            @ValorFiscal DECIMAL(18,2),
            @NumeroMedidor VARCHAR(50),
            @FechaRegistro DATE,
            @PropiedadID INT,
            @MedidorID INT;

    DECLARE curProp CURSOR LOCAL FAST_FORWARD FOR
      SELECT NumeroFinca, MetrosCuadrados, TipoUsoPropiedadID, TipoZonaPropiedadID, ValorFiscal, NumeroMedidor, FechaRegistro
      FROM #PropsTmp;

    OPEN curProp;
    FETCH NEXT FROM curProp INTO @NumeroFinca, @Metros, @TipoUso, @TipoZona, @ValorFiscal, @NumeroMedidor, @FechaRegistro;

    WHILE @@FETCH_STATUS = 0
    BEGIN
      IF @NumeroFinca IS NULL OR LTRIM(RTRIM(@NumeroFinca)) = ''
      BEGIN
        -- ignoramos propiedades sin numero de finca
        FETCH NEXT FROM curProp INTO @NumeroFinca, @Metros, @TipoUso, @TipoZona, @ValorFiscal, @NumeroMedidor, @FechaRegistro;
        CONTINUE;
      END

      -- Si ya existe propiedad con NumeroFinca -> actualizar
      IF EXISTS (SELECT 1 FROM Propiedad WHERE NumeroFinca = @NumeroFinca)
      BEGIN
        UPDATE Propiedad
        SET MetrosCuadrados = COALESCE(@Metros, MetrosCuadrados),
            TipoUsoPropiedadID = COALESCE(@TipoUso, TipoUsoPropiedadID),
            TipoZonaPropiedadID = COALESCE(@TipoZona, TipoZonaPropiedadID),
            ValorFiscal = COALESCE(@ValorFiscal, ValorFiscal),
            FechaRegistro = COALESCE(@FechaRegistro, FechaRegistro),
            Activo = 1
        WHERE NumeroFinca = @NumeroFinca;

        SELECT @PropiedadID = PropiedadID FROM Propiedad WHERE NumeroFinca = @NumeroFinca;
      END
      ELSE
      BEGIN
        INSERT INTO Propiedad
          (NumeroFinca, MetrosCuadrados, TipoUsoPropiedadID, TipoZonaPropiedadID, ValorFiscal, FechaRegistro, SaldoM3, SaldoM3UltimaFactura, FechaCreacion, Activo)
        VALUES
          (@NumeroFinca, ISNULL(@Metros,0), COALESCE(@TipoUso,1), COALESCE(@TipoZona,1), ISNULL(@ValorFiscal,0), COALESCE(@FechaRegistro, GETDATE()), 0, 0, SYSUTCDATETIME(), 1);

        SET @PropiedadID = SCOPE_IDENTITY();
      END

      -- Si NumeroMedidor viene en el XML, insertar medidor si no existe
      IF LTRIM(RTRIM(ISNULL(@NumeroMedidor,''))) <> ''
      BEGIN
        IF NOT EXISTS (SELECT 1 FROM Medidor WHERE NumeroMedidor = @NumeroMedidor)
        BEGIN
          INSERT INTO Medidor (NumeroMedidor, PropiedadID, SaldoM3, FechaCreacion)
          VALUES (@NumeroMedidor, @PropiedadID, 0, SYSUTCDATETIME());

          SET @MedidorID = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
          -- Si existe medidor pero no está asociado a la propiedad, actualizar asociación
          SELECT @MedidorID = MedidorID FROM Medidor WHERE NumeroMedidor = @NumeroMedidor;
          IF EXISTS (SELECT 1 FROM Medidor WHERE MedidorID = @MedidorID AND (PropiedadID IS NULL OR PropiedadID <> @PropiedadID))
          BEGIN
            UPDATE Medidor SET PropiedadID = @PropiedadID WHERE MedidorID = @MedidorID;
          END
        END
      END

      -- (Opcional) insertar PropiedadCC por defecto via trigger TR_Propiedad_Insert que ya creamos
      -- Si no existe trigger, podríamos insertar PropiedadCC aquí.

      FETCH NEXT FROM curProp INTO @NumeroFinca, @Metros, @TipoUso, @TipoZona, @ValorFiscal, @NumeroMedidor, @FechaRegistro;
    END

    CLOSE curProp;
    DEALLOCATE curProp;

    DROP TABLE #PropsTmp;

    COMMIT;
  END TRY
  BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR('SP_ProcesarPropiedadXML: %s', 16, 1, @Err);
  END CATCH;
END;
GO
