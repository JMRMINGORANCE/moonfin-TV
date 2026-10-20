// TaquitoFlix: «Descubrir» (Seerr) al estilo de la portada. Una destacada
// con «Descargar», y filas con todas las categorías; cada carátula dice si
// ya está descargada, descargándose (con su porcentaje) o pedida.
import {useCallback, useEffect, useRef, useState} from 'react';
import Spotlight from '@enact/spotlight';
import Spottable from '@enact/spotlight/Spottable';
import SpotlightContainerDecorator from '@enact/spotlight/SpotlightContainerDecorator';
import {useAuth} from '../../context/AuthContext';
import {useSeerr} from '../../context/SeerrContext';
import * as seerrApi from '../../services/seerrApi';
import CineRow, {Img} from '../../components/cine/CineRow';
import {CineButton, CineToast, EmptyState, TaquitoLoader, useSectionNav, focusSoon} from '../../components/cine/CineBits';
import {backdropUrl, itemTitle, metaLine, overviewOf, seerrState, fromSeerr} from '../../components/cine/cineUtils';

import cineCss from '../../components/cine/Cine.module.less';
import css from '../CineHome/CineHome.module.less';

const SpottableDiv = Spottable('div');
const Buttons = SpotlightContainerDecorator({enterTo: 'last-focused'}, 'div');
const Chips = SpotlightContainerDecorator({enterTo: 'last-focused'}, 'div');

const results = (r) => ((r && r.results) || []).filter((x) => x && (x.mediaType === 'movie' || x.mediaType === 'tv' || x.title || x.name));

const keepUnscrolled = (e) => {
	const el = e.currentTarget;
	if (el.scrollTop) el.scrollTop = 0;
	if (el.scrollLeft) el.scrollLeft = 0;
};

const withType = (type) => (x) => fromSeerr({...x, mediaType: x.mediaType || type});

const CineSeerr = ({onSelectItem, onSelectGenre, onOpenRequests, backHandlerRef}) => {
	const {serverUrl} = useAuth();
	const {isEnabled, isAuthenticated, user: seerrUser} = useSeerr();
	const [rows, setRows] = useState([]);
	const [genres, setGenres] = useState([]);
	const [hero, setHero] = useState(null);
	const [loading, setLoading] = useState(true);
	const [mode, setMode] = useState('hero');
	const [offset, setOffset] = useState(0);
	const [preview, setPreview] = useState(null);
	const [toast, setToast] = useState(null);
	const [busy, setBusy] = useState(false);
	const timer = useRef(null);

	useEffect(() => {
		if (!isEnabled) {
			setLoading(false);
			return undefined;
		}
		let cancelled = false;
		const get = (fn, type) => fn().then((r) => results(r).map(withType(type))).catch(() => []);
		(async () => {
			const [trending, movies, tv, upcoming, upcomingTv, watchlist, genreMovies] = await Promise.all([
				get(() => seerrApi.trending(1)),
				get(() => seerrApi.discover(1), 'movie'),
				get(() => seerrApi.discoverTv(1), 'tv'),
				get(() => seerrApi.upcomingMovies(1), 'movie'),
				get(() => seerrApi.upcomingTv(1), 'tv'),
				get(() => seerrApi.getWatchlist(1)),
				seerrApi.getGenreSliderMovies().catch(() => [])
			]);
			if (cancelled) return;
			const list = [
				{id: 'trending', title: 'Tendencias ahora', items: trending},
				{id: 'movies', title: 'Películas populares', items: movies},
				{id: 'tv', title: 'Series populares', items: tv},
				{id: 'upcoming', title: 'Próximos estrenos de cine', items: upcoming},
				{id: 'upcomingTv', title: 'Series que están por llegar', items: upcomingTv},
				{id: 'watchlist', title: 'Tu lista de deseos', items: watchlist}
			].filter((r) => r.items.length);
			setRows(list);
			setGenres(Array.isArray(genreMovies) ? genreMovies : []);
			setHero(trending.find((x) => x.backdropPath) || trending[0] || null);
			setLoading(false);
		})();
		return () => {
			cancelled = true;
		};
	}, [isEnabled]);

	useEffect(() => {
		if (loading) return;
		setTimeout(() => {
			if (!Spotlight.focus('cine-seerr-buttons')) Spotlight.focus('cine-seerr-chips');
		}, 60);
	}, [loading]);

	useEffect(() => {
		if (!backHandlerRef) return undefined;
		const handler = () => {
			if (mode === 'rows' && hero) {
				setMode('hero');
				setOffset(0);
				setPreview(null);
				focusSoon('cine-seerr-buttons');
				return true;
			}
			return false;
		};
		backHandlerRef.current = handler;
		return () => {
			if (backHandlerRef.current === handler) backHandlerRef.current = null;
		};
	}, [backHandlerRef, mode, hero]);

	const toHero = useCallback(() => {
		setMode('hero');
		setOffset(0);
		setPreview(null);
	}, []);

	const handleFocusRow = useCallback((index, node) => {
		setMode('rows');
		if (node && typeof node.offsetTop === 'number') setOffset(node.offsetTop);
	}, []);

	const handleChipsFocus = useCallback((e) => {
		setMode('rows');
		setOffset(e.currentTarget.offsetTop);
	}, []);

	const handleFocusItem = useCallback((item) => {
		if (timer.current) clearTimeout(timer.current);
		timer.current = setTimeout(() => setPreview(item), 220);
	}, []);

	useEffect(() => () => timer.current && clearTimeout(timer.current), []);

	const heroKey = useCallback((e) => {
		if (e.keyCode === 40) {
			e.preventDefault();
			e.stopPropagation();
			if (!Spotlight.focus('cine-seerr-chips')) Spotlight.focus(`cine-row-${rows[0] && rows[0].id}`);
		}
	}, [rows]);

	const backToHero = useCallback(() => {
		if (!hero) return;
		toHero();
		focusSoon('cine-seerr-buttons');
	}, [hero, toHero]);
	const rowsKey = useSectionNav(backToHero);

	const heroState = hero ? seerrState(hero) : null;
	const canAsk = isAuthenticated && seerrApi.canRequest(seerrUser && seerrUser.permissions);

	const download = useCallback(async () => {
		if (!hero || busy) return;
		setBusy(true);
		try {
			if (hero.mediaType === 'tv') await seerrApi.requestTv(hero.id, {seasons: 'all'});
			else await seerrApi.requestMovie(hero.id);
			setHero({...hero, mediaInfo: {...(hero.mediaInfo || {}), status: 2}});
			setToast({id: Date.now(), title: '¡Pedido!', text: `${itemTitle(hero)} se descargará en cuanto se apruebe.`});
		} catch (e) {
			setToast({id: Date.now(), title: 'No se ha podido pedir', text: (e && e.message) || 'Inténtalo otra vez en un rato.'});
		} finally {
			setBusy(false);
		}
	}, [hero, busy]);

	const info = useCallback(() => hero && onSelectItem?.(hero), [hero, onSelectItem]);
	const openGenre = useCallback((e) => {
		const id = Number(e.currentTarget.getAttribute('data-id'));
		const name = e.currentTarget.getAttribute('data-name');
		onSelectGenre?.(id, name, 'movie');
	}, [onSelectGenre]);
	const clearToast = useCallback(() => setToast(null), []);

	if (loading) return <div className={css.home}><TaquitoLoader text="Buscando estrenos…" /></div>;

	if (!isEnabled || !rows.length) {
		return (
			<div className={css.home}>
				<EmptyState
					title={isEnabled ? 'Seerr no ha respondido' : 'Seerr no está conectado'}
					text={isEnabled ? 'Vuelve a intentarlo en un rato.' : 'Conéctalo en Ajustes › Seerr para pedir películas y series desde la tele.'}
				/>
			</div>
		);
	}

	const shown = mode === 'rows' && preview ? preview : hero;
	const bg = shown ? backdropUrl(serverUrl, shown, 1920) : null;
	const shownState = shown ? seerrState(shown) : null;

	return (
		<div className={`${css.home} ${mode === 'rows' ? css.modeRows : css.modeHero}`} onScroll={keepUnscrolled}>
			<div className={css.backdrop}>
				{bg && <Img key={bg} className={css.backdropImg} src={bg} />}
				<div className={css.shadeLeft} />
				<div className={css.shadeBottom} />
			</div>

			{shown && (
				<div className={css.info} key={(mode === 'rows' ? 'p-' : 'h-') + shown._key}>
					{mode === 'hero' && <div className={css.eyebrow}>TENDENCIA Nº 1 · {shown.mediaType === 'tv' ? 'SERIE' : 'PELÍCULA'}</div>}
					<h1 className={css.title}>{itemTitle(shown)}</h1>
					<div className={css.meta}>{[metaLine(shown), shownState ? shownState.label : ''].filter(Boolean).join('  •  ')}</div>
					<div className={css.overview}>{overviewOf(shown)}</div>
					{mode === 'hero' && (
						<Buttons className={css.heroButtons} spotlightId="cine-seerr-buttons" onFocus={toHero} onKeyDown={heroKey}>
							{!heroState && canAsk && <CineButton primary icon="download" label={busy ? 'Pidiendo…' : 'Descargar'} onClick={download} />}
							{heroState && heroState.kind === 'available' && <CineButton primary icon="play" label="Ver ahora" onClick={info} />}
							<CineButton icon="info" label="Más info" onClick={info} />
							<CineButton icon="check" label="Mis peticiones" onClick={onOpenRequests} />
						</Buttons>
					)}
				</div>
			)}

			<div className={css.rowsViewport} onKeyDown={rowsKey} onScroll={keepUnscrolled}>
				<div className={css.rowsInner} style={{transform: `translate3d(0, ${mode === 'rows' ? -offset : 0}px, 0)`}}>
					{genres.length > 0 && (
						<Chips className={cineCss.chips} spotlightId="cine-seerr-chips" data-cine-section="" onFocus={handleChipsFocus}>
							{genres.map((g) => (
								<SpottableDiv key={g.id} className={cineCss.chip} data-id={g.id} data-name={g.name} onClick={openGenre}>{g.name}</SpottableDiv>
							))}
						</Chips>
					)}
					{rows.map((row, i) => (
						<CineRow
							key={row.id}
							rowId={row.id}
							rowIndex={i}
							title={row.title}
							items={row.items}
							serverUrl={serverUrl}
							onSelectItem={onSelectItem}
							onFocusItem={handleFocusItem}
							onFocusRow={handleFocusRow}
						/>
					))}
					<div className={css.rowsEnd} />
				</div>
			</div>
			{toast && <CineToast key={toast.id} title={toast.title} text={toast.text} duration={4000} onDone={clearToast} />}
		</div>
	);
};

export default CineSeerr;
