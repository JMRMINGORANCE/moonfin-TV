# TaquitoFlix

Cliente de Jellyfin con aspecto de plataforma de streaming para Android, Android TV y televisores Samsung (Tizen). La mascota es Taquito 🐶.

Basado en [Moonfin](https://github.com/Moonfin-Client/Moonfin-Core) (GPL-2.0). Este repo no copia todo su código. Contiene:

- `patches/cine-ui.patch`: cambios sobre archivos de Moonfin (tema, navegación, rutas, nombre, servidor por defecto, idioma).
- `overlay/`: pantallas nuevas completas (portada, ficha, bibliotecas, Seerr y componentes comunes).
- `branding/`: dibujo de Taquito (`taquito_head.svg`), logotipo (`taquitoflix_wordmark.svg`) y `rebrand.py`, que en cada compilación cambia los textos a TaquitoFlix y genera todos los iconos, banners y pantallas de carga.
- `tizen/`: empaquetado para Samsung.

GitHub Actions descarga un commit concreto de Moonfin, aplica el parche, copia `overlay/`, ejecuta `branding/rebrand.py` y compila.

## Qué trae

- **Servidor**: en el primer arranque se conecta solo a `https://tv.josemingorance.es`; también aparece ya escrito al añadir un servidor.
- **Idioma**: español por defecto en la interfaz, el audio y los subtítulos.
- **Inicio**: cabecera destacada, *Seguir viendo*, **Lo último añadido** (de todas las bibliotecas, con etiqueta NUEVO), *Top 10* y el resto de filas.
- **Bibliotecas**: siempre ordenadas con lo último añadido primero (también la rejilla de *Ver todo*). Seerr mantiene su propio orden.
- **Seerr**: todas las categorías del explorador (tendencias, populares, próximos estrenos, géneros, estudios, cadenas, lista de seguimiento y las filas creadas en Seerr) directamente en su pantalla. Sin solicitudes ni problemas: con la aprobación automática, el botón de películas y series dice **Descargar**.
- **Ficha de detalle** y navegación con mando al estilo de las plataformas de streaming.
- **Android**: id `es.josemingorance.taquitoflix`, nombre *TaquitoFlix*.

Lo que conserva el nombre Moonfin a propósito: las rutas y mensajes del plugin Moonfin de tu servidor (`/Moonfin/...`), el nombre con el que la app se presenta al servidor y los nombres internos del código. Cambiarlos rompería Seerr y la sincronización con el plugin.

## Descargas

Cada compilación publica una **Release** con `TaquitoFlix_Android_v*.apk`, `TaquitoFlix_AndroidTV_v*.apk` y `TaquitoFlix_Tizen_v*_sin-firmar.wgt`.

## Samsung (Tizen)

El `.wgt` hay que firmarlo con un certificado Samsung ligado a tu TV (Tizen Studio → *Certificate Manager*), o añadir al repo los secretos `TIZEN_AUTHOR_P12_BASE64`, `TIZEN_AUTHOR_PASSWORD`, `TIZEN_DISTRIBUTOR_P12_BASE64` y `TIZEN_DISTRIBUTOR_PASSWORD` para que la Release lo incluya ya firmado.

## Firma de los APK

Con los secretos `ANDROID_KEYSTORE_BASE64`, `ANDROID_STORE_PASSWORD`, `ANDROID_KEY_ALIAS` y `ANDROID_KEY_PASSWORD` todas las versiones se firman igual y se actualizan sin desinstalar.

## Licencia

GPL-2.0, como Moonfin. Basado en el trabajo de Moonfin-Client y Jellyfin.
