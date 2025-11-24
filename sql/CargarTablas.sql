USE [Tarea3];
GO

DECLARE @xml XML;

SELECT TOP (1) @xml = XmlData 
FROM dbo.XML_Input
ORDER BY Id DESC;

EXEC dbo.SP_InsertarPersonasXML @XML = @xml;
EXEC dbo.SP_InsertarPropiedadesXML @XML = @xml;
EXEC dbo.SP_InsertarPropiedadPersonaXML @XML = @xml;
EXEC dbo.SP_ProcesarLecturasXML @XML = @xml;
EXEC dbo.SP_ProcesarPagosXML @XML = @xml;
EXEC dbo.SP_InsertarCCPropiedadXML @XML = @xml;
