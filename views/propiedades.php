<?php
// ... imports y session ...
require_once __DIR__ . '/../db_connect.php'; 
require_once __DIR__ . '/../controllers/PropiedadController.php'; 
session_start();

if (!isset($_SESSION['user_id'])) { header('Location: ../index.php'); exit; }

$controller = new PropiedadController($db_conn);
$resultados = [];
$termino = $_POST['termino'] ?? '';

if ($_SERVER['REQUEST_METHOD'] === 'POST' && !empty($termino)) {
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
                    <div style="border-bottom: 2px solid #0056b3; margin-bottom: 15px; padding-bottom: 5px;">
                        <h3 style="margin:0; color: #0056b3;">Finca: <?php echo htmlspecialchars($prop['NumeroFinca']); ?></h3>
                    </div>
                    
                    <div class="info-grid">
                        <p><strong>Propietario(s):</strong><br> <?php echo htmlspecialchars($prop['Propietarios']); ?></p>
                        <p><strong>Medidor:</strong><br> <?php echo htmlspecialchars($prop['NumeroMedidor']); ?></p>                        
                        <p><strong>Área:</strong> <?php echo number_format($prop['MetrosCuadrados'], 2); ?> m²</p>
                        <p><strong>Valor Fiscal:</strong> ₡<?php echo number_format($prop['ValorFiscal'], 2); ?></p>
                        
                        <p style="grid-column: span 2;"><strong>Fecha Registro:</strong> <?php echo $prop['FechaRegistro']; ?></p>
                    </div>

                    <div style="margin-top: 20px; text-align: right;">
                        <a href="facturas_pendientes.php?finca=<?php echo $prop['NumeroFinca']; ?>" class="btn btn-success">
                            Gestionar Facturas
                        </a>
                    </div>
                </div>
            <?php endforeach; ?>
        </div>
    <?php elseif ($_SERVER['REQUEST_METHOD'] === 'POST'): ?>
        <div class="alert alert-warning">No se encontraron resultados.</div>
    <?php endif; ?>
</div>
<?php include 'partials/footer.php'; ?>