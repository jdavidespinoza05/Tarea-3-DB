<?php
// Evita el acceso directo al parcial
if (basename($_SERVER['PHP_SELF']) == basename(__FILE__)) {
    // Redireccionar si se accede directamente a un parcial
    // (Opcional, pero buena práctica)
    // header('Location: dashboard.php'); 
    // exit;
}
// Se asume que $page_title y $username están definidos en el archivo principal
$username = htmlspecialchars($_SESSION['username'] ?? 'Administrador'); 
?>

<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Administración | <?php echo htmlspecialchars($page_title ?? 'Portal Administrativo'); ?></title>
    <!-- La ruta del CSS es relativa al index.php (../css) o al dashboard/views (../css) -->
    <link rel="stylesheet" href="../css/styles.css"> 
</head>
<body>

    <!-- Barra de Navegación (Navbar) -->
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

    <!-- El div.container se abre en el archivo principal -->