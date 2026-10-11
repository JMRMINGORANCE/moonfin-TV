# Moonfin Cine (moonfin-TV)

Versión personal de [Moonfin](https://github.com/Moonfin-Client/Moonfin-Core) (cliente de Jellyfin/Emby) con una interfaz de estilo cine/streaming: fondo negro, acento rojo, banner destacado a pantalla completa y fichas con el botón de reproducir en primer plano.

Este repo no copia todo el código de Moonfin. Guarda las pantallas nuevas completas en `overlay/` y los pequeños cambios sobre archivos de Moonfin en `patches/cine-ui.patch`. GitHub Actions descarga un commit concreto de Moonfin, aplica el parche, copia `overlay/` encima y compila. Así es fácil actualizar a nuevas versiones de Moonfin.

## Qué cambia

Toda la interfaz principal está rehecha al estilo Netflix. Los componentes comunes están en `overlay/lib/ui/widgets/cine/cine_widgets.dart`.

- **Inicio**: cabecera destacada con logo, datos, sinopsis y botones **▶ Reproducir** / **ⓘ Más información**; filas de carátulas; *Seguir viendo* con barra roja; fila **Top 10** con números gigantes. En móvil, carátula grande y chips *Series · Películas · Seerr*.
- **Mi biblioteca (Películas / Series)**: cabecera con un título al azar, chips **Categorías ▾** (selector a pantalla completa) y **Ver todo** (rejilla completa), y filas *Añadidas recientemente*, *Las más valoradas*, *Aún no las has visto*, *Mi lista* y una fila por cada género principal.
- **Ficha de detalle**: fondo a pantalla completa, logo, línea de datos (★ valoración, año, edad, duración, temporadas, calidad), botones de Moonfin (reproducir, reanudar, mi lista, visto…), sinopsis, reparto y dirección, **episodios por temporada** con selector "Temporada X ▾" (al pulsar un episodio se reproduce) y **Más títulos similares**.
- **Seerr**: cabecera con la tendencia nº 1 y botón **Solicitar** / **Ver ahora**, filas de tendencias, películas y series del momento, próximos estrenos, más valoradas y lista de seguimiento. Cada carátula lleva etiqueta **DISPONIBLE**, **PARCIAL** o **SOLICITADO**. Chips *Mis solicitudes* y *Explorar más* (el explorador completo de Moonfin).
- **Navegación**: menú lateral en TV; barra inferior en móvil `Inicio · Mi biblioteca · Seerr · Buscar · Tú`. Todo se maneja con el mando (Android TV y Samsung).
- **Tema**: negro puro, rojo `#E50914`, foco blanco, esquinas de 4 px.
- **Android**: id `org.moonfin.cine` y nombre *Moonfin Cine*, se instala junto a Moonfin oficial.

Se mantienen las pantallas de Moonfin para música, libros, juegos, TV en directo, ajustes, el reproductor y la ficha de solicitud de Seerr (con el tema rojo y negro).

Para volver a la interfaz original de Moonfin, compila con `--dart-define=CINE_CLASSIC_UI=true`.

## Descargas

Cada push a `main` (o *Actions → Build → Run workflow*) genera una **Release** con:

| Archivo | Para |
|---|---|
| `MoonfinCine_Android_v*.apk` | Móviles y tablets Android |
| `MoonfinCine_AndroidTV_v*.apk` | Android TV / Google TV / Fire TV |
| `MoonfinCine_Tizen_v*_sin-firmar.wgt` | Televisores Samsung (hay que firmarlo) |
| `MoonfinCine_Tizen_v*.wgt` | Samsung ya firmado (solo si configuras los certificados) |

## Samsung (Tizen)

Tizen no usa APK sino paquetes `.wgt`. La versión Tizen es la compilación web de Moonfin en modo TV, con un adaptador para el mando (Atrás, Play/Pausa…). Funciona mejor en televisores de 2022 en adelante.

Las TV Samsung solo aceptan apps firmadas con un certificado ligado a tu televisor:

1. Activa el modo desarrollador en la TV (Apps → teclea `12345` → IP de tu PC).
2. En Tizen Studio → *Certificate Manager* crea un certificado **Samsung** con el DUID de tu TV.
3. Opción A: firma e instala el `.wgt` sin firmar desde Tizen Studio o con `tizen install`.
   Opción B: añade estos secretos al repo y la Release incluirá el `.wgt` firmado:
   `TIZEN_AUTHOR_P12_BASE64`, `TIZEN_AUTHOR_PASSWORD`, `TIZEN_DISTRIBUTOR_P12_BASE64`, `TIZEN_DISTRIBUTOR_PASSWORD`.

## Firma de los APK (recomendado)

Sin secretos, los APK se firman con una clave de debug distinta en cada compilación, así que para actualizar tendrías que desinstalar antes. Para firmar siempre con la misma clave añade `ANDROID_KEYSTORE_BASE64`, `ANDROID_STORE_PASSWORD`, `ANDROID_KEY_ALIAS` y `ANDROID_KEY_PASSWORD`.

## Actualizar a una nueva versión de Moonfin

Cambia `UPSTREAM_REF` en `.github/workflows/build.yml` por el commit nuevo. Si el parche ya no aplica, regenéralo con `git diff` sobre ese commit.

## Licencia

GPL-2.0, igual que Moonfin. Basado en el trabajo de Moonfin-Client y Jellyfin.
