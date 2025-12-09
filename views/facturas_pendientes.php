<?php
require_once __DIR__ . '/../db_connect.php'; 
require_once __DIR__ . '/../controllers/FacturacionController.php'; 
session_start();

if (!isset($_SESSION['user_id'])) { header('Location: ../index.php'); exit; }

$finca = $_GET['finca'] ?? '';
$mensaje = '';
$tipoMensaje = '';
$controller = new FacturacionController($db_conn); // Instanciamos el controlador

// --- PROCESAR PAGO ---
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['pagar'])) {
    $medioPago = $_POST['medio_pago'] ?? 1;
    $fincaPagar = $_POST['finca_pagar']; 

    $resultado = $controller->pagarFacturaMasVieja($fincaPagar, $medioPago, 'WEB-'.uniqid());
    
    if ($resultado['success']) {
        $mensaje = $resultado['message'];
        $tipoMensaje = "success";
    } else {
        $mensaje = $resultado['message'];
        $tipoMensaje = "danger";
    }
}

// --- CONSULTAR DATOS ---
$listaFacturas = [];
$facturaPagar = null;

if ($finca) {
    // 1. Obtener LISTA COMPLETA para mostrar al usuario
    $listaFacturas = $controller->getTodasFacturasPendientes($finca);
    
    // 2. Obtener la MÁS VIEJA para procesar el pago (usamos la lógica que ya tenías)
    // Nota: Podríamos sacar esto del primer elemento de $listaFacturas[0] para optimizar,
    // pero mantenemos tu llamada al SP para asegurar consistencia con el cálculo de mora del SP.
    try {
        $sql = "EXEC SP_GetFacturaPendiente @NumeroFinca = :finca";
        $stmt = $db_conn->prepare($sql);
        $stmt->bindParam(':finca', $finca);
        $stmt->execute();
        $facturaPagar = $stmt->fetch(PDO::FETCH_ASSOC);
    } catch (Exception $e) { /* Error silencioso */ }
}

include 'partials/header.php';
?>

<div class="container">
    <h1>Facturación Pendiente</h1>
    
    <?php if (!$finca): ?>
        <div class="card">
            <form action="facturas_pendientes.php" method="GET">
                <label>Ingrese Finca:</label>
                <input type="text" name="finca" placeholder="Ej: F-0001">
                <button type="submit" class="btn btn-primary" style="margin-top:10px;">Buscar</button>
            </form>
        </div>
    <?php endif; ?>

    <?php if ($mensaje): ?>
        <div class="alert alert-<?php echo $tipoMensaje; ?>"><?php echo $mensaje; ?></div>
        <?php if ($tipoMensaje == 'success'): ?>
             <a href="propiedades.php" class="btn btn-primary">Volver a Propiedades</a>
             <?php if(count($listaFacturas) > 1): ?>
                <a href="facturas_pendientes.php?finca=<?php echo $finca; ?>" class="btn">Pagar Siguiente</a>
             <?php endif; ?>
        <?php endif; ?>
    <?php endif; ?>

    <?php if (!empty($listaFacturas) && empty($mensaje)): ?>
        <div class="card">
            <h3>Estado de Cuenta: Finca <?php echo htmlspecialchars($finca); ?></h3>
            <p>Se encontraron <strong><?php echo count($listaFacturas); ?></strong> facturas pendientes.</p>
            
            <table style="width:100%; border-collapse: collapse; margin-top:10px;">
                <thead style="background:#f8f9fa; text-align:left;">
                    <tr>
                        <th style="padding:10px; border-bottom:2px solid #ddd;"># Factura</th>
                        <th style="padding:10px; border-bottom:2px solid #ddd;">Vencimiento</th>
                        <th style="padding:10px; border-bottom:2px solid #ddd;">Monto Original</th>
                        <th style="padding:10px; border-bottom:2px solid #ddd;">Estado Mora</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($listaFacturas as $index => $f): ?>
                        <tr style="<?php echo $index === 0 ? 'background-color:#e8f4fd; font-weight:bold;' : ''; ?>">
                            <td style="padding:10px; border-bottom:1px solid #eee;">
                                <?php echo $f['FacturaId']; ?> 
                                <?php if($index === 0) echo '<span style="color:#0056b3; font-size:0.8em;">(A Pagar)</span>'; ?>
                            </td>
                            <td style="padding:10px; border-bottom:1px solid #eee;"><?php echo $f['FechaLimitePago']; ?></td>
                            <td style="padding:10px; border-bottom:1px solid #eee;">₡<?php echo number_format($f['TotalAPagarFinal'], 2); ?></td>
                            <td style="padding:10px; border-bottom:1px solid #eee; color: <?php echo $f['DiasMora'] > 0 ? 'red' : 'green'; ?>;">
                                <?php echo $f['DiasMora'] > 0 ? $f['DiasMora'] . ' días atraso' : 'Al día'; ?>
                            </td>
                        </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    <?php endif; ?>

    <?php if ($facturaPagar && empty($mensaje)): 
        $montoBase = $facturaPagar['MontoActual'];
        $diasMora = $facturaPagar['DiasMora'];
        $interesEstimado = 0;
        if ($diasMora > 0) {
            $interesEstimado = $montoBase * (0.04 / 30) * $diasMora;
        }
        $totalPagar = $montoBase + $interesEstimado;
    ?>
        <div class="card" style="border-left: 5px solid #0056b3; margin-top: 20px;">
            <h2 style="color: #0056b3;">Pagar Factura #<?php echo $facturaPagar['FacturaId']; ?></h2>
            
            <div style="background-color: #f1f3f5; padding: 20px; margin: 20px 0; border-radius: 8px;">
                <div style="display: flex; justify-content: space-between; margin-bottom: 5px;">
                    <span>Subtotal Factura:</span>
                    <strong>₡<?php echo number_format($montoBase, 2); ?></strong>
                </div>
                <?php if ($diasMora > 0): ?>
                <div style="display: flex; justify-content: space-between; color: #dc3545; margin-bottom: 5px;">
                    <span>+ Intereses Moratorios (<?php echo $diasMora; ?> días):</span>
                    <strong>₡<?php echo number_format($interesEstimado, 2); ?></strong>
                </div>
                <?php endif; ?>
                <hr>
                <div style="display: flex; justify-content: space-between; font-size: 1.2rem; color: #0056b3;">
                    <strong>TOTAL A PAGAR:</strong>
                    <strong>₡<?php echo number_format($totalPagar, 2); ?></strong>
                </div>
            </div>
            
            <form method="POST" action="facturas_pendientes.php?finca=<?php echo $finca; ?>">
                <input type="hidden" name="finca_pagar" value="<?php echo $finca; ?>">
                <input type="hidden" name="pagar" value="1">
                
                <div class="form-group">
                    <label>Seleccione Medio de Pago:</label>
                    <select name="medio_pago">
                        <option value="1">Efectivo</option>
                        <option value="2">Tarjeta de Crédito/Débito</option>
                    </select>
                </div>

                <div style="text-align: right; margin-top: 20px;">
                    <a href="propiedades.php" class="btn" style="background:#6c757d; color:white; margin-right:10px;">Cancelar</a>
                    <button type="submit" class="btn btn-primary">Confirmar Pago</button>
                </div>
            </form>
        </div>
    <?php elseif ($finca && empty($listaFacturas) && empty($mensaje)): ?>
        <div class="alert alert-success">¡Excelente! Esta propiedad está al día.</div>
        <a href="propiedades.php" class="btn btn-primary">Volver</a>
    <?php endif; ?>
</div>

<?php include 'partials/footer.php'; ?>