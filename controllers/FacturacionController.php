<?php
/**
 * FacturacionController.php
 * Maneja las consultas de facturas y la lógica de pago.
 */
class FacturacionController {
    private $db;

    // Constantes para el Estado de Factura (Basado en la tabla Factura, campo Estado)
    const ESTADO_PENDIENTE = 1;
    const ESTADO_PAGADO = 2;
    
    // Constante para el Concepto de Cobro (CC) de Intereses Moratorios (asumiendo un ID fijo)
    // ESTO DEBE VENIR DE LA BD, PERO ASUMIMOS 99 POR AHORA
    const CC_INTERESES_MORATORIOS_ID = 99; 

    public function __construct($db_connection) {
        $this->db = $db_connection;
    }

    /**
     * Obtiene todas las facturas pendientes de una propiedad, ordenadas por la fecha más antigua.
     * @param string $numeroFinca
     * @return array
     */
    public function getFacturasPendientesByFinca($numeroFinca) {
        $sql = "
            SELECT 
                f.FacturaId, f.FechaFactura, f.FechaLimitePago, f.FechaLimiteCorte, f.Estado,
                f.TotalAPagarOriginal, f.TotalAPagarFinal,
                p.NumeroFinca, p.PropiedadId,
                -- Calculamos si la factura tiene mora (fecha límite de pago ya pasó)
                CASE WHEN f.FechaLimitePago < CAST(GETDATE() AS DATE) THEN 1 ELSE 0 END AS TieneMora
            FROM Factura f
            JOIN Propiedad p ON f.PropiedadId = p.PropiedadId
            WHERE p.NumeroFinca = :finca AND f.Estado = :estado_pendiente
            ORDER BY f.FechaFactura ASC, f.FacturaId ASC
        ";

        try {
            $stmt = $this->db->prepare($sql);
            $stmt->bindParam(':finca', $numeroFinca, PDO::PARAM_STR);
            $stmt->bindParam(':estado_pendiente', self::ESTADO_PENDIENTE, PDO::PARAM_INT);
            $stmt->execute();
            
            return $stmt->fetchAll(PDO::FETCH_ASSOC);
            
        } catch (PDOException $e) {
            error_log("Error al buscar facturas pendientes: " . $e->getMessage());
            return [];
        }
    }
    
    /**
     * Simula el proceso de pago para la factura pendiente más antigua.
     * Implementa la lógica de cálculo y aplicación de intereses moratorios si aplica.
     * @param int $facturaId ID de la factura a pagar.
     * @param int $tipoMedioPagoId ID del medio de pago (1=Efectivo, 2=Tarjeta).
     * @param string $referencia Número de referencia del comprobante.
     * @return array Resultado del pago con mensaje.
     */
    public function procesarPagoFactura($facturaId, $tipoMedioPagoId, $referencia) {
        if (!$this->db) {
            return ['success' => false, 'message' => 'Error de conexión a la base de datos.'];
        }

        try {
            // 1. INICIAR TRANSACCIÓN (Para asegurar atomicidad)
            $this->db->beginTransaction();

            // 2. OBTENER DETALLE DE LA FACTURA
            $sqlFactura = "SELECT FacturaId, PropiedadId, FechaFactura, FechaLimitePago, TotalAPagarFinal 
                           FROM Factura 
                           WHERE FacturaId = :id AND Estado = :estado_pendiente";
            $stmt = $this->db->prepare($sqlFactura);
            $stmt->bindParam(':id', $facturaId, PDO::PARAM_INT);
            $stmt->bindParam(':estado_pendiente', self::ESTADO_PENDIENTE, PDO::PARAM_INT);
            $stmt->execute();
            $factura = $stmt->fetch(PDO::FETCH_ASSOC);

            if (!$factura) {
                $this->db->rollBack();
                return ['success' => false, 'message' => 'Factura no encontrada o ya ha sido pagada.'];
            }

            $montoPago = $factura['TotalAPagarFinal'];
            $tieneMora = (strtotime($factura['FechaLimitePago']) < time());
            $interesesCalculados = 0; // Inicializamos los intereses

            // 3. CALCULAR INTERESES MORATORIOS (SI APLICA)
            if ($tieneMora) {
                // Lógica de cálculo de intereses (SIMULADO - Se requiere el parámetro de tasa)
                // Usamos un 5% de interés moratorio simple sobre el TotalAPagarFinal.
                $interesesCalculados = round($factura['TotalAPagarFinal'] * 0.05, 2);
                $montoPago += $interesesCalculados;

                // 3.1. INSERTAR DETALLE DE INTERESES EN FacturaDetalle
                // Asumimos que el CC_INTERESES_MORATORIOS_ID ya existe en ConceptoCobro.
                $sqlDetalle = "
                    INSERT INTO FacturaDetalle (FacturaId, CCId, Monto) 
                    VALUES (:factura_id, :cc_id, :monto)
                ";
                $stmtDetalle = $this->db->prepare($sqlDetalle);
                $stmtDetalle->bindParam(':factura_id', $facturaId, PDO::PARAM_INT);
                $stmtDetalle->bindParam(':cc_id', self::CC_INTERESES_MORATORIOS_ID, PDO::PARAM_INT);
                $stmtDetalle->bindParam(':monto', $interesesCalculados);
                $stmtDetalle->execute();
                
                // 3.2. ACTUALIZAR EL TOTAL FINAL A PAGAR EN Factura
                $sqlUpdateFactura = "
                    UPDATE Factura SET TotalAPagarFinal = :nuevo_total
                    WHERE FacturaId = :factura_id
                ";
                $stmtUpdate = $this->db->prepare($sqlUpdateFactura);
                $stmtUpdate->bindParam(':nuevo_total', $montoPago);
                $stmtUpdate->bindParam(':factura_id', $facturaId, PDO::PARAM_INT);
                $stmtUpdate->execute();
            }

            // 4. INSERTAR REGISTRO DE PAGO
            $sqlPago = "
                INSERT INTO Pago (FacturaId, FechaPago, TipoMedioPagoId, NumeroReferencia, MontoPagado) 
                VALUES (:factura_id, CAST(GETDATE() AS DATE), :medio_pago_id, :referencia, :monto_pagado)
            ";
            $stmtPago = $this->db->prepare($sqlPago);
            $stmtPago->bindParam(':factura_id', $facturaId, PDO::PARAM_INT);
            $stmtPago->bindParam(':medio_pago_id', $tipoMedioPagoId, PDO::PARAM_INT);
            $stmtPago->bindParam(':referencia', $referencia, PDO::PARAM_STR);
            $stmtPago->bindParam(':monto_pagado', $montoPago);
            $stmtPago->execute();
            $pagoId = $this->db->lastInsertId(); // Obtener el ID del Pago recién creado

            // 5. ACTUALIZAR ESTADO DE LA FACTURA A PAGADO
            $sqlUpdateEstado = "
                UPDATE Factura SET Estado = :estado_pagado
                WHERE FacturaId = :factura_id
            ";
            $stmtUpdateEstado = $this->db->prepare($sqlUpdateEstado);
            $stmtUpdateEstado->bindParam(':estado_pagado', self::ESTADO_PAGADO, PDO::PARAM_INT);
            $stmtUpdateEstado->bindParam(':factura_id', $facturaId, PDO::PARAM_INT);
            $stmtUpdateEstado->execute();

            // 6. CREAR COMPROBANTE DE PAGO
            // El enunciado pide un código aleatorio para el comprobante.
            $numeroComprobante = 'CP-' . date('YmdHis') . '-' . rand(100, 999);
            $sqlComprobante = "
                INSERT INTO ComprobantePago (PagoId, Fecha, NumeroReferencia, Monto)
                VALUES (:pago_id, CAST(GETDATE() AS DATE), :referencia_cp, :monto)
            ";
            $stmtComprobante = $this->db->prepare($sqlComprobante);
            $stmtComprobante->bindParam(':pago_id', $pagoId, PDO::PARAM_INT);
            $stmtComprobante->bindParam(':referencia_cp', $numeroComprobante, PDO::PARAM_STR);
            $stmtComprobante->bindParam(':monto', $montoPago);
            $stmtComprobante->execute();

            // 7. COMPROMETER LA TRANSACCIÓN
            $this->db->commit();
            
            $mora_text = $tieneMora ? " (Intereses moratorios aplicados: ₡" . number_format($interesesCalculados, 2) . ")" : "";

            return [
                'success' => true, 
                'message' => '¡Pago procesado con éxito!' . $mora_text,
                'comprobante' => $numeroComprobante,
                'monto_pagado' => $montoPago
            ];

        } catch (PDOException $e) {
            // Revertir la transacción en caso de error
            if ($this->db->inTransaction()) {
                $this->db->rollBack();
            }
            error_log("Error fatal en el proceso de pago: " . $e->getMessage());
            return ['success' => false, 'message' => 'Error del sistema al procesar el pago. Intente de nuevo.'];
        }
    }
}