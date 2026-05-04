<script setup>
import { computed } from 'vue'

const props = defineProps({
	label: { type: String, default: '' },
	modelValue: { type: [Number, String], default: 0 },
	min: { type: Number, default: -9999 },
	max: { type: Number, default: 9999 },
	step: { type: [Number, String], default: 'any' }
})

const emit = defineEmits(['update:modelValue'])

const inputValue = computed({
	get() {
		return props.modelValue
	},
	set(v) {
		if (v === '') {
			emit('update:modelValue', '')
			return
		}

		const num = Number(v)
		if (!Number.isNaN(num)) emit('update:modelValue', num)
	}
})
</script>

<template>
	<label class="field">
		<span>{{ label }}</span>
		<input
			v-model="inputValue"
			type="number"
			:min="min"
			:max="max"
			:step="step"
			inputmode="decimal"
		/>
	</label>
</template>

<style scoped>
.field {
	display: flex;
	flex-direction: column;
	gap: 0.45rem;
	margin-bottom: 0.95rem;
	width: 100%;
}

span {
	color: var(--muted-text);
	font-size: 0.92rem;
}

input {
	width: 100%;
	min-height: 44px;
	background: rgba(0, 0, 0, 0.18);
	color: white;
	border: 1px solid rgba(255, 255, 255, 0.1);
	border-radius: 14px;
	padding: 0.8rem 0.9rem;
	font: inherit;
	outline: none;
}

input:focus {
	border-color: var(--blue);
	box-shadow: 0 0 0 3px rgba(47, 193, 232, 0.16);
}

input[type='number']::-webkit-inner-spin-button {
	filter: invert(1);
}
</style>
