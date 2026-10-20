#!/usr/bin/env node
/*
 * TaquitoFlix: maneja la app de tele en Chromium como si fuera el mando y
 * hace capturas. Pensado para probar con el Jellyfin de mentira.
 *
 *   node drive.js <url-de-la-app> <guion> [carpeta-capturas]
 *
 * El guion es una lista de pasos separados por espacios:
 *   login                  entra en http://localhost:8096 como el primer perfil
 *   wait:2000              espera milisegundos
 *   key:ArrowDown[*n]      pulsa una tecla (n veces)
 *   type:texto             escribe
 *   shot:nombre            captura de pantalla
 *   goto:#/ruta            cambia el hash de la URL
 *   eval:código            ejecuta JS en la página e imprime el resultado
 *   focus                  imprime el elemento con el foco
 */
const {chromium} = require('playwright');
const fs = require('fs');
const path = require('path');

const [, , appUrl, script = 'shot:inicio', outDir = '/tmp/taquito-shots'] = process.argv;
fs.mkdirSync(outDir, {recursive: true});

const STRICT_CSP = process.env.STRICT_CSP === '1';

(async () => {
	const browser = await chromium.launch({
		executablePath: '/opt/pw-browsers/chromium',
		args: ['--allow-file-access-from-files', '--autoplay-policy=no-user-gesture-required']
	});
	const context = await browser.newContext({viewport: {width: 1920, height: 1080}, locale: 'es-ES'});
	if (process.env.AVPLAY === '1') await context.addInitScript({path: path.join(__dirname, 'avplay-shim.js')});
	const page = await context.newPage();
	const logs = [];
	page.on('console', (m) => {
		if (['error', 'warning'].includes(m.type())) logs.push(`${m.type()}: ${m.text().slice(0, 300)}`);
	});
	page.on('pageerror', (e) => logs.push(`PAGEERROR: ${e.message}\n${(e.stack || '').split('\n').slice(0, 4).join('\n')}`));
	// Solo se deja salir al Jellyfin de prueba y a la propia app.
	await page.route(/^https?:\/\//, (route) => {
		const u = route.request().url();
		if (/^http:\/\/(localhost|127\.0\.0\.1)/.test(u)) return route.continue();
		return route.abort();
	});
	// El servidor de desarrollo no sirve la carpeta resources/: se lee del disco.
	const RES = process.env.APP_RESOURCES || '/home/claude/moonfin-client/smart-tv/packages/app/resources';
	await page.route(/^http:\/\/localhost:8080\/resources\//, (route) => {
		const rel = decodeURIComponent(new URL(route.request().url()).pathname.replace(/^\/resources\//, ''));
		const file = path.join(RES, rel);
		if (!fs.existsSync(file)) return route.fulfill({status: 404, body: ''});
		const ext = path.extname(file).toLowerCase();
		const type = {'.svg': 'image/svg+xml', '.png': 'image/png', '.jpg': 'image/jpeg', '.json': 'application/json'}[ext] || 'application/octet-stream';
		return route.fulfill({status: 200, contentType: type, body: fs.readFileSync(file)});
	});
	if (STRICT_CSP) {
		await page.route(/^http:\/\/localhost:8080\/(index\.html)?(\?.*)?(#.*)?$/, async (route) => {
			const r = await route.fetch();
			let body = await r.text();
			body = body.replace('<head>', `<head><meta http-equiv="Content-Security-Policy" content="script-src 'self'; style-src 'self'">`);
			route.fulfill({response: r, body});
		});
	}
	await page.goto(appUrl);
	await page.waitForTimeout(4000);

	const focusInfo = () => page.evaluate(() => {
		const el = document.activeElement;
		if (!el || el === document.body) return '(sin foco)';
		const r = el.getBoundingClientRect();
		return `${el.tagName}.${(el.className || '').toString().split(' ').slice(0, 3).join('.')} "${(el.innerText || el.getAttribute('aria-label') || '').trim().slice(0, 60).replace(/\n/g, ' | ')}" @${Math.round(r.x)},${Math.round(r.y)} ${Math.round(r.width)}x${Math.round(r.height)}`;
	});

	for (const step of script.split(/\s+/).filter(Boolean)) {
		const [cmd, ...restParts] = step.split(':');
		const rest = restParts.join(':');
		if (cmd === 'wait') await page.waitForTimeout(Number(rest));
		else if (cmd === 'key') {
			const [key, times] = rest.split('*');
			for (let i = 0; i < Number(times || 1); i++) {
				await page.keyboard.press(key);
				await page.waitForTimeout(250);
			}
		} else if (cmd === 'hold') {
			const [key, ms] = rest.split('*');
			await page.keyboard.down(key);
			for (let t = 0; t < Number(ms || 900); t += 100) {
				await page.waitForTimeout(100);
				await page.keyboard.down(key);
			}
			await page.keyboard.up(key);
		} else if (cmd === 'type') await page.keyboard.type(rest.replace(/_/g, ' '), {delay: 30});
		else if (cmd === 'shot') {
			await page.waitForTimeout(600);
			await page.screenshot({path: path.join(outDir, `${rest}.png`)});
			console.log(`captura ${rest}  foco: ${await focusInfo()}`);
		} else if (cmd === 'goto') await page.evaluate((h) => { location.hash = h; }, rest);
		else if (cmd === 'eval') console.log('eval:', JSON.stringify(await page.evaluate(rest)).slice(0, 2000));
		else if (cmd === 'focus') console.log('foco:', await focusInfo());
		else if (cmd === 'login') {
			// Deja preparado el servidor de prueba en el almacenamiento de la app y
			// recarga: la app entra sola con el primer perfil.
			await page.evaluate(() => { localStorage.setItem('taquito_dev_server', 'http://localhost:8096'); });
			await page.reload();
			await page.waitForTimeout(5000);
		}
	}
	if (logs.length) console.log('--- consola ---\n' + logs.slice(0, 40).join('\n'));
	await browser.close();
})();
