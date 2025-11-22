<?php
/**
 * AuthController.php
 * Maneja la lógica de inicio de sesión consultando la tabla Usuario.
 * Utiliza ContrasenaHash y valida el TipoUsuarioId.
 */
// Incluimos la conexión a la BD
require_once __DIR__ . '/../db_connect.php';

class AuthController {
    private $db;

    public function __construct($db_connection) {
        $this->db = $db_connection;
    }

    /**
     * Intenta autenticar un usuario contra la base de datos.
     * @param string $username
     * @param string $password
     * @return bool True si la autenticación es exitosa, false en caso contrario.
     */
    public function login($username, $password) {
        if (empty($username) || empty($password)) {
            return false;
        }

        try {
            // Consulta SQL para buscar el usuario y su hash.
            $sql = "SELECT UsuarioId, NombreUsuario, ContrasenaHash, TipoUsuarioId 
                    FROM Usuario 
                    WHERE NombreUsuario = :username";
            
            $stmt = $this->db->prepare($sql);
            $stmt->bindParam(':username', $username, PDO::PARAM_STR);
            $stmt->execute();
            
            $user = $stmt->fetch(PDO::FETCH_ASSOC);

            if ($user) {
                // 1. Verificar la contraseña usando password_verify()
                if (password_verify($password, $user['ContrasenaHash'])) {
                    
                    // 2. Determinar si el usuario tiene rol de Administrador.
                    // Asumimos que TipoUsuarioId = 1 es el rol de 'admin'
                    if ($user['TipoUsuarioId'] == 1) {
                        // Autenticación exitosa y es administrador
                        $_SESSION['user_id'] = $user['UsuarioId'];
                        $_SESSION['username'] = $user['NombreUsuario'];
                        $_SESSION['role'] = 'admin'; // Usamos un string para el control de acceso
                        $_SESSION['tipo_usuario_id'] = $user['TipoUsuarioId'];
                        return true;
                    } else {
                        // El usuario existe pero no tiene el rol de administrador
                        return false; 
                    }
                }
            }
            
            return false; // Usuario no encontrado o contraseña incorrecta
            
        } catch (PDOException $e) {
            // Manejo de errores de consulta
            error_log("Error de autenticación en la BD: " . $e->getMessage());
            return false; 
        }
    }
}