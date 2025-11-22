<?php
/**
 * PropiedadController.php
 * Maneja las consultas a la BD relacionadas con las propiedades.
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
        // Usamos LIKE para búsquedas parciales, útil si el formato es estricto (ej: F-0001)
        $sql = "
            SELECT p.PropiedadId, p.NumeroFinca, p.Area, p.TipoUso, p.Direccion,
                   STRING_AGG(CONVERT(VARCHAR(50), pp.PropietarioId), ', ') AS PropietarioIDs
            FROM Propiedad p
            LEFT JOIN PropiedadPropietario pp ON p.PropiedadId = pp.PropiedadId
            WHERE p.NumeroFinca LIKE :finca
            GROUP BY p.PropiedadId, p.NumeroFinca, p.Area, p.TipoUso, p.Direccion
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
     * Consulta las propiedades asociadas a una persona (propietario) por su ID de documento.
     * @param string $idDocumento El valor del documento de identidad del propietario (ValorDocumento en Persona).
     * @return array Lista de propiedades encontradas.
     */
    public function getPropiedadByIdPropietario($idDocumento) {
        $sql = "
            SELECT p.PropiedadId, p.NumeroFinca, p.Area, p.TipoUso, p.Direccion,
                   STRING_AGG(CONVERT(VARCHAR(50), pp.PropietarioId), ', ') AS PropietarioIDs
            FROM Propiedad p
            JOIN PropiedadPropietario pp ON p.PropiedadId = pp.PropiedadId
            JOIN Persona prop ON pp.PropietarioId = prop.PersonaId -- Asumiendo que PropietarioId es la misma llave que PersonaId
            WHERE prop.ValorDocumento = :id_documento
            GROUP BY p.PropiedadId, p.NumeroFinca, p.Area, p.TipoUso, p.Direccion
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