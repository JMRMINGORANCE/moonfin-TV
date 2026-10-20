// TaquitoFlix (pruebas): imita webapis.avplay de las teles Samsung con un
// <video> normal detrás de la página, para poder probar el reproductor en
// Chromium. Solo lo carga drive.js cuando se le pide (AVPLAY=1).
(function () {
	if (window.webapis && window.webapis.avplay) return;
	let video = null;
	let listener = {};
	let state = 'NONE';
	let timer = null;
	const ensure = () => {
		if (video) return video;
		video = document.createElement('video');
		video.id = 'avplay-shim';
		video.muted = true;
		video.style.cssText = 'position:fixed;left:0;top:0;width:100%;height:100%;z-index:-1;background:#000;object-fit:contain';
		document.documentElement.appendChild(video);
		video.addEventListener('ended', () => listener.onstreamcompleted && listener.onstreamcompleted());
		video.addEventListener('waiting', () => listener.onbufferingstart && listener.onbufferingstart());
		video.addEventListener('playing', () => listener.onbufferingcomplete && listener.onbufferingcomplete());
		return video;
	};
	const tick = () => {
		clearInterval(timer);
		timer = setInterval(() => {
			if (video && state === 'PLAYING' && listener.oncurrentplaytime) listener.oncurrentplaytime(Math.floor(video.currentTime * 1000));
		}, 500);
	};
	const avplay = {
		open(url) { ensure().src = url; state = 'IDLE'; },
		close() { if (video) { video.pause(); video.removeAttribute('src'); video.load(); } state = 'NONE'; clearInterval(timer); },
		stop() { if (video) video.pause(); state = 'IDLE'; },
		prepareAsync(ok, fail) {
			const v = ensure();
			const done = () => { state = 'READY'; v.removeEventListener('loadedmetadata', done); ok && ok(); };
			v.addEventListener('loadedmetadata', done);
			v.addEventListener('error', () => fail && fail({name: 'PLAYER_ERROR_CONNECTION_FAILED', message: 'shim error'}), {once: true});
			v.load();
		},
		prepare() { state = 'READY'; },
		play() { ensure().play().catch(() => {}); state = 'PLAYING'; tick(); },
		pause() { if (video) video.pause(); state = 'PAUSED'; },
		seekTo(ms, ok) { if (video) video.currentTime = ms / 1000; setTimeout(() => ok && ok(), 50); },
		jumpForward(ms, ok) { if (video) video.currentTime += ms / 1000; ok && ok(); },
		jumpBackward(ms, ok) { if (video) video.currentTime -= ms / 1000; ok && ok(); },
		getDuration() { return video && isFinite(video.duration) ? Math.floor(video.duration * 1000) : 0; },
		getCurrentTime() { return video ? Math.floor(video.currentTime * 1000) : 0; },
		getState() { return state; },
		setListener(l) { listener = l || {}; },
		setDisplayRect() {}, setDisplayMethod() {}, setStreamingProperty() {}, setBufferingParam() {},
		setTimeoutForBuffering() {}, setBufferSize() {}, setSilentSubtitle() {}, setSpeed(s) { if (video) video.playbackRate = s; },
		setSelectTrack() {}, setDrm() {}, suspend() {}, restore() {}, restoreAsync(a, b, c, ok) { ok && ok(); },
		getTotalTrackInfo() {
			return [
				{index: 0, type: 'VIDEO', extra_info: JSON.stringify({fourCC: 'VP80', Width: 1280, Height: 720})},
				{index: 1, type: 'AUDIO', extra_info: JSON.stringify({language: 'spa', channels: 2, fourCC: 'VORB'})}
			];
		},
		getCurrentStreamInfo() { return this.getTotalTrackInfo(); }
	};
	if (!window.tizen) {
		const noop = () => {};
		window.tizen = {
			tvinputdevice: {registerKey: noop, unregisterKey: noop, registerKeyBatch: noop, getSupportedKeys: () => [], getKey: () => null},
			application: {getCurrentApplication: () => ({exit: noop, hide: noop, appInfo: {id: 'shim', version: '1.0.0'}})},
			systeminfo: {getPropertyValue: (p, ok) => ok && ok({resolutionWidth: 1920, resolutionHeight: 1080}), getCapability: () => true},
			power: {request: noop, release: noop}
		};
	}
	window.webapis = window.webapis || {};
	window.webapis.avplay = avplay;
	window.webapis.productinfo = window.webapis.productinfo || {
		getModel: () => 'QE65Q64BAUXXC', getRealModel: () => 'QE65Q64BAUXXC', getFirmware: () => 'T-KSU2EDEUC-1500.0', getDuid: () => 'SHIM',
		isUdPanelSupported: () => true, is8KPanelSupported: () => false
	};
	window.webapis.appcommon = window.webapis.appcommon || {AppCommonScreenSaverState: {SCREEN_SAVER_OFF: 0, SCREEN_SAVER_ON: 1}, setScreenSaver: () => {}};
})();
