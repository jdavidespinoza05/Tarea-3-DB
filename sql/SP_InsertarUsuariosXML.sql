USE Tarea3;
GO

CREATE OR ALTER PROCEDURE dbo.SP_InsertarUsuariosXML
    @XmlUsuarios XML
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRAN;

        /* =====================================
           1) Pasamos el XML a una tabla temporal
           ===================================== */
        DECLARE @X TABLE (
            ValorDocumentoIdentidad VARCHAR(20),
            TipoUsuarioId INT,
            TipoAsociacion INT
        );

        INSERT INTO @X (ValorDocumentoIdentidad, TipoUsuarioId, TipoAsociacion)
        SELECT
            U.value('@ValorDocumentoIdentidad','VARCHAR(20)'),
            U.value('@TipoUsuario','INT'),
            U.value('@TipoAsociacion','INT')
        FROM @XmlUsuarios.nodes('/Usuarios/Usuario') AS T(U);

        /* =====================================
           2) INSERTAR USUARIOS (TipoAsociacion = 1)
           ===================================== */
        INSERT INTO dbo.Usuario (PersonaId, TipoUsuarioId, NombreUsuario, ContrasenaHash)
        SELECT
            p.PersonaId,
            x.TipoUsuarioId,
            x.ValorDocumentoIdentidad AS NombreUsuario,
            x.ValorDocumentoIdentidad AS ContrasenaHash
        FROM @X x
        INNER JOIN dbo.Persona p ON p.ValorDocumento = x.ValorDocumentoIdentidad
        INNER JOIN dbo.TipoUsuario tu ON tu.TipoUsuarioId = x.TipoUsuarioId
        LEFT JOIN dbo.Usuario u
            ON u.PersonaId = p.PersonaId AND u.TipoUsuarioId = x.TipoUsuarioId
        WHERE x.TipoAsociacion = 1
          AND u.UsuarioId IS NULL;

        /* =====================================
           3) ELIMINAR USUARIOS (TipoAsociacion = 2)
           ===================================== */
        DELETE u
        FROM dbo.Usuario u
        INNER JOIN dbo.Persona p ON p.PersonaId = u.PersonaId
        INNER JOIN @X x
            ON x.ValorDocumentoIdentidad = p.ValorDocumento
           AND x.TipoUsuarioId = u.TipoUsuarioId
        WHERE x.TipoAsociacion = 2;

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END;
GO
