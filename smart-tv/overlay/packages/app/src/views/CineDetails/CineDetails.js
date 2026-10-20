// TaquitoFlix: ficha al estilo de las plataformas de streaming.
//
// Películas, series, temporadas y episodios del servidor, y también lo que
// solo está en Seerr (con su botón «Descargar»). Para el resto de tipos
// (personas, discos, listas…) se sigue usando la ficha de Moonfin.
import {useCallback, useEffect, useMemo, useRef, useState} from 'react';
import Spotlight from '@enact/spotlight';
import Spottable from '@enact/spotlight/Spottable';
import SpotlightContainerDecorator from '@enact/spotlight/SpotlightContainerDecorator';
import {useAuth} from '../../context/AuthContext';
import {useSeerr} from '../../context/SeerrContext';
import * as seerrApi from '../../services/seerrApi';
import {isSeerrOnlyItem} from '../../utils/seerrTarget';
import CineRow, {Img} from '../../components/cine/CineRow';
import {CineButton, CineToast, TaquitoLoader, EmptyState, useSectionNav} from '../../components/cine/CineBits';
import {
	backdropUrl, logoUrl, itemTitle, metaLine, overviewOf, runtimeLabel, seerrState, fromSeerr
} from '../../components/cine/cineUtils';
import Details from '../Details';

import cineCss from '../../components/cine/Cine.module.less';
import css from './CineDetails.module.less';

const SpottableDiv = Spottable('div');
const Actions = SpotlightContainerDecorator({enterTo: 'default-element'}, 'div');
const Chips = SpotlightContainerDecorator({enterTo: 'last-focused'}, 'div');

const HANDLED = ['Movie', 'Series', 'Season', 'Episode', 'Video', 'MusicVideo'];

const itemsOf = (r) => (Array.isArray(r) ? r : (r && Array.isArray(r.Items) ? r.Items : []));

const keepUnscrolled = (e) => {
	const el = e.currentTarget;
	if (el.scrollTop) el.scrollTop = 0;
	if (el.scrollLeft) el.scrollLeft = 0;
};

const remainingLabel = (item) => {
	const pos = item?.UserData?.PlaybackPositionTicks || 0;
	const total = item?.RunTimeTicks || 0;
	if (!pos || !total) return '';
	const left = runtimeLabel(total - pos);
	return left ? `Quedan ${left}` : '';
};

const peopleLine = (people, types, max) => (people || [])
	.filter((p) => types.indexOf(p.Type) !== -1)
	.slice(0, max)
	.map((p) => p.Name)
	.join(', ');

// ---------------------------------------------------------------------------
// Ficha de lo que está en el servidor
// ---------------------------------------------------------------------------

const ServerDetails = ({itemId, initialItem, onPlay, onSelectItem, onSelectPerson, backHandlerRef}) => {
	const {api, serverUrl} = useAuth();
	const [item, setItem] = useState(initialItem && initialItem.Type ? initialItem : null);
	const [seasons, setSeasons] = useState([]);
	const [seasonId, setSeasonId] = useState(null);
	const [episodes, setEpisodes] = useState([]);
	const [nextUp, setNextUp] = useState(null);
	const [similar, setSimilar] = useState([]);
	const [fav, setFav] = useState(false);
	const [played, setPlayed] = useState(false);
	const [toast, setToast] = useState(null);
	const [error, setError] = useState(false);
	const [mode, setMode] = useState('top');
	const [offset, setOffset] = useState(0);
	const placedRef = useRef(null);

	const series = item && (item.Type === 'Series' ? item : null);
	const seriesId = item && (item.Type === 'Series' ? item.Id : item.SeriesId);
	const isShow = !!seriesId;

	// Cargar la ficha.
	useEffect(() => {
		let cancelled = false;
		setError(false);
		api.getItemForDetail(itemId).then((full) => {
			if (cancelled || !full) return;
			setItem(full);
			setFav(!!(full.UserData && full.UserData.IsFavorite));
			setPlayed(!!(full.UserData && full.UserData.Played));
		}).catch(() => !cancelled && setError(true));
		return () => {
			cancelled = true;
		};
	}, [api, itemId]);

	// Temporadas, episodios y «siguiente episodio» de las series.
	useEffect(() => {
		if (!seriesId) return undefined;
		let cancelled = false;
		api.getSeasons(seriesId).then((r) => {
			if (cancelled) return;
			const list = itemsOf(r);
			setSeasons(list);
			const wanted = item.Type === 'Season' ? item.Id : (item.Type === 'Episode' ? item.SeasonId : null);
			setSeasonId((prev) => prev || wanted || (list[0] && list[0].Id) || null);
		}).catch(() => {});
		api.getNextUp(1, seriesId).then((r) => !cancelled && setNextUp(itemsOf(r)[0] || null)).catch(() => {});
		return () => {
			cancelled = true;
		};
	// eslint-disable-next-line react-hooks/exhaustive-deps
	}, [api, seriesId]);

	useEffect(() => {
		if (!seriesId || !seasonId) return undefined;
		let cancelled = false;
		api.getEpisodes(seriesId, seasonId).then((r) => !cancelled && setEpisodes(itemsOf(r))).catch(() => {});
		return () => {
			cancelled = true;
		};
	}, [api, seriesId, seasonId]);

	useEffect(() => {
		const id = seriesId || (item && item.Id);
		if (!id) return undefined;
		let cancelled = false;
		api.getSimilar(id, 16).then((r) => !cancelled && setSimilar(itemsOf(r))).catch(() => {});
		return () => {
			cancelled = true;
		};
	}, [api, seriesId, item && item.Id]); // eslint-disable-line react-hooks/exhaustive-deps

	// El foco empieza en el botón principal.
	useEffect(() => {
		if (!item || placedRef.current === item.Id) return;
		placedRef.current = item.Id;
		setTimeout(() => Spotlight.focus('cine-detail-actions'), 60);
	}, [item]);

	useEffect(() => {
		if (!backHandlerRef) return undefined;
		const handler = () => {
			if (mode === 'rows') {
				setMode('top');
				setOffset(0);
				Spotlight.focus('cine-detail-actions');
				return true;
			}
			return false;
		};
		backHandlerRef.current = handler;
		return () => {
			if (backHandlerRef.current === handler) backHandlerRef.current = null;
		};
	}, [backHandlerRef, mode]);

	// -- qué reproduce el botón grande ------------------------------------------
	const target = useMemo(() => {
		if (!item) return null;
		if (item.Type === 'Series' || item.Type === 'Season') {
			if (nextUp) return nextUp;
			return episodes[0] || null;
		}
		return item;
	}, [item, nextUp, episodes]);

	const resumable = !!(target && target.UserData && target.UserData.PlaybackPositionTicks > 0);

	const playLabel = useMemo(() => {
		if (!target) return 'Reproducir';
		const ep = target.Type === 'Episode' && target.ParentIndexNumber != null && target.IndexNumber != null
			? ` T${target.ParentIndexNumber}:E${target.IndexNumber}` : '';
		if (resumable) return `Reanudar${ep}`;
		return ep && item && item.Type !== 'Episode' ? `Ver${ep}` : 'Reproducir';
	}, [target, resumable, item]);

	const play = useCallback(() => target && onPlay?.(target, resumable), [target, resumable, onPlay]);
	const playFromStart = useCallback(() => target && onPlay?.(target, false), [target, onPlay]);

	const toggleFav = useCallback(async () => {
		const next = !fav;
		setFav(next);
		try {
			await api.setFavorite(item.Id, next);
			setToast({id: Date.now(), title: next ? 'Añadido a Mi lista' : 'Quitado de Mi lista'});
		} catch (e) {
			setFav(!next);
		}
	}, [api, item, fav]);

	const togglePlayed = useCallback(async () => {
		const next = !played;
		setPlayed(next);
		try {
			await api.setWatched(item.Id, next);
			setToast({id: Date.now(), title: next ? 'Marcado como visto' : 'Marcado como no visto'});
		} catch (e) {
			setPlayed(!next);
		}
	}, [api, item, played]);

	const goEpisodes = useCallback(() => {
		if (!Spotlight.focus('cine-row-episodes')) Spotlight.focus('cine-detail-seasons');
	}, []);

	const handleFocusRow = useCallback((index, node) => {
		setMode('rows');
		if (node && typeof node.offsetTop === 'number') setOffset(node.offsetTop);
	}, []);

	const handleChipsFocus = useCallback((e) => {
		setMode('rows');
		setOffset(e.currentTarget.offsetTop);
	}, []);

	const handleActionsFocus = useCallback(() => {
		setMode('top');
		setOffset(0);
	}, []);

	const handleActionsKey = useCallback((e) => {
		if (e.keyCode !== 40) return;
		e.preventDefault();
		e.stopPropagation();
		const order = ['cine-detail-seasons', 'cine-row-episodes', 'cine-row-similar', 'cine-row-cast'];
		for (let i = 0; i < order.length; i++) {
			if (Spotlight.focus(order[i])) break;
		}
	}, []);

	const backToActions = useCallback(() => {
		setMode('top');
		setOffset(0);
		Spotlight.focus('cine-detail-actions');
	}, []);
	const handleRowsKey = useSectionNav(backToActions);

	const pickSeason = useCallback((e) => {
		const id = e.currentTarget.getAttribute('data-season');
		if (id) setSeasonId(id);
	}, []);

	const clearToast = useCallback(() => setToast(null), []);

	const openEpisode = useCallback((ep) => onPlay?.(ep, !!(ep.UserData && ep.UserData.PlaybackPositionTicks > 0)), [onPlay]);
	const openPerson = useCallback((p) => onSelectPerson?.(p), [onSelectPerson]);

	if (error && !item) {
		return <div className={css.page}><EmptyState title="No se ha podido abrir" text="El servidor no ha respondido. Vuelve atrás e inténtalo otra vez." /></div>;
	}
	if (!item) return <div className={css.page}><TaquitoLoader text="" /></div>;

	const shownForArt = series || (item.Type === 'Episode' || item.Type === 'Season' ? {...item, Id: item.SeriesId, BackdropImageTags: item.ParentBackdropImageTags, ImageTags: {}} : item);
	const bg = item.Type === 'Episode' && item.ImageTags && item.ImageTags.Primary
		? backdropUrl(serverUrl, {...item, BackdropImageTags: item.ParentBackdropImageTags || [], Type: 'Episode'}, 1920)
		: backdropUrl(serverUrl, shownForArt, 1920);
	const logo = logoUrl(serverUrl, item);
	const cast = (item.People || []).filter((p) => p.Type === 'Actor').slice(0, 20);
	const castLine = peopleLine(item.People, ['Actor'], 4);
	const directorLine = peopleLine(item.People, ['Director'], 2);
	const meta = metaLine(item);
	const remaining = target === item ? remainingLabel(item) : '';
	const heading = item.Type === 'Episode' ? (item.SeriesName || item.Name) : (item.Type === 'Season' ? (item.SeriesName || item.Name) : item.Name);
	const eyebrow = item.Type === 'Episode'
		? `T${item.ParentIndexNumber}:E${item.IndexNumber}  ${item.Name}`
		: (item.Type === 'Season' ? item.Name : '');
	const videoBadge = (() => {
		const src = item.MediaSources && item.MediaSources[0];
		const v = src && (src.MediaStreams || []).find((s) => s.Type === 'Video');
		if (!v || !v.Width) return '';
		if (v.Width >= 3800) return '4K';
		if (v.Width >= 1900) return 'HD';
		return '';
	})();

	const sections = [];
	if (isShow && seasons.length > 1) sections.push('seasons');
	if (isShow && episodes.length) sections.push('episodes');
	if (similar.length) sections.push('similar');
	if (cast.length) sections.push('cast');

	return (
		<div className={`${css.page} ${mode === 'rows' ? css.modeRows : ''}`} onScroll={keepUnscrolled}>
			<div className={css.backdrop}>
				{bg && <Img key={bg} className={css.backdropImg} src={bg} />}
				<div className={css.shadeLeft} />
				<div className={css.shadeBottom} />
			</div>

			<div className={css.mini}>
				<div className={css.miniTitle}>{heading}</div>
				<div className={css.miniMeta}>{eyebrow || meta}</div>
			</div>

			<div className={css.info}>
				{logo ? <Img className={css.logo} src={logo} /> : <h1 className={css.title}>{heading}</h1>}
				{eyebrow && <div className={css.eyebrow}>{eyebrow}</div>}
				<div className={css.meta}>
					{meta}
					{videoBadge && <span className={css.badgeBox}>{videoBadge}</span>}
				</div>
				{remaining && (
					<div className={css.remaining}>
						<div className={css.remainingBar}><div className={css.remainingFill} style={{width: (item.UserData.PlayedPercentage || 0) + '%'}} /></div>
						<span>{remaining}</span>
					</div>
				)}
				<div className={css.overview}>{overviewOf(item) || overviewOf(series)}</div>
				{castLine && <div className={css.people}><span>Reparto: </span>{castLine}</div>}
				{directorLine && <div className={css.people}><span>Dirección: </span>{directorLine}</div>}

				<Actions className={css.actions} spotlightId="cine-detail-actions" onFocus={handleActionsFocus} onKeyDown={handleActionsKey}>
					<CineButton primary icon="play" label={playLabel} onClick={play} className="spottable-default" />
					{resumable && <CineButton icon="restart" label="Desde el principio" onClick={playFromStart} />}
					{isShow && item.Type !== 'Episode' && episodes.length > 0 && <CineButton icon="chevron" label="Episodios" onClick={goEpisodes} />}
					<CineButton icon={fav ? 'check' : 'plus'} label={fav ? 'En mi lista' : 'Mi lista'} onClick={toggleFav} />
					<CineButton icon={played ? 'check' : 'thumb'} label={played ? 'Visto' : 'Marcar visto'} onClick={togglePlayed} />
				</Actions>
			</div>

			<div className={css.rowsViewport} onKeyDown={handleRowsKey} onScroll={keepUnscrolled}>
				<div className={css.rowsInner} style={{transform: `translate3d(0, ${mode === 'rows' ? -offset : 0}px, 0)`}}>
					{sections.indexOf('seasons') !== -1 && (
						<Chips className={cineCss.chips} spotlightId="cine-detail-seasons" data-cine-section="" onFocus={handleChipsFocus} data-first-section={sections[0] === 'seasons' ? '' : undefined}>
							{seasons.map((s) => (
								<SpottableDiv
									key={s.Id}
									data-season={s.Id}
									className={`${cineCss.chip} ${s.Id === seasonId ? cineCss.chipActive : ''}`}
									onClick={pickSeason}
									onFocus={pickSeason}
								>
									{s.Name}
								</SpottableDiv>
							))}
						</Chips>
					)}
					{sections.indexOf('episodes') !== -1 && (
						<div data-first-section={sections[0] === 'episodes' ? '' : undefined}>
							<CineRow
								rowId="episodes"
								rowIndex={1}
								title={seasons.length === 1 ? 'Episodios' : `Episodios · ${(seasons.find((s) => s.Id === seasonId) || {}).Name || ''}`}
								items={episodes}
								variant="episode"
								serverUrl={serverUrl}
								onSelectItem={openEpisode}
								onFocusRow={handleFocusRow}
							/>
						</div>
					)}
					{sections.indexOf('similar') !== -1 && (
						<div data-first-section={sections[0] === 'similar' ? '' : undefined}>
							<CineRow rowId="similar" rowIndex={2} title="Más títulos similares" items={similar} serverUrl={serverUrl} onSelectItem={onSelectItem} onFocusRow={handleFocusRow} />
						</div>
					)}
					{sections.indexOf('cast') !== -1 && (
						<div data-first-section={sections[0] === 'cast' ? '' : undefined}>
							<CineRow rowId="cast" rowIndex={3} title="Reparto" items={cast} variant="person" serverUrl={serverUrl} onSelectItem={openPerson} onFocusRow={handleFocusRow} />
						</div>
					)}
					<div className={css.rowsEnd} />
				</div>
			</div>
			{toast && <CineToast key={toast.id} title={toast.title} duration={2500} onDone={clearToast} />}
		</div>
	);
};

// ---------------------------------------------------------------------------
// Ficha de lo que solo está en Seerr: se puede pedir con «Descargar»
// ---------------------------------------------------------------------------

const SeerrDetails = ({initialItem, seerrNav, backHandlerRef}) => {
	const {serverUrl} = useAuth();
	const {user: seerrUser, isAuthenticated} = useSeerr();
	const mediaType = initialItem._seerrMediaType || (initialItem.Type === 'Series' ? 'tv' : 'movie');
	const tmdbId = initialItem._seerrMediaId;
	const [data, setData] = useState(null);
	const [similar, setSimilar] = useState([]);
	const [busy, setBusy] = useState(false);
	const [toast, setToast] = useState(null);
	const [error, setError] = useState(false);
	const [mode, setMode] = useState('top');

	const load = useCallback(async () => {
		if (!tmdbId) return;
		try {
			const d = mediaType === 'tv' ? await seerrApi.getTv(tmdbId) : await seerrApi.getMovie(tmdbId);
			setData({...d, mediaType});
		} catch (e) {
			setError(true);
		}
	}, [mediaType, tmdbId]);

	useEffect(() => {
		load();
		if (!tmdbId) return;
		const rec = mediaType === 'tv' ? seerrApi.getTvRecommendations : seerrApi.getMovieRecommendations;
		rec(tmdbId).then((r) => setSimilar(((r && r.results) || []).map(fromSeerr))).catch(() => {});
	}, [load, mediaType, tmdbId]);

	useEffect(() => {
		if (data) setTimeout(() => Spotlight.focus('cine-detail-actions'), 60);
	}, [data]);

	useEffect(() => {
		if (!backHandlerRef) return undefined;
		const handler = () => {
			if (mode === 'rows') {
				setMode('top');
				Spotlight.focus('cine-detail-actions');
				return true;
			}
			return false;
		};
		backHandlerRef.current = handler;
		return () => {
			if (backHandlerRef.current === handler) backHandlerRef.current = null;
		};
	}, [backHandlerRef, mode]);

	const state = data ? seerrState(data) : null;
	const canAsk = isAuthenticated && seerrApi.canRequest(seerrUser && seerrUser.permissions);

	const download = useCallback(async () => {
		if (!data || busy) return;
		setBusy(true);
		try {
			if (mediaType === 'tv') await seerrApi.requestTv(tmdbId, {seasons: 'all'});
			else await seerrApi.requestMovie(tmdbId);
			setToast({title: '¡Pedido!', text: 'Te avisaremos cuando esté lista para ver.'});
			await load();
		} catch (e) {
			setToast({title: 'No se ha podido pedir', text: (e && e.message) || 'Inténtalo otra vez en un rato.'});
		} finally {
			setBusy(false);
		}
	}, [data, busy, mediaType, tmdbId, load]);

	const openSimilar = useCallback((r) => seerrNav?.onSelectItem?.(r), [seerrNav]);
	const toTop = useCallback(() => setMode('top'), []);
	const backToActionsSeerr = useCallback(() => {
		setMode('top');
		Spotlight.focus('cine-detail-actions');
	}, []);
	const seerrRowsKey = useSectionNav(backToActionsSeerr);
	const toRows = useCallback(() => setMode('rows'), []);
	const downToRows = useCallback((e) => {
		if (e.keyCode === 40 && Spotlight.focus('cine-row-similar')) {
			e.preventDefault();
			e.stopPropagation();
		}
	}, []);

	if (error) return <div className={css.page}><EmptyState title="No se ha podido abrir" text="Seerr no ha respondido. Vuelve atrás e inténtalo otra vez." /></div>;
	if (!data) return <div className={css.page}><TaquitoLoader text="" /></div>;

	const item = {...data, _seerr: true};
	const bg = backdropUrl(serverUrl, item, 1920);
	const runtime = data.runtime ? `${Math.floor(data.runtime / 60) ? Math.floor(data.runtime / 60) + ' h ' : ''}${data.runtime % 60} min` : '';
	const seasonsLabel = mediaType === 'tv' && data.numberOfSeasons ? (data.numberOfSeasons === 1 ? '1 temporada' : `${data.numberOfSeasons} temporadas`) : '';
	const meta = [metaLine(item), runtime, seasonsLabel, ...(data.genres || []).slice(0, 2).map((g) => g.name)].filter(Boolean).join('  •  ');
	const cast = ((data.credits && data.credits.cast) || []).slice(0, 4).map((c) => c.name).join(', ');
	const director = ((data.credits && data.credits.crew) || []).filter((c) => c.job === 'Director').slice(0, 2).map((c) => c.name).join(', ');

	let action;
	if (state && state.kind === 'available') action = <div className={`${css.statePill} ${css.stateAvailable}`}>{state.label}</div>;
	else if (state && state.kind === 'downloading') action = <div className={`${css.statePill} ${css.stateDownloading}`}>{state.label}</div>;
	else if (state && state.kind === 'pending') action = <div className={css.statePill}>PEDIDA · ESPERANDO APROBACIÓN</div>;

	return (
		<div className={`${css.page} ${mode === 'rows' ? css.modeRows : ''}`} onScroll={keepUnscrolled}>
			<div className={css.backdrop}>
				{bg && <Img key={bg} className={css.backdropImg} src={bg} />}
				<div className={css.shadeLeft} />
				<div className={css.shadeBottom} />
			</div>
			<div className={css.mini}>
				<div className={css.miniTitle}>{itemTitle(item)}</div>
				<div className={css.miniMeta}>{meta}</div>
			</div>
			<div className={css.info}>
				<h1 className={css.title}>{itemTitle(item)}</h1>
				<div className={css.meta}>{meta}</div>
				<div className={css.overview}>{data.overview || 'Sin sinopsis todavía.'}</div>
				{cast && <div className={css.people}><span>Reparto: </span>{cast}</div>}
				{director && <div className={css.people}><span>Dirección: </span>{director}</div>}
				{(!state || state.kind !== 'available') && <div className={css.seerrNote}>Aún no está en tu biblioteca.</div>}
				<Actions className={css.actions} spotlightId="cine-detail-actions" onFocus={toTop} onKeyDown={downToRows}>
					{action}
					{!state && canAsk && <CineButton primary icon="download" label={busy ? 'Pidiendo…' : 'Descargar'} onClick={download} className="spottable-default" />}
					{!state && !canAsk && <div className={css.statePill}>TU USUARIO DE SEERR NO PUEDE PEDIR</div>}
					{state && <CineButton icon="restart" label="Actualizar estado" onClick={load} />}
				</Actions>
			</div>
			<div className={css.rowsViewport} onKeyDown={seerrRowsKey} onScroll={keepUnscrolled}>
				<div className={css.rowsInner}>
					<CineRow rowId="similar" rowIndex={0} title="Más títulos similares" items={similar} serverUrl={serverUrl} onSelectItem={openSimilar} onFocusRow={toRows} />
				</div>
			</div>
			{toast && <CineToast title={toast.title} text={toast.text} duration={4000} onDone={() => setToast(null)} />}
		</div>
	);
};

// ---------------------------------------------------------------------------

const CineDetails = (props) => {
	const {initialItem, autoPlay} = props;
	if (isSeerrOnlyItem(initialItem) && initialItem._seerrMediaId != null) return <SeerrDetails {...props} />;
	const type = initialItem && initialItem.Type;
	if (!autoPlay && HANDLED.indexOf(type) !== -1 && !isSeerrOnlyItem(initialItem)) {
		return <ServerDetails key={props.itemId} {...props} />;
	}
	return <Details {...props} />;
};

export default CineDetails;
