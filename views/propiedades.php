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
$search_finca = '';
$search_id = '';

// Si se envió el formulario de búsqueda
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $search_finca = trim($_POST['search_finca'] ?? '');
    $search_id = trim($_POST['search_id'] ?? '');

    // Se necesita al menos un criterio de búsqueda
    if (empty($search_finca) && empty($search_id)) {
        $search_error = 'Debe ingresar el número de Finca o el ID de Documento del Propietario para buscar.';
    } else {
        $controller = new PropiedadController($db_conn);
        
        // Determinar el método de búsqueda
        if (!empty($search_finca)) {
            $propiedades = $controller->getPropiedadByFinca($search_finca);
        } elseif (!empty($search_id)) {
            // Buscamos por ValorDocumento (identificación)
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

    <div class="card" style="max-width: none;">
        <h2>Buscar Propiedad</h2>
        <?php if (!empty($search_error)): ?>
            <div class="alert alert-danger"><?php echo htmlspecialchars($search_error); ?></div>
        <?php endif; ?>
        
        <form action="propiedades.php" method="POST">
            <div class="form-group" style="display: flex; gap: 20px;">
                <div style="flex: 1;">
                    <label for="search_finca">Buscar por Número de Finca:</label>
                    <input type="text" id="search_finca" name="search_finca" required 
                           placeholder="Ej: F-001" value="<?php echo htmlspecialchars($search_finca); ?>">
                </div>
                <div style="flex: 1;">
                    <label for="search_id">Buscar por ID de Documento de Propietario (ValorDocumento):</label>
                    <input type="text" id="search_id" name="search_id" required
                           placeholder="Ej: 10000001" value="<?php echo htmlspecialchars($search_id); ?>">
                </div>
            </div>
            <button type="submit" class="btn btn-primary">Buscar Propiedades</button>
        </form>
    </div>

    <?php if (!empty($propiedades)): ?>
        <h2 style="margin-top: 30px;">Resultados de la Búsqueda (<?php echo count($propiedades); ?> Encontradas)</h2>
        <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px;">
        <?php foreach ($propiedades as $propiedad): ?>
            <div class="card">
                <h3>Finca: <?php echo htmlspecialchars($propiedad['NumeroFinca']); ?></h3>
                
                <div class="info-grid">
                    <p><strong>ID Interno:</strong> <?php echo htmlspecialchars($propiedad['PropiedadId']); ?></p>
                    <p><strong>Medidor:</strong> <?php echo htmlspecialchars($propiedad['NumeroMedidor']); ?></p>
                    <p><strong>Área (m²):</strong> <?php echo htmlspecialchars(number_format($propiedad['MetrosCuadrados'], 2)); ?></p>
                    <p><strong>Valor Fiscal:</strong> ₡ <?php echo htmlspecialchars(number_format($propiedad['ValorFiscal'], 2)); ?></p>
                    <p><strong>Uso:</strong> <?php echo htmlspecialchars($propiedad['TipoUso']); ?></p>
                    <p><strong>Zona:</strong> <?php echo htmlspecialchars($propiedad['TipoZona']); ?></p>
                    <p class="span-2"><strong>Fecha Registro:</strong> <?php echo htmlspecialchars($propiedad['FechaRegistro']); ?></p>
                </div>
                
                <h4 style="margin-top: 15px; border-bottom: 1px solid #ddd; padding-bottom: 5px;">Propietarios (Activos)</h4>
                <p style="font-size: 0.9em;"><?php echo nl2br(htmlspecialchars($propiedad['Propietarios'] ?? 'N/A')); ?></p> 
                
                <h4 style="margin-top: 15px; border-bottom: 1px solid #ddd; padding-bottom: 5px;">Acciones</h4>
                <a href="facturas_pendientes.php?finca=<?php echo urlencode($propiedad['NumeroFinca']); ?>" class="btn btn-primary" style="width: auto; margin-top: 10px; background-color: var(--success-color);">Pagar Recibo más Viejo</a>
            </div>
        <?php endforeach; ?>
        </div>
    <?php endif; ?>

</div>

<?php include 'partials/footer.php'; ?>