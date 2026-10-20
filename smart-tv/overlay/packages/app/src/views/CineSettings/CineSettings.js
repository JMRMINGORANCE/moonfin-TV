// TaquitoFlix: ajustes propios, ordenados como en las plataformas de
// streaming: Ver (idioma, reproducción, portada), Tu cuenta (perfil, Seerr,
// protector de pantalla) y Sistema (servidor, acerca de). Cada página tiene
// lo que más se usa y un acceso a todas las opciones de Moonfin.
import {useCallback, useEffect, useMemo, useRef, useState} from 'react';
import Spotlight from '@enact/spotlight';
import Spottable from '@enact/spotlight/Spottable';
import SpotlightContainerDecorator from '@enact/spotlight/SpotlightContainerDecorator';
import {useAuth} from '../../context/AuthContext';
import {useSettings, flushSettingsPush} from '../../context/SettingsContext';
import {useSeerr} from '../../context/SeerrContext';
import {Icon, TAQUITO, WORDMARK} from '../../components/cine/CineBits';
import {checkForUpdates} from '../../services/versionChecker';
import {isBackKey} from '../../utils/keys';
import {isTvKeyboardVisible} from '../../components/TVKeyboard/keyboardBus';
import Settings from '../Settings';

import css from './CineSettings.module.less';

const SpottableDiv = Spottable('div');
const Page = SpotlightContainerDecorator({enterTo: 'last-focused', restrict: 'self-only'}, 'div');

const VERSION = process.env.REACT_APP_TAQUITO_VERSION || process.env.REACT_APP_VERSION || '';

const AUDIO = [
	{value: '', label: 'El del servidor'},
	{value: 'spa', label: 'Español'},
	{value: 'eng', label: 'Inglés'},
	{value: 'cat', label: 'Catalán'},
	{value: 'fra', label: 'Francés'},
	{value: 'jpn', label: 'Japonés'}
];
const SUBS_LANG = [
	{value: '', label: 'Los del servidor'},
	{value: 'spa', label: 'Español'},
	{value: 'eng', label: 'Inglés'}
];
const SUBS_MODE = [
	{value: 'default', label: 'Solo los marcados'},
	{value: 'always', label: 'Siempre'},
	{value: 'foreign', label: 'Solo si el audio es en otro idioma'},
	{value: 'forced', label: 'Solo los forzados'},
	{value: 'none', label: 'Nunca'}
];
const SUBS_SIZE = [
	{value: 'small', label: 'Pequeños'},
	{value: 'medium', label: 'Medianos'},
	{value: 'large', label: 'Grandes'},
	{value: 'xlarge', label: 'Muy grandes'}
];
const UI_LANG = [
	{value: 'es', label: 'Español'},
	{value: 'en-US', label: 'English'},
	{value: 'ca', label: 'Català'}
];
const BITRATE = [
	{value: 0, label: 'Automática'},
	{value: 120000000, label: 'Hasta 120 Mbps'},
	{value: 60000000, label: 'Hasta 60 Mbps'},
	{value: 40000000, label: 'Hasta 40 Mbps'},
	{value: 20000000, label: 'Hasta 20 Mbps'},
	{value: 10000000, label: 'Hasta 10 Mbps'},
	{value: 5000000, label: 'Hasta 5 Mbps'}
];
const SKIP = [
	{value: 5000, label: '5 segundos'},
	{value: 10000, label: '10 segundos'},
	{value: 15000, label: '15 segundos'},
	{value: 30000, label: '30 segundos'}
];
const NEXT_UP = [
	{value: 'extended', label: 'Tarjeta grande con cuenta atrás'},
	{value: 'minimal', label: 'Aviso pequeño'},
	{value: 'disabled', label: 'No pasar solo'}
];
const INTRO = [
	{value: 'ask', label: 'Preguntar'},
	{value: 'auto', label: 'Saltarlas solas'},
	{value: 'none', label: 'No saltarlas'}
];
const SS_BACKDROP = [
	{value: 'taquito', label: 'Fondos de Taquito'},
	{value: 'library', label: 'Tus películas y series'},
	{value: 'black', label: 'Negro'}
];
const SS_TIMEOUT = [
	{value: 60, label: '1 minuto'},
	{value: 120, label: '2 minutos'},
	{value: 180, label: '3 minutos'},
	{value: 300, label: '5 minutos'},
	{value: 600, label: '10 minutos'}
];

const labelOf = (options, value) => {
	const hit = options.find((o) => o.value === value);
	return hit ? hit.label : options[0].label;
};

const nextOf = (options, value) => {
	const i = options.findIndex((o) => o.value === value);
	return options[(i + 1) % options.length].value;
};

// ---------------------------------------------------------------------------

const Row = ({icon, title, value, desc, onClick, toggle, on, ...rest}) => (
	<SpottableDiv className={css.row} onClick={onClick} {...rest}>
		{icon && <Icon name={icon} className={css.rowIcon} />}
		<div className={css.rowText}>
			<div className={css.rowTitle}>{title}</div>
			{desc && <div className={css.rowDesc}>{desc}</div>}
		</div>
		{toggle ? (
			<div className={`${css.switch} ${on ? css.switchOn : ''}`}><div className={css.knob} /></div>
		) : value != null ? (
			<div className={css.rowValue}>{value}<span className={css.chev}>›</span></div>
		) : (
			<span className={css.chev}>›</span>
		)}
	</SpottableDiv>
);

const Section = ({title, children}) => (
	<div className={css.section}>
		{title && <div className={css.sectionTitle}>{title}</div>}
		{children}
	</div>
);

// ---------------------------------------------------------------------------

const CineSettingsHome = ({onBack, onLibrariesChanged, onRunSetupWizard, onSelectItem, onSwitchUser}) => {
	const {user, serverUrl, servers} = useAuth();
	const {settings, updateSetting} = useSettings();
	const {isEnabled: seerrOn, isAuthenticated: seerrAuth, displayName} = useSeerr();
	const [page, setPage] = useState('home');
	const [advanced, setAdvanced] = useState(null);
	const [update, setUpdate] = useState(null);
	const lastRowRef = useRef({});
	const pageRef = useRef(null);
	const lastFocusRef = useRef(0);
	const trackFocus = useCallback((e) => {
		const all = Array.prototype.slice.call(document.querySelectorAll(`.${css.list} .spottable`));
		const i = all.indexOf(e.target);
		if (i >= 0) lastFocusRef.current = i;
	}, []);

	const set = useCallback((key, value) => updateSetting(key, value), [updateSetting]);
	const cycle = useCallback((key, options) => () => set(key, nextOf(options, settings[key])), [set, settings]);
	const flip = useCallback((key, def = true) => () => set(key, !(settings[key] === undefined ? def : settings[key])), [set, settings]);
	const isOn = (key, def = true) => (settings[key] === undefined ? def : settings[key] !== false);

	// Cambiar el idioma de la app recarga la app, como hace Moonfin.
	const bootLang = useRef(settings.uiLanguage);
	useEffect(() => {
		if (settings.uiLanguage !== bootLang.current && typeof window !== 'undefined') {
			flushSettingsPush().then(() => window.location.reload());
		}
	}, [settings.uiLanguage]);

	const open = useCallback((name) => () => {
		const cur = Spotlight.getCurrent();
		const all = Array.prototype.slice.call(document.querySelectorAll(`.${css.list} .spottable`));
		lastRowRef.current.home = all.indexOf(cur);
		setPage(name);
	}, []);

	const openAdvanced = useCallback((view) => () => setAdvanced({view}), []);
	const closeAdvanced = useCallback(() => setAdvanced(null), []);

	useEffect(() => {
		if (advanced) return;
		const t = setTimeout(() => {
			const all = document.querySelectorAll(`.${css.list} .spottable`);
			const back = page === 'home' ? lastRowRef.current.home : -1;
			const el = (back != null && back >= 0 && all[back]) || all[0];
			if (el) Spotlight.focus(el);
		}, 60);
		return () => clearTimeout(t);
	}, [page, advanced]);

	// Atrás: de una página a la lista y de la lista fuera. Mientras están
	// abiertos los ajustes completos de Moonfin, ellos llevan su propio Atrás.
	useEffect(() => {
		if (advanced) return undefined;
		const handleKeyDown = (e) => {
			if (isTvKeyboardVisible()) return;
			// Al cerrarse una ventana por encima (la de perfiles) el foco se queda
			// en el aire: la primera tecla lo devuelve a la fila donde estabas.
			const lost = !document.activeElement || document.activeElement === document.body;
			const code = e.keyCode;
			if (lost && (isBackKey(e) || (code >= 37 && code <= 40) || code === 13)) {
				const all = document.querySelectorAll(`.${css.list} .spottable`);
				const el = all[lastFocusRef.current] || all[0];
				if (el) {
					e.preventDefault();
					e.stopPropagation();
					Spotlight.focus(el);
					return;
				}
			}
			if (!isBackKey(e)) return;
			// Si hay algo abierto encima (la ventana de perfiles, un diálogo),
			// el Atrás es suyo.
			const root = pageRef.current;
			if (root && document.activeElement && document.activeElement !== document.body && !root.contains(document.activeElement)) return;
			e.preventDefault();
			e.stopPropagation();
			if (page !== 'home') setPage('home');
			else onBack?.();
		};
		window.addEventListener('keydown', handleKeyDown, true);
		return () => window.removeEventListener('keydown', handleKeyDown, true);
	}, [advanced, page, onBack]);

	const toggleClock = useCallback(() => set('screensaverClockMode', settings.screensaverClockMode === 'off' ? 'staticCorner' : 'off'), [set, settings.screensaverClockMode]);

	const checkUpdates = useCallback(async () => {
		setUpdate({state: 'checking'});
		try {
			const info = await checkForUpdates(true);
			setUpdate(info ? {state: 'available', version: info.latestVersion} : {state: 'none'});
		} catch (e) {
			setUpdate({state: 'error'});
		}
	}, []);

	const server = useMemo(() => (servers || []).find((s) => s.url === serverUrl) || null, [servers, serverUrl]);

	if (advanced) {
		return (
			<Settings
				onBack={closeAdvanced}
				onLibrariesChanged={onLibrariesChanged}
				onRunSetupWizard={onRunSetupWizard}
				onSelectItem={onSelectItem}
				initialView={advanced.view || undefined}
			/>
		);
	}

	const title = {
		home: 'Ajustes', language: 'Idioma y subtítulos', playback: 'Reproducción', homeRows: 'Portada',
		profile: 'Perfil y seguridad', seerr: 'Seerr', screensaver: 'Protector de pantalla', server: 'Servidor', about: 'Acerca de y ayuda'
	}[page];

	let body;
	if (page === 'home') {
		body = (
			<>
				<div className={css.profile}>
					<div className={css.avatar}><img src={TAQUITO} alt="" /></div>
					<div>
						<div className={css.profileName}>{user ? user.Name : ''}</div>
						<div className={css.profileSub}>{server ? server.name : serverUrl}</div>
					</div>
				</div>
				<Section title="Ver">
					<Row icon="search" title="Idioma y subtítulos" desc={`Audio: ${labelOf(AUDIO, settings.audioLanguage || '').toLowerCase()} · subtítulos: ${labelOf(SUBS_MODE, settings.subtitleMode).toLowerCase()}`} onClick={open('language')} />
					<Row icon="play" title="Reproducción" desc={`Calidad ${labelOf(BITRATE, settings.maxBitrate || 0).toLowerCase()} · saltos de ${Math.round((settings.skipForwardLength || 10000) / 1000)} s`} onClick={open('playback')} />
					<Row icon="trailer" title="Portada" desc={isOn('featuredTrailerPreview') ? 'Filas a tu gusto · tráiler automático' : 'Filas a tu gusto · sin tráiler'} onClick={open('homeRows')} />
				</Section>
				<Section title="Tu cuenta">
					<Row icon="heart" title="Perfil y seguridad" desc={settings.pinCodeProtection ? 'PIN activado · control parental' : 'Sin PIN · control parental'} onClick={open('profile')} />
					<Row icon="download" title={displayName && displayName !== 'Seerr' ? displayName : 'Seerr'} desc={seerrOn && seerrAuth ? 'Conectado: descarga desde la tele' : 'Sin conectar'} onClick={open('seerr')} />
					<Row icon="info" title="Protector de pantalla" desc={isOn('screensaverEnabled') ? `Taquito sale tras ${labelOf(SS_TIMEOUT, settings.screensaverTimeout).replace('minuto', 'min').replace('minutos', 'min')}` : 'Desactivado'} onClick={open('screensaver')} />
				</Section>
				<Section title="Sistema">
					<Row icon="back" title="Servidor" desc={server ? server.name : serverUrl} onClick={open('server')} />
					<Row icon="info" title="Acerca de y ayuda" desc={`TaquitoFlix ${VERSION}`} onClick={open('about')} />
					<Row icon="chevron" title="Todos los ajustes" desc="Todas las opciones de Moonfin, para lo más avanzado" onClick={openAdvanced(null)} />
				</Section>
				<img className={css.footer} src={WORDMARK} alt="TaquitoFlix" />
			</>
		);
	} else if (page === 'language') {
		body = (
			<Section>
				<Row title="Idioma de la app" value={labelOf(UI_LANG, settings.uiLanguage)} onClick={cycle('uiLanguage', UI_LANG)} />
				<Row title="Idioma del audio" value={labelOf(AUDIO, settings.audioLanguage || '')} onClick={cycle('audioLanguage', AUDIO)} />
				<Row title="Cuándo poner subtítulos" value={labelOf(SUBS_MODE, settings.subtitleMode)} onClick={cycle('subtitleMode', SUBS_MODE)} />
				<Row title="Idioma de los subtítulos" value={labelOf(SUBS_LANG, settings.subtitleLanguage || '')} onClick={cycle('subtitleLanguage', SUBS_LANG)} />
				<Row title="Tamaño de los subtítulos" value={labelOf(SUBS_SIZE, settings.subtitleSize)} onClick={cycle('subtitleSize', SUBS_SIZE)} />
				<Row icon="chevron" title="Más opciones de subtítulos" desc="Color, fondo, posición…" onClick={openAdvanced('playback')} />
			</Section>
		);
	} else if (page === 'playback') {
		body = (
			<Section>
				<Row title="Calidad máxima" desc="Bájala si se corta la imagen" value={labelOf(BITRATE, settings.maxBitrate || 0)} onClick={cycle('maxBitrate', BITRATE)} />
				<Row title="Avanzar" value={labelOf(SKIP, settings.skipForwardLength)} onClick={cycle('skipForwardLength', SKIP)} />
				<Row title="Retroceder" value={labelOf(SKIP, settings.skipBackLength)} onClick={cycle('skipBackLength', SKIP)} />
				<Row title="Siguiente episodio" value={labelOf(NEXT_UP, settings.nextUpBehavior)} onClick={cycle('nextUpBehavior', NEXT_UP)} />
				<Row title="Intros" value={labelOf(INTRO, settings.introAction)} onClick={cycle('introAction', INTRO)} />
				<Row icon="chevron" title="Más opciones de reproducción" onClick={openAdvanced('playback')} />
			</Section>
		);
	} else if (page === 'homeRows') {
		body = (
			<Section>
				<Row title="Tráiler en la destacada" desc="Sin sonido, a los pocos segundos" toggle on={isOn('featuredTrailerPreview')} onClick={flip('featuredTrailerPreview')} />
				<Row title="Recién descargado para ti" desc="Lo que has pedido en Seerr y ya está" toggle on={isOn('cineShowDownloaded')} onClick={flip('cineShowDownloaded')} />
				<Row title="Lo último añadido" toggle on={isOn('cineShowLatest')} onClick={flip('cineShowLatest')} />
				<Row title="Top 10 en tu biblioteca" toggle on={isOn('cineShowTop10')} onClick={flip('cineShowTop10')} />
				<Row title="Sagas" desc="Colecciones como Harry Potter, en orden" toggle on={isOn('cineShowSagas')} onClick={flip('cineShowSagas')} />
				<Row title="Ocultar lo que dejaste hace meses" desc="En «Seguir viendo», lo de hace más de 3 meses" toggle on={isOn('cineHideStaleResume')} onClick={flip('cineHideStaleResume')} />
			</Section>
		);
	} else if (page === 'profile') {
		body = (
			<Section>
				<Row icon="back" title="Cambiar de perfil" desc="Elige otro perfil de este servidor o añade uno" onClick={onSwitchUser} />
				<Row icon="chevron" title="PIN y cuenta" desc="Protege tu perfil con un PIN" onClick={openAdvanced('account')} />
				<Row icon="chevron" title="Control parental" desc="Modo niños y clasificación por edades" onClick={openAdvanced('kidsMode')} />
			</Section>
		);
	} else if (page === 'seerr') {
		body = (
			<Section>
				<Row title="Estado" value={seerrOn && seerrAuth ? 'Conectado' : 'Sin conectar'} />
				<Row title="Usar el plugin de Moonfin del servidor" desc="Hace falta para pedir películas y series" toggle on={settings.useMoonfinPlugin !== false} onClick={flip('useMoonfinPlugin')} />
				<Row icon="chevron" title="Cuenta de Seerr" desc="Iniciar sesión o cambiar de cuenta" onClick={openAdvanced('integrations')} />
			</Section>
		);
	} else if (page === 'screensaver') {
		body = (
			<Section>
				<Row title="Protector de pantalla" desc="Taquito y los fondos de TaquitoFlix" toggle on={isOn('screensaverEnabled')} onClick={flip('screensaverEnabled')} />
				<Row title="Fondo" value={labelOf(SS_BACKDROP, settings.screensaverBackdrop)} onClick={cycle('screensaverBackdrop', SS_BACKDROP)} />
				<Row title="Aparece tras" value={labelOf(SS_TIMEOUT, settings.screensaverTimeout)} onClick={cycle('screensaverTimeout', SS_TIMEOUT)} />
				<Row title="Mostrar la hora" toggle on={settings.screensaverClockMode !== 'off'} onClick={toggleClock} />
			</Section>
		);
	} else if (page === 'server') {
		body = (
			<Section>
				<Row title="Nombre" value={server ? server.name : '—'} />
				<Row title="Dirección" value={serverUrl} />
				<Row title="Usuario" value={user ? user.Name : '—'} />
				<Row icon="chevron" title="Bibliotecas que salen en la app" onClick={openAdvanced('general')} />
				<Row icon="back" title="Cambiar de servidor o de perfil" onClick={onSwitchUser} />
			</Section>
		);
	} else if (page === 'about') {
		const upd = !update ? 'Comprobar' : update.state === 'checking' ? 'Comprobando…'
			: update.state === 'available' ? `Hay una nueva: ${update.version}` : update.state === 'none' ? 'Tienes la última' : 'No se ha podido comprobar';
		body = (
			<Section>
				<Row title="Versión" value={`TaquitoFlix ${VERSION}`} />
				<Row title="Buscar actualizaciones" desc="Para instalarla, mándala a la tele desde el ordenador como siempre" value={upd} onClick={checkUpdates} />
				<Row title="Basada en" value={`Moonfin ${process.env.REACT_APP_VERSION || ''}`} />
				<Row icon="chevron" title="Diagnóstico y registros" onClick={openAdvanced('about')} />
			</Section>
		);
	}

	return (
		<div className={css.page} ref={pageRef}>
			<div className={css.header}>
				<h1 className={css.title}>{title}</h1>
				{page !== 'home' && <div className={css.hint}>Atrás para volver</div>}
			</div>
			<Page className={css.list} spotlightId="cine-settings-page" key={page} onFocus={trackFocus}>
				{body}
			</Page>
		</div>
	);
};

const CineSettings = (props) => {
	if (props.panelMode || props.initialView) return <Settings {...props} />;
	return <CineSettingsHome {...props} />;
};

export default CineSettings;
