<?php
// Muestra una imagen cifrada con SSE-KMS guardada en S3 (script del enunciado).
//
// Cambios respecto al enunciado:
//  - Sin claves de acceso en el código: el SDK usa su cadena de credenciales
//    (perfil con AWS_PROFILE, variables de entorno o rol).
//  - Bucket, objeto y región por variables de entorno.
//  - El objeto NO se elige por parámetro de la URL: solo se sirve el configurado,
//    para que la página no sirva cualquier objeto del bucket.
//  - El mensaje de error no se imprime crudo (evita XSS) y devuelve 403/500.

require __DIR__ . '/../vendor/autoload.php';

use Aws\Exception\AwsException;
use Aws\S3\S3Client;

$bucket = getenv('S3_BUCKET') ?: '';
$key    = getenv('S3_KEY') ?: 'aws-servicios.png';
$region = getenv('AWS_REGION') ?: 'us-east-2';

if ($bucket === '') {
    http_response_code(500);
    fwrite(STDERR, "Define S3_BUCKET\n");
    exit(1);
}

$s3 = new S3Client([
    'region'  => $region,
    'version' => 'latest',
]);

try {
    $result = $s3->getObject(['Bucket' => $bucket, 'Key' => $key]);

    header('Content-Type: ' . $result['ContentType']);
    echo $result['Body'];
} catch (AwsException $e) {
    $codigo = $e->getAwsErrorCode() ?: 'ErrorDesconocido';
    $http   = $e->getStatusCode() === 403 ? 403 : 500;
    http_response_code($http);
    header('Content-Type: text/plain; charset=utf-8');
    echo "Error: " . $codigo . "\n" . $e->getAwsErrorMessage() . "\n";
    exit(1);
}
