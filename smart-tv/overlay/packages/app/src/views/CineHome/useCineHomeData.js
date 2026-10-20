// TaquitoFlix: datos de la portada. Cada fila se pide por su cuenta y aparece
// en cuanto llega, así la portada se ve enseguida aunque el servidor tarde.
import {useCallback, useEffect, useRef, useState} from 'react';
import * as seerrApi from '../../services/seerrApi';
import {HOME_ROW_ITEM_FIELDS} from '../../services/jellyfinApi';
import {byDateCreatedDesc, isStaleResume, shuffle} from '../../components/cine/cineUtils';

const FIELDS = HOME_ROW_ITEM_FIELDS + ',RemoteTrailers,ChildCount';
const VIDEO_LIBS = ['movies', 'tvshows', 'homevideos', 'musicvideos', 'mixed', undefined, null, ''];
const LAST_VISIT_KEY = 'taquito_last_home_visit';

const safe = async (fn, fallback) => {
	try {
		const r = await fn();
		return r == null ? fallback : r;
	} catch (e) {
		return fallback;
	}
};

const itemsOf = (r) => (Array.isArray(r) ? r : (r && Array.isArray(r.Items) ? r.Items : []));

const readLastVisit = () => {
	try {
		return Number(localStorage.getItem(LAST_VISIT_KEY)) || 0;
	} catch (e) {
		return 0;
	}
};

const writeLastVisit = () => {
	try {
		localStorage.setItem(LAST_VISIT_KEY, String(Date.now()));
	} catch (e) { /* sin almacenamiento: no pasa nada */ }
};

export default function useCineHomeData({api, user, settings, seerrReady, isVisible}) {
	const [data, setData] = useState({});
	const [loading, setLoading] = useState(true);
	const [arrivals, setArrivals] = useState(null);
	const genRef = useRef(0);
	const lastLoadRef = useRef(0);

	const patch = useCallback((gen, values) => {
		if (gen !== genRef.current) return;
		setData((prev) => ({...prev, ...values}));
	}, []);

	const load = useCallback(async () => {
		if (!api || !user?.Id) return;
		const gen = ++genRef.current;
		lastLoadRef.current = Date.now();

		// Bibliotecas primero: el resto de filas (novedades por biblioteca) salen de ellas.
		const libsP = safe(() => api.getLibraries(), {Items: []}).then((r) => {
			const libs = itemsOf(r).filter((l) => l.CollectionType !== 'playlists' && l.CollectionType !== 'boxsets');
			patch(gen, {libraries: libs});
			return libs;
		});

		const resumeP = safe(() => api.getResumeItems(24), {Items: []}).then((r) => {
			let list = itemsOf(r);
			if (settings.cineHideStaleResume !== false) list = list.filter((it) => !isStaleResume(it));
			patch(gen, {resume: list});
		});

		const nextUpP = safe(() => api.getNextUp(20), {Items: []}).then((r) => patch(gen, {nextUp: itemsOf(r)}));

		const topP = safe(() => api.getItems({
			IncludeItemTypes: 'Movie,Series', Recursive: true, SortBy: 'CommunityRating,SortName',
			SortOrder: 'Descending', Limit: 10, Fields: FIELDS, ImageTypeLimit: 1, HasPrimaryImage: true
		}), {Items: []}).then((r) => patch(gen, {top10: itemsOf(r).filter((it) => it.CommunityRating)}));

		const favP = safe(() => api.getItems({
			Filters: 'IsFavorite', IncludeItemTypes: 'Movie,Series', Recursive: true,
			SortBy: 'DateCreated', SortOrder: 'Descending', Limit: 30, Fields: FIELDS
		}), {Items: []}).then((r) => patch(gen, {myList: itemsOf(r)}));

		// «Porque viste…»: lo último que terminaste y lo que se le parece.
		const becauseP = safe(() => api.getItems({
			Filters: 'IsPlayed', IncludeItemTypes: 'Movie,Series', Recursive: true,
			SortBy: 'DatePlayed', SortOrder: 'Descending', Limit: 1, Fields: FIELDS
		}), {Items: []}).then(async (r) => {
			const seed = itemsOf(r)[0];
			if (!seed) return;
			const similar = itemsOf(await safe(() => api.getSimilar(seed.Id, 16), {Items: []}));
			if (similar.length) patch(gen, {because: {seed, items: similar}});
		});

		const latestP = libsP.then(async (libs) => {
			const video = libs.filter((l) => VIDEO_LIBS.indexOf(l.CollectionType) !== -1);
			const perLib = await Promise.all(video.map((lib) => safe(() => api.getLatest(lib.Id, 20), []).then((r) => ({lib, items: itemsOf(r)}))));
			const seen = {};
			const all = [];
			perLib.forEach(({items}) => items.forEach((it) => {
				if (!seen[it.Id]) {
					seen[it.Id] = true;
					all.push(it);
				}
			}));
			all.sort(byDateCreatedDesc);
			patch(gen, {latest: all.slice(0, 40), perLibrary: perLib.filter((p) => p.items.length >= 3)});

			// Aviso de novedades desde la última vez que abriste la portada.
			const last = readLastVisit();
			if (last) {
				const fresh = all.filter((it) => (Date.parse(it.DateCreated || '') || 0) > last);
				if (fresh.length) setArrivals({count: fresh.length, first: fresh[0]});
			}
			writeLastVisit();
			return all;
		});

		// Sagas: hasta cuatro colecciones al azar con al menos tres títulos,
		// ordenados por fecha de estreno.
		const sagasP = settings.cineShowSagas === false ? Promise.resolve() : safe(() => api.getCollections(60), {Items: []}).then(async (r) => {
			const picks = shuffle(itemsOf(r)).slice(0, 8);
			const sagas = [];
			for (const box of picks) {
				if (sagas.length >= 4) break;
				const kids = itemsOf(await safe(() => api.getCollectionItems(box.Id, 40, 'PremiereDate,ProductionYear,SortName', 'Ascending'), {Items: []}));
				if (kids.length >= 3) sagas.push({box, items: kids});
			}
			patch(gen, {sagas});
		});

		// «Recién descargado para ti»: lo que Seerr ya tiene disponible, cruzado
		// con tu biblioteca por el id de TMDB.
		const downloadedP = !seerrReady || settings.cineShowDownloaded === false ? Promise.resolve() : (async () => {
			const req = await safe(() => seerrApi.getRequests('available', 30, 0, 'modified'), null);
			const results = (req && req.results) || [];
			const tmdb = {};
			results.forEach((x, i) => {
				const id = x.media && (x.media.tmdbId || x.media.tmdbid);
				if (id && tmdb[id] == null) tmdb[id] = i;
			});
			if (!Object.keys(tmdb).length) return;
			const recent = itemsOf(await safe(() => api.getItems({
				IncludeItemTypes: 'Movie,Series', Recursive: true, SortBy: 'DateCreated', SortOrder: 'Descending',
				Limit: 200, Fields: FIELDS + ',ProviderIds'
			}), {Items: []}));
			const matched = recent
				.filter((it) => it.ProviderIds && tmdb[it.ProviderIds.Tmdb || it.ProviderIds.tmdb] != null)
				.sort((a, b) => tmdb[a.ProviderIds.Tmdb || a.ProviderIds.tmdb] - tmdb[b.ProviderIds.Tmdb || b.ProviderIds.tmdb]);
			patch(gen, {downloaded: matched});
		})();

		await Promise.all([libsP, resumeP, nextUpP, latestP]);
		if (gen === genRef.current) setLoading(false);
		await Promise.all([topP, favP, becauseP, sagasP, downloadedP]);
	}, [api, user, settings.cineHideStaleResume, settings.cineShowSagas, settings.cineShowDownloaded, seerrReady, patch]);

	useEffect(() => {
		load();
	}, [load]);

	// Al volver a la portada se refresca lo que cambia al ver cosas.
	useEffect(() => {
		if (!isVisible || !api) return;
		if (Date.now() - lastLoadRef.current < 15000) return;
		const gen = genRef.current;
		safe(() => api.getResumeItems(24), {Items: []}).then((r) => {
			let list = itemsOf(r);
			if (settings.cineHideStaleResume !== false) list = list.filter((it) => !isStaleResume(it));
			patch(gen, {resume: list});
		});
		safe(() => api.getNextUp(20), {Items: []}).then((r) => patch(gen, {nextUp: itemsOf(r)}));
	}, [isVisible, api, settings.cineHideStaleResume, patch]);

	const clearArrivals = useCallback(() => setArrivals(null), []);

	return {data, loading, arrivals, clearArrivals, reload: load};
}
