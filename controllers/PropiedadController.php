<?php
class PropiedadController {
    private $db;

    public function __construct($db_connection) {
        $this->db = $db_connection;
    }

    // Unificamos todo en una sola función inteligente
    public function buscarPropiedad($terminoBusqueda) {
        // Validar que no venga vacío
        if (empty(trim($terminoBusqueda))) {
            return [];
        }

        try {
            // Llamada al SP
            $sql = "EXEC SP_BuscarPropiedad @Busqueda = :busqueda";
            $stmt = $this->db->prepare($sql);
            
            // Limpiamos el input
            $limpio = trim($terminoBusqueda);
            $stmt->bindParam(':busqueda', $limpio);
            
            $stmt->execute();
            return $stmt->fetchAll(PDO::FETCH_ASSOC);

        } catch (PDOException $e) {
            // Loguear error pero no matar la web
            error_log("Error Buscando Propiedad: " . $e->getMessage());
            return [];
        }
    }
}
?>