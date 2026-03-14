import * as localForage  from 'localforage';

const STORAGE_KEY = 'pm-shiny-26';

export function set_item(key, data) {
	if (!key) { return false; }
	let _data = get_item() || {};
	_data[key] = data;
	// console.log('set_item', key, data);
	localStorage.setItem(STORAGE_KEY, JSON.stringify(_data));
};

export function get_item(key) {
	let _data = localStorage.getItem(STORAGE_KEY);
	if (!_data) { return undefined; }
	_data = JSON.parse(_data);
	return key ? _data[key] : _data;
};

async function set_lf_data(key, data) {
	return await localForage.setItem(`${STORAGE_KEY}-${key}`, data);
}
async function get_lf_data(key) {
	return await localForage.getItem(`${STORAGE_KEY}-${key}`);
}
// for user selected status
export async function set_all_records(records) {
	return await set_lf_data('records', records);
}
export async function get_all_records() {
	// return await get_lf_data('records') || [{
	// 	name: '',
	// 	status: '',
	// 	time: 0,
	// }];
	return await get_lf_data('records') || [];
}

export async function fetch_data(url, type = 'json') {
	try	{
		let response = await fetch(url);
		if (!response.ok) {
			throw new Error(response.statusText);
		}

		let body;
		if (type === 'json') {
			body = await response.json();
		} else {
			body = await response.text();
		}
		return body;
	} catch (error) {
		console.error(error);
		confirm_to_reset();
	}
}

export function confirm_to_reset() {
	let checked = confirm(`pokemon data is broken,\nplease use the below url parameters to reset custom config:\n${location.origin + location.pathname}?reset=1\n\nClick 'OK' to reset directly.`)
	if (checked) {
		localStorage.clear();
		location.reload();
	}
}

export function parse_status_visibility(value = '') {
	if (value.length !== 4 || !/^[01]{4}$/.test(value)) {
		return null;
	}
	return Array.from(value, v => v === '1');
}

export function stringify_status_visibility(status_visibility = []) {
	let res = '';
	for (let i = 0; i < 4; i++) {
		res += status_visibility[i] ? '1' : '0';
	}
	return res;
}

export function gen_href(status, name, status_visibility) {
	let a = new URL(location.href);
	a.hash = '';
	a.searchParams.set('name', name);
	a.searchParams.set('status', status);
	if (status_visibility) {
		a.searchParams.set('visibility', stringify_status_visibility(status_visibility));
	}

	return a.toString();
}

export function csv2json(csv) { // by ai
	// Split lines by newline ONLY if it's not inside double quotes
	const lines = csv.split(/\r?\n(?=(?:(?:[^"]*"){2})*[^"]*$)/);

	// Extract headers and remove potential surrounding quotes/spaces
	const headers = lines[0].split(',').map(h => h.trim().replace(/^"|"$/g, ''));

	// Map remaining lines to objects
	const result = lines.slice(1).map(line => {
		// Match fields: accounts for quoted strings containing commas or newlines
		const values = line.match(/(".*?"|[^,]+|(?<=,)(?=,)|(?<=,)$|^$)/g) || [];

		return headers.reduce((obj, header, i) => {
			let val = values[i] ? values[i].trim() : "";

			// Remove outer quotes and unescape double-quotes ("" -> ")
			val = val.replace(/^"|"$/g, '').replace(/""/g, '"');

			obj[header] = val;
			return obj;
		}, {});
	});

	return result;
}

export function get_time_string(time = new Date()) {
	return time.toLocaleString('sv-SE').replace(' ', 'T');
}

export function sort_by(prop, dir = 'asc') {
	return (a, b) => dir === 'asc' ? a[prop] - b[prop] : b[prop] - a[prop];
}
export function rev_sort_by(prop) {
	return sort_by(prop, 'desc');
}

export function once(fn) {
	return function (event) {
		if (fn) fn.call(this, event);
		fn = null;
	};
}

export function pick(obj = {}, props = []) {
	let op = {};

	if (!props.length) {
		return;
	}

	props.forEach(prop => {
		if (obj[prop]) {
			op[prop] = obj[prop];
		}
	});

	return op;
}

export function preventDefault(fn) {
	return function (event) {
		event.preventDefault();
		fn.call(this, event);
	};
}

export const sum_array = (arr) => arr.reduce((acc, val) => acc + val, 0);

const FOLDER_PATH = import.meta.env.VITE_PM_IMAGE_BASE_URL
	|| (import.meta.env.DEV
		? `http://localhost:1111/new-imgs`
		: `https://cdn.jsdelivr.net/gh/PokeMiners/pogo_assets/Images/Pokemon%20-%20256x256/Addressable%20Assets`);

export function get_pm_img_src(pid = '', shiny = true, direct_src = '') {
	return direct_src || `${FOLDER_PATH}/${pid}${shiny ? '.s' : ''}.icon.png`;
}
