<?php
require_once __DIR__ . '/../db_connect.php'; 
require_once __DIR__ . '/../controllers/FacturacionController.php'; 
session_start();

// Verificación de seguridad
if (!isset($_SESSION['user_id']) || $_SESSION['role'] !== 'admin') {
    header('Location: ../index.php');
    exit;
}

$page_title = "Pagar Facturas Pendientes";
$finca = $_REQUEST['finca'] ?? ''; // Soporta GET y POST para mantener el valor
$mensaje = '';
$tipoMensaje = '';
$factura = null;

$controller = new FacturacionController($db_conn);

// --- PROCESAR PAGO (POST) ---
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['accion']) && $_POST['accion'] === 'pagar') {
    $medioPago = $_POST['medio_pago'] ?? 1;
    // Generar código aleatorio de comprobante
    $referencia = 'COMP-' . strtoupper(bin2hex(random_bytes(4))); 
    
    $resultado = $controller->pagarFacturaMasVieja($finca, $medioPago, $referencia);
    
    if ($resultado['success']) {
        $mensaje = $resultado['message'];
        $tipoMensaje = 'success';
        // No buscamos factura de nuevo inmediatamente para mostrar el mensaje limpio
    } else {
        $mensaje = $resultado['message'];
        $tipoMensaje = 'danger';
    }
}

// --- BUSCAR FACTURA (GET/POST si no hay éxito previo) ---
if (!empty($finca) && $tipoMensaje !== 'success') {
    $factura = $controller->getFacturaMasViejaPendiente($finca);
    if (!$factura) {
        $mensaje = "No se encontraron facturas pendientes para la finca: " . htmlspecialchars($finca);
        $tipoMensaje = 'warning';
    }
}

include 'partials/header.php';
?>

<div class="container">
    <h1>Gestión de Pagos</h1>
    
    <!-- Buscador -->
    <div class="card">
        <form method="GET" action="facturas_pendientes.php">
            <div class="form-group">
                <label>Número de Finca:</label>
                <input type="text" name="finca" value="<?php echo htmlspecialchars($finca); ?>" placeholder="Ej: F-0001" required>
            </div>
            <button type="submit" class="btn btn-primary">Buscar Facturas</button>
        </form>
    </div>

    <!-- Mensajes -->
    <?php if ($mensaje): ?>
        <div class="alert alert-<?php echo $tipoMensaje; ?>" style="margin-top: 20px;">
            <?php echo htmlspecialchars($mensaje); ?>
        </div>
    <?php endif; ?>

    <!-- Detalle de Factura a Pagar -->
    <?php if ($factura): 
        $diasMora = $factura['DiasMora'];
        $monto = $factura['MontoActual'];
        // Cálculo visual de intereses (solo informativo, el real lo hace el controlador)
        $interesEstimado = ($diasMora > 0) ? ($monto * 0.001333 * $diasMora) : 0;
        $totalEstimado = $monto + $interesEstimado;
    ?>
    <div class="card" style="margin-top: 20px; border-left: 5px solid var(--primary-color);">
        <h2>Factura Más Antigua Pendiente</h2>
        <div class="info-grid">
            <p><strong>ID Factura:</strong> <?php echo $factura['FacturaId']; ?></p>
            <p><strong>Fecha Emisión:</strong> <?php echo $factura['FechaFactura']; ?></p>
            <p><strong>Fecha Vencimiento:</strong> <?php echo $factura['FechaLimitePago']; ?></p>
            <p><strong>Días de Mora:</strong> <?php echo $diasMora > 0 ? "<span style='color:red'>$diasMora días</span>" : "Al día"; ?></p>
            <p><strong>Monto Original:</strong> ₡<?php echo number_format($factura['TotalAPagarOriginal'], 2); ?></p>
        </div>

        <hr>
        <h3>Total a Pagar: ₡<?php echo number_format($totalEstimado, 2); ?></h3>
        <?php if($diasMora > 0): ?>
            <small style="color: red;">* Incluye intereses moratorios estimados.</small>
        <?php endif; ?>

        <!-- Formulario de Pago -->
        <form method="POST" action="facturas_pendientes.php" style="margin-top: 20px;">
            <input type="hidden" name="accion" value="pagar">
            <input type="hidden" name="finca" value="<?php echo htmlspecialchars($finca); ?>">
            
            <div class="form-group">
                <label>Medio de Pago:</label>
                <select name="medio_pago">
                    <option value="1">Efectivo</option>
                    <option value="2">Tarjeta</option>
                </select>
            </div>

            <button type="submit" class="btn btn-primary" style="background-color: var(--success-color);">
                Confirmar Pago
            </button>
        </form>
    </div>
    <?php endif; ?>

</div>

<?php include 'partials/footer.php'; ?>