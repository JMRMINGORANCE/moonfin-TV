// TaquitoFlix: fila horizontal de la portada al estilo de las plataformas de
// streaming. Carátulas verticales, apaisadas (con barra de progreso), tarjetas
// de biblioteca y el Top 10 con números grandes.
import {memo, useCallback, useRef} from 'react';
import Spottable from '@enact/spotlight/Spottable';
import SpotlightContainerDecorator from '@enact/spotlight/SpotlightContainerDecorator';
import Spotlight from '@enact/spotlight';
import useItemMenuHold, {itemWithIdAt} from '../../hooks/useItemMenuHold';
import {getImageUrl} from '../../utils/helpers';
import {
	posterUrl, landscapeUrl, itemTitle, episodeLabel, progressOf, itemKey, isSeerrItem, seerrState, runtimeLabel
} from './cineUtils';

import css from './Cine.module.less';

const SpottableDiv = Spottable('div');

const keepUnscrolled = (e) => {
	const el = e.currentTarget;
	if (el.scrollLeft) el.scrollLeft = 0;
	if (el.scrollTop) el.scrollTop = 0;
};

const RowContainer = SpotlightContainerDecorator({enterTo: 'last-focused', restrict: 'self-first'}, 'div');

const hideBroken = (e) => { e.currentTarget.style.visibility = 'hidden'; };

export const Img = ({src, className}) => {
	if (!src) return null;
	return (
		<img
			className={className}
			src={src}
			alt=""
			loading="lazy"
			onError={hideBroken}
		/>
	);
};

export const CineCard = memo(({item, variant, serverUrl, index, badge, rank, onSelect, onFocusItem, spotlightId, onSpotlightLeft}) => {
	const handleClick = useCallback(() => onSelect?.(item), [item, onSelect]);
	const handleFocus = useCallback(() => onFocusItem?.(item), [item, onFocusItem]);
	const isEpisodeCard = variant === 'episode';
	const isPerson = variant === 'person';
	const title = isEpisodeCard
		? `${item.IndexNumber != null ? item.IndexNumber + '. ' : ''}${item.Name || ''}`
		: (isPerson ? item.Name : itemTitle(item));
	const landscape = variant === 'landscape' || variant === 'library' || isEpisodeCard;
	let src;
	if (isPerson) src = item.PrimaryImageTag ? getImageUrl(serverUrl, item.Id, 'Primary', {maxHeight: 360, tag: item.PrimaryImageTag}) : (item.profilePath ? 'https://image.tmdb.org/t/p/w185' + item.profilePath : null);
	else if (isEpisodeCard) src = item.ImageTags && item.ImageTags.Primary ? getImageUrl(serverUrl, item.Id, 'Primary', {maxWidth: 560, quality: 85}) : landscapeUrl(serverUrl, item, 560);
	else src = landscape ? landscapeUrl(serverUrl, item, 560) : posterUrl(serverUrl, item, 420);
	const progress = variant === 'landscape' || isEpisodeCard ? progressOf(item) : 0;
	const seerr = isSeerrItem(item) ? seerrState(item) : null;
	let sub = variant === 'landscape' ? episodeLabel(item) : '';
	if (isEpisodeCard) sub = [runtimeLabel(item.RunTimeTicks), item.UserData && item.UserData.Played ? 'Visto' : ''].filter(Boolean).join('  •  ');
	if (isPerson) sub = item.Role || item.character || '';

	const cls = [css.card, css[variant] || css.poster].join(' ');
	return (
		<SpottableDiv
			className={cls}
			data-cine-id={item.Id || ''}
			data-index={index}
			spotlightId={spotlightId}
			onClick={handleClick}
			onFocus={handleFocus}
			onSpotlightLeft={onSpotlightLeft}
			aria-label={title}
		>
			{variant === 'top10' && <div className={css.rank}>{rank}</div>}
			<div className={css.art}>
				<div className={css.artFallback}>{title}</div>
				<Img className={css.artImg} src={src} />
				{variant === 'library' && <div className={css.libraryName}>{title}</div>}
				{badge && <div className={css.badge}>{badge}</div>}
				{seerr && (
					<div className={`${css.seerrBadge} ${css['seerr_' + seerr.kind] || ''}`}>{seerr.label}</div>
				)}
				{seerr && seerr.pct != null && (
					<div className={css.progress}><div className={css.progressFill} style={{width: seerr.pct + '%'}} /></div>
				)}
				{progress > 0 && (
					<div className={css.progress}><div className={css.progressFill} style={{width: progress + '%'}} /></div>
				)}
			</div>
			{(variant === 'landscape' || isEpisodeCard || isPerson) && (
				<div className={css.caption}>
					<div className={css.captionTitle}>{title}</div>
					{sub && <div className={css.captionSub}>{sub}</div>}
					{isEpisodeCard && item.Overview && <div className={css.captionOverview}>{item.Overview}</div>}
				</div>
			)}
		</SpottableDiv>
	);
});

const CineRow = ({
	rowId,
	title,
	items,
	variant = 'poster',
	serverUrl,
	onSelectItem,
	onFocusItem,
	onFocusRow,
	rowIndex,
	badgeFor,
	registerRow
}) => {
	const scrollerRef = useRef(null);
	const rowRef = useRef(null);

	const setRef = useCallback((node) => {
		rowRef.current = node;
		registerRow?.(rowIndex, node);
	}, [registerRow, rowIndex]);

	const itemAt = useCallback((target) => itemWithIdAt(items || [], 'data-cine-id', target), [items]);
	const {onMouseLeave, ...menuHold} = useItemMenuHold(itemAt);
	void onMouseLeave;

	const handleFocus = useCallback((e) => {
		onFocusRow?.(rowIndex, e.currentTarget);
		if (Spotlight.getPointerMode()) return;
		const card = e.target.closest('[data-index]');
		const scroller = scrollerRef.current;
		if (!card || !scroller) return;
		// La tarjeta enfocada se queda siempre en la primera posición visible,
		// como en las plataformas de streaming: la fila se desliza bajo el foco.
		const i = Number(card.getAttribute('data-index')) || 0;
		const first = scroller.firstChild && scroller.firstChild.children[0];
		const step = first ? first.offsetWidth + 24 : 0;
		const target = Math.max(0, i * step - (i > 0 ? step * 0.35 : 0));
		const inner = scroller.firstChild;
		if (inner) inner.style.transform = `translate3d(${-target}px,0,0)`;
	}, [onFocusRow, rowIndex]);

	const handleLeftEdge = useCallback((e) => {
		// Desde la primera tarjeta, izquierda abre el menú lateral.
		e.preventDefault();
		e.stopPropagation();
		if (!Spotlight.focus('navbar')) Spotlight.move('left');
	}, []);

	if (!items || items.length === 0) return null;

	return (
		<RowContainer
			ref={setRef}
			className={`${css.row} ${variant === 'top10' ? css.rowTop10 : ''}`}
			spotlightId={`cine-row-${rowId}`}
			data-row-index={rowIndex}
			onFocus={handleFocus}
		>
			<h2 className={css.rowTitle}>{title}</h2>
			<div className={css.scroller} ref={scrollerRef} onScroll={keepUnscrolled}>
				<div className={css.items} {...menuHold}>
					{items.map((item, i) => (
						<CineCard
							key={itemKey(item) + '-' + i}
							item={item}
							index={i}
							rank={i + 1}
							variant={variant}
							serverUrl={serverUrl}
							badge={badgeFor ? badgeFor(item) : null}
							onSelect={onSelectItem}
							onFocusItem={onFocusItem}
							spotlightId={`cine-${rowId}-${i}`}
							onSpotlightLeft={i === 0 ? handleLeftEdge : undefined}
						/>
					))}
				</div>
			</div>
		</RowContainer>
	);
};

export default memo(CineRow);
