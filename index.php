<?php
// Iniciar la sesión para manejar el estado del usuario
session_start();

// Incluir la conexión a la base de datos. Si falla, el script muere aquí.
// Esto garantiza que el portal solo se ejecute si la BD está accesible.
require_once __DIR__ . '/db_connect.php';

// Si el usuario ya está logueado, redirigir al panel de administración
if (isset($_SESSION['user_id'])) {
    header('Location: views/dashboard.php');
    exit;
}

$error_message = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $username = trim($_POST['username'] ?? '');
    $password = $_POST['password'] ?? '';

    // Lógica de Autenticación (Se reemplazará con consulta a BD en el siguiente paso)
    // Por ahora, solo simula un login exitoso.
    if ($username === 'admin' && $password === 'admin123') {
        // En un entorno real, aquí se consultaría la tabla de Usuarios para autenticar.
        // Simulamos un ID de usuario y rol de administrador.
        $_SESSION['user_id'] = 1; 
        $_SESSION['username'] = $username;
        $_SESSION['role'] = 'admin';

        // Redirigir al panel de administración
        header('Location: views/dashboard.php');
        exit;
    } else {
        $error_message = 'Credenciales incorrectas. (Usuario de prueba: admin / admin123)';
    }
}
?>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Acceso Administrador - Municipalidad</title>
    <link rel="stylesheet" href="css/styles.css">
</head>
<body>
    <!-- Contenedor principal de autenticación -->
    <div class="auth-container">
        <div class="card">
            <h1>Acceso al Portal Administrativo</h1>
            <p style="text-align: center; color: var(--secondary-color);">Municipalidad - Gestión de Servicios</p>

            <?php if (!empty($error_message)): ?>
                <div class="alert alert-danger"><?php echo htmlspecialchars($error_message); ?></div>
            <?php endif; ?>

            <form action="index.php" method="POST">
                
                <div class="form-group">
                    <label for="username">Usuario:</label>
                    <input type="text" id="username" name="username" required 
                           value="<?php echo htmlspecialchars($username ?? ''); ?>" 
                           placeholder="Nombre de usuario o Email">
                </div>

                <div class="form-group">
                    <label for="password">Contraseña:</label>
                    <input type="password" id="password" name="password" required 
                           placeholder="Contraseña">
                </div>

                <button type="submit" class="btn btn-primary">Iniciar Sesión</button>
            </form>
        </div>
    </div>
</body>
</html>