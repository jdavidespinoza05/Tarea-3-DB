<?php
// Incluir la conexión y controladores
require_once __DIR__ . '/../db_connect.php'; 
require_once __DIR__ . '/../controllers/FacturacionController.php'; 
session_start();

// Control de acceso
if (!isset($_SESSION['user_id']) || $_SESSION['role'] !== 'admin') {
    header('Location: ../index.php');
    exit;
}

$page_title = "Gestión de Facturas Pendientes";
$controller = new FacturacionController($db_conn);
$facturas = [];
$finca = trim($_GET['finca'] ?? '');
$search_error = '';
$payment_result = null;

// --- Lógica de Procesamiento de Pago ---
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action']) && $_POST['action'] === 'pay') {
    $facturaId = (int)($_POST['factura_id'] ?? 0);
    $medioPagoId = (int)($_POST['medio_pago_id'] ?? 0);
    $referencia = trim($_POST['referencia'] ?? 'N/A');
    $finca = trim($_POST['numero_finca'] ?? '');

    if ($facturaId > 0 && $medioPagoId > 0) {
        $payment_result = $controller->procesarPagoFactura($facturaId, $medioPagoId, $referencia);
        // Si el pago fue exitoso, limpiamos la variable de finca para recargar la lista de pendientes actualizada
        if ($payment_result['success']) {
            $finca = ''; // Forzamos la recarga en el GET
            header("Location: facturas_pendientes.php?finca=" . urlencode($_POST['numero_finca']) . "&status=paid");
            exit;
        }
    } else {
        $payment_result = ['success' => false, 'message' => 'Datos de pago incompletos.'];
    }
}

// --- Lógica de Carga de Facturas ---
if (!empty($finca)) {
    $facturas = $controller->getFacturasPendientesByFinca($finca);
    if (empty($facturas)) {
        $search_error = "No hay facturas pendientes para la propiedad Finca: " . htmlspecialchars($finca);
    }
} else {
     $search_error = "Ingrese el número de finca para consultar facturas pendientes.";
}

// Mensaje de éxito después de un pago
if (isset($_GET['status']) && $_GET['status'] === 'paid') {
    $payment_result = ['success' => true, 'message' => 'La factura más antigua ha sido pagada con éxito.'];
}


include 'partials/header.php';
?>

<div class="container">
    <h1><?php echo $page_title; ?></h1>
    <p>Consulte las facturas pendientes por número de Finca y procese el pago del recibo más antiguo.</p>
    
    <!-- Formulario de Búsqueda de Finca (Si no hay finca seleccionada) -->
    <div class="card" style="margin-bottom: 20px;">
        <h2>Buscar Finca</h2>
        <form action="facturas_pendientes.php" method="GET">
            <div class="form-group">
                <label for="finca_search">Número de Finca:</label>
                <input type="text" id="finca_search" name="finca" required placeholder="Ej: F-001" value="<?php echo htmlspecialchars($finca); ?>">
            </div>
            <button type="submit" class="btn btn-primary">Consultar Facturas</button>
        </form>
    </div>

    <!-- Mensajes de Estado (Error/Éxito) -->
    <?php if (!empty($search_error)): ?>
        <div class="alert alert-danger"><?php echo htmlspecialchars($search_error); ?></div>
    <?php endif; ?>

    <?php if ($payment_result): ?>
        <div class="alert <?php echo $payment_result['success'] ? 'alert-success' : 'alert-danger'; ?>">
            <?php echo htmlspecialchars($payment_result['message']); ?>
        </div>
    <?php endif; ?>

    <!-- Contenido de Facturas -->
    <?php if (!empty($facturas)): ?>
        
        <h2>Facturas Pendientes para Finca: <?php echo htmlspecialchars($finca); ?></h2>

        <!-- Formulario de Pago (Siempre para la factura más antigua) -->
        <?php $factura_a_pagar = $facturas[0]; ?>
        <div class="card" style="border: 2px solid var(--primary-color); background-color: #e6e6fa; margin-bottom: 30px;">
            <h3>PAGO REQUERIDO (Factura Más Antigua)</h3>
            <p><strong>Factura ID:</strong> <?php echo $factura_a_pagar['FacturaId']; ?></p>
            <p><strong>Fecha de Facturación:</strong> <?php echo $factura_a_pagar['FechaFactura']; ?></p>
            <p><strong>Límite de Pago:</strong> <?php echo $factura_a_pagar['FechaLimitePago']; ?></p>
            <p style="font-size: 1.2em; font-weight: bold; color: <?php echo $factura_a_pagar['TieneMora'] ? 'var(--danger-color)' : 'var(--primary-color)'; ?>;">
                Monto Original: ₡ <?php echo number_format($factura_a_pagar['TotalAPagarOriginal'], 2); ?>
            </p>

            <h3 style="color: <?php echo $factura_a_pagar['TieneMora'] ? 'var(--danger-color)' : 'var(--success-color)'; ?>;">
                Total a Pagar (Incluye Mora*): ₡ <?php echo number_format($factura_a_pagar['TotalAPagarFinal'], 2); ?>
            </h3>
            
            <?php if ($factura_a_pagar['TieneMora']): ?>
                <p style="color: var(--danger-color); font-weight: bold; font-size: 0.9em;">* Esta factura está en mora. Los intereses serán recalculados al momento de procesar el pago.</p>
            <?php endif; ?>

            <form action="facturas_pendientes.php" method="POST" onsubmit="return confirm('¿Confirma el pago de la Factura ID <?php echo $factura_a_pagar['FacturaId']; ?> por ₡<?php echo number_format($factura_a_pagar['TotalAPagarFinal'], 2); ?>?');">
                <input type="hidden" name="action" value="pay">
                <input type="hidden" name="factura_id" value="<?php echo $factura_a_pagar['FacturaId']; ?>">
                <input type="hidden" name="numero_finca" value="<?php echo htmlspecialchars($finca); ?>">

                <div class="form-group">
                    <label>Medio de Pago:</label>
                    <select name="medio_pago_id" required class="full-width-select">
                        <option value="">Seleccione...</option>
                        <option value="1">1: Efectivo</option>
                        <option value="2">2: Tarjeta bancaria</option>
                        <!-- Se pueden cargar dinámicamente desde TipoMedioPago si es necesario -->
                    </select>
                </div>

                 <div class="form-group">
                    <label for="referencia">Referencia/Comprobante (Opcional):</label>
                    <input type="text" id="referencia" name="referencia" placeholder="Número de referencia de pago">
                </div>

                <button type="submit" class="btn btn-primary" style="background-color: var(--success-color); width: 100%;">CONFIRMAR PAGO</button>
            </form>
        </div>
        
        <!-- Lista de otras facturas pendientes -->
        <?php if (count($facturas) > 1): ?>
            <h3 style="margin-top: 40px; border-bottom: 2px solid #ccc; padding-bottom: 10px;">Otras Facturas Pendientes (<?php echo count($facturas) - 1; ?>)</h3>
            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 15px;">
            <?php 
            // Iteramos desde el segundo elemento (índice 1)
            for ($i = 1; $i < count($facturas); $i++): 
                $f = $facturas[$i];
            ?>
                <div class="card" style="background-color: #f0f0f0;">
                    <p><strong>ID:</strong> <?php echo $f['FacturaId']; ?></p>
                    <p><strong>Fecha Factura:</strong> <?php echo $f['FechaFactura']; ?></p>
                    <p><strong>Monto:</strong> ₡ <?php echo number_format($f['TotalAPagarFinal'], 2); ?></p>
                    <p style="color: <?php echo $f['TieneMora'] ? 'var(--danger-color)' : 'var(--secondary-color)'; ?>; font-weight: bold;">
                        <?php echo $f['TieneMora'] ? '¡EN MORA!' : 'Pendiente'; ?>
                    </p>
                </div>
            <?php endfor; ?>
            </div>
        <?php endif; ?>

    <?php endif; ?>

</div>

<?php 
include 'partials/footer.php';
?>