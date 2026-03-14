import { writable, derived } from 'svelte/store';
import { recorder, } from '@lib/recorder.svelte.js';
import { get_item, set_item, } from '@lib/u.js';

let url = new URL(location.href);
let qs = url.searchParams;

if (qs.get('reset') === '1') {
	localStorage.clear();
}

function infer_source_type(source_url = '') {
	return /\.csv(?:$|[?#])/i.test(source_url) ? 'csv' : 'json';
}

const env_source_url = import.meta.env.VITE_PM_SOURCE_URL || '';
const env_source_type = import.meta.env.VITE_PM_SOURCE_TYPE || infer_source_type(env_source_url);

let init_config = {
	status: '',
	name: '?',
};

if (qs.get('status')) {
	init_config.status = qs.get('status');
	init_config.name = qs.get('name');
} else if (recorder?.records[0]) {
	init_config.status = recorder.records[0].status;
	init_config.name = recorder.records[0].name;
}

// reset location.search to prevent confuse
if (location.search) {
	history.pushState({}, null, './');
}

export const status = writable(init_config.status || '');
export const name = writable(init_config.name || '?');
export const pms = writable([]);


export const default_config = {
	img_diff: false,
	show_name: true,
	show_suffix: true,
	locked: false,
	maxwidth: 1200,
	grid_size: 96,
	open_tags: true,
	main_bgc: '#ffffff',
	main_color: '#213547',
	grid_colors: ['#dddddd', '#dada0b', '#a1a112', ],
	// colors: ['#dada0b', '#a1a112'],
	gradient_colors: ['#000000', '#63452c', ],
	source_url: { type: env_source_type, url: env_source_url, },
}

export const config = writable(
	{
		...default_config,
		...get_item('config'),
	}
);

config.subscribe((config) => {
	// console.log('config', config);
	set_item('config', config);
})
