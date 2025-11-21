<?php
/**
 * Clase para manejar la conexión a SQL Server usando PDO Sqlsrv.
 * Se utiliza el patrón Singleton simple para asegurar una única instancia de conexión.
 */
class Database {
    // Detalles del servidor proporcionados por el usuario
    private static $serverName = "mssql-204707-0.cloudclusters.net";
    private static $port = "10100";
    
    // Variables que el usuario debe confirmar/proporcionar en el futuro
    private static $databaseName = "Tarea3"; // Placeholder, por confirmar
    private static $username = "Danivi";          // Placeholder, por confirmar
    private static $password = "Danivi123";     // Placeholder, por confirmar

    // Instancia estática de la conexión PDO
    private static $conn;

    /**
     * Constructor privado para prevenir la instanciación externa (Singleton).
     */
    private function __construct() {}

    /**
     * Obtiene la instancia de la conexión PDO.
     * Si la conexión no existe, la crea. Maneja errores con try/catch.
     *
     * @return PDO|null Retorna el objeto PDO si la conexión es exitosa, o null en caso de fallo.
     */
    public static function getConnection() {
        if (self::$conn === null) {
            // Construcción de la cadena de conexión DSN
            $dsn = "sqlsrv:Server=" . self::$serverName . "," . self::$port . ";Database=" . self::$databaseName;

            try {
                // Crear una nueva conexión PDO
                self::$conn = new PDO($dsn, self::$username, self::$password);
                
                // Configurar el modo de error de PDO a excepción
                self::$conn->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
                
                // Configurar el modo de retorno de resultados (opcional, útil para arrays asociativos)
                self::$conn->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);

                // Opcional: imprimir un mensaje de éxito en la consola del servidor (no en el navegador)
                error_log("Conexión a la base de datos establecida con éxito.");

            } catch (PDOException $e) {
                // En caso de fallo de conexión, registrar el error y devolver null
                error_log("Error de conexión a la BD: " . $e->getMessage());
                // Podríamos lanzar una excepción o devolver null. Devolveremos null por ahora.
                self::$conn = null;
            }
        }

        return self::$conn;
    }
}