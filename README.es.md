# Corrección del Lector de Huellas Dactilares del Samsung Galaxy Book 4 (Fedora)

**Idiomas:** [English](README.md) · [Português (Brasil)](README.pt-BR.md) · **Español**

Hace funcionar el lector de huellas dactilares del **Samsung Galaxy Book 4** en **Fedora**
(pantalla de inicio de sesión, pantalla de bloqueo y `sudo`).

> **Resumen para usuarios sin experiencia técnica**
>
> 1. Abre una terminal.
> 2. Pega los cuatro comandos de la sección [Inicio rápido](#inicio-rápido).
> 3. Listo. Puedes iniciar sesión y usar `sudo` con tu dedo.

---

## Cómo se ve

Una vez instalado, ejecuta `./fingerprint-enroll.sh` para gestionar tus huellas.
La herramienta muestra una vista en tiempo real de tus manos — los dedos registrados
aparecen como `●`, los no registrados muestran su número para que puedas elegir cuál registrar:

```
Fingerprint manager (user: tuusuario)

     Left hand                       Right hand

          _.-._                          _.-._
        _|1|2|3|\                       /|●|7|8|_
       |0| | | ||                       || | | |9|
       | | | | ||                       || | | | |
       | `     ||_                     _||     ` |
       ;       /4//                   \\●\       ;
       |        //                     \\        |
        \      //                       \\      /
         |    | |                       | |    |
         |    | |                       | |    |

  e) Enroll a new finger
  v) Verify a finger (test)
  d) Delete a finger
  D) Delete ALL fingers
  l) List enrolled fingers
  q) Quit

>
```

> En una terminal real los `●` aparecen resaltados en verde y los dígitos
> no registrados aparecen en gris. El mismo dibujo se muestra cada vez que
> registras, verificas o eliminas un dedo.

---

## ¿Esto funcionará para mí?

Necesitas que las **tres** condiciones sean verdaderas:

- [x] Tienes un **Samsung Galaxy Book 4** (Pro, Ultra o 360).
- [x] Estás usando **Fedora** (43 y 44 beta confirmados; 42 probablemente funciona).
- [x] Ves el sensor al ejecutar:
      ```bash
      lsusb | grep 2808:6553
      ```
      Si aparece una línea, todo bien. Si no aparece nada, esta corrección
      **no** te ayudará — es específica para ese sensor exacto.

---

## Inicio rápido

Abre una terminal y ejecuta:

```bash
git clone https://github.com/dalsochio/Samsung-Galaxy-Book-4-Fingerprint-Fedora.git
cd Samsung-Galaxy-Book-4-Fingerprint-Fedora
chmod +x install.sh fingerprint-enroll.sh uninstall.sh

# 1) Instala el controlador corregido y activa el inicio de sesión por huella (pide contraseña):
sudo ./install.sh

# 2) Registra tu dedo (ejecuta como TU usuario, NO con sudo):
./fingerprint-enroll.sh
```

Eso es todo. Después del paso 2 puedes:

- Tocar el sensor en la **pantalla de inicio de sesión** en lugar de escribir tu contraseña.
- Tocar el sensor cuando uses `sudo` en la terminal.
- Tocar el sensor en la **pantalla de bloqueo**.

> **¿Por qué dos pasos con cuentas diferentes?**
> El paso 1 necesita root para instalar paquetes del sistema.
> El paso 2 debe ejecutarse como tu usuario normal porque el sistema de permisos
> del escritorio (polkit) solo autoriza el registro de huellas para el usuario
> que está sentado frente al equipo. Si ejecutas el paso 2 con `sudo`
> obtendrás un error de `PermissionDenied`.

---

## Qué esperar al registrar tu dedo

Al ejecutar `./fingerprint-enroll.sh`, elige `e` en el menú, luego selecciona un dedo. Después:

- Coloca el dedo **plano y centrado** en el sensor.
- **Levanta completamente** el dedo entre los toques.
- Repite **de 8 a 15 veces** hasta ver `enroll-completed`.
- El programa ofrecerá **probar** el dedo de inmediato.

Si fallas, sigue intentando — el sensor solo cuenta los toques correctos.

### Qué significan los mensajes

| Mensaje                        | Qué significa                                |
|--------------------------------|----------------------------------------------|
| `enroll-stage-passed`          | OK, ese toque funcionó. Continúa.            |
| `enroll-finger-not-centered`   | Fallaste el sensor. Inténtalo de nuevo.      |
| `enroll-retry-scan`            | Levanta el dedo y toca de nuevo.             |
| `enroll-completed`             | ¡Listo! Tu dedo está registrado.             |

Puedes registrar **tantos dedos como quieras**. Elige `e` de nuevo en el menú,
o ejecuta `./fingerprint-enroll.sh enroll left-thumb`.

---

## Problemas comunes

### `sudo` no pide la huella dactilar

Verifica que la función esté activada:

```bash
authselect current
```

Si la salida no menciona `with-fingerprint`, ejecuta:

```bash
sudo authselect enable-feature with-fingerprint
sudo authselect apply-changes
```

### El sensor deja de funcionar después de suspender el equipo

El instalador ya incluye una corrección para esto (un pequeño servicio de systemd que
reinicia `fprintd` al despertar). Si falla de todas formas:

```bash
sudo systemctl restart fprintd
```

### `failed to claim device: Remote peer disconnected`

`fprintd` se bloqueó. La mayoría de las veces significa que hay una biblioteca antigua en el camino.
Reinstala:

```bash
sudo ./uninstall.sh
sudo ./install.sh
```

### Sigue apareciendo `enroll-finger-not-centered`

- Usa el **centro** del dedo, no la punta.
- Cubre el sensor completamente.
- Quédate quieto hasta que cambie el mensaje.

### La huella dejó de funcionar después de una actualización del sistema

Puede ocurrir si un `dnf upgrade` sobreescribe el controlador corregido. Solo ejecuta de nuevo:

```bash
sudo ./install.sh
```

---

## Desinstalar / Revertir

Para deshacer todo:

```bash
sudo ./uninstall.sh
```

Esto **eliminará todas las huellas registradas** y dejará el sistema como estaba.
El script pide confirmación; pasa `--yes` para omitir la pregunta.

---

---

## Referencia técnica (para usuarios avanzados)

### Por qué existe esto

El `libfprint` estándar de Fedora aún no soporta el sensor FocalTech Match-on-Chip
que viene con el Galaxy Book 4 (USB ID `2808:6553`). La corrección es un `libfprint`
con parche basado en el MR #554 de libfprint por Sid1803, aún no fusionado al upstream.

Este repositorio es el equivalente Fedora de
[ishashanknigam/Samsung-Galaxy-Book-4-Fingerprint-Ubuntu](https://github.com/ishashanknigam/Samsung-Galaxy-Book-4-Fingerprint-Ubuntu),
que distribuye archivos `.deb` Debian con el mismo parche. El instalador usa el COPR
[`hichambel/libfprint-galaxybook`](https://copr.fedorainfracloud.org/coprs/hichambel/libfprint-galaxybook/),
compilado contra las bibliotecas de Fedora.

> ¿Por qué no reutilizar el `.so` Debian? Porque está enlazado dinámicamente contra
> símbolos de `libgusb` marcados como `LIBGUSB_0.1.0`, mientras que el `libgusb` de Fedora
> exporta las mismas funciones marcadas como `LIBGUSB_0.2.8`. Copiar el binario Debian
> a `/usr/lib64` produce `undefined symbol: g_usb_device_get_interfaces` y `fprintd` muere.

### Compatibilidad con versiones de Fedora

| Fedora        | Estado                                                                          |
|---------------|---------------------------------------------------------------------------------|
| 40 / 41       | No probado. Usará el fallback `fedora-43`. Puede fallar en dependencias.        |
| 42            | No probado. Usará el fallback `fedora-43`; se espera que funcione.              |
| 43            | **Build nativo, totalmente soportado.**                                         |
| 44 (beta)     | **Probado, funciona vía fallback `fedora-43`.**                                 |
| 45+           | Mejor esfuerzo mientras el ABI de glib2 / libgusb / libusb1 sea compatible.    |

### Version lock

El `install.sh` bloquea la versión de `libfprint` con `dnf versionlock` automáticamente.
Sin esto, un `sudo dnf upgrade` eventualmente reemplazaría el build corregido
por el estándar de Fedora, rompiendo el sensor silenciosamente.

Verás esto en `dnf upgrade`:

```
Package "libfprint" excluded by versionlock plugin.
```

Eso es lo esperado — es el bloqueo funcionando.

Para desbloquear (por ejemplo, cuando el COPR publique un build para tu versión de Fedora):

```bash
sudo dnf versionlock list                  # ver qué está bloqueado
sudo dnf versionlock delete libfprint      # desbloquear
```

Para volver a aplicar después:

```bash
sudo dnf versionlock add libfprint
```

### Instalación manual

```bash
sudo dnf install -y dnf-plugins-core
sudo dnf copr enable -y hichambel/libfprint-galaxybook
sudo dnf install -y fprintd fprintd-pam libfprint
sudo dnf reinstall -y libfprint
sudo authselect enable-feature with-fingerprint
sudo authselect apply-changes
sudo systemctl restart fprintd
```

### Comandos de verificación

```bash
rpm -qf /usr/lib64/libfprint-2.so.2   # debe contener "galaxybook"
systemctl status fprintd
ldd /usr/libexec/fprintd | grep fprint
lsusb | grep 2808:6553
fprintd-list "$USER"
```

### SELinux

El RPM del COPR ya viene con los labels SELinux correctos. Si sospechas de un bloqueo:

```bash
sudo ausearch -m AVC -ts recent
```

---

## Créditos

- Corrección original Ubuntu / Debian:
  [ishashanknigam](https://github.com/ishashanknigam/Samsung-Galaxy-Book-4-Fingerprint-Ubuntu).
- Controlador FocalTech MoC: libfprint MR #554 por Sid1803.
- Build COPR para Fedora:
  [`hichambel/libfprint-galaxybook`](https://copr.fedorainfracloud.org/coprs/hichambel/libfprint-galaxybook/).
- Port para Fedora (este repo): scripts, hook systemd, helper de registro de múltiples dedos,
  versionlock automático, documentación — desarrollado con la ayuda de **Claude Sonnet 4.5**.
- Dibujo ASCII de las manos adaptado de
  [Joan G. Stark (Spunk)](https://www.asciiart.eu/art/f8977d5ed396941a).

---

## Aviso

Este instalador reemplaza una biblioteca del sistema a través de un COPR de terceros y
modifica la configuración de PAM. Úsalo bajo tu propia responsabilidad.
