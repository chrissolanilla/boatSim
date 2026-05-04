<script setup>
import { nextTick, onBeforeUnmount, ref } from 'vue'

defineProps({
	text: { type: String, required: true }
})

const detailsRef = ref(null)
const tipRef = ref(null)

function clamp(value, min, max) {
	return Math.min(Math.max(value, min), max)
}

async function updateTipPosition() {
	const details = detailsRef.value
	const tip = tipRef.value

	if (!details?.open || !tip) return

	await nextTick()

	const trigger = details.querySelector('.trigger')
	if (!trigger) return

	const triggerRect = trigger.getBoundingClientRect()
	const tipRect = tip.getBoundingClientRect()

	const padding = 12
	const gap = 8

	let top = triggerRect.bottom + gap
	let left = triggerRect.left + triggerRect.width / 2
	let transform = 'translateX(-50%)'

	const wouldOverflowBottom = top + tipRect.height > window.innerHeight - padding

	if (wouldOverflowBottom) {
		top = triggerRect.top - tipRect.height - gap
	}

	const halfWidth = tipRect.width / 2
	const minLeft = padding + halfWidth
	const maxLeft = window.innerWidth - padding - halfWidth

	left = clamp(left, minLeft, maxLeft)

	tip.style.setProperty('--tip-top', `${top}px`)
	tip.style.setProperty('--tip-left', `${left}px`)
	tip.style.setProperty('--tip-transform', transform)
}

function handleToggle() {
	updateTipPosition()
}

window.addEventListener('resize', updateTipPosition)
window.addEventListener('scroll', updateTipPosition, true)

onBeforeUnmount(() => {
	window.removeEventListener('resize', updateTipPosition)
	window.removeEventListener('scroll', updateTipPosition, true)
})
</script>

<template>
	<details ref="detailsRef" class="info" @toggle="handleToggle">
		<summary class="trigger" aria-label="Info">
			<span aria-hidden="true">i</span>
		</summary>

		<div ref="tipRef" class="tip" role="note">
			{{ text }}
		</div>
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
	width: 24px;
	height: 24px;
	display: inline-flex;
	align-items: center;
	justify-content: center;
	border-radius: 999px;
	border: 1px solid rgba(255, 255, 255, 0.18);
	background: rgba(0, 0, 0, 0.18);
	color: rgba(255, 255, 255, 0.82);
	font-size: 13px;
	font-weight: 700;
	line-height: 1;
	cursor: pointer;
	user-select: none;
}

.trigger::-webkit-details-marker {
	display: none;
}

.tip {
	position: fixed;
	left: var(--tip-left, 50%);
	top: var(--tip-top, 0);
	transform: var(--tip-transform, translateX(-50%));
	width: min(340px, calc(100vw - 24px));
	padding: 0.75rem 0.85rem;
	border-radius: 14px;
	background: rgba(20, 19, 31, 0.98);
	border: 1px solid rgba(255, 255, 255, 0.1);
	box-shadow: var(--shadow);
	color: rgba(255, 255, 255, 0.86);
	white-space: pre-line;
	line-height: 1.45;
	font-size: 0.9rem;
	z-index: 1000;
}

.info:not([open]) .tip {
	display: none;
}
</style>
