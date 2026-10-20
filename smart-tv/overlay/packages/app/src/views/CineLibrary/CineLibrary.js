// TaquitoFlix: página de biblioteca (Películas / Series) al estilo de las
// plataformas de streaming: cabecera con lo último que ha llegado, chips
// «Ver todo» y «Categorías», y filas siempre con lo más reciente primero
// (añadidas, sin ver, mi lista, por género) más las mejor valoradas.
// Las bibliotecas de otro tipo (música, libros, vídeos caseros…) siguen con
// la pantalla de Moonfin, que ahora ordena por fecha de llegada.
import {useCallback, useEffect, useRef, useState} from 'react';
import Spotlight from '@enact/spotlight';
import Spottable from '@enact/spotlight/Spottable';
import SpotlightContainerDecorator from '@enact/spotlight/SpotlightContainerDecorator';
import {useAuth} from '../../context/AuthContext';
import {HOME_ROW_ITEM_FIELDS} from '../../services/jellyfinApi';
import CineRow, {Img} from '../../components/cine/CineRow';
import {CineButton, EmptyState, TaquitoLoader, useSectionNav, focusSoon} from '../../components/cine/CineBits';
import {backdropUrl, logoUrl, itemTitle, metaLine, overviewOf, isRecent} from '../../components/cine/cineUtils';
import Library from '../Library';

import cineCss from '../../components/cine/Cine.module.less';
import css from '../CineHome/CineHome.module.less';

const SpottableDiv = Spottable('div');
const Buttons = SpotlightContainerDecorator({enterTo: 'last-focused'}, 'div');
const Chips = SpotlightContainerDecorator({enterTo: 'last-focused'}, 'div');

const FIELDS = HOME_ROW_ITEM_FIELDS + ',ChildCount';
const CINE_TYPES = {movies: 'Movie', tvshows: 'Series'};

const itemsOf = (r) => (Array.isArray(r) ? r : (r && Array.isArray(r.Items) ? r.Items : []));

const keepUnscrolled = (e) => {
	const el = e.currentTarget;
	if (el.scrollTop) el.scrollTop = 0;
	if (el.scrollLeft) el.scrollLeft = 0;
};

const CineLibraryRows = ({library, onSelectItem, onPlay, backHandlerRef, libraryProps}) => {
	const {api, serverUrl} = useAuth();
	const type = CINE_TYPES[library.CollectionType];
	const noun = type === 'Series' ? 'series' : 'películas';
	const [rows, setRows] = useState([]);
	const [hero, setHero] = useState(null);
	const [genres, setGenres] = useState([]);
	const [loading, setLoading] = useState(true);
	const [mode, setMode] = useState('hero');
	const [offset, setOffset] = useState(0);
	const [preview, setPreview] = useState(null);
	const [grid, setGrid] = useState(null); // null | {genre}
	const [showGenres, setShowGenres] = useState(false);
	const innerBackRef = useRef(null);
	const timer = useRef(null);

	useEffect(() => {
		let cancelled = false;
		const q = (extra) => api.getItems({
			ParentId: library.Id, IncludeItemTypes: type, Recursive: true, Fields: FIELDS,
			ImageTypeLimit: 1, Limit: 30, SortBy: 'DateCreated,SortName', SortOrder: 'Descending', ...extra
		}).then(itemsOf).catch(() => []);
		(async () => {
			const [recent, unwatched, mine, top, genreList] = await Promise.all([
				q({}),
				q({Filters: 'IsUnplayed'}),
				q({Filters: 'IsFavorite'}),
				q({SortBy: 'CommunityRating,SortName', HasPrimaryImage: true}),
				api.getGenres(library.Id, type).then(itemsOf).catch(() => [])
			]);
			if (cancelled) return;
			const base = [
				{id: 'recent', title: 'Añadidas recientemente', items: recent, badges: true},
				{id: 'unwatched', title: type === 'Series' ? 'Aún no las has empezado' : 'Aún no las has visto', items: unwatched},
				{id: 'mine', title: 'Mi lista', items: mine},
				{id: 'top', title: 'Las más valoradas', items: top}
			];
			setRows(base.filter((r) => r.items.length));
			setGenres(genreList);
			const withArt = recent.filter((it) => it.BackdropImageTags && it.BackdropImageTags.length);
			setHero(withArt[0] || recent[0] || null);
			setLoading(false);
			// Filas por género (las seis con más títulos), también lo más nuevo primero.
			const picks = genreList.slice().sort((a, b) => (b.ChildCount || 0) - (a.ChildCount || 0)).slice(0, 6);
			const byGenre = await Promise.all(picks.map((g) => q({Genres: g.Name, Limit: 24}).then((items) => ({id: 'g-' + g.Id, title: g.Name, items}))));
			if (!cancelled) setRows((prev) => prev.concat(byGenre.filter((r) => r.items.length >= 3)));
		})();
		return () => {
			cancelled = true;
		};
	}, [api, library.Id, type]);

	useEffect(() => {
		if (loading || grid) return;
		setTimeout(() => {
			if (!Spotlight.focus('cine-lib-buttons')) Spotlight.focus('cine-lib-chips');
		}, 60);
	}, [loading, grid]);

	useEffect(() => {
		if (!backHandlerRef) return undefined;
		const handler = () => {
			if (grid) {
				if (innerBackRef.current?.()) return true;
				setGrid(null);
				return true;
			}
			if (showGenres) {
				setShowGenres(false);
				Spotlight.focus('cine-lib-chips');
				return true;
			}
			if (mode === 'rows') {
				setMode('hero');
				setOffset(0);
				focusSoon('cine-lib-buttons');
				return true;
			}
			return false;
		};
		backHandlerRef.current = handler;
		return () => {
			if (backHandlerRef.current === handler) backHandlerRef.current = null;
		};
	}, [backHandlerRef, grid, showGenres, mode]);

	const toHero = useCallback(() => {
		setMode('hero');
		setOffset(0);
		setPreview(null);
	}, []);

	const handleFocusRow = useCallback((index, node) => {
		setMode('rows');
		if (node && typeof node.offsetTop === 'number') setOffset(node.offsetTop);
	}, []);

	const handleFocusItem = useCallback((item) => {
		if (timer.current) clearTimeout(timer.current);
		timer.current = setTimeout(() => setPreview(item), 220);
	}, []);

	useEffect(() => () => timer.current && clearTimeout(timer.current), []);

	const handleChipsFocus = useCallback((e) => {
		setMode('rows');
		setOffset(e.currentTarget.offsetTop);
	}, []);

	const openAll = useCallback(() => setGrid({genre: null}), []);
	const toggleGenres = useCallback(() => setShowGenres((v) => !v), []);
	const openGenre = useCallback((e) => {
		const name = e.currentTarget.getAttribute('data-genre');
		setShowGenres(false);
		setGrid({genre: name});
	}, []);

	const playHero = useCallback(() => {
		if (!hero) return;
		if (hero.Type === 'Series') onSelectItem?.(hero);
		else onPlay?.(hero, !!(hero.UserData && hero.UserData.PlaybackPositionTicks));
	}, [hero, onPlay, onSelectItem]);
	const infoHero = useCallback(() => hero && onSelectItem?.(hero), [hero, onSelectItem]);

	const heroKey = useCallback((e) => {
		if (e.keyCode === 40) {
			e.preventDefault();
			e.stopPropagation();
			Spotlight.focus('cine-lib-chips');
		}
	}, []);

	const backToHero = useCallback(() => {
		if (!hero) return;
		toHero();
		focusSoon('cine-lib-buttons');
	}, [hero, toHero]);
	const rowsKey = useSectionNav(backToHero);

	const badgeFor = useCallback((item) => (isRecent(item) ? (item.Type === 'Series' ? 'NUEVOS EPISODIOS' : 'NUEVO') : null), []);

	const shown = mode === 'rows' && preview ? preview : hero;
	const bg = shown ? backdropUrl(serverUrl, shown, 1920) : null;
	const logo = shown ? logoUrl(serverUrl, shown) : null;

	if (grid) {
		return <Library {...libraryProps} library={library} genreFilter={grid.genre || undefined} backHandlerRef={innerBackRef} />;
	}

	if (loading) return <div className={css.home}><TaquitoLoader text="" /></div>;

	if (!rows.length) {
		return (
			<div className={css.home}>
				<EmptyState title={`Aún no hay ${noun}`} text="Cuando lleguen aparecerán aquí, con lo más nuevo primero." />
			</div>
		);
	}

	return (
		<div className={`${css.home} ${mode === 'rows' ? css.modeRows : css.modeHero}`} onScroll={keepUnscrolled}>
			<div className={css.backdrop}>
				{bg && <Img key={bg} className={css.backdropImg} src={bg} />}
				<div className={css.shadeLeft} />
				<div className={css.shadeBottom} />
			</div>

			{shown && (
				<div className={css.info} key={(mode === 'rows' ? 'p-' : 'h-') + shown.Id}>
					{mode === 'hero' && <div className={css.eyebrow}>{library.Name.toUpperCase()} · LO ÚLTIMO QUE HA LLEGADO</div>}
					{logo ? <Img className={css.logo} src={logo} /> : <h1 className={css.title}>{itemTitle(shown)}</h1>}
					<div className={css.meta}>{metaLine(shown)}</div>
					<div className={css.overview}>{overviewOf(shown)}</div>
					{mode === 'hero' && (
						<Buttons className={css.heroButtons} spotlightId="cine-lib-buttons" onFocus={toHero} onKeyDown={heroKey}>
							<CineButton primary icon="play" label={hero.Type === 'Series' ? 'Ver ahora' : 'Reproducir'} onClick={playHero} />
							<CineButton icon="info" label="Más info" onClick={infoHero} />
						</Buttons>
					)}
				</div>
			)}

			<div className={css.rowsViewport} onKeyDown={rowsKey} onScroll={keepUnscrolled}>
				<div className={css.rowsInner} style={{transform: `translate3d(0, ${mode === 'rows' ? -offset : 0}px, 0)`}}>
					<Chips className={cineCss.chips} spotlightId="cine-lib-chips" data-cine-section="" onFocus={handleChipsFocus}>
						<SpottableDiv className={cineCss.chip} onClick={openAll}>{`Ver todas (de la más nueva a la más antigua)`}</SpottableDiv>
						<SpottableDiv className={`${cineCss.chip} ${showGenres ? cineCss.chipActive : ''}`} onClick={toggleGenres}>{'Categorías ▾'}</SpottableDiv>
					</Chips>
					{showGenres && (
						<Chips className={cineCss.chips} spotlightId="cine-lib-genres" data-cine-section="" onFocus={handleChipsFocus}>
							{genres.map((g) => (
								<SpottableDiv key={g.Id} className={cineCss.chip} data-genre={g.Name} onClick={openGenre}>{g.Name}</SpottableDiv>
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
							badgeFor={row.badges ? badgeFor : null}
							onSelectItem={onSelectItem}
							onFocusItem={handleFocusItem}
							onFocusRow={handleFocusRow}
						/>
					))}
					<div className={css.rowsEnd} />
				</div>
			</div>
		</div>
	);
};

const CineLibrary = (props) => {
	const {library, genreFilter, studioFilter} = props;
	if (library && CINE_TYPES[library.CollectionType] && !genreFilter && !studioFilter) {
		return <CineLibraryRows key={library.Id} library={library} onSelectItem={props.onSelectItem} onPlay={props.onPlay} backHandlerRef={props.backHandlerRef} libraryProps={props} />;
	}
	return <Library {...props} />;
};

export default CineLibrary;
