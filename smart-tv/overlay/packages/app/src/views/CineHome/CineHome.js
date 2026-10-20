// TaquitoFlix: portada al estilo de las plataformas de streaming.
//
// Arriba una cabecera grande con la película o serie destacada (con su tráiler
// sin sonido) y los botones Reproducir / Más info / Mi lista. Al bajar a las
// filas, la cabecera pasa a enseñar lo que tengas enfocado (la «vista previa
// en vivo») y las filas se deslizan para que la enfocada quede siempre en el
// mismo sitio.
import {useCallback, useEffect, useMemo, useRef, useState} from 'react';
import Spotlight from '@enact/spotlight';
import SpotlightContainerDecorator from '@enact/spotlight/SpotlightContainerDecorator';
import {useAuth} from '../../context/AuthContext';
import {useSettings} from '../../context/SettingsContext';
import {useSeerr} from '../../context/SeerrContext';
import CineRow, {Img} from '../../components/cine/CineRow';
import {CineButton, CineToast, EmptyState, TaquitoLoader, useSectionNav, focusSoon} from '../../components/cine/CineBits';
import {
	backdropUrl, logoUrl, itemTitle, metaLine, overviewOf, episodeLabel, isRecent, shuffle
} from '../../components/cine/cineUtils';
import useTrailerPreview from '../Browse/useTrailerPreview';
import useCineHomeData from './useCineHomeData';

import css from './CineHome.module.less';

const HeroButtons = SpotlightContainerDecorator({enterTo: 'last-focused'}, 'div');

const PREVIEW_DELAY_MS = 220;

// El navegador desplaza cualquier contenedor al enfocar algo dentro, aunque
// tenga overflow: hidden. Aquí todo se mueve con transform, así que se deshace.
const keepUnscrolled = (e) => {
	const el = e.currentTarget;
	if (el.scrollTop) el.scrollTop = 0;
	if (el.scrollLeft) el.scrollLeft = 0;
};

const libraryNoun = (lib) => {
	switch (lib && lib.CollectionType) {
		case 'movies': return 'Películas';
		case 'tvshows': return 'Series';
		default: return lib ? lib.Name : '';
	}
};

const CineHome = ({onSelectItem, onSelectLibrary, onPlay, isVisible = true, backHandlerRef}) => {
	const {api, serverUrl, user} = useAuth();
	const {settings} = useSettings();
	const {isEnabled: seerrEnabled, isAuthenticated: seerrAuthenticated} = useSeerr();
	const seerrReady = !!(seerrEnabled && seerrAuthenticated);
	const {data, loading, arrivals, clearArrivals} = useCineHomeData({api, user, settings, seerrReady, isVisible});

	const [mode, setMode] = useState('hero');
	const [preview, setPreview] = useState(null);
	const [heroFav, setHeroFav] = useState(false);
	const rowsRef = useRef({});
	const previewTimer = useRef(null);
	const placedRef = useRef(false);
	const homeRef = useRef(null);

	// -- la destacada -----------------------------------------------------------
	const hero = useMemo(() => {
		const pool = (data.latest || []).filter((it) => it.BackdropImageTags && it.BackdropImageTags.length && (it.Type === 'Movie' || it.Type === 'Series'));
		if (!pool.length) return (data.latest || [])[0] || null;
		return shuffle(pool.slice(0, 8))[0];
	// La destacada se elige una vez por carga, no en cada repintado.
	// eslint-disable-next-line react-hooks/exhaustive-deps
	}, [data.latest && data.latest.length ? data.latest[0].Id : null]);

	useEffect(() => {
		setHeroFav(!!(hero && hero.UserData && hero.UserData.IsFavorite));
	}, [hero]);

	const getItemServerUrl = useCallback((item) => (item && item._serverUrl) || serverUrl, [serverUrl]);

	const {trailerActive, trailerContainerRef} = useTrailerPreview({
		currentItem: hero,
		isVisible: isVisible && mode === 'hero',
		enabled: settings.featuredTrailerPreview !== false,
		preferMuted: true,
		showCaptions: false,
		captionLanguage: settings.uiLanguage,
		api,
		getItemServerUrl
	});

	// -- filas, en el orden de TaquitoFlix ---------------------------------------
	const rows = useMemo(() => {
		const list = [];
		const add = (id, title, items, variant, extra) => {
			if (items && items.length) list.push({id, title, items, variant: variant || 'poster', ...extra});
		};
		add('libraries', 'Mis bibliotecas', data.libraries, 'library');
		if (settings.cineShowDownloaded !== false) add('downloaded', 'Recién descargado para ti', data.downloaded, 'poster', {badges: true});
		if (settings.cineShowLatest !== false) add('latest', 'Lo último añadido', data.latest, 'poster', {badges: true});
		add('resume', 'Seguir viendo', data.resume, 'landscape');
		add('nextup', 'Siguiente episodio', data.nextUp, 'landscape');
		if (settings.cineShowTop10 !== false && data.top10 && data.top10.length >= 5) add('top10', 'Top 10 en tu biblioteca', data.top10, 'top10');
		if (data.because) add('because', `Porque viste «${itemTitle(data.because.seed)}»`, data.because.items);
		add('mylist', 'Mi lista', data.myList);
		(data.perLibrary || []).forEach(({lib, items}) => add(`lib-${lib.Id}`, `Novedades en ${lib.Name || libraryNoun(lib)}`, items, 'poster', {library: lib}));
		(data.sagas || []).forEach(({box, items}) => add(`saga-${box.Id}`, `Saga: ${box.Name.replace(/\s*-\s*(Colección|Collection)$/i, '')}`, items));
		return list;
	}, [data, settings.cineShowDownloaded, settings.cineShowLatest, settings.cineShowTop10]);

	const badgeFor = useCallback((item) => {
		if (!isRecent(item)) return null;
		return item.Type === 'Series' ? 'NUEVOS EPISODIOS' : 'NUEVO';
	}, []);

	// -- foco --------------------------------------------------------------------
	const registerRow = useCallback((index, node) => {
		if (node) rowsRef.current[index] = node;
		else delete rowsRef.current[index];
	}, []);

	const [offset, setOffset] = useState(0);
	const handleFocusRow = useCallback((index, node) => {
		setMode('rows');
		if (node && typeof node.offsetTop === 'number') setOffset(node.offsetTop);
	}, []);

	const handleFocusItem = useCallback((item) => {
		if (previewTimer.current) clearTimeout(previewTimer.current);
		previewTimer.current = setTimeout(() => setPreview(item), PREVIEW_DELAY_MS);
	}, []);

	useEffect(() => () => previewTimer.current && clearTimeout(previewTimer.current), []);

	const handleHeroFocus = useCallback(() => {
		setMode('hero');
		setPreview(null);
	}, []);

	const focusHero = useCallback(() => {
		setMode('hero');
		setPreview(null);
		return focusSoon('cine-hero');
	}, []);

	// Al llegar a la portada el foco va a «Reproducir»; al volver de otra
	// pantalla, a la tarjeta en la que estabas.
	const lastFocusRef = useRef(null);
	const rememberFocus = useCallback((e) => {
		lastFocusRef.current = e.target;
	}, []);
	useEffect(() => {
		if (!isVisible || loading) return undefined;
		const first = !placedRef.current;
		placedRef.current = true;
		const t = setTimeout(() => {
			const cur = Spotlight.getCurrent();
			if (!first && cur && homeRef.current && homeRef.current.contains(cur)) return;
			const last = lastFocusRef.current;
			if (!first && last && document.body.contains(last) && Spotlight.focus(last)) return;
			if (hero) focusHero();
			else if (rows.length) Spotlight.focus(`cine-row-${rows[0].id}`);
		}, first ? 80 : 120);
		return () => clearTimeout(t);
	// eslint-disable-next-line react-hooks/exhaustive-deps
	}, [isVisible, loading, !!hero]);

	// Atrás desde las filas vuelve arriba; desde arriba deja salir.
	useEffect(() => {
		if (!backHandlerRef || !isVisible) return undefined;
		const handler = () => {
			if (mode === 'rows' && hero) {
				focusHero();
				return true;
			}
			return false;
		};
		backHandlerRef.current = handler;
		return () => {
			if (backHandlerRef.current === handler) backHandlerRef.current = null;
		};
	}, [backHandlerRef, isVisible, mode, hero, focusHero]);

	const handleHeroKeyDown = useCallback((e) => {
		if (e.keyCode === 40 && rows.length) {
			e.preventDefault();
			e.stopPropagation();
			setMode('rows');
			Spotlight.focus(`cine-row-${rows[0].id}`);
		}
	}, [rows]);

	// Arriba desde la primera fila vuelve a la destacada.
	const backToHero = useCallback(() => {
		if (hero) focusHero();
	}, [hero, focusHero]);
	const handleRowKeyDown = useSectionNav(backToHero);

	// -- acciones -----------------------------------------------------------------
	const handleSelect = useCallback((item) => {
		const row = rows.find((r) => r.items.indexOf(item) !== -1);
		if (row && row.id === 'libraries') onSelectLibrary?.(item);
		else onSelectItem?.(item);
	}, [rows, onSelectItem, onSelectLibrary]);

	const playHero = useCallback(() => {
		if (!hero) return;
		if (hero.Type === 'Series') onSelectItem?.(hero);
		else if (onPlay) onPlay(hero, !!(hero.UserData && hero.UserData.PlaybackPositionTicks));
		else onSelectItem?.(hero);
	}, [hero, onPlay, onSelectItem]);

	const infoHero = useCallback(() => hero && onSelectItem?.(hero), [hero, onSelectItem]);

	const toggleHeroFav = useCallback(async () => {
		if (!hero || !api) return;
		const next = !heroFav;
		setHeroFav(next);
		try {
			await api.setFavorite(hero.Id, next);
		} catch (e) {
			setHeroFav(!next);
		}
	}, [api, hero, heroFav]);

	// -- dibujo -------------------------------------------------------------------
	const shown = mode === 'rows' && preview ? preview : hero;
	const isLibraryPreview = shown && (shown.CollectionType || shown.Type === 'CollectionFolder' || shown.Type === 'UserView');
	const bg = shown ? backdropUrl(getItemServerUrl(shown), shown, 1920) : null;
	const logo = shown && !isLibraryPreview ? logoUrl(getItemServerUrl(shown), shown) : null;


	if (loading && !rows.length) {
		return <div className={css.home}><TaquitoLoader /></div>;
	}

	if (!loading && !rows.length && !hero) {
		return (
			<div className={css.home}>
				<EmptyState title="Aún no hay nada por aquí" text="Cuando tu servidor tenga películas o series aparecerán en la portada." />
			</div>
		);
	}

	return (
		<div ref={homeRef} className={`${css.home} ${mode === 'rows' ? css.modeRows : css.modeHero}`} onScroll={keepUnscrolled} onFocus={rememberFocus}>
			<div className={css.backdrop}>
				{bg && <Img key={bg} className={css.backdropImg} src={bg} />}
				<div
					className={`${css.trailer} ${trailerActive && mode === 'hero' ? css.trailerOn : ''}`}
					ref={trailerContainerRef}
				/>
				<div className={css.shadeLeft} />
				<div className={css.shadeBottom} />
			</div>

			{shown && (
				<div className={css.info} key={(mode === 'rows' ? 'p-' : 'h-') + (shown.Id || '')}>
					{logo ? (
						<Img className={css.logo} src={logo} />
					) : (
						<h1 className={css.title}>{itemTitle(shown)}</h1>
					)}
					{episodeLabel(shown) && <div className={css.eyebrow}>{episodeLabel(shown)}</div>}
					{!isLibraryPreview && <div className={css.meta}>{metaLine(shown)}</div>}
					<div className={css.overview}>{isLibraryPreview ? 'Abre la biblioteca para ver todo lo que tiene, de lo más nuevo a lo más antiguo.' : overviewOf(shown)}</div>
					{mode === 'hero' && hero && (
						<HeroButtons className={css.heroButtons} spotlightId="cine-hero" onFocus={handleHeroFocus} onKeyDown={handleHeroKeyDown}>
							<CineButton primary icon="play" label={hero.Type === 'Series' ? 'Ver ahora' : 'Reproducir'} onClick={playHero} spotlightId="cine-hero-play" />
							<CineButton icon="info" label="Más info" onClick={infoHero} />
							<CineButton icon={heroFav ? 'check' : 'plus'} label={heroFav ? 'En mi lista' : 'Mi lista'} onClick={toggleHeroFav} />
						</HeroButtons>
					)}
				</div>
			)}

			<div className={css.rowsViewport} onKeyDown={handleRowKeyDown} onScroll={keepUnscrolled}>
				<div className={css.rowsInner} style={{transform: `translate3d(0, ${mode === 'rows' ? -offset : 0}px, 0)`}}>
					{rows.map((row, i) => (
						<CineRow
							key={row.id}
							rowId={row.id}
							rowIndex={i}
							title={row.title}
							items={row.items}
							variant={row.variant}
							serverUrl={serverUrl}
							badgeFor={row.badges ? badgeFor : null}
							onSelectItem={handleSelect}
							onFocusItem={handleFocusItem}
							onFocusRow={handleFocusRow}
							registerRow={registerRow}
						/>
					))}
					<div className={css.rowsEnd} />
				</div>
			</div>

			{arrivals && isVisible && (
				<CineToast
					title={arrivals.count === 1 ? '¡Ha llegado algo nuevo!' : `¡Han llegado ${arrivals.count} novedades!`}
					text={`Desde tu última visita: ${itemTitle(arrivals.first)}${arrivals.count > 1 ? ' y más' : ''}. Las tienes en «Lo último añadido».`}
					onDone={clearArrivals}
				/>
			)}
		</div>
	);
};

export default CineHome;
