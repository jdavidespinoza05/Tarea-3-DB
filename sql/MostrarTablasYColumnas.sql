SELECT 
    t.name AS NombreTabla,
    c.name AS NombreColumna,
    ty.name AS TipoDato,
    c.max_length AS Longitud,
    c.precision AS Precision,
    c.scale AS Escala,
    c.is_nullable AS AceptaNulos,
    c.is_identity AS EsIdentity
FROM sys.tables t
INNER JOIN sys.columns c ON t.object_id = c.object_id
INNER JOIN sys.types ty ON c.user_type_id = ty.user_type_id
ORDER BY t.name, c.column_id;
