DECLARE @XML XML;

SELECT TOP (1) @XML = XmlData
FROM dbo.XML_Input;

EXEC dbo.SP_ProcesarXMLCompleto @XML = @XML;
