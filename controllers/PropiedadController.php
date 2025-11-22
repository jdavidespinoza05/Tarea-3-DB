<?php
/**
 * PropiedadController.php
 * Maneja las consultas a la BD relacionadas con las propiedades, utilizando el esquema de Tarea3.
 */
class PropiedadController {
    private $db;

    public function __construct($db_connection) {
        $this->db = $db_connection;
    }

    /**
     * Consulta el detalle de una propiedad por su número de finca.
     * @param string $numeroFinca
     * @return array Lista de propiedades encontradas.
     */
    public function getPropiedadByFinca($numeroFinca) {
        // La función STRING_AGG de SQL Server concatena múltiples filas en una sola cadena.
        $sql = "
            SELECT p.PropiedadId, p.NumeroFinca, p.MetrosCuadrados, p.ValorFiscal, p.FechaRegistro,
                   tu.Nombre AS TipoUso,  -- Alias para obtener el nombre legible
                   tz.Nombre AS TipoZona,  -- Alias para obtener el nombre legible
                   m.NumeroMedidor,
                   -- Concatena los IDs y ValoresDocumento de los propietarios activos
                   STRING_AGG(CONVERT(VARCHAR(50), prop.PersonaId) + ' (' + prop.ValorDocumento + ')', ', ') AS Propietarios
            FROM Propiedad p
            -- JOIN para obtener el nombre del Tipo de Uso
            JOIN TipoUsoPropiedad tu ON p.TipoUsoId = tu.TipoUsoId
            -- JOIN para obtener el nombre del Tipo de Zona
            JOIN TipoZonaPropiedad tz ON p.TipoZonaId = tz.TipoZonaId
            -- JOIN para obtener el Número de Medidor
            JOIN Medidor m ON p.MedidorId = m.MedidorId
            -- LEFT JOIN para obtener los propietarios asociados
            LEFT JOIN PropiedadPropietario pp ON p.PropiedadId = pp.PropiedadId
            LEFT JOIN Persona prop ON pp.PersonaId = prop.PersonaId
            WHERE p.NumeroFinca LIKE :finca AND (pp.FechaFin IS NULL OR pp.FechaFin >= CAST(GETDATE() AS DATE)) -- Solo propietarios activos
            GROUP BY p.PropiedadId, p.NumeroFinca, p.MetrosCuadrados, p.ValorFiscal, p.FechaRegistro, tu.Nombre, tz.Nombre, m.NumeroMedidor
        ";

        try {
            $stmt = $this->db->prepare($sql);
            $searchFinca = "%" . $numeroFinca . "%"; // Búsqueda parcial
            $stmt->bindParam(':finca', $searchFinca, PDO::PARAM_STR);
            $stmt->execute();
            
            return $stmt->fetchAll(PDO::FETCH_ASSOC);
            
        } catch (PDOException $e) {
            error_log("Error al buscar por Finca: " . $e->getMessage());
            return [];
        }
    }

    /**
     * Consulta las propiedades asociadas a una persona (propietario) por su ValorDocumento.
     * @param string $idDocumento El valor del documento de identidad del propietario (ValorDocumento en Persona).
     * @return array Lista de propiedades encontradas.
     */
    public function getPropiedadByIdPropietario($idDocumento) {
        $sql = "
            SELECT p.PropiedadId, p.NumeroFinca, p.MetrosCuadrados, p.ValorFiscal, p.FechaRegistro,
                   tu.Nombre AS TipoUso, 
                   tz.Nombre AS TipoZona,
                   m.NumeroMedidor,
                   -- Concatena los IDs y ValoresDocumento de los propietarios activos
                   STRING_AGG(CONVERT(VARCHAR(50), prop.PersonaId) + ' (' + prop.ValorDocumento + ')', ', ') AS Propietarios
            FROM Propiedad p
            JOIN TipoUsoPropiedad tu ON p.TipoUsoId = tu.TipoUsoId
            JOIN TipoZonaPropiedad tz ON p.TipoZonaId = tz.TipoZonaId
            JOIN Medidor m ON p.MedidorId = m.MedidorId
            -- JOIN a la tabla Persona para buscar por ValorDocumento
            JOIN PropiedadPropietario pp ON p.PropiedadId = pp.PropiedadId
            JOIN Persona prop ON pp.PersonaId = prop.PersonaId
            WHERE prop.ValorDocumento = :id_documento AND (pp.FechaFin IS NULL OR pp.FechaFin >= CAST(GETDATE() AS DATE)) -- Solo propietarios activos
            GROUP BY p.PropiedadId, p.NumeroFinca, p.MetrosCuadrados, p.ValorFiscal, p.FechaRegistro, tu.Nombre, tz.Nombre, m.NumeroMedidor
        ";

        try {
            $stmt = $this->db->prepare($sql);
            $stmt->bindParam(':id_documento', $idDocumento, PDO::PARAM_STR);
            $stmt->execute();
            
            return $stmt->fetchAll(PDO::FETCH_ASSOC);
            
        } catch (PDOException $e) {
            error_log("Error al buscar por ID de Propietario: " . $e->getMessage());
            return [];
        }
    }
}