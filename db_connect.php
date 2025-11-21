<?php
/**
 * db_connect.php
 * Script simple para incluir la clase Database y obtener una instancia de la conexión.
 * Se incluye en cualquier archivo que necesite acceder a la BD.
 */
require_once __DIR__ . '/config/db.php';

$db_conn = Database::getConnection();

if ($db_conn === null) {
    // Si la conexión falla, detenemos la ejecución y mostramos un error genérico (por seguridad).
    // El error detallado se registra en el log del servidor (ver config/db.php).
    // Usamos una función para mostrar el error de forma controlada.
    function display_fatal_error($message) {
        http_response_code(500);
        echo "<!DOCTYPE html><html><head><title>Error Fatal</title>";
        echo "<link rel='stylesheet' href='./css/styles.css'></head><body>";
        echo "<div class='auth-container'><div class='card'>";
        echo "<h1>Error del Sistema</h1>";
        echo "<div class='alert alert-danger'>{$message}</div>";
        echo "<p>Por favor, revise el archivo de configuración de la base de datos y asegúrese de que el driver 'pdo_sqlsrv' esté habilitado en su php.ini.</p>";
        echo "</div></div></body></html>";
        exit;
    }

    display_fatal_error("No se pudo conectar a la base de datos.");
}

// Ahora $db_conn contiene la instancia PDO conectada.