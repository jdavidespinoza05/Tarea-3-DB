<?php
/**
 * FacturacionController.php
 * Maneja la lógica de negocio para facturación y pagos.
 */
class FacturacionController {
    private $db;

    // Constantes de Estado según tu esquema
    const ESTADO_PENDIENTE = 1;
    const ESTADO_PAGADO = 2;
    
    // ID del Concepto de Cobro para Intereses Moratorios (Asegúrate de que exista en tu BD o cámbialo)
    // Se asume que existe un CC con ID 99 o similar para "Intereses Moratorios"
    const CC_INTERES_MORATORIO = 10; // Ajusta este ID según tus datos del XML (ej: un ID que no choque)

    public function __construct($db_connection) {
        $this->db = $db_connection;
    }

    /**
     * Obtiene la factura pendiente más antigua para un número de finca.
     */
    public function getFacturaMasViejaPendiente($numeroFinca) {
        $sql = "
            SELECT TOP 1 
                f.FacturaId, 
                f.FechaFactura, 
                f.FechaLimitePago, 
                f.TotalAPagarFinal AS MontoActual,
                f.TotalAPagarOriginal,
                p.NumeroFinca,
                -- Calcula días pasados desde la fecha límite
                DATEDIFF(day, f.FechaLimitePago, CAST(GETDATE() AS DATE)) AS DiasMora
            FROM Factura f
            JOIN Propiedad p ON f.PropiedadId = p.PropiedadId
            WHERE p.NumeroFinca = :finca AND f.Estado = :estado
            ORDER BY f.FechaFactura ASC
        ";

        try {
            $stmt = $this->db->prepare($sql);
            $stmt->bindParam(':finca', $numeroFinca, PDO::PARAM_STR);
            $stmt->bindValue(':estado', self::ESTADO_PENDIENTE, PDO::PARAM_INT);
            $stmt->execute();
            return $stmt->fetch(PDO::FETCH_ASSOC);
        } catch (PDOException $e) {
            error_log("Error al obtener factura: " . $e->getMessage());
            return null;
        }
    }

    /**
     * Realiza el pago de la factura más vieja pendiente.
     * Aplica intereses moratorios si aplica.
     */
    public function pagarFacturaMasVieja($numeroFinca, $tipoMedioPagoId, $numeroReferencia) {
        $factura = $this->getFacturaMasViejaPendiente($numeroFinca);

        if (!$factura) {
            return ['success' => false, 'message' => 'No hay facturas pendientes para la finca ' . htmlspecialchars($numeroFinca)];
        }

        $facturaId = $factura['FacturaId'];
        $diasMora = $factura['DiasMora'];
        $montoPagar = (float)$factura['MontoActual'];
        
        // Configuración de intereses (Ejemplo: 1% mensual = 0.033% diario aprox, ajusta según requerimiento)
        $tasaDiaria = 0.00033; 
        $interesAplicado = 0.0;
        $hayInteres = false;

        try {
            $this->db->beginTransaction();

            // 1. Calcular e insertar Interés Moratorio si hay mora (> 0 días después de fecha límite)
            if ($diasMora > 0) {
                $interesAplicado = round($montoPagar * $tasaDiaria * $diasMora, 2);
                $montoPagar += $interesAplicado;
                $hayInteres = true;

                // Insertar detalle de factura por el interés
                $sqlDetalle = "INSERT INTO FacturaDetalle (FacturaId, CCId, Monto) VALUES (:fid, :ccid, :monto)";
                $stmtDet = $this->db->prepare($sqlDetalle);
                $stmtDet->bindValue(':fid', $facturaId);
                $stmtDet->bindValue(':ccid', self::CC_INTERES_MORATORIO);
                $stmtDet->bindValue(':monto', $interesAplicado);
                $stmtDet->execute();
            }

            // 2. Actualizar Factura (Total Final y Estado)
            $sqlFactura = "UPDATE Factura SET Estado = :pagado, TotalAPagarFinal = :total WHERE FacturaId = :fid";
            $stmtF = $this->db->prepare($sqlFactura);
            $stmtF->bindValue(':pagado', self::ESTADO_PAGADO);
            $stmtF->bindValue(':total', $montoPagar);
            $stmtF->bindValue(':fid', $facturaId);
            $stmtF->execute();

            // 3. Crear Registro de Pago
            $sqlPago = "INSERT INTO Pago (FacturaId, FechaPago, TipoMedioPagoId, NumeroReferencia, MontoPagado) 
                        VALUES (:fid, CAST(GETDATE() AS DATE), :mediopago, :ref, :monto)";
            $stmtP = $this->db->prepare($sqlPago);
            $stmtP->bindValue(':fid', $facturaId);
            $stmtP->bindValue(':mediopago', $tipoMedioPagoId);
            $stmtP->bindValue(':ref', $numeroReferencia);
            $stmtP->bindValue(':monto', $montoPagar);
            $stmtP->execute();

            $pagoId = $this->db->lastInsertId();

            // 4. Crear Comprobante de Pago
            // Se usa el mismo número de referencia del pago para el comprobante o uno nuevo
            $sqlComp = "INSERT INTO ComprobantePago (PagoId, Fecha, NumeroReferencia, Monto) 
                        VALUES (:pid, CAST(GETDATE() AS DATE), :ref, :monto)";
            $stmtC = $this->db->prepare($sqlComp);
            $stmtC->bindValue(':pid', $pagoId);
            $stmtC->bindValue(':ref', $numeroReferencia); // Código aleatorio generado en la vista
            $stmtC->bindValue(':monto', $montoPagar);
            $stmtC->execute();

            $this->db->commit();

            $msg = "Pago realizado con éxito. Monto: ₡" . number_format($montoPagar, 2);
            if($hayInteres) $msg .= " (Incluye intereses por mora: ₡" . number_format($interesAplicado, 2) . ")";

            return ['success' => true, 'message' => $msg, 'comprobante' => $numeroReferencia];

        } catch (Exception $e) {
            $this->db->rollBack();
            return ['success' => false, 'message' => 'Error en transacción: ' . $e->getMessage()];
        }
    }
}