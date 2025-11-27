<?php
require_once __DIR__ . '/../db_connect.php'; 
session_start();

if (!isset($_SESSION['user_id']) || $_SESSION['role'] !== 'admin') {
    header('Location: ../index.php');
    exit;
}

$page_title = "Procesamiento Masivo";
$mensaje = '';
$tipoMensaje = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_FILES['archivo_xml'])) {
    $file = $_FILES['archivo_xml'];
    
    // Validar subida
    if ($file['error'] === UPLOAD_ERR_OK) {
        $ext = pathinfo($file['name'], PATHINFO_EXTENSION);
        if (strtolower($ext) === 'xml') {
            
            $xmlContent = file_get_contents($file['tmp_name']);

            // --- CORRECCIÓN CRÍTICA PARA SQL SERVER ---
            // SQL Server falla si le pasas un string con 'encoding="UTF-8"' porque lo trata como UCS-2.
            // Simplemente eliminamos la declaración de encoding del string.
            $xmlContent = str_replace('encoding="UTF-8"', '', $xmlContent);
            $xmlContent = str_replace("encoding='UTF-8'", "", $xmlContent);
            
            try {
                // Aumentar tiempo de ejecución para archivos grandes
                set_time_limit(300); 

                // 2. LLAMAR AL STORED PROCEDURE MASIVO
                // Tu SP se llama SP_ProcesarXMLCompleto y recibe @XML
                $sql = "EXEC SP_ProcesarXMLCompleto @XML = :xmlData";
                $stmt = $db_conn->prepare($sql);
                $stmt->bindParam(':xmlData', $xmlContent, PDO::PARAM_STR);
                
                $stmt->execute();
                
                $mensaje = "¡Éxito! El archivo XML fue procesado y la simulación completada.";
                $tipoMensaje = "success";

            } catch (PDOException $e) {
                $mensaje = "Error de Base de Datos: " . $e->getMessage();
                $tipoMensaje = "danger";
            }
        } else {
            $mensaje = "Por favor suba un archivo .xml válido.";
            $tipoMensaje = "warning";
        }
    } else {
        $mensaje = "Error al subir el archivo. Código: " . $file['error'];
        $tipoMensaje = "danger";
    }
}

include 'partials/header.php';
?>

<div class="container">
    <h1>Carga de Simulación (XML)</h1>
    <p>Este proceso leerá el archivo de operaciones, insertará personas, propiedades, lecturas y ejecutará la facturación masiva día por día.</p>

    <div class="card">
        <form action="proceso_xml.php" method="POST" enctype="multipart/form-data">
            <div class="form-group">
                <label for="archivo_xml">Seleccionar Archivo (archivoDatos.xml):</label>
                <input type="file" name="archivo_xml" id="archivo_xml" accept=".xml" required>
            </div>
            <button type="submit" class="btn btn-primary">Iniciar Simulación</button>
        </form>
    </div>

    <?php if ($mensaje): ?>
        <div class="alert alert-<?php echo $tipoMensaje; ?>">
            <?php echo htmlspecialchars($mensaje); ?>
        </div>
    <?php endif; ?>
</div>

<?php include 'partials/footer.php'; ?>