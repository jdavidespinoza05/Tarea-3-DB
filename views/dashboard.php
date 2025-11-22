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
$page_title = "Panel Principal";

// Incluimos la cabecera (incluye la barra de navegación)
include 'partials/header.php';
?>

<!-- Contenido Principal del Dashboard -->
<div class="container">
    <h1>Bienvenido, <?php echo htmlspecialchars($_SESSION['username']); ?></h1>
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
            <!-- En el paso 4 implementaremos facturas_pendientes.php -->
            <a href="facturas_pendientes.php" class="btn btn-primary" style="width: auto;">Ver Facturas</a>
        </div>

        <div class="card">
            <h2>Procesos Masivos</h2>
            <p>Ejecuta el proceso manual de facturación o carga y procesamiento del archivo XML.</p>
            <!-- En el paso 6 implementaremos proceso_xml.php -->
            <a href="proceso_xml.php" class="btn btn-primary" style="width: auto;">Ejecutar Procesos</a>
        </div>
        
    </div>
    
</div>

<?php 
// Incluimos el pie de página
include 'partials/footer.php';
?>