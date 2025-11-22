<?php
// Incluir la conexión y verificar la sesión
require_once __DIR__ . '/../db_connect.php'; 
require_once __DIR__ . '/../controllers/PropiedadController.php'; 
session_start();

// Control de acceso: si no está logueado o no es 'admin', redirigir al login
if (!isset($_SESSION['user_id']) || $_SESSION['role'] !== 'admin') {
    header('Location: ../index.php');
    exit;
}

$page_title = "Consulta de Propiedades";
$propiedades = [];
$search_error = '';

// Si se envió el formulario de búsqueda
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $search_finca = trim($_POST['search_finca'] ?? '');
    $search_id = trim($_POST['search_id'] ?? '');

    // Se necesita al menos un criterio de búsqueda
    if (empty($search_finca) && empty($search_id)) {
        $search_error = 'Debe ingresar el número de Finca o el ID del Propietario para buscar.';
    } else {
        $controller = new PropiedadController($db_conn);
        
        // Determinar el método de búsqueda
        if (!empty($search_finca)) {
            $propiedades = $controller->getPropiedadByFinca($search_finca);
        } elseif (!empty($search_id)) {
            $propiedades = $controller->getPropiedadByIdPropietario($search_id);
        }

        if (empty($propiedades)) {
             $search_error = 'No se encontraron propiedades con el criterio de búsqueda proporcionado.';
        }
    }
}

// Incluimos la barra de navegación para reusar el HTML
include 'partials/header.php';
?>

<div class="container">
    <h1><?php echo $page_title; ?></h1>
    <p>Utilice esta interfaz para buscar propiedades y ver el detalle de sus propietarios y servicios.</p>

    <!-- Formulario de Búsqueda -->
    <div class="card" style="max-width: none;">
        <h2>Buscar Propiedad</h2>
        <?php if (!empty($search_error)): ?>
            <div class="alert alert-danger"><?php echo htmlspecialchars($search_error); ?></div>
        <?php endif; ?>
        
        <form action="propiedades.php" method="POST">
            <div class="form-group" style="display: flex; gap: 20px;">
                <div style="flex: 1;">
                    <label for="search_finca">Buscar por Número de Finca:</label>
                    <input type="text" id="search_finca" name="search_finca" placeholder="Ej: F-001">
                </div>
                <div style="flex: 1;">
                    <label for="search_id">Buscar por ID de Propietario:</label>
                    <input type="text" id="search_id" name="search_id" placeholder="Ej: 10000001">
                </div>
            </div>
            <button type="submit" class="btn btn-primary">Buscar Propiedades</button>
        </form>
    </div>

    <!-- Resultados de la Búsqueda -->
    <?php if (!empty($propiedades)): ?>
        <h2 style="margin-top: 30px;">Resultados de la Búsqueda</h2>
        <div style="display: grid; grid-template-columns: 1fr; gap: 20px;">
        <?php foreach ($propiedades as $propiedad): ?>
            <div class="card">
                <h3>Propiedad Finca: <?php echo htmlspecialchars($propiedad['NumeroFinca']); ?></h3>
                <p><strong>ID Interno:</strong> <?php echo htmlspecialchars($propiedad['PropiedadId']); ?></p>
                <p><strong>Área (m²):</strong> <?php echo htmlspecialchars($propiedad['Area']); ?></p>
                <p><strong>Uso:</strong> <?php echo htmlspecialchars($propiedad['TipoUso']); ?></p>
                <p><strong>Dirección:</strong> <?php echo htmlspecialchars($propiedad['Direccion']); ?></p>
                
                <h4 style="margin-top: 15px; border-bottom: 1px solid #ddd; padding-bottom: 5px;">Propietarios Asociados</h4>
                <!-- Aquí se listaría el detalle de propietarios. Por ahora, solo indicamos el PropietarioID. -->
                <p>Propietarios IDs: <?php echo htmlspecialchars($propiedad['PropietarioIDs'] ?? 'N/A'); ?></p> 
                
                <h4 style="margin-top: 15px; border-bottom: 1px solid #ddd; padding-bottom: 5px;">Facturación</h4>
                <!-- En el Paso 4, mostraremos el enlace para ver/pagar facturas -->
                <a href="facturas_pendientes.php?finca=<?php echo urlencode($propiedad['NumeroFinca']); ?>" class="btn btn-primary" style="width: auto; margin-top: 10px; background-color: var(--success-color);">Ver Facturas Pendientes</a>
            </div>
        <?php endforeach; ?>
        </div>
    <?php endif; ?>

</div>

<!-- Incluimos el footer para cerrar la etiqueta body/html si es necesario -->
<?php include 'partials/footer.php'; ?>