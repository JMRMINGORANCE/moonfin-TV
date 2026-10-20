// TaquitoFlix: piezas pequeñas compartidas (botones, iconos, Taquito
// cargando, pantallas vacías y avisos).
import {useEffect, useState} from 'react';
import Spottable from '@enact/spotlight/Spottable';

import css from './Cine.module.less';

export const TAQUITO = 'resources/cine/taquito.svg';
export const WORDMARK = 'resources/cine/wordmark.svg';
export const WALLPAPERS = [
	'resources/cine/wallpaper-1.jpg',
	'resources/cine/wallpaper-2.jpg',
	'resources/cine/wallpaper-3.jpg'
];

const PATHS = {
	play: 'M8 5.14v13.72a1 1 0 0 0 1.52.85l10.6-6.86a1 1 0 0 0 0-1.7L9.52 4.29A1 1 0 0 0 8 5.14z',
	info: 'M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm1 15h-2v-6h2v6zm0-8h-2V7h2v2z',
	plus: 'M19 11h-6V5h-2v6H5v2h6v6h2v-6h6z',
	check: 'M9 16.17 4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z',
	heart: 'M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z',
	heartOutline: 'M16.5 3c-1.74 0-3.41.81-4.5 2.09C10.91 3.81 9.24 3 7.5 3 4.42 3 2 5.42 2 8.5c0 3.78 3.4 6.86 8.55 11.54L12 21.35l1.45-1.32C18.6 15.36 22 12.28 22 8.5 22 5.42 19.58 3 16.5 3zm-4.4 15.55-.1.1-.1-.1C7.14 14.24 4 11.39 4 8.5 4 6.5 5.5 5 7.5 5c1.54 0 3.04.99 3.57 2.36h1.87C13.46 5.99 14.96 5 16.5 5c2 0 3.5 1.5 3.5 3.5 0 2.89-3.14 5.74-7.9 10.05z',
	download: 'M5 20h14v-2H5v2zM19 9h-4V3H9v6H5l7 7 7-7z',
	restart: 'M12 5V1L7 6l5 5V7c3.31 0 6 2.69 6 6s-2.69 6-6 6-6-2.69-6-6H4c0 4.42 3.58 8 8 8s8-3.58 8-8-3.58-8-8-8z',
	trailer: 'M18 4l2 4h-3l-2-4h-2l2 4h-3l-2-4H8l2 4H7L5 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V4h-4z',
	search: 'M15.5 14h-.79l-.28-.27A6.47 6.47 0 0 0 16 9.5 6.5 6.5 0 1 0 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z',
	back: 'M20 11H7.83l5.59-5.59L12 4l-8 8 8 8 1.41-1.41L7.83 13H20v-2z',
	chevron: 'M8.59 16.59 13.17 12 8.59 7.41 10 6l6 6-6 6z',
	thumb: 'M1 21h4V9H1v12zm22-11c0-1.1-.9-2-2-2h-6.31l.95-4.57.03-.32c0-.41-.17-.79-.44-1.06L14.17 1 7.59 7.59C7.22 7.95 7 8.45 7 9v10c0 1.1.9 2 2 2h9c.83 0 1.54-.5 1.84-1.22l3.02-7.05c.09-.23.14-.47.14-.73v-2z'
};

export const Icon = ({name, className}) => (
	<svg className={className} viewBox="0 0 24 24" aria-hidden="true"><path d={PATHS[name] || PATHS.info} /></svg>
);

const SpottableDiv = Spottable('div');

export const CineButton = ({icon, label, primary, round, className, ...rest}) => (
	<SpottableDiv
		className={[css.button, primary ? css.buttonPrimary : '', round ? css.iconButton : '', className || ''].join(' ')}
		aria-label={label}
		{...rest}
	>
		{icon && <Icon name={icon} />}
		{!round && label}
	</SpottableDiv>
);

export const TaquitoLoader = ({text = 'Preparando las palomitas…'}) => (
	<div className={css.loader}>
		<img className={css.loaderTaquito} src={TAQUITO} alt="" />
		<div className={css.loaderBar} />
		{text && <div className={css.loaderText}>{text}</div>}
	</div>
);

export const EmptyState = ({title, text, children}) => (
	<div className={css.empty}>
		<img className={css.emptyTaquito} src={TAQUITO} alt="" />
		<div className={css.emptyTitle}>{title}</div>
		{text && <div className={css.emptyText}>{text}</div>}
		{children}
	</div>
);

// Aviso que aparece abajo a la derecha y se va solo.
export const CineToast = ({title, text, duration = 7000, onDone}) => {
	const [visible, setVisible] = useState(true);
	useEffect(() => {
		const t = setTimeout(() => {
			setVisible(false);
			onDone?.();
		}, duration);
		return () => clearTimeout(t);
	}, [duration, onDone]);
	if (!visible) return null;
	return (
		<div className={css.toast}>
			<div className={css.toastTitle}>{title}</div>
			{text && <div className={css.toastText}>{text}</div>}
		</div>
	);
};
