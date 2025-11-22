<?php
// Incluir la conexión a la base de datos (por si se necesita)
require_once __DIR__ . '/../db_connect.php'; 
session_start();

// Control de acceso: si no está logueado o no es 'admin', redirigir al login
if (!isset($_SESSION['user_id']) || $_SESSION['role'] !== 'admin') {
    header('Location: ../index.php');
    exit;
}

// Variables para el dashboard
$username = htmlspecialchars($_SESSION['username'] ?? 'Administrador');
$page_title = "Panel Principal";
?>

<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Administración | <?php echo $page_title; ?></title>
    <link rel="stylesheet" href="../css/styles.css">
</head>
<body>

    <header class="navbar">
        <div class="navbar-brand">Portal Administrativo</div>
        <nav class="navbar-nav">
            <a href="dashboard.php">Inicio</a>
            <a href="propiedades.php">Consulta de Propiedades</a>
            <a href="facturas_pendientes.php">Facturas Pendientes</a>
            <a href="crud_personas.php">CRUD Personas</a>
            <a href="proceso_xml.php">Proceso XML</a>
            <a href="logout.php" style="color: var(--danger-color);">Cerrar Sesión (<?php echo $username; ?>)</a>
        </nav>
    </header>

    <div class="container">
        <h1>Bienvenido, <?php echo $username; ?></h1>
        <p>Este es el panel central de administración para gestionar propiedades, facturación y procesos masivos.</p>

        <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; margin-top: 30px;">
            
            <div class="card">
                <h2>Búsqueda Rápida</h2>
                <p>Consulta el estado de una propiedad buscando por su número de finca o por el ID del propietario.</p>
                <a href="propiedades.php" class="btn btn-primary" style="width: auto;">Ir a Consultar</a>
            </div>

            <div class="card">
                <h2>Facturación Pendiente</h2>
                <p>Visualiza y gestiona el pago de facturas pendientes de servicio.</p>
                <a href="facturas_pendientes.php" class="btn btn-primary" style="width: auto;">Ver Facturas</a>
            </div>

            <div class="card">
                <h2>Procesos Masivos</h2>
                <p>Ejecuta el proceso manual de facturación o carga y procesamiento del archivo XML.</p>
                <a href="proceso_xml.php" class="btn btn-primary" style="width: auto;">Ejecutar Procesos</a>
            </div>
            
        </div>
        
    </div>
</body>
</html>