# Laboratorio 14 - Seguridad en servicios AWS (KMS + S3)

Curso: Desarrollo de Soluciones en la Nube · TECSUP · Sección 5 - C24 ABCD
Alumno: Jason Gomez · Docente: Jaime Farfán

## Escenario

"EcomSecure" necesita proteger información confidencial de sus desarrolladores
publicada en S3. Se implementa cifrado en reposo con **AWS KMS** (clave simétrica
administrada por el cliente), con permisos de administración y de uso separados.

## Objetivos cubiertos

| Objetivo del enunciado | Cómo se cubre | Script |
|---|---|---|
| Entender AWS KMS | Clave simétrica `alias/lab14`, rotación anual, política de clave | `02-kms.sh` |
| Cifrar datos sensibles con KMS (simétrico) | Objeto `aws-servicios.png` con SSE-KMS; Encrypt/Decrypt directo | `03-s3.sh`, `04-pruebas-acceso.sh` |
| Políticas y permisos de acceso a la clave | Administradores y usuarios de la clave (dev01, dev02) y prueba negativa con dev03 | `01-iam.sh`, `02-kms.sh`, `04-pruebas-acceso.sh` |

## Requisitos

- AWS CLI v2 con sesión iniciada (`aws sts get-caller-identity` debe responder) y permisos de administrador sobre IAM, KMS y S3.
- PHP 8 y Composer (macOS: `brew install php composer`).
- Región `us-east-2` (Ohio), la misma del enunciado.

## Ejecución

```bash
bash scripts/aws/01-iam.sh            # grupos Developer/Backend/Frontend y usuarios dev01, dev02, dev03
bash scripts/aws/02-kms.sh            # clave simétrica lab14 + rotación
bash scripts/aws/03-s3.sh             # bucket privado, objetos y cifrado SSE-KMS
composer install                       # SDK de AWS para PHP
bash scripts/aws/04-pruebas-acceso.sh  # pruebas positivas y negativas (guarda evidencias)
```

Todos los scripts son idempotentes: se pueden repetir sin duplicar recursos.
Variables opcionales: `AWS_REGION`, `BUCKET`, `KEY_ALIAS` (ver `scripts/aws/00-env.sh`).

### Ver la imagen desde el navegador (script PHP del enunciado)

```bash
export S3_BUCKET="ecomsecure-lab14-<ID_DE_CUENTA>"
AWS_PROFILE=lab14-dev01 php -S localhost:8000 -t src      # abrir http://localhost:8000/ver-imagen.php
AWS_PROFILE=lab14-dev03 php -S localhost:8000 -t src      # mismo URL: AccessDenied (kms:Decrypt)
```

## Estructura

```
scripts/aws/
  00-env.sh                       variables comunes
  01-iam.sh                       grupos, políticas y usuarios
  02-kms.sh                       clave KMS + rotación
  policies/lab14-key-policy.json.tpl   política de la clave (admins y usuarios)
  03-s3.sh                        bucket, objetos y SSE-KMS
  04-pruebas-acceso.sh            pruebas de acceso
  99-limpieza.sh                  elimina todo (pide --confirmar)
src/ver-imagen.php                script PHP del enunciado, sin claves en el código
docs/evidencias/                  salidas reales de los scripts (sin credenciales)
docs/capturas/                    capturas de la consola de AWS (las toma el alumno)
```

## Recursos creados

| Recurso | Valor |
|---|---|
| Región | us-east-2 (Ohio) |
| Grupos IAM | `Developer` (S3FullAccess, KMSPowerUser, ReadOnlyAccess), `Backend_Developer`, `Frontend_Developer` |
| Usuarios IAM | `dev01`, `dev02` (grupo Developer, administran y usan la clave), `dev03` (solo `AmazonS3ReadOnlyAccess`) |
| Clave KMS | `alias/lab14`, simétrica, origen KMS, una sola región, rotación anual |
| Bucket | `ecomsecure-lab14-<ID_DE_CUENTA>`, privado, acceso público bloqueado |
| Objetos | `aws-servicios.png` (SSE-KMS con lab14), `data.txt` (SSE-S3, de contraste) |

## Resultados de las pruebas

Salida completa en [`docs/evidencias/04-pruebas-acceso.txt`](docs/evidencias/04-pruebas-acceso.txt).

| Prueba | Resultado |
|---|---|
| dev01 lee `aws-servicios.png` (SSE-KMS) | Permitido |
| dev03 lee `data.txt` (SSE-S3) | Permitido |
| dev03 lee `aws-servicios.png` (SSE-KMS) | `AccessDenied`: no puede hacer `kms:Decrypt` |
| dev01 cifra con la clave; dev03 intenta cifrar | Permitido / `AccessDeniedException` |
| Encrypt y Decrypt de dev01 (ida y vuelta) | Recupera el texto original |
| Script PHP con dev01 / con dev03 | Devuelve la imagen PNG / error 403 |

## Desviaciones respecto al enunciado

1. **Consola vs. CLI**: el enunciado guía la creación por la consola web; aquí se hace con scripts reproducibles de AWS CLI y se obtiene el mismo resultado. Las capturas de consola se toman sobre los recursos ya creados.
2. **Claves de acceso escritas en el PHP**: el script original pide pegar `key` y `secret` en el código. Se eliminó: el SDK toma las credenciales de un perfil (`AWS_PROFILE`), y bucket y objeto vienen de variables de entorno.
3. **`sudo composer require`**: se usa `composer require` sin `sudo` (con `sudo` el directorio `vendor` queda con dueño root) y, en macOS, `brew` en lugar de `apt`.
4. **Objeto de prueba**: el enunciado usa `aws-servicios.webp`; se genera `aws-servicios.png` localmente porque el archivo original no viene con el documento. El script PHP lee el tipo de contenido del objeto, así que funciona igual.
5. **Mensajes de error**: el PHP original imprimía la excepción cruda; ahora devuelve 403/500 con código y mensaje del servicio escapado a texto plano.
6. **Usuario dev03**: no está en el enunciado; se agregó para demostrar que sin permisos sobre la clave no se puede leer un objeto SSE-KMS.
7. **Cuenta de las capturas**: las capturas del enunciado muestran la cuenta del docente (`946439029408`, claves `lab14`, `lab14A`, `lab14SB`); aquí solo existe la clave `lab14`.

Nota técnica: la política de la clave conserva la sentencia por defecto que delega a IAM la cuenta raíz. Eso es lo habitual (evita perder el control de la clave), pero significa que un usuario con permisos KMS en una política IAM también podría usar la clave aunque no figure en "Usuarios de la clave". Dev03 queda denegado porque no tiene ninguna política IAM sobre KMS.

## Limpieza y costos

Costo aproximado mientras existan los recursos: clave KMS ≈ US$1/mes (prorrateado), más peticiones y almacenamiento de S3 de centavos. Para eliminar todo:

```bash
bash scripts/aws/99-limpieza.sh --confirmar
```

La clave KMS queda programada para eliminarse en 7 días (mínimo de AWS) y puede cancelarse en ese plazo.

## Capturas para el informe (las toma el alumno, región Ohio)

Guardarlas en `docs/capturas/` con estos nombres:

| Archivo | Qué mostrar |
|---|---|
| `01-grupos-iam.png` | IAM > Grupos de usuarios: Developer con 2 usuarios y permisos "Definido" |
| `02-politicas-developer.png` | IAM > Developer > Permisos: las 3 políticas |
| `03-bucket-s3.png` | S3 > Buckets: `ecomsecure-lab14-<ID>` en us-east-2 |
| `04-clave-kms.png` | KMS > Claves administradas por el cliente > `lab14` (simétrica, KMS) |
| `05-admin-usuarios-clave.png` | `lab14` > pestaña Política de claves: administradores y usuarios dev01 y dev02 |
| `06-cifrado-objeto.png` | S3 > `aws-servicios.png` > Propiedades > Cifrado del lado del servidor: SSE-KMS con la clave lab14 |
| `07-php-dev01.png` | Navegador con la imagen servida por el PHP (perfil dev01) |
| `08-php-dev03.png` | Navegador con el error AccessDenied (perfil dev03) |

## Conclusiones (borrador para editar)

1. KMS separa la administración de una clave de su uso: dev01 y dev02 la administran y la usan, pero la política puede dar solo una de las dos cosas a otra persona.
2. Con SSE-KMS tener permiso sobre el bucket no basta: dev03 puede leer `data.txt` (SSE-S3) pero recibe `AccessDenied` en la imagen porque no puede hacer `kms:Decrypt`. Es un segundo control de acceso sobre el mismo dato.
3. La política de la clave manda, pero la sentencia de la cuenta raíz delega en IAM; hay que revisar ambas capas al diagnosticar un acceso denegado.
4. Cifrar un objeto existente no cambia su contenido ni su URL: se reescribe con la nueva clave, y los objetos antiguos pueden quedar con otro cifrado (como `data.txt`) si no se actualizan.
5. Poner claves de acceso dentro del código (como en el PHP original) es un riesgo; el uso de perfiles o roles con el SDK evita filtrarlas al repositorio.
6. Automatizar con scripts idempotentes y limpieza explícita hace el laboratorio repetible y evita costos olvidados (la clave KMS cobra aunque no se use).

## Repositorio

`https://github.com/JasonGomezzz/Lab14-KMS-S3` (pendiente de crear y hacer `git push`).
