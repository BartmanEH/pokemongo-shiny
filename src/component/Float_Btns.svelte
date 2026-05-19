<script>
	import { recorder, } from '@lib/recorder.svelte.js';
	import { i18n } from '@lib/i18n.svelte.js';
</script>

<label class="btn-icon ctrl-btn hide-for-print" for="ctrl-checkbox">
	⚙️
	<span class="sr-only-u">
		toggle control panel
	</span>
</label>


<button class="btn-icon record-btn hide-for-print"
	onclick={recorder.add_current}
	title={i18n.t('record.save')}
>
	💾
	<span class="sr-only-u">
		Save current record
	</span>
</button>

<label class="btn-icon locker-btn hide-for-print" for="list-locker">
	<span class="sr-only-u">
		Lock
	</span>
</label>



<style>

	:global(:root) {
		--float-btn-size: clamp(40px, 9vw, 56px);
		--float-btn-gap: clamp(8px, 2vw, 14px);
		--float-btn-left: calc(min(3vw, 1em) + 4px);
		--float-btn-bottom: calc(clamp(64px, 14vw, 88px) + env(safe-area-inset-bottom, 0px));
	}

	.ctrl-btn {
		bottom: var(--float-btn-bottom);
	}

	.record-btn {
		bottom: calc(var(--float-btn-bottom) + var(--float-btn-size) + var(--float-btn-gap));
		left: calc(var(--float-btn-left) + var(--float-btn-size) + var(--float-btn-gap));
	}

	.locker-btn {
		bottom: calc(var(--float-btn-bottom) + (var(--float-btn-size) + var(--float-btn-gap)) * 2);

		&::before {
			content: var(--locker-icon, '🔓');
		}

		:global(body:has(#list-locker:checked)) & {
			background-color: #ffd;
			--locker-icon:  '🔒';
		}
	}

	.btn-icon {
		position: fixed;
		z-index: 30;
		/* bottom: .5rem; */
		left: var(--float-btn-left);
		border: 1px outset #0006;
		display: flex;
		width: var(--float-btn-size);
		height: var(--float-btn-size);
		padding: 0;
		place-items: center;
		place-content: center;
		font-size: clamp(1.1rem, 4vw, 1.5rem);
		background-color: #f4f4f4;
		cursor: pointer;
		user-select: none;
		border-radius: 2px;
		transition: opacity 0.3s, scale .1s;

		&:hover,
		&:focus,
		&:active {
			opacity: 1;
			scale: 1.1;
		}

		&:active {
			border-style: inset;
			background-color: #ffd;
		}
	}
</style>
