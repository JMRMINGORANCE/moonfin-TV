#!/usr/bin/env node
/*
 * TaquitoFlix: servidor Jellyfin de mentira para probar la app de tele sin
 * un servidor real. Sirve una biblioteca inventada (películas, series,
 * episodios, sagas, perfiles) y un Seerr a través del plugin Moonfin.
 *
 *   node mock-jellyfin.js [puerto]      (por defecto 8096)
 *
 * Las imágenes son SVG generados con el título del elemento. Las rutas que
 * no conoce responden con una lista vacía y se anotan en mock-unknown.log.
 */
const http = require('http');
const fs = require('fs');
const path = require('path');
const {URL} = require('url');

const PORT = Number(process.argv[2] || 8096);
const SERVER_ID = 'mockserver0001';
const LOG = path.join(__dirname, 'mock-unknown.log');

// --- datos -----------------------------------------------------------------

const COLORS = ['#7b1fa2', '#1565c0', '#2e7d32', '#c62828', '#ef6c00', '#00838f', '#4e342e', '#283593', '#ad1457', '#558b2f'];
const now = Date.now();
const day = 24 * 3600 * 1000;
const iso = (t) => new Date(t).toISOString();

const users = [
	{Name: 'Copi', Id: 'user-copi', HasPassword: false},
	{Name: 'Laura', Id: 'user-laura', HasPassword: false},
	{Name: 'Peques', Id: 'user-peques', HasPassword: false}
];

const items = new Map();
const add = (it) => { items.set(it.Id, it); return it; };

const libMovies = add({Id: 'lib-movies', Name: 'Películas', Type: 'CollectionFolder', CollectionType: 'movies', IsFolder: true});
const libShows = add({Id: 'lib-shows', Name: 'Series', Type: 'CollectionFolder', CollectionType: 'tvshows', IsFolder: true});
const libKids = add({Id: 'lib-kids', Name: 'Infantil', Type: 'CollectionFolder', CollectionType: 'movies', IsFolder: true});

const GENRES = ['Acción', 'Comedia', 'Drama', 'Aventura', 'Ciencia ficción', 'Animación', 'Thriller', 'Fantasía'];
const movieNames = [
	'La gran aventura de Taquito', 'Noche de cine', 'El último tren', 'Sombras en la ciudad',
	'Viaje a las estrellas', 'El jardín secreto', 'Operación Croqueta', 'La casa del lago',
	'Rápidos y hambrientos', 'Misterio en el museo', 'El perro que sabía demasiado', 'Planeta azul',
	'La isla del tesoro', 'Código rojo', 'Un verano en Cádiz', 'Los guardianes', 'Tormenta perfecta',
	'El chef', 'Robots del mañana', 'La última frontera', 'Pequeño gran héroe', 'Bajo cero',
	'Harry Potter y la piedra filosofal', 'Harry Potter y la cámara secreta', 'Harry Potter y el prisionero de Azkaban'
];
movieNames.forEach((name, i) => {
	const kids = /Taquito|Pequeño|robots/i.test(name);
	add({
		Id: `movie-${i}`, Name: name, Type: 'Movie', MediaType: 'Video', IsFolder: false,
		ParentId: kids ? libKids.Id : libMovies.Id,
		ProductionYear: 1998 + (i * 3) % 27, PremiereDate: iso(now - (400 + i * 90) * day),
		DateCreated: iso(now - (i < 6 ? i : i * 4) * day),
		CommunityRating: Math.round((5.5 + (i * 7) % 40 / 10) * 10) / 10,
		OfficialRating: ['TP', '7', '12', '16', '18'][i % 5],
		RunTimeTicks: (85 + (i * 13) % 70) * 60 * 10000000,
		Genres: [GENRES[i % GENRES.length], GENRES[(i + 3) % GENRES.length]],
		Overview: `Sinopsis de «${name}». Una historia inventada para probar TaquitoFlix en la tele, con suficiente texto para ocupar un par de líneas en la cabecera.`,
		Taglines: ['Una película de prueba'],
		UserData: {Played: i % 7 === 3, IsFavorite: i % 5 === 0, PlaybackPositionTicks: [2, 9, 14].includes(i) ? 30 * 60 * 10000000 : 0,
			PlayedPercentage: [2, 9, 14].includes(i) ? 35 : undefined, LastPlayedDate: iso(now - (i === 14 ? 120 : i) * day)},
		ImageTags: {Primary: 'p', Logo: i % 3 === 0 ? 'l' : undefined},
		BackdropImageTags: ['b'],
		RemoteTrailers: i % 4 === 0 ? [{Url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'}] : [],
		ProviderIds: {Tmdb: String(1000 + i)}
	});
});

const showNames = ['Los Taquitos', 'Ciudad Neón', 'Cocina con amigos', 'El Pueblo', 'Anatomía de un instante', 'Euphoria', 'La teoría del Big Bang', 'Aquí no hay quien viva'];
showNames.forEach((name, s) => {
	const series = add({
		Id: `series-${s}`, Name: name, Type: 'Series', IsFolder: true, ParentId: libShows.Id,
		ProductionYear: 2005 + s * 2, PremiereDate: iso(now - (2000 - s * 100) * day), DateCreated: iso(now - s * 2 * day),
		DateLastMediaAdded: iso(now - s * day),
		CommunityRating: 7 + (s % 3) * 0.5, OfficialRating: '12', Genres: [GENRES[s % GENRES.length]],
		Overview: `«${name}» es una serie de prueba con varias temporadas para comprobar la ficha, los episodios y el siguiente capítulo.`,
		ImageTags: {Primary: 'p', Logo: s % 2 === 0 ? 'l' : undefined}, BackdropImageTags: ['b'],
		ChildCount: 2, RecursiveItemCount: 12, Status: s % 2 ? 'Ended' : 'Continuing',
		UserData: {UnplayedItemCount: 6, IsFavorite: s === 1}
	});
	for (let n = 1; n <= 2; n++) {
		const season = add({Id: `season-${s}-${n}`, Name: `Temporada ${n}`, Type: 'Season', IsFolder: true, IndexNumber: n,
			SeriesId: series.Id, SeriesName: name, ParentId: series.Id, ImageTags: {Primary: 'p'}, BackdropImageTags: [],
			ParentBackdropItemId: series.Id, ParentBackdropImageTags: ['b'], UserData: {UnplayedItemCount: 6}});
		for (let e = 1; e <= 6; e++) {
			const played = n === 1 && e <= (s % 4) + 1;
			add({
				Id: `ep-${s}-${n}-${e}`, Name: `Capítulo ${e}`, Type: 'Episode', MediaType: 'Video', IsFolder: false,
				IndexNumber: e, ParentIndexNumber: n, SeriesId: series.Id, SeriesName: name, SeasonId: season.Id, SeasonName: season.Name,
				ParentId: season.Id, DateCreated: iso(now - (s + e) * day), PremiereDate: iso(now - (500 - e) * day),
				RunTimeTicks: 42 * 60 * 10000000, Overview: `Capítulo ${e} de la temporada ${n} de ${name}.`,
				ImageTags: {Primary: 'p'}, SeriesPrimaryImageTag: 'p', ParentBackdropItemId: series.Id, ParentBackdropImageTags: ['b'],
				ParentThumbItemId: series.Id, ParentThumbImageTag: 't',
				UserData: {Played: played, PlaybackPositionTicks: (s === 2 && n === 1 && e === 3) ? 20 * 60 * 10000000 : 0,
					PlayedPercentage: (s === 2 && n === 1 && e === 3) ? 48 : undefined, LastPlayedDate: iso(now - s * day)}
			});
		}
	}
});

add({Id: 'boxset-hp', Name: 'Harry Potter - Colección', Type: 'BoxSet', IsFolder: true, ImageTags: {Primary: 'p'}, BackdropImageTags: ['b'],
	Overview: 'Todas las películas de Harry Potter.', ChildIds: ['movie-22', 'movie-23', 'movie-24']});

// --- Seerr -----------------------------------------------------------------

const seerrMovies = Array.from({length: 18}, (_, i) => ({
	id: 5000 + i, mediaType: i % 3 === 0 ? 'tv' : 'movie',
	title: i % 3 === 0 ? undefined : `Estreno ${i + 1}`, name: i % 3 === 0 ? `Serie nueva ${i + 1}` : undefined,
	originalTitle: `Release ${i + 1}`, overview: `Título de Seerr número ${i + 1} para probar las filas y la ficha de lo que aún no tienes.`,
	posterPath: `/poster${i}.jpg`, backdropPath: `/backdrop${i}.jpg`, voteAverage: 6 + (i % 4),
	releaseDate: '2026-0' + ((i % 9) + 1) + '-15', firstAirDate: '2025-1' + (i % 3) + '-01', genreIds: [28, 12],
	mediaInfo: i === 1 ? {status: 5, downloadStatus: []} : i === 2 ? {status: 3, downloadStatus: [{size: 100, sizeLeft: 55, title: 'x'}]} : undefined
}));
const page = (results) => ({page: 1, totalPages: 1, totalResults: results.length, results});

function seerr(pathname, url) {
	const p = pathname.replace(/^\/+/, '');
	if (/^discover\/(trending|movies|tv|movies\/upcoming|tv\/upcoming)/.test(p)) return page(seerrMovies);
	if (/^discover\/watchlist/.test(p)) return page(seerrMovies.slice(0, 5));
	if (/^discover\/genreslider\/(movie|tv)/.test(p)) return [{id: 28, name: 'Acción', backdrops: ['/g1.jpg']}, {id: 35, name: 'Comedia', backdrops: ['/g2.jpg']}, {id: 18, name: 'Drama', backdrops: ['/g3.jpg']}];
	if (/^search/.test(p)) {
		const q = (url.searchParams.get('query') || '').toLowerCase();
		return page(seerrMovies.filter((m) => (m.title || m.name).toLowerCase().includes(q)).concat(q ? [] : []));
	}
	let m = p.match(/^(movie|tv)\/(\d+)(\/.*)?$/);
	if (m) {
		const base = seerrMovies.find((x) => x.id === Number(m[2])) || seerrMovies[0];
		if (m[3] && /recommendations|similar/.test(m[3])) return page(seerrMovies.slice(3, 10));
		return {...base, genres: [{id: 28, name: 'Acción'}], runtime: 110, credits: {cast: [], crew: []},
			relatedVideos: [], seasons: m[1] === 'tv' ? [{seasonNumber: 1, episodeCount: 8, name: 'Temporada 1'}] : undefined,
			mediaInfo: base.mediaInfo || null};
	}
	if (/^request/.test(p)) {
		if (url.searchParams.get('filter') === 'available') {
			return {pageInfo: {pages: 1, results: 3}, results: [1001, 1004, 1010].map((t, i) => ({id: 900 + i, status: 2, media: {tmdbId: t, mediaType: 'movie', status: 5}}))};
		}
		return {pageInfo: {pages: 1, results: 0}, results: []};
	}
	if (/^auth\/me/.test(p)) return {id: 1, displayName: 'Copi', permissions: 2, requestCount: 3};
	if (/^status/.test(p)) return {version: '2.7.0'};
	if (/^settings\/public/.test(p)) return {applicationTitle: 'Seerr', localLogin: true};
	if (/^discover\/sliders/.test(p)) return [];
	return null;
}

// --- utilidades ------------------------------------------------------------

const baseItem = (it) => ({ServerId: SERVER_ID, ...it});
const userData = (it) => it.UserData || {};

function svg(title, color, w, h, kind) {
	const t = String(title || '').replace(/[<&>]/g, '');
	const lines = t.match(/.{1,16}(\s|$)/g) || [t];
	const fs = Math.round(Math.min(w, h) / 9);
	const text = lines.slice(0, 3).map((l, i) => `<text x="50%" y="${50 + (i - (lines.length - 1) / 2) * 12}%" font-family="sans-serif" font-size="${fs}" font-weight="700" fill="#fff" text-anchor="middle">${l.trim()}</text>`).join('');
	return `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">` +
		`<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${color}"/><stop offset="1" stop-color="#111"/></linearGradient></defs>` +
		`<rect width="100%" height="100%" fill="url(#g)"/>${kind === 'Logo' ? '' : `<circle cx="${w * 0.8}" cy="${h * 0.2}" r="${Math.min(w, h) * 0.15}" fill="rgba(255,255,255,0.12)"/>`}${text}</svg>`;
}

function filterItems(q, userId) {
	let list = [...items.values()];
	const parentId = q.get('ParentId') || q.get('parentId');
	const types = (q.get('IncludeItemTypes') || q.get('includeItemTypes') || '').split(',').filter(Boolean);
	const ids = (q.get('Ids') || q.get('ids') || '').split(',').filter(Boolean);
	const recursive = /true/i.test(q.get('Recursive') || q.get('recursive') || '');
	const search = (q.get('SearchTerm') || q.get('searchTerm') || '').toLowerCase();
	const filters = (q.get('Filters') || q.get('filters') || '');
	const genres = (q.get('Genres') || q.get('genres') || '').split('|').filter(Boolean);
	if (ids.length) list = ids.map((id) => items.get(id)).filter(Boolean);
	if (parentId) {
		if (parentId === 'boxset-hp') list = items.get('boxset-hp').ChildIds.map((id) => items.get(id));
		else {
			const under = (it) => {
				let cur = it;
				for (let k = 0; k < 4 && cur; k++) {
					if (cur.ParentId === parentId) return true;
					if (!recursive) return false;
					cur = items.get(cur.ParentId);
				}
				return false;
			};
			list = list.filter(under);
		}
	}
	if (types.length) list = list.filter((it) => types.includes(it.Type));
	else if (!ids.length && !parentId) list = list.filter((it) => !['CollectionFolder'].includes(it.Type));
	if (search) list = list.filter((it) => it.Name.toLowerCase().includes(search));
	if (filters.includes('IsFavorite')) list = list.filter((it) => userData(it).IsFavorite);
	if (filters.includes('IsResumable')) list = list.filter((it) => userData(it).PlaybackPositionTicks > 0);
	if (filters.includes('IsUnplayed')) list = list.filter((it) => !userData(it).Played);
	if (genres.length) list = list.filter((it) => (it.Genres || []).some((g) => genres.includes(g)));
	const sortBy = (q.get('SortBy') || q.get('sortBy') || '').split(',')[0];
	const desc = /desc/i.test(q.get('SortOrder') || q.get('sortOrder') || '');
	const key = {DateCreated: 'DateCreated', SortName: 'Name', CommunityRating: 'CommunityRating', PremiereDate: 'PremiereDate', ProductionYear: 'ProductionYear', DatePlayed: null, Random: null}[sortBy];
	if (key) list.sort((a, b) => (a[key] > b[key] ? 1 : a[key] < b[key] ? -1 : 0) * (desc ? -1 : 1));
	if (sortBy === 'Random') list.sort(() => Math.random() - 0.5);
	const total = list.length;
	const start = Number(q.get('StartIndex') || q.get('startIndex') || 0);
	const limit = Number(q.get('Limit') || q.get('limit') || 0);
	if (limit) list = list.slice(start, start + limit);
	else if (start) list = list.slice(start);
	return {Items: list.map(baseItem), TotalRecordCount: total, StartIndex: start};
}

function nextUp(q) {
	const out = [];
	for (let s = 0; s < showNames.length; s++) {
		const eps = [...items.values()].filter((it) => it.Type === 'Episode' && it.SeriesId === `series-${s}`)
			.sort((a, b) => a.ParentIndexNumber - b.ParentIndexNumber || a.IndexNumber - b.IndexNumber);
		const lastPlayed = eps.map((e) => userData(e).Played).lastIndexOf(true);
		if (lastPlayed >= 0 && eps[lastPlayed + 1]) out.push(eps[lastPlayed + 1]);
	}
	const seriesId = q.get('SeriesId') || q.get('seriesId');
	return {Items: out.filter((e) => !seriesId || e.SeriesId === seriesId).map(baseItem), TotalRecordCount: out.length};
}

const json = (res, status, body) => {
	res.writeHead(status, {'Content-Type': 'application/json; charset=utf-8'});
	res.end(body === undefined ? '' : JSON.stringify(body));
};

// --- servidor --------------------------------------------------------------

const server = http.createServer((req, res) => {
	res.setHeader('Access-Control-Allow-Origin', '*');
	res.setHeader('Access-Control-Allow-Headers', '*');
	res.setHeader('Access-Control-Allow-Methods', 'GET,POST,DELETE,PUT,OPTIONS');
	if (req.method === 'OPTIONS') { res.writeHead(204); res.end(); return; }
	const url = new URL(req.url, `http://localhost:${PORT}`);
	const p = url.pathname.replace(/^\/(jellyfin|emby)(?=\/)/i, '');
	const q = url.searchParams;
	let body = '';
	req.on('data', (c) => { body += c; });
	req.on('end', () => {
		let m;
		// Reproducción: un vídeo de prueba (webm) para todo, con rangos.
		if ((m = p.match(/^\/Items\/([^/]+)\/PlaybackInfo$/i))) {
			const it = items.get(m[1]) || {Id: m[1], RunTimeTicks: 900000000};
			return json(res, 200, {PlaySessionId: 'ps-' + m[1], MediaSources: [{
				Id: m[1], Name: it.Name, Protocol: 'File', Container: 'webm', Path: '/media/test.webm', Type: 'Default',
				SupportsDirectPlay: true, SupportsDirectStream: true, SupportsTranscoding: false, IsRemote: false,
				RunTimeTicks: 900000000, Bitrate: 700000, DefaultAudioStreamIndex: 1,
				DirectStreamUrl: `/Videos/${m[1]}/stream.webm?Static=true`, TranscodingUrl: `/Videos/${m[1]}/stream.webm?Static=true&VideoCodec=vp8`, TranscodingSubProtocol: 'http', TranscodingContainer: 'webm',
				MediaStreams: [
					{Index: 0, Type: 'Video', Codec: 'vp8', Width: 1280, Height: 720, IsDefault: true},
					{Index: 1, Type: 'Audio', Codec: 'vorbis', Language: 'spa', DisplayTitle: 'Español', Channels: 2, IsDefault: true},
					{Index: 2, Type: 'Subtitle', Codec: 'srt', Language: 'spa', DisplayTitle: 'Español', IsExternal: true, DeliveryMethod: 'External', DeliveryUrl: '/Videos/x/x/Subtitles/2/0/Stream.vtt'}
				]
			}]});
		}
		if (/^\/Videos\/[^/]+\/(stream|master|main)/i.test(p) || /^\/Videos\/[^/]+\/[^/]+\/stream/i.test(p)) {
			const file = process.env.MOCK_VIDEO || '/tmp/claude-0/test.webm';
			if (!fs.existsSync(file)) { res.writeHead(404); res.end(); return; }
			const size = fs.statSync(file).size;
			const range = req.headers.range;
			if (range) {
				const [a, b] = range.replace(/bytes=/, '').split('-');
				const start = Number(a) || 0;
				const end = b ? Number(b) : size - 1;
				res.writeHead(206, {'Content-Range': `bytes ${start}-${end}/${size}`, 'Accept-Ranges': 'bytes', 'Content-Length': end - start + 1, 'Content-Type': 'video/webm'});
				fs.createReadStream(file, {start, end}).pipe(res);
			} else {
				res.writeHead(200, {'Content-Length': size, 'Content-Type': 'video/webm', 'Accept-Ranges': 'bytes'});
				fs.createReadStream(file).pipe(res);
			}
			return;
		}
		if (/Subtitles\/.*\.vtt$/i.test(p)) {
			res.writeHead(200, {'Content-Type': 'text/vtt'});
			res.end('WEBVTT\n\n00:00:01.000 --> 00:00:06.000\nHola, esto es un subtítulo de prueba.\n');
			return;
		}
		if (/^\/Sessions\/Playing/i.test(p)) { res.writeHead(204); res.end(); return; }
		if (/^\/MediaSegments\//i.test(p)) return json(res, 200, {Items: [{Type: 'Intro', StartTicks: 20000000, EndTicks: 120000000}]});
		// Imágenes
		if ((m = p.match(/^\/Items\/([^/]+)\/Images\/(\w+)/i))) {
			const it = items.get(m[1]) || users.find((u) => u.Id === m[1]) || {Name: m[1]};
			const kind = m[2];
			const color = COLORS[[...String(m[1])].reduce((a, c) => a + c.charCodeAt(0), 0) % COLORS.length];
			const dims = {Primary: it.Type === 'Episode' || it.Type === 'CollectionFolder' ? [640, 360] : [400, 600], Backdrop: [1280, 720], Thumb: [640, 360], Logo: [800, 300], Banner: [1000, 185]}[kind] || [400, 400];
			res.writeHead(200, {'Content-Type': 'image/svg+xml', 'Cache-Control': 'max-age=3600'});
			res.end(svg(kind === 'Backdrop' ? '' : it.Name, kind === 'Logo' ? 'rgba(0,0,0,0)' : color, dims[0], dims[1], kind));
			return;
		}
		if ((m = p.match(/^\/Users\/([^/]+)\/Images\/Primary/i))) {
			res.writeHead(404); res.end(); return;
		}
		if (/^\/System\/Info\/Public$/i.test(p)) return json(res, 200, {ServerName: 'Servidor de prueba', Version: '10.10.7', Id: SERVER_ID, ProductName: 'Jellyfin Server', LocalAddress: `http://localhost:${PORT}`, StartupWizardCompleted: true});
		if (/^\/System\/Info$/i.test(p)) return json(res, 200, {ServerName: 'Servidor de prueba', Version: '10.10.7', Id: SERVER_ID, OperatingSystem: 'Linux'});
		if (/^\/System\/Ping$/i.test(p)) return json(res, 200, 'Jellyfin Server');
		if (/^\/Users\/Public$/i.test(p)) return json(res, 200, users.map((u) => ({...u, ServerId: SERVER_ID})));
		if (/^\/Users\/AuthenticateByName$/i.test(p)) {
			let name = 'Copi';
			try { name = JSON.parse(body).Username || name; } catch (e) { /* */ }
			const user = users.find((u) => u.Name.toLowerCase() === name.toLowerCase()) || users[0];
			return json(res, 200, {User: {...user, ServerId: SERVER_ID, Policy: {IsAdministrator: user.Id === 'user-copi', EnableAllFolders: true}, Configuration: {}}, AccessToken: `token-${user.Id}`, ServerId: SERVER_ID, SessionInfo: {}});
		}
		if (/^\/QuickConnect\/Enabled$/i.test(p)) return json(res, 200, false);
		if (/^\/Branding\/Configuration$/i.test(p)) return json(res, 200, {});
		if ((m = p.match(/^\/Users\/([^/]+)$/i)) && !/Items|Views/i.test(m[1])) {
			const user = users.find((u) => u.Id === m[1]) || users[0];
			return json(res, 200, {...user, ServerId: SERVER_ID, Policy: {IsAdministrator: true, EnableAllFolders: true}, Configuration: {}});
		}
		if (/^\/Users\/Me$/i.test(p)) return json(res, 200, {...users[0], ServerId: SERVER_ID, Policy: {IsAdministrator: true}, Configuration: {}});
		if (/^\/(UserViews|Users\/[^/]+\/Views)$/i.test(p)) return json(res, 200, {Items: [libMovies, libShows, libKids].map((l) => baseItem({...l, ImageTags: {Primary: 'p'}})), TotalRecordCount: 3});
		if (/^\/(UserItems|Users\/[^/]+\/Items)\/Resume$/i.test(p)) {
			const list = [...items.values()].filter((it) => userData(it).PlaybackPositionTicks > 0);
			return json(res, 200, {Items: list.map(baseItem), TotalRecordCount: list.length});
		}
		if (/^\/(Items|Users\/[^/]+\/Items)\/Latest$/i.test(p)) {
			const parentId = q.get('ParentId') || q.get('parentId');
			let list = [...items.values()].filter((it) => ['Movie', 'Series'].includes(it.Type));
			if (parentId) list = list.filter((it) => it.ParentId === parentId);
			list.sort((a, b) => (a.DateCreated < b.DateCreated ? 1 : -1));
			return json(res, 200, list.slice(0, Number(q.get('Limit') || 16)).map(baseItem));
		}
		if (/^\/Shows\/NextUp$/i.test(p)) return json(res, 200, nextUp(q));
		if ((m = p.match(/^\/Shows\/([^/]+)\/Seasons$/i))) {
			const list = [...items.values()].filter((it) => it.Type === 'Season' && it.SeriesId === m[1]);
			return json(res, 200, {Items: list.map(baseItem), TotalRecordCount: list.length});
		}
		if ((m = p.match(/^\/Shows\/([^/]+)\/Episodes$/i))) {
			const seasonId = q.get('SeasonId') || q.get('seasonId');
			const list = [...items.values()].filter((it) => it.Type === 'Episode' && it.SeriesId === m[1] && (!seasonId || it.SeasonId === seasonId));
			return json(res, 200, {Items: list.map(baseItem), TotalRecordCount: list.length});
		}
		if ((m = p.match(/^\/(?:Items|Users\/[^/]+\/Items)\/([^/]+)\/(Similar|ThemeSongs|ThemeMedia|LocalTrailers|SpecialFeatures|Ancestors|Collections)$/i)) || (m = p.match(/^\/Moonfin\/Items\/([^/]+)\/(Similar)$/i))) {
			if (/Similar/i.test(m[2])) {
				const list = [...items.values()].filter((it) => it.Type === 'Movie' && it.Id !== m[1]).slice(0, 12);
				return json(res, 200, {Items: list.map(baseItem), TotalRecordCount: list.length});
			}
			if (/LocalTrailers|SpecialFeatures|Ancestors/i.test(m[2])) return json(res, 200, []);
			return json(res, 200, {Items: [], TotalRecordCount: 0});
		}
		if ((m = p.match(/^\/(?:Items|Users\/[^/]+\/Items)\/([^/]+)$/i)) && !/^(Latest|Resume|Filters2?|Counts)$/i.test(m[1])) {
			const it = items.get(m[1]);
			if (!it) return json(res, 404, {});
			return json(res, 200, baseItem({...it, MediaSources: it.MediaType === 'Video' ? [{Id: it.Id, Container: 'mp4', MediaStreams: [{Type: 'Video', Codec: 'h264', Width: 1920, Height: 1080}, {Type: 'Audio', Codec: 'aac', Language: 'spa', DisplayTitle: 'Español'}]}] : undefined, People: [{Name: 'Actriz Inventada', Role: 'Protagonista', Type: 'Actor', Id: 'person-1'}]}));
		}
		if (/^\/(Items|Users\/[^/]+\/Items)$/i.test(p)) return json(res, 200, filterItems(q));
		if (/^\/(Genres|Studios|Persons|Artists)/i.test(p)) return json(res, 200, {Items: GENRES.map((g, i) => baseItem({Id: `genre-${i}`, Name: g, Type: 'Genre'})), TotalRecordCount: GENRES.length});
		if (/^\/DisplayPreferences\//i.test(p)) return json(res, 200, {Id: 'usersettings', CustomPrefs: {}, SortBy: 'SortName'});
		if (/^\/Sessions/i.test(p) || /^\/(UserItems|Users\/[^/]+\/(PlayedItems|FavoriteItems))/i.test(p)) return json(res, 200, {});
		// Plugin Moonfin y Seerr
		if (/^\/Moonfin\/Ping$/i.test(p)) return json(res, 200, {Installed: true, Version: '1.9.0', SeerrEnabled: true, SettingsSyncEnabled: false, ServerName: 'Servidor de prueba'});
		if (/^\/Moonfin\/Seerr\/Status$/i.test(p)) return json(res, 200, {authenticated: true, enabled: true, url: 'https://seerr.example', username: 'Copi', sessionValid: true});
		if (/^\/Moonfin\/Seerr\/Config$/i.test(p)) return json(res, 200, {enabled: true, url: 'https://seerr.example', displayName: 'Seerr', variant: 'seerr'});
		if (/^\/Moonfin\/Settings$/i.test(p)) return json(res, 200, {});
		if ((m = p.match(/^\/Moonfin\/Seerr\/Api\/(.*)$/i))) {
			const r = seerr(m[1], url);
			if (r === null) fs.appendFileSync(LOG, `SEERR ${req.method} ${m[1]}${url.search}\n`);
			return json(res, 200, r === null ? {} : r);
		}
		if (/^\/Moonfin\//i.test(p)) return json(res, 200, {});
		fs.appendFileSync(LOG, `${req.method} ${p}${url.search}\n`);
		return json(res, 200, {Items: [], TotalRecordCount: 0});
	});
});

server.listen(PORT, () => console.log(`Jellyfin de prueba en http://localhost:${PORT}`));
