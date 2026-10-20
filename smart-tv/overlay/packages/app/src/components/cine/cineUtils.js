// TaquitoFlix: utilidades compartidas por las pantallas propias (portada,
// ficha, bibliotecas, búsqueda, Seerr y ajustes).
import {getImageUrl, getBackdropId, getLogoUrl, getPrimaryImageId} from '../../utils/helpers';
import {getImageUrl as seerrImage} from '../../services/seerrApi';

export const CINE_RED = '#E50914';

const DAY = 24 * 60 * 60 * 1000;

// Un elemento de Seerr (aún no está en el servidor) lleva tmdb y mediaType.
export const isSeerrItem = (item) => !!item && (item._seerr === true || (item.mediaType && item.id && !item.Id));

export const posterUrl = (serverUrl, item, height = 420) => {
	if (!item) return null;
	if (isSeerrItem(item)) {
		const path = item.posterPath || item.poster_path;
		return path ? seerrImage(path, 'w342') : null;
	}
	if (item.Type === 'Episode' && item.SeriesId && item.SeriesPrimaryImageTag) {
		return getImageUrl(serverUrl, item.SeriesId, 'Primary', {maxHeight: height, quality: 90, tag: item.SeriesPrimaryImageTag});
	}
	const id = getPrimaryImageId(item) || item.Id;
	return getImageUrl(serverUrl, id, 'Primary', {maxHeight: height, quality: 90, tag: item.ImageTags?.Primary});
};

export const backdropUrl = (serverUrl, item, width = 1920) => {
	if (!item) return null;
	if (isSeerrItem(item)) {
		const path = item.backdropPath || item.backdrop_path;
		return path ? seerrImage(path, 'w1280') : posterUrl(serverUrl, item);
	}
	const id = getBackdropId(item);
	if (id) return getImageUrl(serverUrl, id, 'Backdrop', {maxWidth: width, quality: 85});
	return posterUrl(serverUrl, item, 1080);
};

// Imagen apaisada: miniatura del episodio, «Thumb» o el fondo.
export const landscapeUrl = (serverUrl, item, width = 640) => {
	if (!item) return null;
	if (isSeerrItem(item)) return backdropUrl(serverUrl, item, width);
	if (item.Type === 'Episode' && item.ImageTags?.Primary) {
		return getImageUrl(serverUrl, item.Id, 'Primary', {maxWidth: width, quality: 85});
	}
	if (item.ImageTags?.Thumb) return getImageUrl(serverUrl, item.Id, 'Thumb', {maxWidth: width, quality: 85});
	if (item.CollectionType || item.Type === 'CollectionFolder' || item.Type === 'UserView') {
		return getImageUrl(serverUrl, item.Id, 'Primary', {maxWidth: width, quality: 85});
	}
	const id = getBackdropId(item);
	if (id) return getImageUrl(serverUrl, id, 'Backdrop', {maxWidth: width, quality: 85});
	return posterUrl(serverUrl, item);
};

export const logoUrl = (serverUrl, item) => {
	if (!item || isSeerrItem(item)) return null;
	if (item.Type === 'Episode' && item.SeriesId && item.ParentLogoItemId) {
		return getLogoUrl(serverUrl, item, {maxWidth: 700});
	}
	return getLogoUrl(serverUrl, item, {maxWidth: 700});
};

export const itemTitle = (item) => {
	if (!item) return '';
	if (isSeerrItem(item)) return item.title || item.name || item.originalTitle || '';
	if (item.Type === 'Episode') return item.SeriesName || item.Name;
	return item.Name || '';
};

export const episodeLabel = (item) => {
	if (!item || item.Type !== 'Episode') return '';
	const s = item.ParentIndexNumber;
	const e = item.IndexNumber;
	return s != null && e != null ? `T${s}:E${e}  ${item.Name}` : item.Name;
};

const ticksToMinutes = (ticks) => Math.round((ticks || 0) / 600000000);

export const runtimeLabel = (ticks) => {
	const m = ticksToMinutes(ticks);
	if (!m) return '';
	const h = Math.floor(m / 60);
	return h ? `${h} h ${m % 60} min` : `${m} min`;
};

export const metaLine = (item) => {
	if (!item) return '';
	if (isSeerrItem(item)) {
		const date = item.releaseDate || item.firstAirDate || '';
		return [
			item.voteAverage ? `★ ${Number(item.voteAverage).toFixed(1)}` : '',
			date.slice(0, 4),
			item.mediaType === 'tv' ? 'Serie' : 'Película'
		].filter(Boolean).join('  •  ');
	}
	const parts = [];
	if (item.CommunityRating) parts.push(`★ ${Number(item.CommunityRating).toFixed(1)}`);
	if (item.ProductionYear) parts.push(String(item.ProductionYear));
	if (item.OfficialRating) parts.push(item.OfficialRating);
	if (item.Type === 'Movie' && item.RunTimeTicks) parts.push(runtimeLabel(item.RunTimeTicks));
	if (item.Type === 'Series' && item.ChildCount) parts.push(item.ChildCount === 1 ? '1 temporada' : `${item.ChildCount} temporadas`);
	(item.Genres || []).slice(0, 2).forEach((g) => parts.push(g));
	return parts.join('  •  ');
};

export const overviewOf = (item) => (item ? (item.Overview || item.overview || '') : '');

export const progressOf = (item) => {
	const pct = item?.UserData?.PlayedPercentage;
	return pct ? Math.max(0, Math.min(100, pct)) : 0;
};

export const isRecent = (item, days = 14) => {
	const created = Date.parse(item?.DateCreated || '');
	return !isNaN(created) && Date.now() - created < days * DAY;
};

// Seguir viendo: lo que lleva más de tres meses parado no se enseña.
export const isStaleResume = (item, days = 90) => {
	const last = Date.parse(item?.UserData?.LastPlayedDate || '');
	return !isNaN(last) && Date.now() - last > days * DAY;
};

export const byDateCreatedDesc = (a, b) => (Date.parse(b.DateCreated || '') || 0) - (Date.parse(a.DateCreated || '') || 0);

export const shuffle = (list) => {
	const a = list.slice();
	for (let i = a.length - 1; i > 0; i--) {
		const j = Math.floor(Math.random() * (i + 1));
		const t = a[i];
		a[i] = a[j];
		a[j] = t;
	}
	return a;
};

// Estado de Seerr: 5 disponible, 4 parcialmente, 3 procesando/descargando, 2 pendiente.
export const seerrState = (item) => {
	const info = item?.mediaInfo;
	if (!info) return null;
	if (info.status === 5) return {kind: 'available', label: 'YA DESCARGADA'};
	if (info.status === 4) return {kind: 'available', label: 'DISPONIBLE EN PARTE'};
	const dl = (info.downloadStatus || [])[0];
	if (info.status === 3 && dl && dl.size) {
		const pct = Math.round(100 * (1 - (dl.sizeLeft || 0) / dl.size));
		return {kind: 'downloading', label: `DESCARGANDO ${pct}%`, pct};
	}
	if (info.status === 3) return {kind: 'downloading', label: 'DESCARGANDO'};
	if (info.status === 2) return {kind: 'pending', label: 'PEDIDA'};
	return null;
};

// Convierte un resultado de Seerr en algo que las filas saben pintar.
export const fromSeerr = (r) => ({...r, _seerr: true, Id: undefined, _key: `seerr-${r.mediaType}-${r.id}`});

export const itemKey = (item) => (item ? (item._key || item.Id || `${item.mediaType}-${item.id}`) : '');

export const greeting = () => {
	const h = new Date().getHours();
	if (h < 6) return 'Buenas noches';
	if (h < 14) return 'Buenos días';
	if (h < 21) return 'Buenas tardes';
	return 'Buenas noches';
};
