<?php
class FacturacionController {
    private $db;
    const CC_INTERES_ID = 6; // Ajusta este ID si en tu XML/BD es otro

    public function __construct($db) {
        $this->db = $db;
    }

    public function getFacturaMasViejaPendiente($numeroFinca) {
        try {
            // Llamamos al SP nuevo
            $sql = "EXEC SP_GetFacturaPendiente @NumeroFinca = :finca";
            $stmt = $this->db->prepare($sql);
            $stmt->bindParam(':finca', $numeroFinca);
            $stmt->execute();
            
            $resultado = $stmt->fetch(PDO::FETCH_ASSOC);
            return $resultado ?: null; // Si no hay nada, devuelve null

        } catch (PDOException $e) {
            error_log("Error trayendo factura: " . $e->getMessage());
            return null;
        }
    }

    public function pagarFacturaMasVieja($numeroFinca, $medioPagoId, $referencia) {
        $factura = $this->getFacturaMasViejaPendiente($numeroFinca);
        
        if (!$factura) {
            return ['success' => false, 'message' => 'No se encontraron facturas pendientes.'];
        }

        // Mapeamos los datos que vienen del SP
        $facturaId = $factura['FacturaId'];
        $monto = (float)$factura['MontoActual']; // Viene del SP
        $diasMora = (int)$factura['DiasMora'];   // Viene del SP

        try {
            $this->db->beginTransaction();

            // 1. Calcular Intereses si hay mora
            if ($diasMora > 0) {
                // Interés 4% mensual prorrateado
                $interes = $monto * 0.04 * ($diasMora / 30);
                $interes = round($interes, 2);

                if ($interes > 0) {
                    // Insertar CC Interés
                    $stmt = $this->db->prepare("INSERT INTO FacturaDetalle (FacturaId, CCId, Monto) VALUES (?, ?, ?)");
                    $stmt->execute([$facturaId, self::CC_INTERES_ID, $interes]);

                    // Actualizar Total
                    $monto += $interes;
                    $this->db->prepare("UPDATE Factura SET TotalAPagarFinal = ? WHERE FacturaId = ?")
                             ->execute([$monto, $facturaId]);
                }
            }

            // 2. Registrar Pago
            $sqlPago = "INSERT INTO Pago (FacturaId, FechaPago, TipoMedioPagoId, NumeroReferencia, MontoPagado) 
                        VALUES (?, CAST(GETDATE() AS DATE), ?, ?, ?)";
            $this->db->prepare($sqlPago)->execute([$facturaId, $medioPagoId, $referencia, $monto]);
            $pagoId = $this->db->lastInsertId();

            // 3. Comprobante
            $sqlComp = "INSERT INTO ComprobantePago (PagoId, Fecha, NumeroReferencia, Monto) 
                        VALUES (?, CAST(GETDATE() AS DATE), ?, ?)";
            $this->db->prepare($sqlComp)->execute([$pagoId, $referencia, $monto]);

            // 4. Actualizar Estado Factura
            $this->db->prepare("UPDATE Factura SET Estado = 2 WHERE FacturaId = ?")->execute([$facturaId]);

            // 5. Gestionar Reconexión (si aplica)
            $this->procesarReconexion($facturaId);

            $this->db->commit();
            return ['success' => true, 'message' => "Pago exitoso. Total cobrado: ₡" . number_format($monto, 2)];

        } catch (Exception $e) {
            $this->db->rollBack();
            return ['success' => false, 'message' => 'Error SQL: ' . $e->getMessage()];
        }
    }

    private function procesarReconexion($facturaId) {
        // Verifica si esta factura tenía orden de corte
        $sql = "SELECT OrdenCorteId FROM OrdenCorte WHERE FacturaId = ? AND Estado = 1";
        $stmt = $this->db->prepare($sql);
        $stmt->execute([$facturaId]);
        $corte = $stmt->fetch(PDO::FETCH_ASSOC);

        if ($corte) {
            // Crear reconexión
            $sqlRec = "INSERT INTO OrdenReconexion (OrdenCorteId, FechaReconexion) VALUES (?, CAST(GETDATE() AS DATE))";
            $this->db->prepare($sqlRec)->execute([$corte['OrdenCorteId']]);
            // Cerrar orden de corte
            $this->db->prepare("UPDATE OrdenCorte SET Estado = 2 WHERE OrdenCorteId = ?")
                     ->execute([$corte['OrdenCorteId']]);
        }
    }
}
?>