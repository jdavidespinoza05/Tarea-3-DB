CREATE OR ALTER PROCEDURE SP_InsertarPersonasXML
    @XML XML
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH X AS (
        SELECT
            P.value('@valorDocumento','VARCHAR(20)') AS ValorDocumento,
            P.value('@nombre','VARCHAR(100)') AS Nombre,
            P.value('@email','VARCHAR(100)') AS Email,
            P.value('@telefono','VARCHAR(20)') AS Telefono
        FROM @XML.nodes('/Operaciones/FechaOperacion/Personas/Persona') AS T(P)
    )
    INSERT INTO Persona (ValorDocumento, Nombre, Email, Telefono)
    SELECT ValorDocumento, Nombre, Email, Telefono
    FROM X
    WHERE ValorDocumento NOT IN (SELECT ValorDocumento FROM Persona);

END;
GO
