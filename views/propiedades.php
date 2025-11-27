<?php
// ... imports y session ...
require_once __DIR__ . '/../db_connect.php'; 
require_once __DIR__ . '/../controllers/PropiedadController.php'; 
session_start();

// Validar sesion...
if (!isset($_SESSION['user_id'])) { header('Location: ../index.php'); exit; }

$controller = new PropiedadController($db_conn);
$resultados = [];
$termino = $_POST['termino'] ?? ''; // Un solo input

if ($_SERVER['REQUEST_METHOD'] === 'POST' && !empty($termino)) {
    // Usamos la nueva funcion unificada
    $resultados = $controller->buscarPropiedad($termino);
}

include 'partials/header.php';
?>

<div class="container">
    <h1>Consulta de Propiedades</h1>
    <div class="card">
        <form method="POST" action="propiedades.php" style="display:flex; gap:10px;">
            <div style="flex:1">
                <label>Buscar por Finca o Cédula:</label>
                <input type="text" name="termino" value="<?php echo htmlspecialchars($termino); ?>" 
                       placeholder="Ej: F-0001 o 10000001" required>
            </div>
            <div style="align-self: flex-end;">
                <button type="submit" class="btn btn-primary">Buscar</button>
            </div>
        </form>
    </div>

    <?php if (!empty($resultados)): ?>
        <div style="display: grid; gap: 20px;">
            <?php foreach ($resultados as $prop): ?>
                <div class="card">
                    <h3><?php echo htmlspecialchars($prop['NumeroFinca']); ?></h3>
                    <p><strong>Propietario(s):</strong> <?php echo htmlspecialchars($prop['Propietarios']); ?></p>
                    <p><strong>Valor:</strong> ₡<?php echo number_format($prop['ValorFiscal'], 2); ?></p>
                    <a href="facturas_pendientes.php?finca=<?php echo $prop['NumeroFinca']; ?>" class="btn btn-success">Ver Facturas</a>
                </div>
            <?php endforeach; ?>
        </div>
    <?php elseif ($_SERVER['REQUEST_METHOD'] === 'POST'): ?>
        <div class="alert alert-warning">No se encontraron resultados.</div>
    <?php endif; ?>
</div>
<?php include 'partials/footer.php'; ?>