<script setup>
import InfoTip from './InfoTip.vue'

defineProps({
	label: { type: String, default: '' },
	value: { type: String, default: '' },
	tone: { type: String, default: 'neutral' },
	help: { type: String, default: '' }
})
</script>

<template>
	<div class="metric" :class="tone">
		<div class="label">
			<span class="label-text">{{ label }}</span>
			<InfoTip v-if="help" :text="help" />
		</div>
		<div class="value">{{ value }}</div>
	</div>
</template>

<style scoped>
.metric {
	min-width: 0;
	padding: 1rem;
	border-radius: 18px;
	background: rgba(255, 255, 255, 0.04);
	border: 1px solid rgba(255, 255, 255, 0.06);
}

.metric.good {
	border-color: rgba(63, 211, 140, 0.4);
}

.metric.warn {
	border-color: rgba(255, 177, 74, 0.42);
}

.metric.bad {
	border-color: rgba(255, 110, 122, 0.42);
}

.label {
	display: flex;
	align-items: center;
	gap: 0.5rem;
	font-size: 0.82rem;
	color: var(--muted-text);
	margin-bottom: 0.4rem;
}

.label-text {
	min-width: 0;
}

.value {
	font-size: clamp(1.35rem, 6vw, 1.65rem);
	font-weight: 800;
	letter-spacing: -0.02em;
	overflow-wrap: anywhere;
}

.metric.good .value {
	color: var(--green);
}

.metric.warn .value {
	color: var(--orange);
}

.metric.bad .value {
	color: var(--red);
}
</style>
