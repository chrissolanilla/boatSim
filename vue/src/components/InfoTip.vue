<script setup>
defineProps({
	text: { type: String, required: true }
})
</script>

<template>
	<details class="info">
		<summary class="trigger" aria-label="Info">
			<span aria-hidden="true">i</span>
		</summary>
		<div class="tip" role="note">{{ text }}</div>
	</details>
</template>

<style scoped>
.info {
	position: relative;
	display: inline-block;
	vertical-align: middle;
}

.trigger {
	list-style: none;
	width: 18px;
	height: 18px;
	display: inline-flex;
	align-items: center;
	justify-content: center;
	border-radius: 999px;
	border: 1px solid rgba(255, 255, 255, 0.18);
	background: rgba(0, 0, 0, 0.18);
	color: rgba(255, 255, 255, 0.82);
	font-size: 12px;
	font-weight: 700;
	line-height: 1;
	cursor: pointer;
	user-select: none;
}

.trigger::-webkit-details-marker {
	display: none;
}

.tip {
	position: absolute;
	right: 0;
	top: calc(100% + 8px);
	width: min(340px, 72vw);
	padding: 0.75rem 0.85rem;
	border-radius: 14px;
	background: rgba(20, 19, 31, 0.98);
	border: 1px solid rgba(255, 255, 255, 0.1);
	box-shadow: var(--shadow);
	color: rgba(255, 255, 255, 0.86);
	white-space: pre-line;
	line-height: 1.45;
	font-size: 0.9rem;
	z-index: 20;
}

.info:not([open]) .tip {
	display: none;
}
</style>
